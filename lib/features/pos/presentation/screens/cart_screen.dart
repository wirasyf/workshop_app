import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/screens/owner_dashboard_screen.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../reports/presentation/screens/report_screen.dart';
import '../providers/cart_provider.dart';

/// Layar keranjang & pembayaran
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _paidCtrl = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() { _paidCtrl.dispose(); super.dispose(); }

  Future<void> _processPayment() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final total = ref.read(cartTotalProvider);
    final method = ref.read(paymentMethodProvider);
    final paid = double.tryParse(_paidCtrl.text.replaceAll('.', '')) ?? 0;

    if (method == 'cash' && paid < total) {
      AppToast.show(context, 'Jumlah bayar kurang', type: ToastType.error);
      return;
    }

    setState(() => _isProcessing = true);
    final db = ref.read(databaseProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    final subtotal = ref.read(cartSubtotalProvider);
    final discount = ref.read(cartDiscountProvider);
    final change = method == 'cash' ? paid - total : 0.0;
    final invoiceNo = 'INV-${DateTime.now().millisecondsSinceEpoch}';

    try {
      await db.transaction(() async {
        // 1. Insert transaksi header
        final txnId = await db.insertTransaction(TransactionsCompanion.insert(
          invoiceNo: invoiceNo,
          cashierId: user?.id ?? 1,
          paymentMethod: Value(method),
          subtotal: Value(subtotal),
          discount: Value(discount),
          total: Value(total),
          paidAmount: Value(method == 'cash' ? paid : total),
          changeAmount: Value(change),
          createdAt: Value(DateTime.now()),
        ));

        // 2. Insert items & kurangi stok
        for (final item in cart) {
          await db.insertTransactionItem(TransactionItemsCompanion.insert(
            transactionId: txnId,
            productId: item.productId,
            qty: item.qty,
            unitPrice: item.unitPrice,
            discount: Value(item.discount),
            subtotal: item.subtotal,
          ));
          await db.updateStock(item.productId, -item.qty);
        }
      });

      // Feedback & Cleanup
      HapticFeedback.heavyImpact();

      // Reset cart
      ref.read(cartProvider.notifier).clear();
      ref.read(cartDiscountProvider.notifier).state = 0;
      ref.read(paidAmountProvider.notifier).state = 0;

      // Invalidate providers to refresh data
      ref.invalidate(productsProvider);
      ref.invalidate(ownerDashboardProvider);
      ref.invalidate(reportDataProvider);

      if (mounted) {
        context.go('/pos/success', extra: {
          'invoiceNo': invoiceNo,
          'items': cart.toList(),
          'total': total,
          'paid': method == 'cash' ? paid : total,
          'change': change,
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Pembayaran Gagal: $e', type: ToastType.error);
      }
    }
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final discount = ref.watch(cartDiscountProvider);
    final total = ref.watch(cartTotalProvider);
    final method = ref.watch(paymentMethodProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/pos')),
        actions: [
          if (cart.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => ref.read(cartProvider.notifier).clear()),
        ],
      ),
      body: cart.isEmpty
          ? const Center(child: Text('Keranjang kosong'))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemBuilder: (_, i) {
                      final item = cart[i];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item.name, style: theme.textTheme.titleSmall),
                              Text('${CurrencyFormatter.format(item.unitPrice)} × ${item.qty}', style: theme.textTheme.bodySmall),
                            ]),
                          ),
                          // Qty controls
                          Row(children: [
                            _qtyButton(Icons.remove, () => ref.read(cartProvider.notifier).updateQty(item.productId, item.qty - 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('${item.qty}', style: theme.textTheme.titleSmall),
                            ),
                            _qtyButton(Icons.add, () => ref.read(cartProvider.notifier).updateQty(item.productId, item.qty + 1)),
                          ]),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 85,
                            child: Text(CurrencyFormatter.format(item.subtotal), style: theme.textTheme.titleSmall, textAlign: TextAlign.right),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Payment section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    border: const Border(top: BorderSide(color: AppColors.border)),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _summaryRow('Subtotal', CurrencyFormatter.format(subtotal)),
                    if (discount > 0) _summaryRow('Diskon', '-${CurrencyFormatter.format(discount)}'),
                    const Divider(),
                    _summaryRow('Total', CurrencyFormatter.format(total), bold: true),
                    const SizedBox(height: 12),

                    // Metode bayar
                    Row(children: [
                      for (final m in ['cash', 'transfer', 'qris'])
                        Expanded(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(m == 'cash' ? 'Tunai' : m == 'transfer' ? 'Transfer' : 'QRIS'),
                            selected: method == m,
                            onSelected: (_) => ref.read(paymentMethodProvider.notifier).state = m,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.infoLight,
                            labelStyle: TextStyle(
                              color: method == m ? Colors.white : AppColors.primary,
                              fontWeight: method == m ? FontWeight.bold : FontWeight.w600,
                              fontSize: 13,
                            ),
                            side: const BorderSide(color: Colors.transparent),
                            showCheckmark: false,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )),
                    ]),
                    const SizedBox(height: 12),

                    // Jumlah bayar (tunai)
                    if (method == 'cash') ...[
                      TextField(
                        controller: _paidCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Jumlah Bayar',
                          prefixText: 'Rp ',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _paidCtrl.clear(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Quick Pay Buttons
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _quickPayButton('Uang Pas', total),
                            _quickPayButton('Rp 50rb', 50000),
                            _quickPayButton('Rp 100rb', 100000),
                            if (total > 100000) _quickPayButton('Rp 200rb', 200000),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _processPayment,
                        child: _isProcessing
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Proses Pembayaran'),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16),
    ),
  );

  Widget _quickPayButton(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          setState(() {
            _paidCtrl.text = amount.toStringAsFixed(0);
          });
        },
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      Text(value, style: TextStyle(fontSize: bold ? 18 : 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? AppColors.primary : null)),
    ]),
  );
}
