import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../providers/workshop_provider.dart';

/// Halaman utama bengkel — Antrean & Riwayat
class WorkshopScreen extends ConsumerWidget {
  const WorkshopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bengkel'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Antrean Aktif'),
              Tab(text: 'Riwayat'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.build_circle_outlined),
              tooltip: 'Kelola Jasa',
              onPressed: () => context.go('/services'),
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            _ActiveQueueTab(),
            _HistoryTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/workshop/new-order'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Work Order Baru'),
          backgroundColor: AppColors.primary,
        ),
      ),
    );
  }
}

/// Tab antrean aktif (waiting + in_progress)
class _ActiveQueueTab extends ConsumerWidget {
  const _ActiveQueueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final woAsync = ref.watch(activeWorkOrdersProvider);

    return woAsync.when(
      loading: () => const Center(child: LoadingWidget()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (orders) {
        if (orders.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.check_circle_outlined,
            title: 'Tidak ada antrean',
            subtitle: 'Semua pekerjaan sudah selesai!',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(activeWorkOrdersProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _WorkOrderCard(workOrder: orders[i]),
          ),
        );
      },
    );
  }
}

/// Tab riwayat (completed + paid + cancelled)
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final woAsync = ref.watch(workOrdersProvider);

    return woAsync.when(
      loading: () => const Center(child: LoadingWidget()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (orders) {
        final history = orders.where((w) =>
            w.status == 'completed' || w.status == 'paid' || w.status == 'cancelled'
        ).toList();

        if (history.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.history_rounded,
            title: 'Belum ada riwayat',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(workOrdersProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _WorkOrderCard(workOrder: history[i]),
          ),
        );
      },
    );
  }
}

/// Card work order
class _WorkOrderCard extends ConsumerWidget {
  final WorkOrder workOrder;
  const _WorkOrderCard({required this.workOrder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vehicleAsync = ref.watch(vehicleDetailProvider(workOrder.vehicleId));
    final statusColor = _getStatusColor(workOrder.status);
    final statusLabel = WorkOrderStatus.getLabel(workOrder.status);

    return InkWell(
      onTap: () => context.go('/workshop/${workOrder.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Order No + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getStatusIcon(workOrder.status),
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workOrder.orderNo,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormatter.formatWithTime(workOrder.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Vehicle info
            vehicleAsync.when(
              loading: () => const SizedBox(height: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 1))),
              error: (_, __) => const Text('-'),
              data: (vehicle) {
                if (vehicle == null) return const Text('-');
                return Row(
                  children: [
                    Icon(Icons.person_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      vehicle.customerName,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.directions_car_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      vehicle.plateNumber,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (vehicle.vehicleType != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${vehicle.vehicleBrand ?? ''} ${vehicle.vehicleType ?? ''}'.trim(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),

            // Complaint
            if (workOrder.complaint != null && workOrder.complaint!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.report_problem_rounded, size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      workOrder.complaint!,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Total
            if (workOrder.grandTotal > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  CurrencyFormatter.format(workOrder.grandTotal),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'waiting': return AppColors.warning;
      case 'in_progress': return AppColors.info;
      case 'completed': return AppColors.success;
      case 'paid': return AppColors.primary;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'waiting': return Icons.hourglass_top_rounded;
      case 'in_progress': return Icons.build_rounded;
      case 'completed': return Icons.check_circle_rounded;
      case 'paid': return Icons.payment_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      default: return Icons.help_rounded;
    }
  }
}
