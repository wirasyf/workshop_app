import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../main.dart';
import '../widgets/receipt_preview_dialog.dart';

/// Layar konfirmasi pembayaran berhasil
class PaymentSuccessScreen extends ConsumerWidget {
  final Map<String, dynamic>? data;
  const PaymentSuccessScreen({super.key, this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, size: 72, color: AppColors.success),
              ),
              const SizedBox(height: 24),
              Text('Pembayaran Berhasil!', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Transaksi telah disimpan', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/pos'),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('Transaksi Baru'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final settings = ref.read(settingsServiceProvider);
                    showDialog(
                      context: context,
                      builder: (context) => ReceiptPreviewDialog(
                        storeInfo: {
                          'name': settings.storeName,
                          'address': settings.storeAddress,
                          'phone': settings.storePhone,
                          'footer': settings.receiptFooter,
                        },
                        items: data?['items'] ?? [],
                        total: data?['total'] ?? 0,
                        paid: data?['paid'] ?? 0,
                        change: data?['change'] ?? 0,
                        invoiceNo: data?['invoiceNo'] ?? 'INV-000',
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Lihat Struk'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
