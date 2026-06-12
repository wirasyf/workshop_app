import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
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
    try {
      final snap = await FirebaseFirestore.instance.collection('vehicles').where('plateNumber', isEqualTo: plate).limit(1).get();
      if (snap.docs.isNotEmpty && mounted) {
        final vehicle = snap.docs.first.data();
        setState(() {
          _existingVehicleId = snap.docs.first.id;
          _nameCtrl.text = vehicle['customerName'] ?? '';
          _phoneCtrl.text = vehicle['phoneNumber'] ?? '';
          _brandCtrl.text = vehicle['vehicleBrand'] ?? '';
          _typeCtrl.text = vehicle['vehicleType'] ?? '';
          _yearCtrl.text = vehicle['vehicleYear']?.toString() ?? '';
        });
        AppToast.show(context, 'Data pelanggan ditemukan!', type: ToastType.success);
      }
    } catch (e) {
      debugPrint('Error searching vehicle: $e');
    }
  }

  Future<String> _getNextOrderNo() async {
    final now = DateTime.now();
    return 'WO-${now.millisecondsSinceEpoch}';
  }

  Future<void> _createWorkOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final user = ref.read(authStateProvider).value;
    final uuid = const Uuid();
    
    try {
      String vehicleId;
      if (_existingVehicleId != null) {
        vehicleId = _existingVehicleId!;
        await FirebaseFirestore.instance.collection('vehicles').doc(vehicleId).update({
          'customerName': _nameCtrl.text.trim(),
          'phoneNumber': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'plateNumber': _plateCtrl.text.trim().toUpperCase(),
          'vehicleBrand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          'vehicleType': _typeCtrl.text.trim().isEmpty ? null : _typeCtrl.text.trim(),
          'vehicleYear': int.tryParse(_yearCtrl.text),
        });
      } else {
        vehicleId = uuid.v4();
        await FirebaseFirestore.instance.collection('vehicles').doc(vehicleId).set({
          'id': vehicleId,
          'customerName': _nameCtrl.text.trim(),
          'phoneNumber': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'plateNumber': _plateCtrl.text.trim().toUpperCase(),
          'vehicleBrand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          'vehicleType': _typeCtrl.text.trim().isEmpty ? null : _typeCtrl.text.trim(),
          'vehicleYear': int.tryParse(_yearCtrl.text),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      final orderNo = await _getNextOrderNo();
      final woId = uuid.v4();
      
      await FirebaseFirestore.instance.collection('work_orders').doc(woId).set({
        'id': woId,
        'orderNo': orderNo,
        'vehicleId': vehicleId,
        'userId': user?.id ?? '1',
        'status': 'waiting',
        'complaint': _complaintCtrl.text.trim().isEmpty ? null : _complaintCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      
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
              const Padding(padding: EdgeInsets.only(top: 4),
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
              validator: (v) {
                if (v != null && v.isNotEmpty) {
                  if (!RegExp(r'^[0-9]+$').hasMatch(v)) return 'Format nomor HP salah';
                  if (v.length < 9) return 'Nomor HP terlalu pendek';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _brandCtrl, decoration: const InputDecoration(labelText: 'Merk Motor', hintText: 'Honda', prefixIcon: Icon(Icons.two_wheeler_rounded)))),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _typeCtrl, decoration: const InputDecoration(labelText: 'Tipe Motor', hintText: 'Beat'))),
            ]),
            const SizedBox(height: 16),
            TextFormField(controller: _yearCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tahun', hintText: '2024', prefixIcon: Icon(Icons.calendar_today_rounded)),
              validator: (v) {
                if (v != null && v.isNotEmpty) {
                  final year = int.tryParse(v);
                  if (year == null || year < 1990 || year > DateTime.now().year) return 'Tahun tidak valid';
                }
                return null;
              },
            ),
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
