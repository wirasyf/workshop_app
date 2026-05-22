import 'dart:io';
import 'package:dnd_markasban_app/features/pos/presentation/widgets/receipt_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../shared/widgets/metric_card.dart';
import 'notification_screen.dart';

import 'package:fl_chart/fl_chart.dart';
import '../../../../core/utils/report_utils.dart';
import '../../../../core/utils/date_picker_utils.dart';
import '../../../../core/enums/report_period.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final dashboardChartPeriodProvider = StateProvider<ReportPeriod>(
  (ref) => ReportPeriod.daily,
);
final dashboardChartDateProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

final dashboardChartDataProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = ref.watch(databaseProvider);
  final period = ref.watch(dashboardChartPeriodProvider);
  final selectedDate = ref.watch(dashboardChartDateProvider);

  DateTime start;
  DateTime end;

  switch (period) {
    case ReportPeriod.daily:
      start = DateFormatter.startOfDay(
        selectedDate,
      ).subtract(const Duration(days: 6));
      end = DateFormatter.endOfDay(selectedDate);
    case ReportPeriod.weekly:
      start = DateTime(selectedDate.year, selectedDate.month, 1);
      end = DateTime(selectedDate.year, selectedDate.month + 1, 0, 23, 59, 59);
    case ReportPeriod.monthly:
      start = DateTime(selectedDate.year, 1, 1);
      end = DateTime(selectedDate.year, 12, 31, 23, 59, 59);
    case ReportPeriod.yearly:
      start = DateTime(selectedDate.year - 6, 1, 1);
      end = DateTime(selectedDate.year, 12, 31, 23, 59, 59);
  }

  return db.getSalesByDateRange(start, end);
});

/// Dashboard provider — omzet hari ini, jumlah transaksi, stok menipis
final ownerDashboardProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final start = DateFormatter.startOfDay(now);
  final end = DateFormatter.endOfDay(now);

  final todayTxns = await db.getTransactionsByDate(start, end);
  final lowStock = await db.getLowStockProducts();
  final summaryProfit = await db.getSummaryProfit(start, end);
  final activeWOCount = await db.getActiveWorkOrderCount();
  final pendingApprovals = await db.getPendingServiceApprovals();

  final totalSales = todayTxns.fold(0.0, (sum, t) => sum + t.total);
  final txnCount = todayTxns.length;

  return {
    'totalSales': totalSales,
    'txnCount': txnCount,
    'lowStockCount': lowStock.length,
    'lowStockItems': lowStock,
    'summaryProfit': summaryProfit,
    'activeWOCount': activeWOCount,
    'recentTxns': todayTxns.take(5).toList(),
    'pendingApprovalCount': pendingApprovals.length,
  };
});

/// Dashboard Owner
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
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ownerDashboardProvider),
            child: ListView(
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
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        backgroundImage:
                            user?.avatarUrl != null &&
                                user!.avatarUrl!.isNotEmpty
                            ? (user.avatarUrl!.startsWith('http')
                                  ? CachedNetworkImageProvider(user.avatarUrl!)
                                  : FileImage(File(user.avatarUrl!)))
                            : null,
                        child:
                            user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                            ? const Icon(
                                Icons.person_rounded,
                                color: AppColors.primary,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick Actions
                if (user?.role != 'cashier') ...[
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

                // Metric cards
                GridView.count(
                  crossAxisCount: user?.role == 'cashier' ? 1 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: user?.role == 'cashier' ? 3.5 : 1.4,
                  children: [
                    if (user?.role != 'cashier')
                      MetricCard(
                        label: 'Omzet Hari Ini',
                        value: CurrencyFormatter.format(
                          data['totalSales'] ?? 0,
                        ),
                        icon: Icons.monetization_on_rounded,
                        iconColor: AppColors.success,
                        onTap: () => context.go('/reports'),
                      ),
                    if (user?.role != 'cashier')
                      MetricCard(
                        label: 'Estimasi Laba Hari Ini',
                        value: CurrencyFormatter.format(
                          data['summaryProfit']['grossProfit'] ?? 0,
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
                const SizedBox(height: 32),

                // Chart penjualan
                if (user?.role != 'cashier') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Analisis Penjualan',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final period = ref.watch(
                            dashboardChartPeriodProvider,
                          );
                          final current = ref.watch(dashboardChartDateProvider);
                          return Row(
                            children: [
                              TextButton.icon(
                                onPressed: () async {
                                  final picked = await DatePickerUtils.pickDate(
                                    context,
                                    period,
                                    current,
                                  );
                                  if (picked != null) {
                                    ref
                                            .read(
                                              dashboardChartDateProvider
                                                  .notifier,
                                            )
                                            .state =
                                        picked;
                                  }
                                },
                                icon: const Icon(
                                  Icons.edit_calendar_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  DatePickerUtils.formatSelectedDate(
                                    period,
                                    current,
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              DropdownButton<ReportPeriod>(
                                value: period,
                                underline: const SizedBox(),
                                icon: const Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: AppColors.primary,
                                ),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                items: ReportPeriod.values.map((p) {
                                  final label = switch (p) {
                                    ReportPeriod.daily => 'Harian',
                                    ReportPeriod.weekly => 'Mingguan',
                                    ReportPeriod.monthly => 'Bulanan',
                                    ReportPeriod.yearly => 'Tahunan',
                                  };
                                  return DropdownMenuItem(
                                    value: p,
                                    child: Text(label),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null)
                                    ref
                                            .read(
                                              dashboardChartPeriodProvider
                                                  .notifier,
                                            )
                                            .state =
                                        val;
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final chartData = ref.watch(dashboardChartDataProvider);
                      final chartPeriod = ref.watch(
                        dashboardChartPeriodProvider,
                      );
                      return chartData.when(
                        loading: () => const SizedBox(
                          height: 220,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => SizedBox(
                          height: 220,
                          child: Center(child: Text('Gagal memuat chart')),
                        ),
                        data: (dailySales) {
                          return Container(
                            height: 220,
                            padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.border.withValues(alpha: 0.6),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Builder(
                              builder: (context) {
                                final selectedDate = ref.read(
                                  dashboardChartDateProvider,
                                );
                                final displaySales =
                                    ReportUtils.getChartDisplayData(
                                      dailySales,
                                      chartPeriod,
                                      selectedDate,
                                    );
                                final maxY = ReportUtils.getChartMaxY(
                                  displaySales,
                                );

                                return BarChart(
                                  BarChartData(
                                    maxY: maxY,
                                    barTouchData: BarTouchData(
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipColor: (_) =>
                                            const Color(0xFF334155),
                                        tooltipBorder: BorderSide.none,
                                        getTooltipItem:
                                            (group, groupIndex, rod, rodIndex) {
                                              return BarTooltipItem(
                                                CurrencyFormatter.format(
                                                  rod.toY * 1000,
                                                ),
                                                const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                    barGroups: displaySales.asMap().entries.map(
                                      (e) {
                                        return BarChartGroupData(
                                          x: e.key,
                                          barRods: [
                                            ReportUtils.buildBarRod(
                                              value:
                                                  (e.value['total'] as num?)
                                                      ?.toDouble() ??
                                                  0,
                                              maxY: maxY,
                                              width: 16,
                                              radius: 6,
                                              backgroundBarColor: AppColors
                                                  .border
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ],
                                        );
                                      },
                                    ).toList(),
                                    borderData: FlBorderData(show: false),
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      getDrawingHorizontalLine: (value) =>
                                          FlLine(
                                            color: AppColors.border.withValues(
                                              alpha: 0.5,
                                            ),
                                            strokeWidth: 1,
                                            dashArray: [4, 4],
                                          ),
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 44,
                                          getTitlesWidget: (value, meta) {
                                            if (value == meta.min ||
                                                value == meta.max)
                                              return const SizedBox();
                                            return SideTitleWidget(
                                              meta: meta,
                                              space: 4,
                                              child: Text(
                                                CurrencyFormatter.formatCompact(
                                                  value * 1000,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color:
                                                      theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.color ??
                                                      AppColors.textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 36,
                                          interval: 1,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index >= 0 &&
                                                index < displaySales.length) {
                                              return SideTitleWidget(
                                                meta: meta,
                                                space: 6,
                                                angle:
                                                    chartPeriod ==
                                                        ReportPeriod.weekly
                                                    ? 0
                                                    : -0.5,
                                                child: Text(
                                                  displaySales[index]['label']
                                                      as String,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color:
                                                        theme
                                                            .textTheme
                                                            .bodySmall
                                                            ?.color ??
                                                        AppColors.textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            }
                                            return SideTitleWidget(
                                              meta: meta,
                                              child: const SizedBox(),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
                // Recent Activity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Aktivitas Terbaru',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/history?from=dashboard'),
                      child: const Text(
                        'Lihat Semua',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    children: (data['recentTxns'] as List<Transaction>)
                        .asMap()
                        .entries
                        .map((entry) {
                          final txn = entry.value;
                          final isLast =
                              entry.key ==
                              (data['recentTxns'] as List).length - 1;
                          return Column(
                            children: [
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: Text(
                                  txn.invoiceNo,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  DateFormatter.formatShort(txn.createdAt),
                                ),
                                trailing: Text(
                                  CurrencyFormatter.format(txn.total),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                                onTap: () =>
                                    ReceiptModal.show(context, ref, txn),
                                dense: true,
                              ),
                              if (!isLast)
                                const Divider(
                                  height: 1,
                                  indent: 60,
                                  endIndent: 16,
                                ),
                            ],
                          );
                        })
                        .toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // Stok kritis
                if (user?.role != 'cashier' &&
                    (data['lowStockItems'] as List).isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Stok Kritis',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/products?from=dashboard'),
                        child: const Text(
                          'Kelola',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      children:
                          ((data['lowStockItems'] as List<Product>)
                                  .take(5)
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    final p = entry.value;
                                    final isLast =
                                        entry.key ==
                                        ((data['lowStockItems'] as List)
                                                .take(5)
                                                .length -
                                            1);
                                    return Column(
                                      children: [
                                        ListTile(
                                          leading: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: p.stockQty == 0
                                                  ? AppColors.errorLight
                                                  : AppColors.warningLight,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              p.stockQty == 0
                                                  ? Icons.error_rounded
                                                  : Icons.warning_rounded,
                                              size: 18,
                                              color: p.stockQty == 0
                                                  ? AppColors.error
                                                  : AppColors.warning,
                                            ),
                                          ),
                                          title: Text(
                                            p.name,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          subtitle: Text(
                                            'Sisa ${p.stockQty} ${p.unit}',
                                          ),
                                          trailing: const Icon(
                                            Icons.chevron_right_rounded,
                                            size: 18,
                                            color: AppColors.textHint,
                                          ),
                                          onTap: () => context.go(
                                            '/products/${p.id}?from=dashboard',
                                          ),
                                          dense: true,
                                        ),
                                        if (!isLast)
                                          const Divider(
                                            height: 1,
                                            indent: 60,
                                            endIndent: 16,
                                          ),
                                      ],
                                    );
                                  }))
                              .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
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
