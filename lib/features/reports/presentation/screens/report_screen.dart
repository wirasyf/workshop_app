import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/database/app_database.dart';

import '../../../../core/services/sync_service.dart';
import '../../../../shared/widgets/metric_card.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/utils/report_utils.dart';

enum ReportPeriod { daily, weekly, monthly }

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
  }

  return {
    'totalSales': await db.getTotalSales(start, end),
    'txnCount': await db.getTransactionCount(start, end),
    'topProducts': await db.getTopProducts(start, end, limit: 5),
    'dailySales': await db.getDailySales(chartDays),
    'transactions': await db.getTransactionsByDate(start, end),
    'start': start,
    'end': end,
  };
});

/// Layar laporan penjualan
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final report = ref.watch(reportDataProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Unduh Laporan CSV',
            onPressed: () => _exportReport(context, ref),
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
                };
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: period == p,
                      onSelected: (_) =>
                          ref.read(reportPeriodProvider.notifier).state = p,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.infoLight,
                      labelStyle: TextStyle(
                        color: period == p ? Colors.white : AppColors.primary,
                        fontWeight: period == p
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 13,
                      ),
                      side: const BorderSide(color: Colors.transparent),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                final txns = data['transactions'] as List<Transaction>;
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(reportDataProvider),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: MetricCard(
                              label: 'Omzet',
                              value: CurrencyFormatter.formatCompact(
                                data['totalSales'] ?? 0,
                              ),
                              icon: Icons.monetization_on_outlined,
                              iconColor: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MetricCard(
                              label: 'Transaksi',
                              value: '${data['txnCount'] ?? 0}',
                              icon: Icons.receipt_long_outlined,
                              iconColor: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Chart
                      Text(
                        'Grafik Penjualan',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildChart(context, daily, period),
                      const SizedBox(height: 24),



                      // Riwayat Transaksi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Riwayat Transaksi',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${txns.length} transaksi',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (txns.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Belum ada transaksi'),
                        )
                      else
                        ...txns
                            .take(10)
                            .map(
                              (txn) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.cardTheme.color,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.receipt,
                                        color: AppColors.success,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            txn.invoiceNo,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            DateFormatter.formatWithTime(
                                              txn.createdAt,
                                            ),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 11,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyFormatter.format(txn.total),
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.successLight,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            txn.paymentMethod.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      if (txns.length > 10)
                        Center(
                          child: TextButton(
                            onPressed: () => context.go('/history'),
                            child: Text(
                              'Lihat ${txns.length - 10} transaksi lainnya',
                              style: const TextStyle(fontSize: 12),
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

  Widget _buildChart(
    BuildContext context,
    List<Map<String, dynamic>> daily,
    ReportPeriod period,
  ) {
    final theme = Theme.of(context);
    final isMonthly = period == ReportPeriod.monthly;
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
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  CurrencyFormatter.formatCompact(rod.toY * 1000),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
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
                  backgroundBarColor: AppColors.border.withValues(alpha: 0.3),
                ),
              ],
            );
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
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max)
                    return const SizedBox();
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
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < displaySales.length) {
                    if (isMonthly &&
                        idx % 5 != 0 &&
                        idx != displaySales.length - 1) {
                      return SideTitleWidget(
                        meta: meta,
                        child: const SizedBox(),
                      );
                    }
                    final d = displaySales[idx]['date'] as String;
                    String label;
                    if (d.length >= 10) {
                      label = '${d.substring(8)}/${d.substring(5, 7)}';
                    } else {
                      label = '${idx + 1}';
                    }
                    return SideTitleWidget(
                      meta: meta,
                      space: 6,
                      angle: isMonthly ? -0.6 : -0.5,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: isMonthly ? 8 : 9,
                          color: theme.textTheme.bodySmall?.color ?? AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return SideTitleWidget(meta: meta, child: const SizedBox());
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportReport(BuildContext context, WidgetRef ref) async {
    final data = ref.read(reportDataProvider).valueOrNull;
    if (data == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data belum tersedia')));
      return;
    }

    final period = ref.read(reportPeriodProvider);
    final periodLabel = switch (period) {
      ReportPeriod.daily => 'Harian',
      ReportPeriod.weekly => 'Mingguan',
      ReportPeriod.monthly => 'Bulanan',
    };

    final txns = data['transactions'] as List<Transaction>;
    final top = data['topProducts'] as List<Map<String, dynamic>>;

    // Build CSV rows
    final rows = <List<String>>[
      ['Laporan Penjualan SpareArt Motor'],
      ['Periode: $periodLabel'],
      ['Total Omzet: ${CurrencyFormatter.format(data['totalSales'] ?? 0)}'],
      ['Jumlah Transaksi: ${data['txnCount'] ?? 0}'],
      [],
      ['=== RIWAYAT TRANSAKSI ==='],
      ['No', 'Invoice', 'Tanggal', 'Metode Bayar', 'Total'],
    ];

    for (var i = 0; i < txns.length; i++) {
      final t = txns[i];
      rows.add([
        '${i + 1}',
        t.invoiceNo,
        DateFormatter.formatWithTime(t.createdAt),
        t.paymentMethod,
        CurrencyFormatter.format(t.total),
      ]);
    }

    rows.addAll([
      [],
      ['=== PRODUK TERLARIS ==='],
      ['No', 'Nama Produk', 'Jumlah Terjual', 'Total Pendapatan'],
    ]);
    for (var i = 0; i < top.length; i++) {
      final p = top[i];
      rows.add([
        '${i + 1}',
        p['name']?.toString() ?? '-',
        '${p['totalQty'] ?? 0}',
        CurrencyFormatter.format((p['totalRevenue'] as num?)?.toDouble() ?? 0),
      ]);
    }

    final csvStr = const CsvEncoder().convert(rows);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fileName =
          'laporan_${periodLabel.toLowerCase()}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csvStr);

      if (context.mounted) {
        // Menggunakan shareXFiles yang merupakan standar terbaru dari share_plus
        await Share.shareXFiles([
          XFile(file.path),
        ], subject: 'Laporan Penjualan $periodLabel - SpareArt Motor');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengekspor: $e')));
      }
    }
  }
}
