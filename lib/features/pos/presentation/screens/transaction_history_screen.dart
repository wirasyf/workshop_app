import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dnd_markasban_app/core/services/sync_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../providers/cart_provider.dart';
import '../widgets/receipt_modal.dart';

/// Riwayat transaksi
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  final String? transactionId;
  const TransactionHistoryScreen({super.key, this.transactionId});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  bool _hasCheckedInitialId = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.transactionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkInitialId();
      });
    }

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(transactionHistoryProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialId() async {
    if (_hasCheckedInitialId || widget.transactionId == null) return;
    _hasCheckedInitialId = true;

    final db = ref.read(databaseProvider);
    final txn = await db.getTransactionById(widget.transactionId!);
    if (txn != null && mounted) {
      ReceiptModal.show(context, ref, txn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateRange = ref.watch(historyDateRangeProvider);
    final txns = ref.watch(transactionHistoryProvider);
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
        ),
        body: Column(
          children: [
            _buildFilterPanel(context, ref, dateRange, theme),
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
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        items.length +
                        (ref.read(transactionHistoryProvider.notifier).hasMore
                            ? 1
                            : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      if (i == items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final txn = items[i];
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      txn.invoiceNo,
                                      style: theme.textTheme.titleSmall,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel(
    BuildContext context,
    WidgetRef ref,
    DateTimeRange dateRange,
    ThemeData theme,
  ) {
    final now = DateTime.now();

    // Check which quick chip is active
    final isToday =
        dateRange.start.day == now.day &&
        dateRange.start.month == now.month &&
        dateRange.end.day == now.day &&
        dateRange.end.month == now.month;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        dateRange.start.day == yesterday.day &&
        dateRange.start.month == yesterday.month &&
        dateRange.end.day == yesterday.day &&
        dateRange.end.month == yesterday.month;
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final isThisWeek =
        dateRange.start.day == weekStart.day &&
        dateRange.start.month == weekStart.month &&
        dateRange.end.day == now.day &&
        dateRange.end.month == now.month;
    final isThisMonth =
        dateRange.start.day == 1 &&
        dateRange.start.month == now.month &&
        dateRange.end.day == now.day &&
        dateRange.end.month == now.month;

    String activeLabel = 'Rentang Kustom';
    if (isToday)
      activeLabel = 'Hari Ini';
    else if (isYesterday)
      activeLabel = 'Kemarin';
    else if (isThisWeek)
      activeLabel = 'Minggu Ini';
    else if (isThisMonth)
      activeLabel = 'Bulan Ini';

    void updateRange(DateTime start, DateTime end) {
      ref.read(historyDateRangeProvider.notifier).state = DateTimeRange(
        start: DateFormatter.startOfDay(start),
        end: DateFormatter.endOfDay(end),
      );
      Navigator.pop(context);
    }

    void showFilterOptions() {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Pilih Rentang Waktu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.today_rounded),
                title: const Text('Hari Ini'),
                trailing: isToday
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                      )
                    : null,
                onTap: () => updateRange(now, now),
              ),
              ListTile(
                leading: const Icon(Icons.turn_left_rounded),
                title: const Text('Kemarin'),
                trailing: isYesterday
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                      )
                    : null,
                onTap: () => updateRange(yesterday, yesterday),
              ),
              ListTile(
                leading: const Icon(Icons.view_week_rounded),
                title: const Text('Minggu Ini'),
                trailing: isThisWeek
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                      )
                    : null,
                onTap: () => updateRange(weekStart, now),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_rounded),
                title: const Text('Bulan Ini'),
                trailing: isThisMonth
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                      )
                    : null,
                onTap: () => updateRange(DateTime(now.year, now.month, 1), now),
              ),
              ListTile(
                leading: const Icon(Icons.date_range_rounded),
                title: const Text('Pilih Tanggal Kustom...'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final newRange = await showDateRangePicker(
                    context: context,
                    initialDateRange: dateRange,
                    firstDate: DateTime(2020),
                    lastDate: now,
                  );
                  if (newRange != null) {
                    ref
                        .read(historyDateRangeProvider.notifier)
                        .state = DateTimeRange(
                      start: DateFormatter.startOfDay(newRange.start),
                      end: DateFormatter.endOfDay(newRange.end),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                activeLabel == 'Rentang Kustom'
                    ? '${DateFormatter.formatShort(dateRange.start)} - ${DateFormatter.formatShort(dateRange.end)}'
                    : activeLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: showFilterOptions,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Text(
                    'Ubah',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
