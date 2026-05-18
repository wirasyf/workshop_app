import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../../auth/presentation/providers/auth_provider.dart';

/// Dashboard provider — omzet hari ini, jumlah transaksi, stok menipis
final ownerDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final start = DateFormatter.startOfDay(now);
  final end = DateFormatter.endOfDay(now);

  final todayTxns = await db.getTransactionsByDate(start, end);
  final lowStock = await db.getLowStockProducts();
  final dailySales = await db.getDailySales(7);
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
    'dailySales': dailySales,
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
        title: const Text('SpareArt Motor'),
        actions: [
          Consumer(builder: (context, ref, _) {
            final count = ref.watch(notificationBadgeProvider);
            return IconButton(
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count', style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.notifications_rounded),
              ),
              onPressed: () => context.go('/notifications'),
            );
          }),
        ],
      ),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          final dailySales = (data['dailySales'] as List<Map<String, dynamic>>);
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
                        Text('Halo, ${user?.name ?? "User"} 👋', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(DateFormatter.formatLong(DateTime.now()), style: theme.textTheme.bodySmall),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => context.go('/settings'),
                      child: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                            ? (user.avatarUrl!.startsWith('http')
                                ? CachedNetworkImageProvider(user.avatarUrl!)
                                : FileImage(File(user.avatarUrl!)))
                            : null,
                        child: user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                            ? const Icon(Icons.person_rounded, color: AppColors.primary)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Approval Alert (only for Owner)
                if (user?.role == 'owner' && (data['pendingApprovalCount'] ?? 0) > 0) ...[
                  InkWell(
                    onTap: () => context.go('/service-approval'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pending_actions_rounded, color: AppColors.warning),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Persetujuan Jasa', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.warning)),
                                Text('Ada ${data['pendingApprovalCount']} jasa menunggu persetujuan Anda', style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.warning),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Quick Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _QuickActionBtn(
                      label: 'Penjualan', icon: Icons.shopping_cart_rounded, color: AppColors.primary,
                      onTap: () => context.go('/pos'),
                    ),
                    _QuickActionBtn(
                      label: 'Bengkel', icon: Icons.build_rounded, color: AppColors.secondary,
                      onTap: () => context.go('/workshop'),
                    ),
                    _QuickActionBtn(
                      label: 'Barang', icon: Icons.inventory_2_rounded, color: AppColors.info,
                      onTap: () => context.go('/products'),
                    ),
                    _QuickActionBtn(
                      label: 'Laporan', icon: Icons.bar_chart_rounded, color: AppColors.success,
                      onTap: () => context.go('/reports'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Staff Management Shortcut (Owner only)
                if (user?.role == 'owner') ...[
                  InkWell(
                    onTap: () => context.go('/staff'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, color: AppColors.info),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kelola Karyawan', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.info)),
                                const Text('Buat dan kelola akun kasir untuk karyawan Anda', style: TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.info),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Metric cards
                GridView.count(
                  crossAxisCount: 2, shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.4,
                  children: [
                    MetricCard(
                      label: 'Omzet Hari Ini', value: CurrencyFormatter.formatCompact(data['totalSales'] ?? 0),
                      icon: Icons.monetization_on_rounded, iconColor: AppColors.success,
                      onTap: () => context.go('/reports'),
                    ),
                    MetricCard(
                      label: 'Estimasi Laba', value: CurrencyFormatter.formatCompact(data['summaryProfit']['grossProfit'] ?? 0),
                      icon: Icons.trending_up_rounded, iconColor: AppColors.primary,
                      subtitle: '${(data['summaryProfit']['margin'] as double).toStringAsFixed(1)}%',
                      onTap: () => context.go('/reports'),
                    ),
                    MetricCard(
                      label: 'Transaksi', value: '${data['txnCount'] ?? 0}',
                      icon: Icons.receipt_long_rounded, iconColor: AppColors.info,
                      onTap: () => context.go('/history'),
                    ),
                    MetricCard(
                      label: 'Antrian Bengkel', value: '${data['activeWOCount'] ?? 0}',
                      icon: Icons.engineering_rounded, iconColor: AppColors.warning,
                      onTap: () => context.go('/workshop'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Chart penjualan 7 hari
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Analisis Penjualan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(onPressed: () => context.go('/reports'), child: const Text('Lihat Detail', style: TextStyle(fontSize: 12))),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 220,
                  padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Builder(
                          builder: (context) {
                            final displaySales = ReportUtils.getChartDisplayData(dailySales, 7);
                            final maxY = ReportUtils.getChartMaxY(displaySales);
                            
                            return BarChart(BarChartData(
                              maxY: maxY,
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipColor: (_) => const Color(0xFF334155),
                                  tooltipBorder: BorderSide.none,
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      CurrencyFormatter.formatCompact(rod.toY * 1000),
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    );
                                  },
                                ),
                              ),
                              barGroups: displaySales.asMap().entries.map((e) {
                                return BarChartGroupData(x: e.key, barRods: [
                                  ReportUtils.buildBarRod(
                                    value: (e.value['total'] as num?)?.toDouble() ?? 0,
                                    maxY: maxY,
                                    width: 16,
                                    radius: 6,
                                    backgroundBarColor: AppColors.border.withValues(alpha: 0.3),
                                  ),
                                ]);
                              }).toList(),
                              borderData: FlBorderData(show: false),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: AppColors.border.withValues(alpha: 0.5),
                                  strokeWidth: 1,
                                  dashArray: [4, 4],
                                ),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                leftTitles: AxisTitles(sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 44,
                                  getTitlesWidget: (value, meta) {
                                    if (value == meta.min || value == meta.max) return const SizedBox();
                                    return SideTitleWidget(
                                      meta: meta,
                                      space: 4,
                                      child: Text(
                                        CurrencyFormatter.formatCompact(value * 1000),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: theme.textTheme.bodySmall?.color ?? AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  },
                                )),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 36,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 && value.toInt() < displaySales.length) {
                                      final d = displaySales[value.toInt()]['date'] as String;
                                      String label;
                                      if (d.length >= 10) {
                                        label = '${d.substring(8)}/${d.substring(5, 7)}';
                                      } else {
                                        label = '${value.toInt() + 1}';
                                      }
                                      return SideTitleWidget(
                                        meta: meta,
                                        space: 6,
                                        angle: -0.5,
                                        child: Text(label, style: TextStyle(
                                          fontSize: 9,
                                          color: theme.textTheme.bodySmall?.color ?? AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        )),
                                      );
                                    }
                                    return SideTitleWidget(meta: meta, child: const SizedBox());
                                  },
                                )),
                              ),
                            ));
                          },
                        ),
                ),
                // Recent Activity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Aktivitas Terbaru', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(onPressed: () => context.go('/history'), child: const Text('Lihat Semua', style: TextStyle(fontSize: 12))),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    children: (data['recentTxns'] as List<Transaction>).asMap().entries.map((entry) {
                      final txn = entry.value;
                      final isLast = entry.key == (data['recentTxns'] as List).length - 1;
                      return Column(
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.receipt_rounded, size: 18, color: AppColors.primary),
                            ),
                            title: Text(txn.invoiceNo, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                            subtitle: Text(DateFormatter.formatShort(txn.createdAt)),
                            trailing: Text(
                              CurrencyFormatter.format(txn.total),
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.success),
                            ),
                            onTap: () => context.go('/history?id=${txn.id}'),
                            dense: true,
                          ),
                          if (!isLast)
                            const Divider(height: 1, indent: 60, endIndent: 16),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // Stok kritis
                if ((data['lowStockItems'] as List).isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Stok Kritis', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      TextButton(onPressed: () => context.go('/products'), child: const Text('Kelola', style: TextStyle(fontSize: 12))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      children: ((data['lowStockItems'] as List<Product>).take(5).toList().asMap().entries.map((entry) {
                        final p = entry.value;
                        final isLast = entry.key == ((data['lowStockItems'] as List).take(5).length - 1);
                        return Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: p.stockQty == 0 ? AppColors.errorLight : AppColors.warningLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  p.stockQty == 0 ? Icons.error_rounded : Icons.warning_rounded,
                                  size: 18,
                                  color: p.stockQty == 0 ? AppColors.error : AppColors.warning,
                                ),
                              ),
                              title: Text(p.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                              subtitle: Text('Sisa ${p.stockQty} ${p.unit}'),
                              trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
                              onTap: () => context.go('/products/${p.id}'),
                              dense: true,
                            ),
                            if (!isLast)
                              const Divider(height: 1, indent: 60, endIndent: 16),
                          ],
                        );
                      })).toList(),
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
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
