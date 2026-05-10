import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../../main.dart';

class StoreProfileScreen extends ConsumerStatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  ConsumerState<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends ConsumerState<StoreProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsServiceProvider);
    _nameCtrl = TextEditingController(text: settings.storeName);
    _addressCtrl = TextEditingController(text: settings.storeAddress);
    _phoneCtrl = TextEditingController(text: settings.storePhone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    await ref.read(settingsServiceProvider).setStoreInfo(
      _nameCtrl.text.trim(),
      _addressCtrl.text.trim(),
      _phoneCtrl.text.trim(),
    );
    if (mounted) {
      AppToast.show(context, 'Profil toko berhasil disimpan', type: ToastType.success);
      context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Toko')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_nameCtrl, 'Nama Toko'),
          _field(_addressCtrl, 'Alamat Toko', maxLines: 3),
          _field(_phoneCtrl, 'Nomor Telepon', keyboard: TextInputType.phone),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('Simpan Perubahan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1, TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
