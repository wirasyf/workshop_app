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
import '../../../dashboard/presentation/screens/notification_screen.dart';
import 'package:uuid/uuid.dart';
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
    final user = ref.read(authStateProvider).value;
    final subtotal = ref.read(cartSubtotalProvider);
    final discount = ref.read(cartDiscountProvider);
    final change = method == 'cash' ? paid - total : 0.0;
    final uuid = const Uuid();
    final txnId = uuid.v4();
    final invoiceNo = 'INV-${DateTime.now().millisecondsSinceEpoch}';

    try {
      await db.transaction(() async {
        // 1. Insert transaksi header
        final txnCompanion = TransactionsCompanion.insert(
          id: txnId,
          invoiceNo: invoiceNo,
          userId: user?.id ?? '1',
          paymentMethod: Value(method),
          subtotal: Value(subtotal),
          discount: Value(discount),
          total: Value(total),
          paidAmount: Value(method == 'cash' ? paid : total),
          changeAmount: Value(change),
          createdAt: Value(DateTime.now()),
        );
        await db.insertTransaction(txnCompanion);

        // Enqueue sync untuk header
        final syncService = ref.read(syncServiceProvider);
        await syncService.enqueue(
          tableName: 'transactions',
          recordId: txnId,
          operation: 'create',
          data: {
            'id': txnId,
            'invoice_no': invoiceNo,
            'user_id': user?.id ?? '1',
            'payment_method': method,
            'subtotal': subtotal,
            'discount': discount,
            'total': total,
            'paid_amount': method == 'cash' ? paid : total,
            'change_amount': change,
            'created_at': DateTime.now().toIso8601String(),
          },
        );

        // 2. Insert items & kurangi stok (hanya untuk produk)
        for (final item in cart) {
          final itemId = uuid.v4();
          final itemCompanion = TransactionItemsCompanion.insert(
            id: itemId,
            transactionId: txnId,
            itemType: Value(item.type == CartItemType.service ? 'service' : 'product'),
            productId: item.type == CartItemType.product ? Value(item.productId) : const Value(null),
            serviceId: item.type == CartItemType.service ? Value(item.productId) : const Value(null),
            qty: item.qty,
            unitPrice: item.unitPrice,
            discount: Value(item.discount),
            subtotal: item.subtotal,
          );
          await db.insertTransactionItem(itemCompanion);

          // Enqueue sync untuk item
          await syncService.enqueue(
            tableName: 'transaction_items',
            recordId: itemId,
            operation: 'create',
            data: {
              'id': itemId,
              'transaction_id': txnId,
              'item_type': item.type == CartItemType.service ? 'service' : 'product',
              'product_id': item.type == CartItemType.product ? item.productId : null,
              'service_id': item.type == CartItemType.service ? item.productId : null,
              'qty': item.qty,
              'unit_price': item.unitPrice,
              'discount': item.discount,
              'subtotal': item.subtotal,
            },
          );

          // Kurangi stok hanya untuk produk (bukan jasa)
          if (item.type == CartItemType.product) {
            await db.updateStock(item.productId, -item.qty);
            
            final updatedProduct = await db.getProductById(item.productId);
            if (updatedProduct != null) {
              await syncService.enqueue(
                tableName: 'products',
                recordId: item.productId,
                operation: 'update',
                data: {'stock_qty': updatedProduct.stockQty},
              );
            }
          }
        }
      });

      // Feedback & Cleanup
      HapticFeedback.heavyImpact();

      // Reset cart
      ref.read(cartProvider.notifier).clear();
      ref.read(cartDiscountProvider.notifier).state = 0;
      ref.read(paidAmountProvider.notifier).state = 0;

      // Cek stok menipis (hanya produk)
      bool hasLowStock = false;
      List<String> lowStockNames = [];
      for (final item in cart) {
        if (item.type == CartItemType.product) {
          final p = await db.getProductById(item.productId);
          if (p != null && p.stockQty <= p.stockMin) {
            hasLowStock = true;
            lowStockNames.add(p.name);
          }
        }
      }

      // Invalidate providers to refresh data
      ref.invalidate(productsProvider);
      ref.invalidate(ownerDashboardProvider);
      ref.invalidate(reportDataProvider);
      ref.invalidate(notificationNotifierProvider);

      if (mounted) {
        if (hasLowStock) {
          AppToast.show(context, 'Peringatan: Stok menipis untuk ${lowStockNames.join(', ')}', type: ToastType.warning, duration: const Duration(seconds: 4));
        }
        
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
    final serviceSubtotal = ref.watch(cartServiceSubtotalProvider);
    final partsSubtotal = ref.watch(cartPartsSubtotalProvider);
    final discount = ref.watch(cartDiscountProvider);
    final total = ref.watch(cartTotalProvider);
    final method = ref.watch(paymentMethodProvider);
    final theme = Theme.of(context);

    final hasServices = cart.any((i) => i.type == CartItemType.service);
    final hasParts = cart.any((i) => i.type == CartItemType.product);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang'),
        leading: IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => context.go('/pos')),
        actions: [
          if (cart.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_rounded), onPressed: () => ref.read(cartProvider.notifier).clear()),
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
                      final isService = item.type == CartItemType.service;
                      return Row(
                        children: [
                          // Icon tipe
                          Container(
                            padding: const EdgeInsets.all(6),
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: (isService ? AppColors.info : AppColors.primary).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isService ? Icons.build_rounded : Icons.settings_rounded,
                              size: 16,
                              color: isService ? AppColors.info : AppColors.primary,
                            ),
                          ),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item.name, style: theme.textTheme.titleSmall),
                              Text('${CurrencyFormatter.format(item.unitPrice)} × ${item.qty}', style: theme.textTheme.bodySmall),
                            ]),
                          ),
                          // Qty controls
                          Row(children: [
                            _qtyButton(Icons.remove_rounded, () => ref.read(cartProvider.notifier).updateQty(item.productId, item.qty - 1, item.type)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('${item.qty}', style: theme.textTheme.titleSmall),
                            ),
                            _qtyButton(Icons.add_rounded, () => ref.read(cartProvider.notifier).updateQty(item.productId, item.qty + 1, item.type)),
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
                    if (hasServices && hasParts) ...[
                      _summaryRow('Subtotal Jasa', CurrencyFormatter.format(serviceSubtotal), color: AppColors.info),
                      _summaryRow('Subtotal Sparepart', CurrencyFormatter.format(partsSubtotal)),
                      const Divider(height: 12),
                    ],
                    _summaryRow('Subtotal', CurrencyFormatter.format(subtotal)),
                    // Diskon Global
                    InkWell(
                      onTap: () => _showDiscountDialog(context, ref),
                      child: _summaryRow(
                        'Diskon', 
                        discount > 0 ? '-${CurrencyFormatter.format(discount)}' : 'Tambah Diskon',
                        color: discount > 0 ? AppColors.error : AppColors.primary,
                      ),
                    ),
                    const Divider(),
                    _summaryRow('Total', CurrencyFormatter.format(total), bold: true),
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
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => _paidCtrl.clear(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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

  Widget _summaryRow(String label, String value, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      Text(value, style: TextStyle(fontSize: bold ? 18 : 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color ?? (bold ? AppColors.primary : null))),
    ]),
  );

  void _showDiscountDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: ref.read(cartDiscountProvider).toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diskon Global'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Jumlah Diskon', prefixText: 'Rp '),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final d = double.tryParse(ctrl.text) ?? 0;
              ref.read(cartDiscountProvider.notifier).state = d;
              Navigator.pop(context);
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
  }
}
