import 'dart:io';
import 'package:dnd_markasban_app/features/products/presentation/providers/product_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/metric_card.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import 'notification_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/transaction_model.dart';
import '../../../pos/presentation/widgets/receipt_modal.dart';

import '../../../pos/data/transaction_repository.dart';

final recentDashboardTransactionsProvider =
    StreamProvider<List<TransactionModel>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value([]);
      final repo = ref.watch(transactionRepositoryProvider);
      return repo.getRecentTransactions(20); // increased limit
    });

final todayTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getTodayTransactionsStream();
});

final ownerDashboardProvider = Provider<AsyncValue<Map<String, dynamic>>>((
  ref,
) {
  final txAsync = ref.watch(todayTransactionsProvider);
  final lowStockAsync = ref.watch(lowStockProvider);
  final user = ref.watch(authStateProvider).value;

  if (txAsync is AsyncLoading || lowStockAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }

  if (txAsync is AsyncError) {
    return AsyncValue.error(txAsync.error!, txAsync.stackTrace!);
  }
  if (lowStockAsync is AsyncError) {
    return AsyncValue.error(lowStockAsync.error!, lowStockAsync.stackTrace!);
  }

  final transactions = txAsync.value ?? [];
  final lowStockItems = lowStockAsync.value ?? [];

  double totalSales = 0.0;
  double grossProfit = 0.0;
  int txnCount = 0;
  List<TransactionModel> recentTxns = [];

  for (var tx in transactions) {
    if (tx.status == 'completed') {
      if (user?.role == 'cashier') {
        if (tx.userId == user?.id) {
          totalSales += tx.total;
          txnCount++;
          recentTxns.add(tx);
        }
      } else {
        totalSales += tx.total;
        grossProfit += (tx.total - tx.totalCost);
        txnCount++;
        recentTxns.add(tx);
      }
    }
  }

  return AsyncValue.data({
    'totalSales': totalSales,
    'txnCount': txnCount,
    'lowStockCount': lowStockItems.length,
    'lowStockItems': lowStockItems,
    'summaryProfit': {'grossProfit': grossProfit},
    'activeWOCount': 0, // Placeholder
    'recentTxns': recentTxns.take(5).toList(),
    'pendingApprovalCount': 0,
  });
});

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(ownerDashboardProvider);
    final user = ref.watch(authStateProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('D&D Markas Ban'),
        actions: [
          if (user?.role != 'cashier')
            Consumer(
              builder: (context, ref, _) {
                final count = ref.watch(notificationBadgeProvider);
                return IconButton(
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count', style: const TextStyle(fontSize: 10)),
                    child: const Icon(Icons.notifications_rounded),
                  ),
                  onPressed: () => context.go('/notifications?from=dashboard'),
                );
              },
            ),
        ],
      ),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${user?.name ?? "User"} 👋',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormatter.formatLong(DateTime.now()),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => context.go('/settings'),
                    child: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      backgroundImage:
                          user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                          ? (user.avatarUrl!.startsWith('http')
                                ? CachedNetworkImageProvider(user.avatarUrl!)
                                : FileImage(File(user.avatarUrl!))
                                      as ImageProvider)
                          : null,
                      child: user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                          ? Text(
                              user?.name.substring(0, 1).toUpperCase() ?? 'U',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  MetricCard(
                    label: 'Omzet Hari Ini',
                    value: CurrencyFormatter.format(data['totalSales'] ?? 0),
                    icon: Icons.monetization_on_rounded,
                    iconColor: AppColors.success,
                    onTap: () => user?.role == 'cashier' ? context.go('/history?from=dashboard') : context.go('/reports'),
                  ),
                  if (user?.role != 'cashier')
                    MetricCard(
                      label: 'Estimasi Laba Hari Ini',
                      value: CurrencyFormatter.format(
                        data['summaryProfit']?['grossProfit'] ?? 0,
                      ),
                      icon: Icons.trending_up_rounded,
                      iconColor: AppColors.primary,
                      onTap: () => context.go('/reports'),
                    ),
                  MetricCard(
                    label: 'Transaksi Hari Ini',
                    value: '${data['txnCount'] ?? 0}',
                    icon: Icons.receipt_long_rounded,
                    iconColor: AppColors.info,
                    onTap: () => context.go('/history?from=dashboard'),
                  ),
                  if (user?.role != 'cashier')
                    MetricCard(
                      label: 'Stok Menipis',
                      value: '${data['lowStockCount'] ?? 0}',
                      icon: Icons.warning_rounded,
                      iconColor: AppColors.warning,
                      onTap: () => context.go('/products?from=dashboard'),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              if (user?.role != 'cashier') ...[
                Text(
                  'Akses Cepat',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _QuickActionBtn(
                      label: 'Riwayat',
                      icon: Icons.history_rounded,
                      color: AppColors.primary,
                      onTap: () => context.go('/history?from=dashboard'),
                    ),
                    _QuickActionBtn(
                      label: 'Jasa',
                      icon: Icons.build_rounded,
                      color: AppColors.secondary,
                      onTap: () => context.go('/services?from=dashboard'),
                    ),
                    _QuickActionBtn(
                      label: 'Barang',
                      icon: Icons.inventory_2_rounded,
                      color: AppColors.info,
                      onTap: () => context.go('/products?from=dashboard'),
                    ),
                    if (user?.role == 'owner')
                      _QuickActionBtn(
                        label: 'Karyawan',
                        icon: Icons.people_alt_rounded,
                        color: AppColors.warning,
                        onTap: () => context.go('/staff?from=dashboard'),
                      ),
                    _QuickActionBtn(
                      label: 'Persetujuan',
                      icon: Icons.assignment_turned_in_rounded,
                      color: AppColors.success,
                      onTap: () =>
                          context.go('/service-approval?from=dashboard'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              const SizedBox(height: 24),
              Text(
                'Riwayat Transaksi Harian',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Consumer(
                builder: (context, ref, child) {
                  final recentAsync = ref.watch(todayTransactionsProvider);
                  return recentAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Text('Error: $err'),
                    data: (transactions) {
                      final todaysTransactions = user?.role == 'cashier'
                          ? transactions.where((t) => t.userId == user?.id).toList()
                          : transactions;

                      if (todaysTransactions.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: EmptyStateWidget(
                            icon: Icons.history_rounded,
                            title: 'Belum ada transaksi hari ini',
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: todaysTransactions.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final txn = todaysTransactions[index];
                          return InkWell(
                            onTap: () => ReceiptModal.show(context, ref, txn),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.cardTheme.color,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_rounded,
                                      color: AppColors.success,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              txn.invoiceNo,
                                              style: theme.textTheme.titleSmall,
                                            ),
                                            if (txn.status == 'returned') ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.error.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'DIRETUR',
                                                  style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormatter.formatWithTime(
                                            txn.createdAt,
                                          ),
                                          style: theme.textTheme.labelSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(txn.total),
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              color: AppColors.primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
