import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:spareart_app/core/services/sync_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/bluetooth_printer_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../main.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../providers/cart_provider.dart';
import '../widgets/receipt_widget.dart';

final historyDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  return DateTimeRange(
    start: DateFormatter.startOfDay(now),
    end: DateFormatter.endOfDay(now),
  );
});

/// Riwayat transaksi
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  final String? transactionId;
  const TransactionHistoryScreen({super.key, this.transactionId});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  bool _hasCheckedInitialId = false;

  @override
  void initState() {
    super.initState();
    if (widget.transactionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkInitialId();
      });
    }
  }

  Future<void> _checkInitialId() async {
    if (_hasCheckedInitialId || widget.transactionId == null) return;
    _hasCheckedInitialId = true;

    final db = ref.read(databaseProvider);
    final txn = await db.getTransactionById(widget.transactionId!);
    if (txn != null && mounted) {
      _showReceipt(context, txn);
    }
  }

  Future<void> _printReceipt(
    BuildContext context,
    dynamic settings,
    dynamic txn,
    List<dynamic> details,
  ) async {
    final printerState = ref.read(printerStateProvider);

    if (!printerState.isConnected) {
      AppToast.show(
        context,
        'Hubungkan printer terlebih dahulu di Lainnya → Printer Bluetooth',
        type: ToastType.warning,
      );
      return;
    }

    // Cek koneksi real-time
    final isStillConnected =
        await ref.read(printerStateProvider.notifier).checkConnection();
    if (!isStillConnected) {
      if (context.mounted) {
        AppToast.show(
          context,
          'Koneksi printer terputus. Coba hubungkan ulang.',
          type: ToastType.error,
        );
      }
      return;
    }

    try {
      final printItems = details
          .map((d) => PrintReceiptItem(
                name: d.productName,
                qty: d.item.qty,
                unitPrice: d.item.unitPrice,
                subtotal: d.item.subtotal,
                type: d.itemType,
                workerName: d.item.workerName,
              ))
          .toList();

      final bytes = await ThermalPrintService.generateReceipt(
        storeName: settings.storeName,
        storeAddress: settings.storeAddress,
        storePhone: settings.storePhone,
        invoiceNo: txn.invoiceNo,
        date: txn.createdAt,
        items: printItems,
        total: txn.total,
        paid: txn.paidAmount,
        change: txn.changeAmount,
        footer: settings.receiptFooter,
      );

      final result = await ThermalPrintService.printBytes(bytes);
      HapticFeedback.mediumImpact();

      if (context.mounted) {
        AppToast.show(
          context,
          result ? 'Struk berhasil dicetak!' : 'Gagal mencetak struk',
          type: result ? ToastType.success : ToastType.error,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(
          context,
          'Error: $e',
          type: ToastType.error,
        );
      }
    }
  }

  void _showReceipt(BuildContext context, dynamic txn) {
    final settings = ref.read(settingsServiceProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final itemsAsync =
                        ref.watch(transactionItemsProvider(txn.id));
                    final printerState = ref.watch(printerStateProvider);

                    return itemsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (details) => Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              child: ReceiptWidget(
                                storeName: settings.storeName,
                                storeAddress: settings.storeAddress,
                                storePhone: settings.storePhone,
                                invoiceNo: txn.invoiceNo,
                                date: txn.createdAt,
                                items: details
                                        .map((d) => ReceiptItem(
                                              name: d.productName,
                                              qty: d.item.qty,
                                              unitPrice: d.item.unitPrice,
                                              subtotal: d.item.subtotal,
                                              type: d.itemType,
                                              isApproved: d.item.isApproved,
                                              workerName: d.item.workerName,
                                            ))
                                        .toList(),
                                total: txn.total,
                                paid: txn.paidAmount,
                                change: txn.changeAmount,
                                footer: settings.receiptFooter,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () => _printReceipt(
                                  context,
                                  settings,
                                  txn,
                                  details,
                                ),
                                icon: Icon(
                                  printerState.isConnected
                                      ? Icons.print_rounded
                                      : Icons.print_disabled_rounded,
                                ),
                                label: Text(
                                  printerState.isConnected
                                      ? 'Cetak Struk'
                                      : 'Printer Tidak Terhubung',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: printerState.isConnected
                                      ? AppColors.secondary
                                      : AppColors.textHint,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateRange = ref.watch(historyDateRangeProvider);
    final txns = ref.watch(transactionHistoryProvider((
      start: dateRange.start,
      end: dateRange.end,
    )));
    final theme = Theme.of(context);
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final target = from == 'dashboard' ? '/dashboard' : '/settings';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(target);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Riwayat Transaksi'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => context.go(target),
          ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded),
            onPressed: () async {
              final newRange = await showDateRangePicker(
                context: context,
                initialDateRange: dateRange,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                builder: (context, child) => Theme(
                  data: theme.copyWith(
                    colorScheme: theme.colorScheme.copyWith(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (newRange != null) {
                ref.read(historyDateRangeProvider.notifier).state = DateTimeRange(
                  start: DateFormatter.startOfDay(newRange.start),
                  end: DateFormatter.endOfDay(newRange.end),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primary.withValues(alpha: 0.05),
            child: Row(
              children: [
                const Icon(Icons.filter_list_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '${DateFormatter.formatShort(dateRange.start)} - ${DateFormatter.formatShort(dateRange.end)}',
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (dateRange.start.day != DateTime.now().day || dateRange.start.month != DateTime.now().month)
                  TextButton(
                    onPressed: () {
                      final now = DateTime.now();
                      ref.read(historyDateRangeProvider.notifier).state = DateTimeRange(
                        start: DateFormatter.startOfDay(now),
                        end: DateFormatter.endOfDay(now),
                      );
                    },
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Reset', style: TextStyle(fontSize: 10)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: txns.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.receipt_long_rounded,
              title: 'Belum ada transaksi hari ini',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final txn = items[i];
              return InkWell(
                onTap: () => _showReceipt(context, txn),
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
                          color: AppColors.success.withValues(alpha: 0.1),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(txn.invoiceNo,
                                style: theme.textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(DateFormatter.formatWithTime(txn.createdAt),
                                style: theme.textTheme.labelSmall),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(txn.total),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.primary,
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
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              txn.paymentMethod.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
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
              );
            },
          );
        },
          ),
          )
        ],
      ),
    ));
  }
}

