import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/utils/excel_export_service.dart';
import '../../../../shared/widgets/metric_card.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/utils/report_utils.dart';

enum ReportPeriod { daily, weekly, monthly, yearly }

final reportPeriodProvider = StateProvider<ReportPeriod>(
  (ref) => ReportPeriod.daily,
);

final reportDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseProvider);
  final period = ref.watch(reportPeriodProvider);
  final now = DateTime.now();

  late DateTime start;
  late DateTime end;
  late int chartDays;

  switch (period) {
    case ReportPeriod.daily:
      start = DateFormatter.startOfDay(now);
      end = DateFormatter.endOfDay(now);
      chartDays = 7;
    case ReportPeriod.weekly:
      start = DateFormatter.startOfWeek(now);
      end = DateFormatter.endOfDay(now);
      chartDays = 7;
    case ReportPeriod.monthly:
      start = DateFormatter.startOfMonth(now);
      end = DateFormatter.endOfDay(now);
      chartDays = 30;
    case ReportPeriod.yearly:
      start = DateTime(now.year, 1, 1);
      end = DateFormatter.endOfDay(now);
      chartDays = 365;
  }

  final profitSummary = await db.getSummaryProfit(start, end);

  return {
    'totalSales': profitSummary['totalSales'] ?? 0.0,
    'totalCost': profitSummary['totalCost'] ?? 0.0,
    'grossProfit': profitSummary['grossProfit'] ?? 0.0,
    'margin': profitSummary['margin'] ?? 0.0,
    'serviceRevenue': profitSummary['serviceRevenue'] ?? 0.0,
    'partsRevenue': profitSummary['partsRevenue'] ?? 0.0,
    'txnCount': await db.getTransactionCount(start, end),
    'topProducts': await db.getTopProducts(start, end, limit: 5),
    'dailySales': await db.getDailySales(chartDays > 30 ? 30 : chartDays),
    'start': start,
    'end': end,
  };
});

/// Layar laporan penjualan & profit
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final report = ref.watch(reportDataProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Keuangan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_rounded),
            tooltip: 'Unduh Laporan Excel',
            onPressed: () => _exportExcel(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Period filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ReportPeriod.values.map((p) {
                final label = switch (p) {
                  ReportPeriod.daily => 'Harian',
                  ReportPeriod.weekly => 'Mingguan',
                  ReportPeriod.monthly => 'Bulanan',
                  ReportPeriod.yearly => 'Tahunan',
                };
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: period == p,
                      onSelected: (_) =>
                          ref.read(reportPeriodProvider.notifier).state = p,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.infoLight,
                      labelStyle: TextStyle(
                        color: period == p ? Colors.white : AppColors.primary,
                        fontWeight: period == p ? FontWeight.bold : FontWeight.w600,
                        fontSize: 12,
                      ),
                      side: const BorderSide(color: Colors.transparent),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (data) {
                final daily = data['dailySales'] as List<Map<String, dynamic>>;
                final totalSales = (data['totalSales'] as num?)?.toDouble() ?? 0;
                final totalCost = (data['totalCost'] as num?)?.toDouble() ?? 0;
                final grossProfit = (data['grossProfit'] as num?)?.toDouble() ?? 0;
                final serviceRev = (data['serviceRevenue'] as num?)?.toDouble() ?? 0;
                final partsRev = (data['partsRevenue'] as num?)?.toDouble() ?? 0;

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(reportDataProvider),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Metric Cards Row 1: Omzet & Transaksi
                      Row(children: [
                        Expanded(child: MetricCard(
                          label: 'Omzet', value: CurrencyFormatter.format(totalSales),
                          icon: Icons.monetization_on_rounded, iconColor: AppColors.success,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: MetricCard(
                          label: 'Transaksi', value: '${data['txnCount'] ?? 0}',
                          icon: Icons.receipt_long_rounded, iconColor: AppColors.info,
                        )),
                      ]),
                      const SizedBox(height: 12),

                      // Metric Cards Row 2: Modal & Laba
                      Row(children: [
                        Expanded(child: MetricCard(
                          label: 'Modal (HPP)', value: CurrencyFormatter.format(totalCost),
                          icon: Icons.account_balance_wallet_rounded, iconColor: AppColors.warning,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: MetricCard(
                          label: 'Laba Kotor', value: CurrencyFormatter.format(grossProfit),
                          icon: Icons.trending_up_rounded,
                          iconColor: grossProfit >= 0 ? AppColors.success : AppColors.error,
                        )),
                      ]),
                      const SizedBox(height: 12),

                      // Metric Cards Row 3: Jasa & Sparepart
                      Row(children: [
                        Expanded(child: MetricCard(
                          label: 'Pendapatan Jasa', value: CurrencyFormatter.format(serviceRev),
                          icon: Icons.build_rounded, iconColor: AppColors.info,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: MetricCard(
                          label: 'Pendapatan Part', value: CurrencyFormatter.format(partsRev),
                          icon: Icons.settings_rounded, iconColor: AppColors.primary,
                        )),
                      ]),
                      const SizedBox(height: 20),

                      // Chart
                      Text('Grafik Penjualan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildChart(context, daily, period),
                      const SizedBox(height: 24),

                      const Divider(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/history'),
                          icon: const Icon(Icons.receipt_long_rounded),
                          label: const Text('Buka Riwayat & Detail Transaksi'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<Map<String, dynamic>> daily, ReportPeriod period) {
    final theme = Theme.of(context);
    final isMonthly = period == ReportPeriod.monthly || period == ReportPeriod.yearly;
    final chartDays = isMonthly ? 30 : 7;

    final displaySales = ReportUtils.getChartDisplayData(daily, chartDays);
    final maxY = ReportUtils.getChartMaxY(displaySales);

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF334155),
              tooltipBorder: BorderSide.none,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  CurrencyFormatter.format(rod.toY * 1000),
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              },
            ),
          ),
          barGroups: displaySales.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                ReportUtils.buildBarRod(
                  value: (e.value['total'] as num?)?.toDouble() ?? 0,
                  maxY: maxY,
                  width: isMonthly ? 6 : 16,
                  radius: isMonthly ? 2 : 6,
                  backgroundBarColor: AppColors.border.withOpacity(0.3),
                ),
              ],
            );
          }).toList(),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.border.withOpacity(0.5), strokeWidth: 1, dashArray: [4, 4]),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) return const SizedBox();
                return SideTitleWidget(meta: meta, space: 4,
                  child: Text(CurrencyFormatter.formatCompact(value * 1000),
                    style: TextStyle(fontSize: 9, color: theme.textTheme.bodySmall?.color ?? AppColors.textSecondary, fontWeight: FontWeight.w500)));
              },
            )),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 36, interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < displaySales.length) {
                  if (isMonthly && idx % 5 != 0 && idx != displaySales.length - 1) {
                    return SideTitleWidget(meta: meta, child: const SizedBox());
                  }
                  final d = displaySales[idx]['date'] as String;
                  String label;
                  if (d.length >= 10) {
                    label = '${d.substring(8)}/${d.substring(5, 7)}';
                  } else {
                    label = '${idx + 1}';
                  }
                  return SideTitleWidget(meta: meta, space: 6, angle: isMonthly ? -0.6 : -0.5,
                    child: Text(label, style: TextStyle(fontSize: isMonthly ? 8 : 9,
                      color: theme.textTheme.bodySmall?.color ?? AppColors.textPrimary, fontWeight: FontWeight.w600)));
                }
                return SideTitleWidget(meta: meta, child: const SizedBox());
              },
            )),
          ),
        ),
      ),
    );
  }

  Future<void> _exportExcel(BuildContext context, WidgetRef ref) async {
    final data = ref.read(reportDataProvider).value;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data belum tersedia')));
      return;
    }

    final period = ref.read(reportPeriodProvider);
    final periodLabel = switch (period) {
      ReportPeriod.daily => 'Harian',
      ReportPeriod.weekly => 'Mingguan',
      ReportPeriod.monthly => 'Bulanan',
      ReportPeriod.yearly => 'Tahunan',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Membuat laporan Excel...')),
    );

    try {
      final db = ref.read(databaseProvider);
      final exportService = ExcelExportService(db);
      final file = await exportService.generateReport(
        start: data['start'] as DateTime,
        end: data['end'] as DateTime,
        periodLabel: periodLabel,
        storeName: 'SpareArt Motor',
      );

      if (context.mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Laporan Keuangan $periodLabel - SpareArt Motor',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor: $e')),
        );
      }
    }
  }
}
