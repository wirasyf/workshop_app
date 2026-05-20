import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/workshop_provider.dart';

class WorkOrderFormScreen extends ConsumerStatefulWidget {
  const WorkOrderFormScreen({super.key});
  @override
  ConsumerState<WorkOrderFormScreen> createState() => _WorkOrderFormScreenState();
}

class _WorkOrderFormScreenState extends ConsumerState<WorkOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _complaintCtrl = TextEditingController();
  bool _isLoading = false;
  String? _existingVehicleId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _plateCtrl.dispose();
    _brandCtrl.dispose();
    _typeCtrl.dispose();
    _yearCtrl.dispose();
    _complaintCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchByPlate() async {
    final plate = _plateCtrl.text.trim().toUpperCase();
    if (plate.isEmpty) return;
    final db = ref.read(databaseProvider);
    final vehicle = await db.getVehicleByPlateNumber(plate);
    if (vehicle != null && mounted) {
      setState(() {
        _existingVehicleId = vehicle.id;
        _nameCtrl.text = vehicle.customerName;
        _phoneCtrl.text = vehicle.phoneNumber ?? '';
        _brandCtrl.text = vehicle.vehicleBrand ?? '';
        _typeCtrl.text = vehicle.vehicleType ?? '';
        _yearCtrl.text = vehicle.vehicleYear?.toString() ?? '';
      });
      AppToast.show(context, 'Data pelanggan ditemukan!', type: ToastType.success);
    }
  }

  Future<void> _createWorkOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final db = ref.read(databaseProvider);
    final syncService = ref.read(syncServiceProvider);
    final user = ref.read(authStateProvider).value;
    final uuid = const Uuid();
    try {
      String vehicleId;
      if (_existingVehicleId != null) {
        vehicleId = _existingVehicleId!;
        await db.updateVehicle(VehiclesCompanion(
          id: Value(vehicleId),
          customerName: Value(_nameCtrl.text.trim()),
          phoneNumber: Value(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
          plateNumber: Value(_plateCtrl.text.trim().toUpperCase()),
          vehicleBrand: Value(_brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim()),
          vehicleType: Value(_typeCtrl.text.trim().isEmpty ? null : _typeCtrl.text.trim()),
          vehicleYear: Value(int.tryParse(_yearCtrl.text)),
        ));
        await syncService.enqueue(tableName: 'vehicles', recordId: vehicleId, operation: 'update', data: {
          'customer_name': _nameCtrl.text.trim(),
          'phone_number': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'plate_number': _plateCtrl.text.trim().toUpperCase(),
          'vehicle_brand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          'vehicle_type': _typeCtrl.text.trim().isEmpty ? null : _typeCtrl.text.trim(),
          'vehicle_year': int.tryParse(_yearCtrl.text),
        });
      } else {
        vehicleId = uuid.v4();
        final vehicleData = {
          'id': vehicleId,
          'customer_name': _nameCtrl.text.trim(),
          'phone_number': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'plate_number': _plateCtrl.text.trim().toUpperCase(),
          'vehicle_brand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          'vehicle_type': _typeCtrl.text.trim().isEmpty ? null : _typeCtrl.text.trim(),
          'vehicle_year': int.tryParse(_yearCtrl.text),
          'created_at': DateTime.now().toIso8601String(),
        };
        await db.insertVehicle(VehiclesCompanion.insert(
          id: vehicleId,
          customerName: _nameCtrl.text.trim(),
          phoneNumber: Value(vehicleData['phone_number'] as String?),
          plateNumber: vehicleData['plate_number'] as String,
          vehicleBrand: Value(vehicleData['vehicle_brand'] as String?),
          vehicleType: Value(vehicleData['vehicle_type'] as String?),
          vehicleYear: Value(vehicleData['vehicle_year'] as int?),
        ));
        await syncService.enqueue(tableName: 'vehicles', recordId: vehicleId, operation: 'create', data: vehicleData);
      }
      final orderNo = await db.getNextOrderNo();
      final woId = uuid.v4();
      final woData = {
        'id': woId,
        'order_no': orderNo,
        'vehicle_id': vehicleId,
        'user_id': user?.id ?? '1',
        'status': 'waiting',
        'complaint': _complaintCtrl.text.trim().isEmpty ? null : _complaintCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      };
      await db.insertWorkOrder(WorkOrdersCompanion.insert(
        id: woId,
        orderNo: orderNo,
        vehicleId: vehicleId,
        userId: user?.id ?? '1',
        complaint: Value(woData['complaint']),
      ));
      await syncService.enqueue(tableName: 'work_orders', recordId: woId, operation: 'create', data: woData);
      HapticFeedback.heavyImpact();
      ref.invalidate(activeWorkOrdersProvider);
      ref.invalidate(workOrdersProvider);
      ref.invalidate(todayWorkOrdersProvider);
      ref.invalidate(vehiclesProvider);
      if (mounted) {
        AppToast.show(context, 'Work Order $orderNo berhasil dibuat!', type: ToastType.success);
        context.go('/workshop/$woId');
      }
    } catch (e) {
      if (mounted) AppToast.show(context, 'Gagal: $e', type: ToastType.error);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/workshop');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Work Order Baru'),
          leading: IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => context.go('/workshop')),
        ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Info Pelanggan & Kendaraan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plateCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Plat Nomor *', hintText: 'B 1234 XYZ',
                prefixIcon: const Icon(Icons.directions_car_rounded),
                suffixIcon: IconButton(icon: const Icon(Icons.search_rounded), tooltip: 'Cari pelanggan', onPressed: _searchByPlate),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Plat nomor wajib diisi' : null,
              onFieldSubmitted: (_) => _searchByPlate(),
            ),
            if (_existingVehicleId != null)
              Padding(padding: const EdgeInsets.only(top: 4),
                child: Text('✓ Pelanggan terdaftar', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600))),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Pelanggan *', prefixIcon: Icon(Icons.person_rounded)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'No. HP', hintText: '08xxx', prefixIcon: Icon(Icons.phone_rounded)),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _brandCtrl, decoration: const InputDecoration(labelText: 'Merk Motor', hintText: 'Honda', prefixIcon: Icon(Icons.two_wheeler_rounded)))),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _typeCtrl, decoration: const InputDecoration(labelText: 'Tipe Motor', hintText: 'Beat'))),
            ]),
            const SizedBox(height: 16),
            TextFormField(controller: _yearCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tahun', hintText: '2024', prefixIcon: Icon(Icons.calendar_today_rounded))),
            const SizedBox(height: 24),
            Text('Keluhan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(controller: _complaintCtrl, maxLines: 4,
              decoration: const InputDecoration(labelText: 'Keluhan Pelanggan', hintText: 'Jelaskan keluhan...', alignLabelWithHint: true,
                prefixIcon: Padding(padding: EdgeInsets.only(bottom: 60), child: Icon(Icons.report_problem_rounded)))),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _createWorkOrder,
                icon: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.receipt_long_rounded),
                label: const Text('Buat Work Order'),
              )),
          ],
        ),
      ),
    ));
  }
}
