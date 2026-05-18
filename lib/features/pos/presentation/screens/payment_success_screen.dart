import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/bluetooth_printer_service.dart';
import '../../../../main.dart';
import '../../../../shared/utils/app_toast.dart';
import '../widgets/receipt_widget.dart';

/// Layar konfirmasi pembayaran berhasil
class PaymentSuccessScreen extends ConsumerWidget {
  final Map<String, dynamic>? data;
  const PaymentSuccessScreen({super.key, this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsServiceProvider);
    final printerState = ref.watch(printerStateProvider);

    final items = (data?['items'] as List?)
            ?.map((e) => ReceiptItem(
                  name: e.name,
                  qty: e.qty,
                  unitPrice: e.unitPrice,
                  subtotal: e.subtotal,
                  type: e.type.toString().contains('service')
                      ? 'service'
                      : 'product',
                  isApproved: e.isApproved,
                ))
            .toList() ??
        [];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ReceiptWidget(
                      storeName: settings.storeName,
                      storeAddress: settings.storeAddress,
                      storePhone: settings.storePhone,
                      invoiceNo: data?['invoiceNo'] ?? 'INV-000',
                      date: DateTime.now(),
                      items: items,
                      total: data?['total'] ?? 0,
                      paid: data?['paid'] ?? 0,
                      change: data?['change'] ?? 0,
                      footer: settings.receiptFooter,
                      showSuccessIcon: true,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tombol Cetak Struk (hanya tampil jika printer terhubung)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => _printReceipt(
                        context,
                        ref,
                        settings,
                        items,
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
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: printerState.isConnected
                            ? AppColors.secondary
                            : AppColors.textHint,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/pos'),
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: const Text(
                        'Transaksi Baru',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/dashboard'),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text(
                        'Kembali ke Beranda',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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

  Future<void> _printReceipt(
    BuildContext context,
    WidgetRef ref,
    dynamic settings,
    List<ReceiptItem> items,
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
    final isStillConnected =
        await ref.read(printerStateProvider.notifier).checkConnection();
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
      final printItems = items
          .map((e) => PrintReceiptItem(
                name: e.name,
                qty: e.qty,
                unitPrice: e.unitPrice,
                subtotal: e.subtotal,
                type: e.type,
              ))
          .toList();

      final bytes = await ThermalPrintService.generateReceipt(
        storeName: settings.storeName,
        storeAddress: settings.storeAddress,
        storePhone: settings.storePhone,
        invoiceNo: data?['invoiceNo'] ?? 'INV-000',
        date: DateTime.now(),
        items: printItems,
        total: data?['total'] ?? 0,
        paid: data?['paid'] ?? 0,
        change: data?['change'] ?? 0,
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
        AppToast.show(
          context,
          'Error: $e',
          type: ToastType.error,
        );
      }
    }
  }
}
