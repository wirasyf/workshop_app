import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';

import '../../../../shared/widgets/empty_state_widget.dart';
import '../providers/cart_provider.dart';

/// Riwayat transaksi
class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final start = DateFormatter.startOfDay(today);
    final end = DateFormatter.endOfDay(today);
    final txns = ref.watch(transactionHistoryProvider((start: start, end: end)));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      body: txns.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateWidget(icon: Icons.receipt_long_rounded, title: 'Belum ada transaksi hari ini');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final txn = items[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_rounded, color: AppColors.success, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(txn.invoiceNo, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(DateFormatter.formatWithTime(txn.createdAt), style: theme.textTheme.labelSmall),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(CurrencyFormatter.format(txn.total), style: theme.textTheme.titleSmall?.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(20)),
                      child: Text(txn.paymentMethod.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success)),
                    ),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
