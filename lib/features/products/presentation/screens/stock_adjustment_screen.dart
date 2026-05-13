import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../dashboard/presentation/screens/notification_screen.dart';
import '../../../dashboard/presentation/screens/owner_dashboard_screen.dart';
import '../providers/product_provider.dart';
import 'package:uuid/uuid.dart';
/// Form penyesuaian stok manual
class StockAdjustmentScreen extends ConsumerStatefulWidget {
  final String productId;
  const StockAdjustmentScreen({super.key, required this.productId});

  @override
  ConsumerState<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _type = 'correction';
  bool _isAdd = true;
  bool _isLoading = false;

  final _types = {
    'correction': 'Koreksi',
    'opname': 'Stock Opname',
    'damaged': 'Rusak',
    'lost': 'Hilang',
  };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final db = ref.read(databaseProvider);
    final user = ref.read(authStateProvider).value;
    final qty = int.parse(_qtyCtrl.text);
    final change = _isAdd ? qty : -qty;

    try {
      final id = const Uuid().v4();
      await db.insertStockAdjustment(StockAdjustmentsCompanion.insert(
        id: id,
        productId: widget.productId,
        userId: user?.id ?? '1',
        type: _type,
        qtyChange: change,
        reason: Value(_reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim()),
      ));
      await db.updateStock(widget.productId, change);
      ref.invalidate(productsProvider);
      ref.invalidate(productDetailProvider(widget.productId));
      ref.invalidate(notificationNotifierProvider);
      ref.invalidate(ownerDashboardProvider);

      if (mounted) {
        AppToast.show(context, 'Stok ${_isAdd ? "ditambah" : "dikurangi"} $qty', type: ToastType.success);
        context.go('/products/${widget.productId}');
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Error: $e', type: ToastType.error);
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() { _qtyCtrl.dispose(); _reasonCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesuaikan Stok'),
        leading: IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => context.go('/products/${widget.productId}')),
      ),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (product) {
          if (product == null) return const Center(child: Text('Produk tidak ditemukan'));
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info produk
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.inventory_2_rounded, color: AppColors.info),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(product.name, style: theme.textTheme.titleSmall),
                      Text('Stok saat ini: ${product.stockQty} ${product.unit}', style: theme.textTheme.bodySmall),
                    ])),
                  ]),
                ),
                const SizedBox(height: 20),

                // Tipe penyesuaian
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Tipe Penyesuaian'),
                  items: _types.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 16),

                // Tambah / Kurang
                Row(children: [
                  Expanded(child: _toggleButton('Tambah', true, Icons.add_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _toggleButton('Kurangi', false, Icons.remove_rounded)),
                ]),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Jumlah *'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Wajib diisi';
                    final n = int.tryParse(v);
                    if (n == null || n <= 0) return 'Harus angka positif';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Alasan (opsional)'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan Penyesuaian'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _toggleButton(String label, bool isAddOption, IconData icon) {
    final selected = _isAdd == isAddOption;
    return ChoiceChip(
      label: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: selected ? Colors.white : AppColors.primary),
        const SizedBox(width: 8),
        Text(label),
      ]),
      selected: selected,
      onSelected: (_) => setState(() => _isAdd = isAddOption),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.infoLight,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.primary,
        fontWeight: selected ? FontWeight.bold : FontWeight.w600,
        fontSize: 13,
      ),
      side: const BorderSide(color: Colors.transparent),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
