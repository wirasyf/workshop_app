import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../../main.dart';

class ReceiptTemplateScreen extends ConsumerStatefulWidget {
  const ReceiptTemplateScreen({super.key});

  @override
  ConsumerState<ReceiptTemplateScreen> createState() => _ReceiptTemplateScreenState();
}

class _ReceiptTemplateScreenState extends ConsumerState<ReceiptTemplateScreen> {
  late TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsServiceProvider);
    _footerCtrl = TextEditingController(text: settings.receiptFooter);
  }

  @override
  void dispose() {
    _footerCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    await ref.read(settingsServiceProvider).setReceiptFooter(_footerCtrl.text.trim());
    if (mounted) {
      AppToast.show(context, 'Template struk berhasil disimpan', type: ToastType.success);
      context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Template Struk')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Header Struk menggunakan informasi dari Profil Toko.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          _field(_footerCtrl, 'Footer / Pesan Bawah Struk', maxLines: 3),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('Simpan Perubahan'),
            ),
          ),
          const SizedBox(height: 40),
          const Text('Preview Struk dapat dilihat di layar sukses pembayaran setelah melakukan transaksi.', 
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textHint), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: 'Contoh: Barang yang sudah dibeli tidak dapat ditukar'),
      ),
    );
  }
}
