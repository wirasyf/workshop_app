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
import '../../../../core/utils/date_picker_utils.dart';
import '../../../../core/enums/report_period.dart';

final reportPeriodProvider = StateProvider<ReportPeriod>((ref) => ReportPeriod.daily);
final reportDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final reportDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseProvider);
  final period = ref.watch(reportPeriodProvider);
  final selectedDate = ref.watch(reportDateProvider);

  late DateTime start;
  late DateTime end;

  switch (period) {
    case ReportPeriod.daily:
      start = DateFormatter.startOfDay(selectedDate);
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

  final chartStart = period == ReportPeriod.daily ? start.subtract(const Duration(days: 6)) : start;
  final chartEnd = end;

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
    'dailySales': await db.getSalesByDateRange(chartStart, chartEnd),
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
            child: Consumer(
              builder: (context, ref, _) {
                final current = ref.watch(reportDateProvider);
                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<ReportPeriod>(
                        value: period,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                          filled: true,
                          fillColor: theme.cardTheme.color,
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
                            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(reportPeriodProvider.notifier).state = val;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: () async {
                          final picked = await DatePickerUtils.pickDate(context, period, current);
                          if (picked != null) {
                            ref.read(reportDateProvider.notifier).state = picked;
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                            color: theme.cardTheme.color,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DatePickerUtils.formatSelectedDate(period, current), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
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
                      Consumer(
                        builder: (context, ref, _) => _buildChart(context, daily, period, ref.watch(reportDateProvider)),
                      ),
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

  Widget _buildChart(BuildContext context, List<Map<String, dynamic>> daily, ReportPeriod period, DateTime selectedDate) {
    final theme = Theme.of(context);
    final displaySales = ReportUtils.getChartDisplayData(daily, period, selectedDate);
    final maxY = ReportUtils.getChartMaxY(displaySales);

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
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
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= displaySales.length) return const SizedBox();
                
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  angle: period == ReportPeriod.weekly ? 0 : -0.5,
                  child: Text(
                    displaySales[index]['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.textTheme.bodySmall?.color ?? AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            )),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
        ),
      ),
    );
  }

  Future<void> _exportExcel(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        ReportPeriod tempPeriod = ref.read(reportPeriodProvider);
        DateTime tempDate = ref.read(reportDateProvider);
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Export Laporan Keuangan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pilih periode laporan yang ingin diexport:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ReportPeriod>(
                    value: tempPeriod,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      if (val != null) {
                        setState(() => tempPeriod = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await DatePickerUtils.pickDate(context, tempPeriod, tempDate);
                      if (picked != null) {
                        setState(() => tempDate = picked);
                      }
                    },
                    icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                    label: Text(DatePickerUtils.formatSelectedDate(tempPeriod, tempDate)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, {'period': tempPeriod, 'date': tempDate}),
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;
    if (!context.mounted) return;
    
    final selectedPeriod = result['period'] as ReportPeriod;
    final selectedDate = result['date'] as DateTime;

    final db = ref.read(databaseProvider);
    late DateTime start;
    late DateTime end;

    switch (selectedPeriod) {
      case ReportPeriod.daily:
        start = DateFormatter.startOfDay(selectedDate);
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

    final periodLabel = switch (selectedPeriod) {
      ReportPeriod.daily => 'Harian',
      ReportPeriod.weekly => 'Mingguan',
      ReportPeriod.monthly => 'Bulanan',
      ReportPeriod.yearly => 'Tahunan',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Membuat laporan Excel...')),
    );

    try {
      final exportService = ExcelExportService(db);
      final file = await exportService.generateReport(
        start: start,
        end: end,
        periodLabel: periodLabel,
        storeName: 'D&D Markas Ban',
      );

      if (context.mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Laporan Keuangan $periodLabel - D&D Markas Ban',
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
