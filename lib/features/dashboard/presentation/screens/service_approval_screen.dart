import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../../core/models/transaction_model.dart';
import '../../../../shared/widgets/empty_state_widget.dart';

final approvalTabProvider = StateProvider<int>((ref) => 0); // 0 = Menunggu, 1 = Riwayat

final pendingApprovalsProvider = StreamProvider<List<TransactionItemModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('transaction_items')
      .where('itemType', isEqualTo: 'service')
      .where('isApproved', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.map((d) => TransactionItemModel.fromFirestore(d)).toList());
});

final historyApprovalsProvider = StreamProvider<List<TransactionItemModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('transaction_items')
      .where('itemType', isEqualTo: 'service')
      .where('isApproved', isEqualTo: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map((d) => TransactionItemModel.fromFirestore(d)).toList());
});

class ServiceApprovalScreen extends ConsumerWidget {
  const ServiceApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final target = from == 'dashboard' ? '/dashboard' : '/settings';
    final activeTab = ref.watch(approvalTabProvider);
    
    final pendingAsync = ref.watch(pendingApprovalsProvider);
    final historyAsync = ref.watch(historyApprovalsProvider);

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
        ),
        body: Column(
          children: [
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
              child: activeTab == 0
                  ? _buildList(pendingAsync, context, ref, isPending: true)
                  : _buildList(historyAsync, context, ref, isPending: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(AsyncValue<List<TransactionItemModel>> asyncData, BuildContext context, WidgetRef ref, {required bool isPending}) {
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: EmptyStateWidget(
              icon: isPending ? Icons.assignment_turned_in_rounded : Icons.history_rounded,
              title: isPending ? 'Tidak ada persetujuan' : 'Belum ada riwayat',
              subtitle: isPending ? 'Tidak ada jasa menunggu persetujuan' : 'Belum ada riwayat persetujuan',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(item.productName ?? 'Jasa Tidak Diketahui', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPending ? AppColors.warning.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isPending ? AppColors.warning : AppColors.success),
                        ),
                        child: Text(
                          isPending ? 'Menunggu' : 'Disetujui',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isPending ? AppColors.warning : AppColors.success),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Mekanik: ${item.workerName ?? '-'}', style: const TextStyle(color: AppColors.textSecondary)),
                  Text('Subtotal: ${CurrencyFormatter.format(item.subtotal)}', style: const TextStyle(color: AppColors.textSecondary)),
                  
                  if (isPending) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _approveItem(context, ref, item.id),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Setujui Jasa'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _approveItem(BuildContext context, WidgetRef ref, String itemId) async {
    try {
      await FirebaseFirestore.instance.collection('transaction_items').doc(itemId).update({
        'isApproved': true,
      });
      if (context.mounted) {
        AppToast.show(context, 'Jasa berhasil disetujui', type: ToastType.success);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Gagal menyetujui jasa: $e', type: ToastType.error);
      }
    }
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.icon, required this.isSelected, required this.onTap});

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
              Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
