import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/bluetooth_printer_service.dart';
import '../../../../main.dart';
import '../../../../shared/utils/app_toast.dart';
import '../providers/cart_provider.dart';
import 'receipt_widget.dart';

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
                                        name: d.productName,
                                        qty: d.item.qty,
                                        unitPrice: d.item.unitPrice,
                                        subtotal: d.item.subtotal,
                                        type: d.itemType,
                                        isApproved: d.item.isApproved,
                                        workerName: d.item.workerName,
                                      ),
                                    )
                                    .toList(),
                                total: txn.total,
                                paid: txn.paidAmount,
                                change: txn.changeAmount,
                                footer: settings.receiptFooter,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: SizedBox(
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
}
