import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../dashboard/presentation/screens/staff_list_screen.dart';
import '../providers/cart_provider.dart';
import '../../data/transaction_repository.dart';
import '../../../../core/models/transaction_model.dart';
import '../../../../core/services/direct_fcm_service.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../../shared/widgets/empty_state_widget.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _paidCtrl = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _paidCtrl.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final hasServices = cart.any((i) => i.type == CartItemType.service);
    final selectedWorker = ref.read(cartSelectedWorkerProvider);
    if (hasServices && selectedWorker == null) {
      AppToast.show(
        context,
        'Pilih mekanik / pekerja untuk jasa',
        type: ToastType.error,
      );
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

    final List<Map<String, dynamic>> lowStockNotifications = [];

    // Validasi stok sebelum melanjutkan
    for (final item in cart) {
      if (item.type == CartItemType.product) {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .doc(item.productId)
            .get();
        if (!doc.exists) {
          if (mounted) {
            AppToast.show(
              context,
              'Produk ${item.name} tidak ditemukan',
              type: ToastType.error,
            );
            setState(() => _isProcessing = false);
          }
          return;
        }
        final stockQty = doc.data()?['stockQty'] ?? 0;
        final stockMin = doc.data()?['stockMin'] ?? 0;
        if (stockQty < item.qty) {
          if (mounted) {
            AppToast.show(
              context,
              'Stok tidak mencukupi untuk ${item.name}. Sisa: $stockQty',
              type: ToastType.error,
            );
            setState(() => _isProcessing = false);
          }
          return;
        }

        final newStock = stockQty - item.qty;
        if (newStock <= stockMin) {
          lowStockNotifications.add({'name': item.name, 'newStock': newStock});
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
    final totalCost = cart.fold<double>(
      0,
      (acc, item) => acc + (item.costPrice * item.qty),
    );

    try {
      final txn = TransactionModel(
        id: txnId,
        invoiceNo: invoiceNo,
        userId: user?.id ?? '1',
        cashierName: user?.name,
        paymentMethod: method,
        subtotal: subtotal,
        discount: discount,
        total: total,
        paidAmount: method == 'cash' ? paid : total,
        changeAmount: change,
        totalCost: totalCost,
        createdAt: DateTime.now(),
      );

      final items = cart.map((item) {
        final isService = item.type == CartItemType.service;
        final isApproved = !isService || (user?.role == 'owner');
        return TransactionItemModel(
          id: uuid.v4(),
          transactionId: txnId,
          itemType: isService ? 'service' : 'product',
          productId: isService ? null : item.productId,
          serviceId: isService ? item.productId : null,
          qty: item.qty,
          unitPrice: item.unitPrice,
          costPrice: item.costPrice,
          discount: item.discount,
          subtotal: item.subtotal,
          isApproved: isApproved,
          workerName: isService ? selectedWorker : null,
          productName: item.name,
          createdAt: DateTime.now(),
        );
      }).toList();

      final repo = ref.read(transactionRepositoryProvider);
      await repo.saveTransaction(txn, items);

      final woId = ref.read(cartWorkOrderIdProvider);
      if (woId != null) {
        await FirebaseFirestore.instance.collection('work_orders').doc(woId).update({
          'status': 'paid',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        ref.read(cartWorkOrderIdProvider.notifier).state = null;
      }

      final firestore = FirebaseFirestore.instance;
      final isCashier = user?.role == 'cashier';

      if (isCashier) {
        final cashierName = user?.name ?? 'Kasir';

        await firestore.collection('notifications').add({
          'title': 'Transaksi Berhasil',
          'message':
              '$cashierName telah memproses transaksi ${txn.invoiceNo} sebesar ${CurrencyFormatter.format(txn.total)}.',
          'type': 'info',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'targetRole': 'owner',
          'senderId': user?.id,
        });
        
        DirectFcmService.sendPushNotification(
          targetRole: 'owner',
          title: 'Transaksi Berhasil',
          body: '$cashierName telah memproses transaksi ${txn.invoiceNo} sebesar ${CurrencyFormatter.format(txn.total)}.',
          type: 'transaction',
          senderId: user?.id,
        );

        final hasServices = cart.any((i) => i.type == CartItemType.service);
        if (hasServices) {
          await firestore.collection('notifications').add({
            'title': 'Penjualan Jasa',
            'message':
                '$cashierName telah memproses penjualan jasa pada transaksi ${txn.invoiceNo}.',
            'type': 'info',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
            'targetRole': 'owner',
            'senderId': user?.id,
          });
          
          DirectFcmService.sendPushNotification(
            targetRole: 'owner',
            title: 'Penjualan Jasa',
            body: '$cashierName telah memproses penjualan jasa pada transaksi ${txn.invoiceNo}.',
            type: 'service_approval',
            senderId: user?.id,
          );
        }
      }

      for (var notif in lowStockNotifications) {
        final title = notif['newStock'] <= 0 ? 'Stok Habis!' : 'Stok Menipis';
        final message = 'Produk ${notif['name']} tersisa ${notif['newStock']}. Segera lakukan restock!';
        
        await firestore.collection('notifications').add({
          'title': title,
          'message': message,
          'type': notif['newStock'] <= 0 ? 'error' : 'warning',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'targetRole': 'owner',
          'senderId': user?.id,
        });
        
        DirectFcmService.sendPushNotification(
          targetRole: 'owner',
          title: title,
          body: message,
          type: 'stock_alert',
          senderId: user?.id,
        );
      }

      HapticFeedback.heavyImpact();

      ref.read(cartProvider.notifier).clear();
      ref.read(cartDiscountProvider.notifier).state = 0;
      ref.read(paidAmountProvider.notifier).state = 0;

      // Create processed items with approval status for the success screen
      final processedItems = cart.map((item) {
        final isService = item.type == CartItemType.service;
        final isApproved = !isService || (user?.role == 'owner');
        return item.copyWith(
          isApproved: isApproved,
          workerName: isService ? selectedWorker : null,
        );
      }).toList();

      ref.read(cartSelectedWorkerProvider.notifier).state = null;

      if (mounted) {
        context.go(
          '/payment-success',
          extra: {
            'invoiceNo': invoiceNo,
            'items': processedItems,
            'total': total,
            'paid': method == 'cash' ? paid : total,
            'change': change,
          },
        );
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
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => context.go('/pos'),
          ),
          actions: [
            if (cart.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_rounded),
                onPressed: () => ref.read(cartProvider.notifier).clear(),
              ),
          ],
        ),
        body: cart.isEmpty
            ? Center(
                child: EmptyStateWidget(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Keranjang masih kosong',
                  subtitle: 'Pilih produk atau jasa untuk ditambahkan',
                  actionLabel: 'Mulai Belanja',
                  onAction: () => context.go('/pos'),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: cart.length,
                      separatorBuilder: (context, index) => const Divider(height: 20),
                      itemBuilder: (_, i) {
                        final item = cart[i];
                        final isService = item.type == CartItemType.service;
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color:
                                    (isService
                                            ? AppColors.info
                                            : AppColors.primary)
                                        .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isService
                                    ? Icons.build_rounded
                                    : Icons.settings_rounded,
                                size: 16,
                                color: isService
                                    ? AppColors.info
                                    : AppColors.primary,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  Text(
                                    '${CurrencyFormatter.format(item.unitPrice)} × ${item.qty}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                _qtyButton(
                                  Icons.remove_rounded,
                                  () => ref
                                      .read(cartProvider.notifier)
                                      .updateQty(
                                        item.productId,
                                        item.qty - 1,
                                        item.type,
                                        item.workerName,
                                      ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    '${item.qty}',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                _qtyButton(Icons.add_rounded, () {
                                  if (item.type == CartItemType.product) {
                                    final products =
                                        ref.read(productsProvider).value ?? [];
                                    try {
                                      final prod = products.firstWhere(
                                        (p) => p.id == item.productId,
                                      );
                                      if (item.qty >= prod.stockQty) {
                                        AppToast.show(
                                          context,
                                          'Maksimal stok ${prod.stockQty}',
                                          type: ToastType.warning,
                                        );
                                        return;
                                      }
                                    } catch (_) {}
                                  }
                                  ref
                                      .read(cartProvider.notifier)
                                      .updateQty(
                                        item.productId,
                                        item.qty + 1,
                                        item.type,
                                        item.workerName,
                                      );
                                }),
                              ],
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 85,
                              child: Text(
                                CurrencyFormatter.format(item.subtotal),
                                style: theme.textTheme.titleSmall,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      border: const Border(
                        top: BorderSide(color: AppColors.border),
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: () => context.go('/pos'),
                            icon: const Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 20,
                            ),
                            label: const Text(
                              'Tambah Pesanan Lainnya',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (hasServices && hasParts) ...[
                          _summaryRow(
                            'Subtotal Jasa',
                            CurrencyFormatter.format(serviceSubtotal),
                            color: AppColors.info,
                          ),
                          _summaryRow(
                            'Subtotal Sparepart',
                            CurrencyFormatter.format(partsSubtotal),
                          ),
                          const Divider(height: 12),
                        ],
                        _summaryRow(
                          'Subtotal',
                          CurrencyFormatter.format(subtotal),
                        ),
                        InkWell(
                          onTap: () => _showDiscountDialog(context, ref),
                          child: _summaryRow(
                            'Diskon',
                            discount > 0
                                ? '-${CurrencyFormatter.format(discount)}'
                                : 'Tambah Diskon',
                            color: discount > 0
                                ? AppColors.error
                                : AppColors.primary,
                          ),
                        ),
                        const Divider(),
                        _summaryRow(
                          'Total',
                          CurrencyFormatter.format(total),
                          bold: true,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: method,
                          decoration: const InputDecoration(
                            labelText: 'Metode Pembayaran',
                            prefixIcon: Icon(Icons.payment_rounded, size: 18, color: AppColors.primary),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'cash', child: Text('Tunai (Cash)')),
                            DropdownMenuItem(value: 'transfer', child: Text('Transfer Bank')),
                            DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(paymentMethodProvider.notifier).state = val;
                              if (val != 'cash') {
                                _paidCtrl.clear();
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 12),
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
                        if (hasServices) ...[
                          const SizedBox(height: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pilih Mekanik / Pekerja *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              staffAsync.when(
                                loading: () => const LinearProgressIndicator(),
                                error: (e, _) => Text('Error: $e'),
                                data: (staff) {
                                  final mechanics = staff
                                      .where((u) => u.role == 'mechanic')
                                      .toList();
                                  if (mechanics.isEmpty) {
                                    return const Text(
                                      'Belum ada data mekanik.',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontSize: 12,
                                      ),
                                    );
                                  }
                                  return DropdownButtonFormField<String>(
                                    initialValue: selectedWorker,
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.build_rounded,
                                        size: 18,
                                        color: AppColors.info,
                                      ),
                                      hintText: 'Pilih Mekanik / Pekerja',
                                    ),
                                    items: mechanics
                                        .map(
                                          (u) => DropdownMenuItem(
                                            value: u.name,
                                            child: Text(u.name),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) =>
                                        ref
                                                .read(
                                                  cartSelectedWorkerProvider
                                                      .notifier,
                                                )
                                                .state =
                                            val,
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _processPayment,
                            child: _isProcessing
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text('Proses Pembayaran'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16),
    ),
  );

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? (bold ? AppColors.primary : null),
          ),
        ),
      ],
    ),
  );

  void _showDiscountDialog(BuildContext context, WidgetRef ref) {
    final currentVal = ref.read(cartDiscountProvider);
    final ctrl = TextEditingController(
      text: currentVal > 0 ? CurrencyFormatter.formatNumber(currentVal) : '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diskon Global'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [RupiahInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Jumlah Diskon',
            prefixText: 'Rp ',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final d = CurrencyFormatter.parse(ctrl.text);
              final subtotal = ref.read(cartSubtotalProvider);
              if (d > subtotal) {
                AppToast.show(context, 'Diskon tidak boleh lebih dari subtotal', type: ToastType.error);
                return;
              }
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
