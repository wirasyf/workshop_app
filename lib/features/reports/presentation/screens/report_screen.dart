import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/metric_card.dart';
import '../../../../core/enums/report_period.dart';
import '../../../../core/models/transaction_model.dart';
import '../../../pos/data/transaction_repository.dart';
import '../../../pos/presentation/widgets/receipt_modal.dart';
import '../../../products/data/product_repository.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/utils/app_toast.dart';
import 'package:intl/intl.dart';

final reportPeriodProvider = StateProvider<ReportPeriod>(
  (ref) => ReportPeriod.daily,
);

final customStartDateProvider = StateProvider<DateTime?>((ref) => null);
final customEndDateProvider = StateProvider<DateTime?>((ref) => null);

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final reportDataProvider = StreamProvider<Map<String, dynamic>>((ref) async* {
  final period = ref.watch(reportPeriodProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  final selectedDate = ref.watch(selectedDateProvider);

  DateTime start;
  DateTime end;

  switch (period) {
    case ReportPeriod.daily:
      start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      end = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        23,
        59,
        59,
        999,
      );
      break;
    case ReportPeriod.weekly:
      start = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
      start = DateTime(start.year, start.month, start.day);
      end = start.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );
      break;
    case ReportPeriod.monthly:
      start = DateTime(selectedDate.year, selectedDate.month, 1);
      final nextMonth = DateTime(selectedDate.year, selectedDate.month + 1, 1);
      end = nextMonth.subtract(const Duration(milliseconds: 1));
      break;
    case ReportPeriod.yearly:
      start = DateTime(selectedDate.year, 1, 1);
      end = DateTime(selectedDate.year, 12, 31, 23, 59, 59, 999);
      break;
    case ReportPeriod.custom:
      start =
          ref.watch(customStartDateProvider) ??
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          );
      final customEnd = ref.watch(customEndDateProvider) ?? DateTime.now();
      end = DateTime(
        customEnd.year,
        customEnd.month,
        customEnd.day,
        23,
        59,
        59,
        999,
      );
      break;
  }

  await for (final transactions in repo.getTransactionsByDateRangeStream(start, end)) {
    double totalSales = 0.0;
    double totalHpp = 0.0;
    for (var tx in transactions) {
      if (tx.status == 'completed') {
        final items = await repo.getTransactionItems(tx.id);
        double txSales = 0.0;
        double txHpp = 0.0;
        for (var item in items) {
          if (!item.isReturned) {
            txSales += item.subtotal;
            txHpp += (item.costPrice * item.qty);
          }
        }
        totalSales += txSales;
        totalHpp += txHpp;
      }
    }
    double labaBersih = totalSales - totalHpp;

    yield {
      'totalSales': totalSales,
      'totalHpp': totalHpp,
      'labaBersih': labaBersih,
      'txnCount': transactions.where((t) => t.status == 'completed').length,
      'transactions': transactions,
      'start': start,
      'end': end,
    };
  }
});

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  Future<void> _exportToExcel(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> data,
  ) async {
    try {
      final transactions = data['transactions'] as List<TransactionModel>;
      final period = ref.read(reportPeriodProvider);

      String periodType = '';
      switch (period) {
        case ReportPeriod.daily:
          periodType = 'Harian';
          break;
        case ReportPeriod.weekly:
          periodType = 'Mingguan';
          break;
        case ReportPeriod.monthly:
          periodType = 'Bulanan';
          break;
        case ReportPeriod.yearly:
          periodType = 'Tahunan';
          break;
        case ReportPeriod.custom:
          periodType = 'Kustom';
          break;
      }

      final label = _getFilterLabel(ref, period);
      final safePeriodLabel = label.replaceAll('/', '-').replaceAll(' ', '_');

      var excel = Excel.createExcel();

      if (excel.tables.keys.isNotEmpty &&
          excel.tables.keys.first != 'Laporan') {
        excel.rename(excel.tables.keys.first, 'Laporan');
      }

      Sheet sheetObject = excel['Laporan'];
      excel.setDefaultSheet('Laporan');

      // Add Headers
      sheetObject.appendRow([
        TextCellValue('Tanggal dan Waktu'),
        TextCellValue('No Invoice'),
        TextCellValue('Keterangan Produk dan Jumlah'),
        TextCellValue('Harga Beli Produk'),
        TextCellValue('Harga Jual Produk'),
        TextCellValue('Harga Karyawan'),
        TextCellValue('Keterangan Jasa'),
        TextCellValue('Keterangan Mekanik'),
        TextCellValue('Harga Jasa'),
        TextCellValue('Pembayaran Karyawan'),
        TextCellValue('Pembayaran Karyawan (60%)'),
        TextCellValue('Pembayaran Karyawan (40%)'),
        TextCellValue('Harga Jual Total'),
        TextCellValue('Laba Kotor'),
        TextCellValue('Status'),
      ]);

      // Apply style to header row
      final headerStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#1976D2'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        bold: true,
      );
      for (int i = 0; i < 15; i++) {
        var cell = sheetObject.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.cellStyle = headerStyle;
        sheetObject.setColumnAutoFit(i);
      }

      final repo = ref.read(transactionRepositoryProvider);
      final productRepo = ref.read(productRepositoryProvider);

      // Add Data
      for (var tx in transactions) {
        final items = await repo.getTransactionItems(tx.id);

        List<String> productDetails = [];
        List<String> serviceDetails = [];
        Set<String> mechanics = {};

        double totalProductSales = 0.0;
        double totalServiceSales = 0.0;
        double totalWorkerPrice = 0.0;

        double txTotal = 0.0;
        double txTotalCost = 0.0;

        for (var item in items) {
          if (item.itemType == 'product') {
            if (item.isReturned) {
              productDetails.add(
                '${item.productName ?? 'Produk'} x${item.qty} (Retur)',
              );
            } else {
              productDetails.add(
                '${item.productName ?? 'Produk'} x${item.qty}',
              );
              totalProductSales += item.subtotal;
              txTotal += item.subtotal;
              txTotalCost += (item.costPrice * item.qty);
              if (item.productId != null) {
                try {
                  final product = await productRepo
                      .getProductById(item.productId!)
                      .first;
                  if (product != null) {
                    totalWorkerPrice += product.workerPrice * item.qty;
                  }
                } catch (_) {}
              }
            }
          } else if (item.itemType == 'service') {
            if (item.isReturned) {
              serviceDetails.add(
                '${item.productName ?? 'Jasa'} x${item.qty} (Retur)',
              );
            } else {
              serviceDetails.add('${item.productName ?? 'Jasa'} x${item.qty}');
              totalServiceSales += item.subtotal;
              txTotal += item.subtotal;
              txTotalCost += (item.costPrice * item.qty);
              if (item.workerName != null && item.workerName!.isNotEmpty) {
                mechanics.add(item.workerName!);
              }
            }
          }
        }

        String statusIndo = tx.status;
        if (tx.status == 'completed') {
          statusIndo = 'Selesai';
        } else if (tx.status == 'pending') {
          statusIndo = 'Tertunda';
        } else if (tx.status == 'cancelled') {
          statusIndo = 'Dibatalkan';
        } else if (tx.status == 'returned') {
          statusIndo = 'Diretur';
        }

        double pembayaranKaryawan = totalWorkerPrice + totalServiceSales;
        double pembayaranKaryawan60 = pembayaranKaryawan * 0.6;
        double pembayaranKaryawan40 = pembayaranKaryawan * 0.4;

        sheetObject.appendRow([
          TextCellValue(DateFormatter.formatWithTime(tx.createdAt)),
          TextCellValue(tx.invoiceNo),
          TextCellValue(
            productDetails.isNotEmpty ? productDetails.join(', ') : '-',
          ),
          TextCellValue(CurrencyFormatter.format(txTotalCost)),
          TextCellValue(CurrencyFormatter.format(totalProductSales)),
          TextCellValue(CurrencyFormatter.format(totalWorkerPrice)),
          TextCellValue(
            serviceDetails.isNotEmpty ? serviceDetails.join(', ') : '-',
          ),
          TextCellValue(mechanics.isNotEmpty ? mechanics.join(', ') : '-'),
          TextCellValue(CurrencyFormatter.format(totalServiceSales)),
          TextCellValue(CurrencyFormatter.format(pembayaranKaryawan)),
          TextCellValue(CurrencyFormatter.format(pembayaranKaryawan60)),
          TextCellValue(CurrencyFormatter.format(pembayaranKaryawan40)),
          TextCellValue(CurrencyFormatter.format(txTotal)),
          TextCellValue(CurrencyFormatter.format(txTotal - txTotalCost)),
          TextCellValue(statusIndo),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/Laporan_${periodType}_$safePeriodLabel.xlsx';
        final file = File(path);
        await file.writeAsBytes(fileBytes);

        if (context.mounted) {
          AppToast.show(
            context,
            'Laporan $periodType ($label) berhasil diunduh!',
            type: ToastType.success,
          );
          await Share.shareXFiles([
            XFile(path),
          ], text: 'Laporan $periodType ($label)');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(
          context,
          'Gagal mengekspor laporan: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _showMonthYearPicker(
    BuildContext context,
    WidgetRef ref,
    bool isYearOnly,
  ) async {
    final current = ref.read(selectedDateProvider);
    int selectedYear = current.year;
    int selectedMonth = current.month;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(isYearOnly ? 'Pilih Tahun' : 'Pilih Bulan & Tahun'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(() => selectedYear--),
                      ),
                      Text(
                        '$selectedYear',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setState(() => selectedYear++),
                      ),
                    ],
                  ),
                  if (!isYearOnly) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(12, (index) {
                        final month = index + 1;
                        final isSelected = month == selectedMonth;
                        return InkWell(
                          onTap: () => setState(() => selectedMonth = month),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Text(
                              DateFormat(
                                'MMM',
                                'id_ID',
                              ).format(DateTime(2020, month)),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    ref.read(selectedDateProvider.notifier).state = DateTime(
                      selectedYear,
                      isYearOnly ? 1 : selectedMonth,
                      1,
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Pilih'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getFilterLabel(WidgetRef ref, ReportPeriod period) {
    if (period == ReportPeriod.custom) {
      final start = ref.watch(customStartDateProvider);
      final end = ref.watch(customEndDateProvider);
      if (start != null && end != null) {
        return '${DateFormatter.formatShort(start)} - ${DateFormatter.formatShort(end)}';
      }
      return 'Pilih Tanggal';
    }

    final selected = ref.watch(selectedDateProvider);
    switch (period) {
      case ReportPeriod.daily:
        return DateFormatter.formatShort(selected);
      case ReportPeriod.weekly:
        final start = selected.subtract(Duration(days: selected.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${DateFormatter.formatShort(start)} - ${DateFormatter.formatShort(end)}';
      case ReportPeriod.monthly:
        return DateFormat('MMMM yyyy', 'id_ID').format(selected);
      case ReportPeriod.yearly:
        return '${selected.year}';
      default:
        return 'Pilih Tanggal';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final report = ref.watch(reportDataProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Keuangan'),
        actions: [
          report.maybeWhen(
            data: (data) => IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Unduh Excel',
              onPressed: () {
                AppToast.show(
                  context,
                  'Menyiapkan file Excel...',
                  type: ToastType.loading,
                );
                _exportToExcel(context, ref, data);
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<ReportPeriod>(
                    value: period,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: ReportPeriod.values.map((p) {
                      final label = switch (p) {
                        ReportPeriod.daily => 'Harian',
                        ReportPeriod.weekly => 'Mingguan',
                        ReportPeriod.monthly => 'Bulanan',
                        ReportPeriod.yearly => 'Tahunan',
                        ReportPeriod.custom => 'Kustom Tanggal',
                      };
                      return DropdownMenuItem(
                        value: p,
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 13),
                        ),
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
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (period == ReportPeriod.daily ||
                          period == ReportPeriod.weekly) {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: ref.read(selectedDateProvider),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          ref.read(selectedDateProvider.notifier).state =
                              picked;
                        }
                      } else if (period == ReportPeriod.monthly ||
                          period == ReportPeriod.yearly) {
                        await _showMonthYearPicker(
                          context,
                          ref,
                          period == ReportPeriod.yearly,
                        );
                      } else if (period == ReportPeriod.custom) {
                        final currentStart =
                            ref.read(customStartDateProvider) ?? DateTime.now();
                        final currentEnd =
                            ref.read(customEndDateProvider) ?? DateTime.now();
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: DateTimeRange(
                            start: currentStart,
                            end: currentEnd,
                          ),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          ref.read(customStartDateProvider.notifier).state =
                              picked.start;
                          ref.read(customEndDateProvider.notifier).state =
                              picked.end;
                        }
                      }
                    },
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      _getFilterLabel(ref, period),
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) => Center(child: Text('Error: $e')),
              data: (data) {
                final transactions =
                    data['transactions'] as List<TransactionModel>;

                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: MetricCard(
                                    label: 'Total Pendapatan',
                                    value: CurrencyFormatter.format(
                                      data['totalSales'],
                                    ),
                                    icon: Icons.monetization_on_rounded,
                                    iconColor: AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: MetricCard(
                                    label: 'Jml Transaksi',
                                    value: '${data['txnCount']}',
                                    icon: Icons.receipt_long_rounded,
                                    iconColor: AppColors.info,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: MetricCard(
                                    label: 'Total HPP',
                                    value: CurrencyFormatter.format(
                                      data['totalHpp'],
                                    ),
                                    icon: Icons.inventory_2_rounded,
                                    iconColor: AppColors.warning,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: MetricCard(
                                    label: 'Laba Bersih',
                                    value: CurrencyFormatter.format(
                                      data['labaBersih'],
                                    ),
                                    icon: Icons.trending_up_rounded,
                                    iconColor: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Daftar Transaksi',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    transactions.isEmpty
                        ? const SliverFillRemaining(
                            child: EmptyStateWidget(
                              icon: Icons.receipt_long_rounded,
                              title: 'Belum ada transaksi di periode ini',
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final txn = transactions[index];
                                return Column(
                                  children: [
                                    InkWell(
                                      onTap: () =>
                                          ReceiptModal.show(context, ref, txn),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: theme.cardTheme.color,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppColors.success
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
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
                                                        style: theme
                                                            .textTheme
                                                            .titleSmall,
                                                      ),
                                                      if (txn.status ==
                                                          'returned') ...[
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: AppColors
                                                                .error
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                          child: const Text(
                                                            'DIRETUR',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: AppColors
                                                                  .error,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
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
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  CurrencyFormatter.format(
                                                    txn.total,
                                                  ),
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                );
                              }, childCount: transactions.length),
                            ),
                          ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
