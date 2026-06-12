import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/bluetooth_printer_service.dart';
import '../../../../main.dart';
import '../../../../shared/utils/app_toast.dart';
import '../providers/cart_provider.dart';
import 'receipt_widget.dart';
import '../../data/transaction_repository.dart';
import '../../../../core/models/transaction_model.dart';

class ReceiptModal {
  static Future<void> printReceipt(
    BuildContext context,
    WidgetRef ref,
    dynamic settings,
    dynamic txn,
    List<dynamic> details,
  ) async {
    final printerState = ref.read(printerStateProvider);

    if (!printerState.isConnected) {
      AppToast.show(
        context,
        'Hubungkan printer terlebih dahulu di Lainnya → Printer Bluetooth',
        type: ToastType.warning,
      );
      return;
    }

    // Cek koneksi real-time
    final isStillConnected = await ref
        .read(printerStateProvider.notifier)
        .checkConnection();
    if (!isStillConnected) {
      if (context.mounted) {
        AppToast.show(
          context,
          'Koneksi printer terputus. Coba hubungkan ulang.',
          type: ToastType.error,
        );
      }
      return;
    }

    try {
      final printItems = details
          .map(
            (d) => PrintReceiptItem(
              name: d.productName,
              qty: d.item.qty,
              unitPrice: d.item.unitPrice,
              subtotal: d.item.subtotal,
              type: d.itemType,
              workerName: d.item.workerName,
            ),
          )
          .toList();

      final bytes = await ThermalPrintService.generateReceipt(
        storeName: settings.storeName,
        storeAddress: settings.storeAddress,
        storePhone: settings.storePhone,
        invoiceNo: txn.invoiceNo,
        cashierName: txn.cashierName,
        date: txn.createdAt,
        items: printItems,
        total: txn.total,
        paid: txn.paidAmount,
        change: txn.changeAmount,
        footer: settings.receiptFooter,
      );

      final result = await ThermalPrintService.printBytes(bytes);
      HapticFeedback.mediumImpact();

      if (context.mounted) {
        AppToast.show(
          context,
          result ? 'Struk berhasil dicetak!' : 'Gagal mencetak struk',
          type: result ? ToastType.success : ToastType.error,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Error: $e', type: ToastType.error);
      }
    }
  }

  static Future<void> _handleReturn(
    BuildContext context,
    WidgetRef ref,
    dynamic txn,
    List<dynamic> details,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Retur'),
        content: const Text('Apakah Anda yakin ingin meretur seluruh transaksi ini? Stok barang akan dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retur Transaksi'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final items = details.map((d) => d.item as TransactionItemModel).toList();
      await ref.read(transactionRepositoryProvider).returnTransaction(txn.id, items);
      
      if (context.mounted) {
        AppToast.show(context, 'Transaksi berhasil diretur', type: ToastType.success);
        Navigator.pop(context); // Close modal
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Error: $e', type: ToastType.error);
      }
    }
  }

  static void show(BuildContext context, WidgetRef ref, dynamic txn) {
    final settings = ref.read(settingsServiceProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final itemsAsync = ref.watch(
                      transactionItemsProvider(txn.id),
                    );
                    final printerState = ref.watch(printerStateProvider);

                    return itemsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (details) => Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              child: ReceiptWidget(
                                storeName: settings.storeName,
                                storeAddress: settings.storeAddress,
                                storePhone: settings.storePhone,
                                invoiceNo: txn.invoiceNo,
                                cashierName: txn.cashierName,
                                date: txn.createdAt,
                                items: details
                                    .map(
                                      (d) => ReceiptItem(
                                        id: d.item.id,
                                        name: d.productName,
                                        qty: d.item.qty,
                                        unitPrice: d.item.unitPrice,
                                        subtotal: d.item.subtotal,
                                        type: d.itemType,
                                        isApproved: d.item.isApproved,
                                        workerName: d.item.workerName,
                                        isReturned: d.item.isReturned,
                                      ),
                                    )
                                    .toList(),
                                total: txn.total,
                                paid: txn.paidAmount,
                                change: txn.changeAmount,
                                footer: settings.receiptFooter,
                                onReturnItem: (item) {
                                  _showReturnDialog(context, ref, txn.id, item, d: details.firstWhere((element) => element.item.id == item.id).item);
                                },
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () => printReceipt(
                                      context,
                                      ref,
                                      settings,
                                      txn,
                                      details,
                                    ),
                                    icon: Icon(
                                      printerState.isConnected
                                          ? Icons.print_rounded
                                          : Icons.print_disabled_rounded,
                                    ),
                                    label: Text(
                                      printerState.isConnected
                                          ? 'Cetak Struk'
                                          : 'Printer Tidak Terhubung',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: printerState.isConnected
                                          ? AppColors.secondary
                                          : AppColors.textHint,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                if (txn.status == 'completed') ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _handleReturn(context, ref, txn, details),
                                      icon: const Icon(Icons.undo_rounded, color: AppColors.error),
                                      label: const Text(
                                        'Retur Transaksi',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.error,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.error),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showReturnDialog(BuildContext context, WidgetRef ref, String txnId, ReceiptItem receiptItem, {required dynamic d}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Retur'),
        content: Text('Apakah Anda yakin ingin meretur barang ini?\n\n${receiptItem.name} (${receiptItem.qty}x)\n\nStok barang akan dikembalikan ke inventaris.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final repo = ref.read(transactionRepositoryProvider);
              final parentContext = context;
              Navigator.pop(context); // Tutup dialog
              try {
                await repo.returnTransactionItem(txnId, d);
                if (parentContext.mounted) {
                  AppToast.show(parentContext, 'Retur berhasil diproses. Stok dan saldo telah diperbarui.', type: ToastType.success);
                }
              } catch (e) {
                if (parentContext.mounted) {
                  AppToast.show(parentContext, 'Gagal memproses retur: $e', type: ToastType.error);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Ya, Retur', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
