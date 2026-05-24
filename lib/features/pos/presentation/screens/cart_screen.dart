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
import '../../../../core/services/notification_service.dart';
import 'package:uuid/uuid.dart';
import '../../../dashboard/presentation/screens/staff_list_screen.dart';
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

    final hasServices = cart.any((i) => i.type == CartItemType.service);
    final selectedWorker = ref.read(cartSelectedWorkerProvider);
    if (hasServices && selectedWorker == null) {
      AppToast.show(context, 'Pilih mekanik / pekerja untuk jasa', type: ToastType.error);
      return;
    }

    final total = ref.read(cartTotalProvider);
    final method = ref.read(paymentMethodProvider);
    final paid = CurrencyFormatter.parse(_paidCtrl.text);

    if (method == 'cash' && paid < total) {
      AppToast.show(context, 'Jumlah bayar kurang', type: ToastType.error);
      return;
    }

    setState(() => _isProcessing = true);
    final db = ref.read(databaseProvider);
    
    // Validasi stok sebelum melanjutkan
    for (final item in cart) {
      if (item.type == CartItemType.product) {
        final p = await db.getProductById(item.productId);
        if (p == null || p.stockQty < item.qty) {
          if (mounted) {
            AppToast.show(context, 'Stok tidak mencukupi untuk ${item.name}. Sisa: ${p?.stockQty ?? 0}', type: ToastType.error);
            setState(() => _isProcessing = false);
          }
          return;
        }
      }
    }

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
          final isService = item.type == CartItemType.service;
          // Jasa perlu approval jika yang input adalah kasir
          final isApproved = !isService || (user?.role == 'owner');
          final workerName = isService ? selectedWorker : null;

          final itemCompanion = TransactionItemsCompanion.insert(
            id: itemId,
            transactionId: txnId,
            itemType: Value(isService ? 'service' : 'product'),
            productId: !isService ? Value(item.productId) : const Value(null),
            serviceId: isService ? Value(item.productId) : const Value(null),
            qty: item.qty,
            unitPrice: item.unitPrice,
            discount: Value(item.discount),
            subtotal: item.subtotal,
            isApproved: Value(isApproved),
            workerName: Value(workerName),
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
              'item_type': isService ? 'service' : 'product',
              'product_id': !isService ? item.productId : null,
              'service_id': isService ? item.productId : null,
              'qty': item.qty,
              'unit_price': item.unitPrice,
              'discount': item.discount,
              'subtotal': item.subtotal,
              'is_approved': isApproved,
              'worker_name': workerName,
            },
          );

          // Kurangi stok hanya untuk produk (bukan jasa)
          if (item.type == CartItemType.product) {
            await db.updateStock(item.productId, -item.qty);
            
            await syncService.enqueue(
              tableName: 'products',
              recordId: item.productId,
              operation: 'rpc_adjust_stock',
              data: {'qty_change': -item.qty},
            );
          }
        }
      });

      // Feedback & Cleanup
      HapticFeedback.heavyImpact();

      // Reset cart
      ref.read(cartProvider.notifier).clear();
      ref.read(cartDiscountProvider.notifier).state = 0;
      ref.read(paidAmountProvider.notifier).state = 0;

      // Cek stok menipis (hanya produk) & picu notifikasi OS
      bool hasLowStock = false;
      List<String> lowStockNames = [];
      final notifService = ref.read(notificationServiceProvider);
      final syncService = ref.read(syncServiceProvider);

      for (final item in cart) {
        if (item.type == CartItemType.product) {
          final p = await db.getProductById(item.productId);
          if (p != null && p.stockQty <= p.stockMin) {
            hasLowStock = true;
            lowStockNames.add(p.name);
            final isZero = p.stockQty == 0;
            final title = isZero ? 'Stok Habis: ${p.name}' : 'Stok Menipis: ${p.name}';
            final body = isZero 
                ? 'Stok produk ${p.name} sudah habis. Segera lakukan restok.'
                : 'Sisa stok ${p.name} tinggal ${p.stockQty} ${p.unit}.';
            notifService.showStockWarning(
              id: p.id.hashCode,
              title: title,
              body: body,
              isCritical: isZero,
            );
            await db.insertNotification(NotificationsCompanion.insert(
              title: title,
              message: body,
              type: isZero ? 'stock_critical' : 'stock_low',
              createdAt: Value(DateTime.now()),
            ));
            
            if (user?.role == 'cashier') {
              final notifId = const Uuid().v4();
              await syncService.enqueue(
                tableName: 'notifications',
                recordId: notifId,
                operation: 'create',
                data: {
                  'id': notifId,
                  'title': title,
                  'message': body,
                  'type': isZero ? 'stock_critical' : 'stock_low',
                  'target_role': 'owner',
                  'is_read': false,
                  'created_at': DateTime.now().toIso8601String(),
                },
              );
            }
          }
        }
      }

      await db.insertNotification(NotificationsCompanion.insert(
        title: 'Transaksi Sukses',
        message: 'Invoice $invoiceNo senilai ${CurrencyFormatter.format(total)} berhasil diproses.',
        type: 'transaction',
        createdAt: Value(DateTime.now()),
      ));
      
      if (user?.role == 'cashier') {
        final notifId = const Uuid().v4();
        await syncService.enqueue(
          tableName: 'notifications',
          recordId: notifId,
          operation: 'create',
          data: {
            'id': notifId,
            'title': 'Transaksi Sukses (Kasir)',
            'message': 'Kasir ${user?.name ?? ""} memproses Invoice $invoiceNo senilai ${CurrencyFormatter.format(total)}.',
            'type': 'transaction',
            'target_role': 'owner',
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          },
        );
      }

      final hasService = cart.any((i) => i.type == CartItemType.service);
      if (hasService && user?.role == 'cashier') {
        final notifId = const Uuid().v4();
        await syncService.enqueue(
          tableName: 'notifications',
          recordId: notifId,
          operation: 'create',
          data: {
            'id': notifId,
            'title': 'Menunggu Persetujuan Jasa',
            'message': 'Invoice $invoiceNo memiliki item jasa yang membutuhkan persetujuan Owner.',
            'type': 'approval_needed',
            'target_role': 'owner',
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          },
        );
      }

      // Langsung sync agar notifikasi Realtime seketika terkirim ke Owner
      // Gunakan timeout agar tidak blocking jika offline
      try {
        await syncService.syncPendingChanges().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⚠️ Sync timeout setelah 10 detik, lanjut offline');
          },
        );
        debugPrint('✅ Sync selesai, notifikasi terkirim ke cloud');
      } catch (e) {
        debugPrint('⚠️ Immediate sync failed (offline): $e');
      }

      // Invalidate providers to refresh data
      ref.invalidate(productsProvider);
      ref.invalidate(ownerDashboardProvider);
      ref.invalidate(reportDataProvider);
      ref.invalidate(notificationNotifierProvider);
      ref.invalidate(transactionHistoryProvider);

      // Create processed items with approval status for the success screen
      final processedItems = cart.map((item) {
        final isService = item.type == CartItemType.service;
        final isApproved = !isService || (user?.role == 'owner');
        return item.copyWith(isApproved: isApproved, workerName: isService ? selectedWorker : null);
      }).toList();

      ref.read(cartProvider.notifier).clear();
      ref.read(cartSelectedWorkerProvider.notifier).state = null;

      if (mounted) {
        if (hasLowStock) {
          AppToast.show(context, 'Peringatan: Stok menipis untuk ${lowStockNames.join(', ')}', type: ToastType.warning, duration: const Duration(seconds: 4));
        }
        context.go('/payment-success', extra: {
          'invoiceNo': invoiceNo,
          'items': processedItems,
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
    final staffAsync = ref.watch(staffProvider);
    final selectedWorker = ref.watch(cartSelectedWorkerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/pos');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Keranjang'),
          leading: IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => context.go('/pos')),
          actions: [
            if (cart.isNotEmpty)
              IconButton(icon: const Icon(Icons.delete_rounded), onPressed: () => ref.read(cartProvider.notifier).clear()),
          ],
        ),
      body: cart.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  const Text('Keranjang masih kosong', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/pos'),
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: const Text('Mulai Belanja'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
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
                            _qtyButton(Icons.remove_rounded, () => ref.read(cartProvider.notifier).updateQty(item.productId, item.qty - 1, item.type, item.workerName)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('${item.qty}', style: theme.textTheme.titleSmall),
                            ),
                            _qtyButton(Icons.add_rounded, () {
                              if (item.type == CartItemType.product) {
                                final products = ref.read(productsProvider).value ?? [];
                                final product = products.firstWhere(
                                  (p) => p.id == item.productId,
                                  orElse: () => throw Exception('Produk tidak ditemukan'),
                                );
                                if (item.qty >= product.stockQty) {
                                  AppToast.show(context, 'Stok maksimal tercapai (${product.stockQty})', type: ToastType.warning, duration: const Duration(seconds: 2));
                                  return;
                                }
                              }
                              ref.read(cartProvider.notifier).updateQty(item.productId, item.qty + 1, item.type, item.workerName);
                            }),
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
                    // Tombol tambah pesanan lainnya
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/pos'),
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                        label: const Text('Tambah Pesanan Lainnya', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        inputFormatters: [RupiahInputFormatter()],
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

                    // Pilihan mekanik jika ada jasa
                    if (hasServices) ...[
                      const SizedBox(height: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pilih Mekanik / Pekerja *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          staffAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text('Error: $e'),
                            data: (staff) {
                              final mechanics = staff.where((u) => u.role == 'mechanic').toList();
                              if (mechanics.isEmpty) {
                                return const Text('Belum ada data mekanik. Tambahkan di menu Kelola Karyawan.', style: TextStyle(color: AppColors.error, fontSize: 12));
                              }
                              return DropdownButtonFormField<String>(
                                value: selectedWorker,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.build_rounded, size: 18, color: AppColors.info),
                                  hintText: 'Pilih Mekanik / Pekerja',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: mechanics.map((u) {
                                  return DropdownMenuItem(
                                    value: u.name,
                                    child: Text(u.name, style: const TextStyle(fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  ref.read(cartSelectedWorkerProvider.notifier).state = val;
                                },
                              );
                            },
                          ),
                        ],
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
    ));
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
    final currentVal = ref.read(cartDiscountProvider);
    final ctrl = TextEditingController(text: currentVal > 0 ? CurrencyFormatter.formatNumber(currentVal) : '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diskon Global'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [RupiahInputFormatter()],
          decoration: const InputDecoration(labelText: 'Jumlah Diskon', prefixText: 'Rp '),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final d = CurrencyFormatter.parse(ctrl.text);
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
