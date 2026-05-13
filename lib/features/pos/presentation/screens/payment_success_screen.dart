import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../main.dart';
import '../widgets/receipt_widget.dart';

/// Layar konfirmasi pembayaran berhasil
class PaymentSuccessScreen extends ConsumerWidget {
  final Map<String, dynamic>? data;
  const PaymentSuccessScreen({super.key, this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsServiceProvider);
    
    final items = (data?['items'] as List?)?.map((e) => ReceiptItem(
      name: e.name,
      qty: e.qty,
      unitPrice: e.unitPrice,
      subtotal: e.subtotal,
    )).toList() ?? [];

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
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -5)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/pos'),
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: const Text('Transaksi Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      label: const Text('Kembali ke Beranda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
}
