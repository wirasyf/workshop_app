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
import '../providers/service_provider.dart';

/// Form tambah/edit jasa bengkel
class ServiceFormScreen extends ConsumerStatefulWidget {
  final String? serviceId;
  const ServiceFormScreen({super.key, this.serviceId});

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _timeCtrl = TextEditingController(text: '30');
  String _category = 'umum';
  bool _isActive = true;
  bool _isLoading = false;

  bool get isEditing => widget.serviceId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadService();
  }

  Future<void> _loadService() async {
    final db = ref.read(databaseProvider);
    final service = await db.getServiceById(widget.serviceId!);
    if (service != null && mounted) {
      setState(() {
        _nameCtrl.text = service.name;
        _descCtrl.text = service.description ?? '';
        _priceCtrl.text = service.price.toStringAsFixed(0);
        _timeCtrl.text = service.estimatedMinutes.toString();
        _category = service.category;
        _isActive = service.isActive;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final db = ref.read(databaseProvider);
    final syncService = ref.read(syncServiceProvider);
    final price = double.tryParse(_priceCtrl.text.replaceAll('.', '')) ?? 0;
    final estimatedMinutes = int.tryParse(_timeCtrl.text) ?? 30;

    try {
      if (isEditing) {
        final companion = ServicesCompanion(
          id: Value(widget.serviceId!),
          name: Value(_nameCtrl.text.trim()),
          description: Value(_descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim()),
          price: Value(price),
          estimatedMinutes: Value(estimatedMinutes),
          category: Value(_category),
          isActive: Value(_isActive),
        );
        await db.updateService(companion);

        await syncService.enqueue(
          tableName: 'services',
          recordId: widget.serviceId!,
          operation: 'update',
          data: {
            'id': widget.serviceId!,
            'name': _nameCtrl.text.trim(),
            'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            'price': price,
            'estimated_minutes': estimatedMinutes,
            'category': _category,
            'is_active': _isActive,
          },
        );
      } else {
        final id = const Uuid().v4();
        final companion = ServicesCompanion.insert(
          id: id,
          name: _nameCtrl.text.trim(),
          description: Value(_descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim()),
          price: Value(price),
          estimatedMinutes: Value(estimatedMinutes),
          category: Value(_category),
          isActive: Value(_isActive),
        );
        await db.insertService(companion);

        await syncService.enqueue(
          tableName: 'services',
          recordId: id,
          operation: 'create',
          data: {
            'id': id,
            'name': _nameCtrl.text.trim(),
            'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            'price': price,
            'estimated_minutes': estimatedMinutes,
            'category': _category,
            'is_active': _isActive,
            'created_at': DateTime.now().toIso8601String(),
          },
        );
      }

      HapticFeedback.mediumImpact();
      ref.invalidate(servicesProvider);
      ref.invalidate(filteredServicesProvider);
      ref.invalidate(allServicesProvider);

      if (mounted) {
        AppToast.show(context, isEditing ? 'Jasa berhasil diperbarui' : 'Jasa berhasil ditambahkan', type: ToastType.success);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Gagal menyimpan: $e', type: ToastType.error);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _deleteService() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Jasa'),
        content: const Text('Yakin ingin menghapus jasa ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final db = ref.read(databaseProvider);
    final syncService = ref.read(syncServiceProvider);
    await db.deleteService(widget.serviceId!);
    await syncService.enqueue(
      tableName: 'services',
      recordId: widget.serviceId!,
      operation: 'delete',
      data: {},
    );

    ref.invalidate(servicesProvider);
    ref.invalidate(filteredServicesProvider);
    ref.invalidate(allServicesProvider);

    if (mounted) {
      AppToast.show(context, 'Jasa dihapus', type: ToastType.success);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Jasa' : 'Tambah Jasa'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: AppColors.error),
              onPressed: _deleteService,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nama Jasa
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Jasa *',
                hintText: 'Contoh: Ganti Oli, Servis Rutin',
                prefixIcon: Icon(Icons.build_rounded),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama jasa wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Deskripsi
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
                hintText: 'Detail layanan (opsional)',
                prefixIcon: Icon(Icons.description_rounded),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Harga
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga *',
                prefixText: 'Rp ',
                prefixIcon: Icon(Icons.payments_rounded),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Harga wajib diisi';
                if (double.tryParse(v.replaceAll('.', '')) == null) return 'Masukkan angka valid';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Estimasi Waktu
            TextFormField(
              controller: _timeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimasi Waktu (menit)',
                suffixText: 'menit',
                prefixIcon: Icon(Icons.timer_rounded),
              ),
            ),
            const SizedBox(height: 16),

            // Kategori
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: ServiceCategories.all.map((c) =>
                DropdownMenuItem(value: c['value'], child: Text(c['label']!)),
              ).toList(),
              onChanged: (v) => setState(() => _category = v ?? 'umum'),
            ),
            const SizedBox(height: 16),

            // Status Aktif
            SwitchListTile(
              title: const Text('Status Aktif'),
              subtitle: Text(_isActive ? 'Jasa dapat dipilih di POS' : 'Jasa dinonaktifkan'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveService,
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEditing ? 'Simpan Perubahan' : 'Simpan Jasa'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
