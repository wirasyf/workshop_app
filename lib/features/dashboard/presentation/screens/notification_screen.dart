import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/notification_model.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../main.dart'; // For firebaseMessagingServiceProvider

final notificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final fcm = ref.watch(firebaseMessagingServiceProvider);
  return fcm.getMyNotifications();
});

final notificationBadgeProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider);
  return notifs.valueOrNull?.where((n) => !n.isRead).length ?? 0;
});

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsProvider);
    Theme.of(context);
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
          title: const Text('Notifikasi'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => context.go(target),
          ),
        ),
        body: notifsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: EmptyStateWidget(
                  icon: Icons.notifications_off_rounded,
                  title: 'Tidak ada notifikasi',
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = items[index];
                return _NotificationTile(
                  notification: n,
                  onTap: () {
                    ref.read(firebaseMessagingServiceProvider).markAsRead(n.id);
                    if (n.type == 'service_approval') {
                      context.go('/service-approval?from=dashboard');
                    } else {
                      _showNotificationDetail(context, n);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
  void _showNotificationDetail(BuildContext context, NotificationModel n) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isError = n.type == 'error';
        final isWarning = n.type == 'warning';
        final iconColor = isError ? AppColors.error : (isWarning ? AppColors.warning : AppColors.info);
        final icon = isError ? Icons.error_outline_rounded : (isWarning ? Icons.warning_amber_rounded : Icons.info_outline_rounded);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Expanded(child: Text(n.title, style: theme.textTheme.titleMedium)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.message, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
              const SizedBox(height: 16),
              Text(
                DateFormatter.formatWithTime(n.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textHint),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  const _NotificationTile({required this.notification, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRead = notification.isRead;
    final colorBg = AppColors.infoLight;
    final colorIcon = AppColors.info;
    final colorBorder = AppColors.info.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead
              ? theme.cardTheme.color
              : colorBg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isRead ? AppColors.border : colorBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isRead)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorIcon,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorIcon.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.notifications_rounded,
                size: 20,
                color: colorIcon,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                      color: isRead
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormatter.formatWithTime(notification.createdAt),
                    style: TextStyle(fontSize: 10, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
