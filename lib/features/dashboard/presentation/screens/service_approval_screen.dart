import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../shared/utils/app_toast.dart';
import 'owner_dashboard_screen.dart';

final pendingApprovalsProvider = FutureProvider<List<TypedResult>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getPendingServiceApprovals();
});

final approvedApprovalsProvider = FutureProvider<List<TypedResult>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getApprovedServiceApprovals();
});

/// Provider to track current tab in Service Approval screen
final approvalTabProvider = StateProvider<int>((ref) => 0); // 0 = Menunggu, 1 = Riwayat

class ServiceApprovalScreen extends ConsumerWidget {
  const ServiceApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final target = from == 'dashboard' ? '/dashboard' : '/settings';
    final activeTab = ref.watch(approvalTabProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(target);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Persetujuan Jasa'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => context.go(target),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.invalidate(pendingApprovalsProvider);
                ref.invalidate(approvedApprovalsProvider);
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Custom Tab: Menunggu | Riwayat (styled like POS screen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _TabButton(
                      label: 'Menunggu',
                      icon: Icons.pending_actions_rounded,
                      isSelected: activeTab == 0,
                      onTap: () => ref.read(approvalTabProvider.notifier).state = 0,
                    ),
                    _TabButton(
                      label: 'Riwayat',
                      icon: Icons.history_rounded,
                      isSelected: activeTab == 1,
                      onTap: () => ref.read(approvalTabProvider.notifier).state = 1,
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: activeTab == 0 ? const _PendingTab() : const _HistoryTab(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Tab Button designed to match POS screen style
class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingTab extends ConsumerWidget {
  const _PendingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingApprovalsProvider);
    final theme = Theme.of(context);

    return pending.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                const Text('Semua jasa sudah disetujui', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final row = list[index];
            final item = row.readTable(ref.read(databaseProvider).transactionItems);
            final txn = row.readTable(ref.read(databaseProvider).transactions);
            final service = row.readTableOrNull(ref.read(databaseProvider).services);

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('MENUNGGU', style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        Text(DateFormatter.formatShort(txn.createdAt), style: theme.textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(service?.name ?? 'Jasa Tidak Diketahui', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Invoice: ${txn.invoiceNo}', style: theme.textTheme.bodySmall),
                    Text('Kasir ID: ${txn.userId}', style: theme.textTheme.bodySmall),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Nilai Jasa', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text(CurrencyFormatter.format(item.subtotal), style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                AppToast.show(context, 'Fitur tolak segera hadir');
                              },
                              child: const Text('Tolak', style: TextStyle(color: AppColors.error)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                await ref.read(databaseProvider).approveTransactionItem(item.id);
                                await ref.read(syncServiceProvider).enqueue(
                                  tableName: 'transaction_items',
                                  recordId: item.id,
                                  operation: 'update',
                                  data: {'is_approved': true},
                                );
                                ref.invalidate(pendingApprovalsProvider);
                                ref.invalidate(approvedApprovalsProvider);
                                ref.invalidate(ownerDashboardProvider);
                                if (context.mounted) {
                                  AppToast.show(context, 'Jasa disetujui', type: ToastType.success);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: const Text('Setujui'),
                            ),
                          ],
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
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(approvedApprovalsProvider);
    final theme = Theme.of(context);

    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                const Text('Belum ada riwayat persetujuan', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final row = list[index];
            final item = row.readTable(ref.read(databaseProvider).transactionItems);
            final txn = row.readTable(ref.read(databaseProvider).transactions);
            final service = row.readTableOrNull(ref.read(databaseProvider).services);

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('DISETUJUI', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        Text(DateFormatter.formatShort(txn.createdAt), style: theme.textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(service?.name ?? 'Jasa Tidak Diketahui', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Invoice: ${txn.invoiceNo}', style: theme.textTheme.bodySmall),
                    Text('Kasir ID: ${txn.userId}', style: theme.textTheme.bodySmall),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Nilai Jasa', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(CurrencyFormatter.format(item.subtotal), style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
  }
}
