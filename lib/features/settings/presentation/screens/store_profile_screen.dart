import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
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
  late TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsServiceProvider);
    _nameCtrl = TextEditingController(text: settings.storeName)..addListener(_onTextChanged);
    _addressCtrl = TextEditingController(text: settings.storeAddress)..addListener(_onTextChanged);
    _phoneCtrl = TextEditingController(text: settings.storePhone)..addListener(_onTextChanged);
    _footerCtrl = TextEditingController(text: settings.receiptFooter)..addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onTextChanged);
    _addressCtrl.removeListener(_onTextChanged);
    _phoneCtrl.removeListener(_onTextChanged);
    _footerCtrl.removeListener(_onTextChanged);
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    final settings = ref.read(settingsServiceProvider);
    await settings.setStoreInfo(
      _nameCtrl.text.trim(),
      _addressCtrl.text.trim(),
      _phoneCtrl.text.trim(),
    );
    await settings.setReceiptFooter(_footerCtrl.text.trim());
    if (mounted) {
      AppToast.show(context, 'Profil & Struk berhasil disimpan', type: ToastType.success);
      context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/settings');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profil & Struk Toko'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => context.go('/settings'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Informasi Toko (Header Struk)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            _field(_nameCtrl, 'Nama Toko'),
            _field(_addressCtrl, 'Alamat Toko', maxLines: 3),
            _field(_phoneCtrl, 'Nomor Telepon', keyboard: TextInputType.phone),
            const Divider(height: 32),
            const Text(
              'Pengaturan Struk Belanja',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            _field(_footerCtrl, 'Catatan Kaki / Footer Struk', maxLines: 3, hint: 'Contoh: Barang yang sudah dibeli tidak dapat ditukar/dikembalikan'),
            const SizedBox(height: 24),
            const Text(
              'Preview Struk Belanja',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            _ReceiptPreview(
              name: _nameCtrl.text,
              address: _addressCtrl.text,
              phone: _phoneCtrl.text,
              footer: _footerCtrl.text,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Simpan Perubahan'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1, TextInputType keyboard = TextInputType.text, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
      ),
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  final String name;
  final String address;
  final String phone;
  final String footer;

  const _ReceiptPreview({
    required this.name,
    required this.address,
    required this.phone,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTearEdge(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Text(
                  name.isEmpty ? 'NAMA TOKO' : name.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Telp: $phone',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 12),
                _buildDottedLine(),
                const SizedBox(height: 12),
                _buildReceiptItem('Oli Mesin MPX 2', '1', 'Rp 45.000'),
                _buildReceiptItem('Busi Honda Supra', '2', 'Rp 30.000'),
                const SizedBox(height: 12),
                _buildDottedLine(),
                const SizedBox(height: 12),
                _buildTotalRow('Total', 'Rp 75.000'),
                _buildTotalRow('Bayar', 'Rp 100.000'),
                _buildTotalRow('Kembali', 'Rp 25.000'),
                const SizedBox(height: 12),
                _buildDottedLine(),
                const SizedBox(height: 12),
                Text(
                  footer.isEmpty ? 'Terima kasih atas kunjungan Anda' : footer,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          _buildTearEdge(),
        ],
      ),
    );
  }

  Widget _buildTearEdge() {
    return Row(
      children: List.generate(
        16,
        (index) => Expanded(
          child: CustomPaint(
            size: const Size(double.infinity, 6),
            painter: _TrianglePainter(),
          ),
        ),
      ),
    );
  }

  Widget _buildDottedLine() {
    return Row(
      children: List.generate(
        35,
        (index) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            height: 1,
            color: Colors.grey.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptItem(String itemName, String qty, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              itemName,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
          Text(
            '$qty x ',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          Text(
            price,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
