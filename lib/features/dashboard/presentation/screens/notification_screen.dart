import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:spareart_app/core/database/app_database.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';


/// Model notifikasi
class AppNotification {
  final int? id;
  final String title;
  final String message;
  final String type; // 'stock_critical', 'stock_low', 'transaction', 'info'
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  IconData get icon => switch (type) {
    'stock_critical' => Icons.error_rounded,
    'stock_low' => Icons.warning_amber_rounded,
    'transaction' => Icons.receipt_long_rounded,
    _ => Icons.info_rounded,
  };

  AppNotification copyWith({int? id, bool? isRead}) => AppNotification(
    id: id ?? this.id, 
    title: title, 
    message: message, 
    type: type,
    createdAt: createdAt, 
    isRead: isRead ?? this.isRead,
  );
}

/// StateNotifier untuk notifikasi — mendukung read/delete
class NotificationNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final Ref _ref;
  NotificationNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final db = _ref.read(databaseProvider);
      
      // 1. Ambil dari DB
      final dbNotifs = await db.getAllNotifications();
      
      // 2. Jika kosong atau perlu refresh (simulasi auto-generation)
      if (dbNotifs.isEmpty) {
        await _generateInitialNotifications(db);
        final refreshed = await db.getAllNotifications();
        state = AsyncValue.data(refreshed.map(_fromDb).toList());
      } else {
        state = AsyncValue.data(dbNotifs.map(_fromDb).toList());
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  AppNotification _fromDb(Notification n) => AppNotification(
    id: n.id,
    title: n.title,
    message: n.message,
    type: n.type,
    createdAt: n.createdAt,
    isRead: n.isRead,
  );

  Future<void> _generateInitialNotifications(AppDatabase db) async {
    final now = DateTime.now();
    final start = DateFormatter.startOfDay(now);
    final end = DateFormatter.endOfDay(now);

    // Stok rendah
    final lowStock = await db.getLowStockProducts();
    for (final p in lowStock) {
      await db.insertNotification(NotificationsCompanion.insert(
        title: p.stockQty == 0 ? 'Stok Habis!' : 'Stok Menipis',
        message: p.stockQty == 0 
          ? '${p.name} sudah habis. Segera restok.' 
          : '${p.name} sisa ${p.stockQty} ${p.unit}.',
        type: p.stockQty == 0 ? 'stock_critical' : 'stock_low',
        createdAt: Value(now),
      ));
    }

    // Transaksi hari ini
    final txnCount = await db.getTransactionCount(start, end);
    if (txnCount > 0) {
      final total = await db.getTotalSales(start, end);
      await db.insertNotification(NotificationsCompanion.insert(
        title: 'Transaksi Hari Ini',
        message: '$txnCount transaksi berhasil. Total: ${CurrencyFormatter.format(total)}',
        type: 'transaction',
        createdAt: Value(now),
      ));
    }
  }

  Future<void> markAsRead(int id) async {
    await _ref.read(databaseProvider).markNotificationRead(id);
    final items = state.value;
    if (items != null) {
      state = AsyncValue.data(
        items.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList(),
      );
    }
  }

  Future<void> markAllAsRead() async {
    final items = state.value;
    if (items == null) return;
    
    final db = _ref.read(databaseProvider);
    for (final n in items) {
      if (!n.isRead && n.id != null) {
        await db.markNotificationRead(n.id!);
      }
    }
    
    state = AsyncValue.data(items.map((n) => n.copyWith(isRead: true)).toList());
  }

  Future<void> deleteNotification(int id) async {
    await _ref.read(databaseProvider).deleteNotification(id);
    final items = state.value;
    if (items != null) {
      state = AsyncValue.data(items.where((n) => n.id != id).toList());
    }
  }
}

final notificationNotifierProvider =
    StateNotifierProvider<NotificationNotifier, AsyncValue<List<AppNotification>>>((ref) {
  return NotificationNotifier(ref);
});

/// Provider badge count (unread)
final notificationBadgeProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationNotifierProvider);
  return notifs.value?.where((n) => !n.isRead).length ?? 0;
});

/// Layar Notifikasi
class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (notifs.value?.any((n) => !n.isRead) == true)
            TextButton.icon(
              onPressed: () => ref.read(notificationNotifierProvider.notifier).markAllAsRead(),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Baca Semua', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
      body: notifs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_rounded, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('Tidak ada notifikasi', style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.read(notificationNotifierProvider.notifier).load(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = items[index];
                return Dismissible(
                  key: Key(n.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete_rounded, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    if (n.id != null) ref.read(notificationNotifierProvider.notifier).deleteNotification(n.id!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Notifikasi "${n.title}" dihapus'), duration: const Duration(seconds: 2)),
                    );
                  },
                  child: _NotificationTile(
                    notification: n,
                    onTap: () {
                      if (n.id != null) ref.read(notificationNotifierProvider.notifier).markAsRead(n.id!);
                      _showNotificationDetail(context, n);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showNotificationDetail(BuildContext context, AppNotification n) {
    final theme = Theme.of(context);
    final colors = _getNotifColors(n.type);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            // Icon + Type badge
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.icon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(n.icon, size: 24, color: colors.icon),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  _getTypeLabel(n.type),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.icon),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Text(n.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(n.message, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.access_time_rounded, size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(DateFormatter.formatWithTime(n.createdAt),
                style: TextStyle(fontSize: 12, color: AppColors.textHint)),
            ]),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(String type) => switch (type) {
    'stock_critical' => 'Darurat',
    'stock_low' => 'Peringatan',
    'transaction' => 'Transaksi',
    _ => 'Info',
  };

  _NotifColors _getNotifColors(String type) => switch (type) {
    'stock_critical' => _NotifColors(AppColors.errorLight, AppColors.error, AppColors.error.withValues(alpha: 0.3)),
    'stock_low' => _NotifColors(AppColors.warningLight, AppColors.warning, AppColors.warning.withValues(alpha: 0.3)),
    'transaction' => _NotifColors(AppColors.successLight, AppColors.success, AppColors.success.withValues(alpha: 0.3)),
    _ => _NotifColors(AppColors.infoLight, AppColors.info, AppColors.info.withValues(alpha: 0.3)),
  };
}

class _NotifColors {
  final Color bg;
  final Color icon;
  final Color border;
  const _NotifColors(this.bg, this.icon, this.border);
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  const _NotificationTile({required this.notification, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _getColors(notification.type);
    final isRead = notification.isRead;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? theme.cardTheme.color : (theme.brightness == Brightness.dark ? colors.bg.withValues(alpha: 0.15) : colors.bg.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isRead ? (theme.brightness == Brightness.dark ? AppColors.borderDark : AppColors.border) : colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread dot
            if (!isRead)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: colors.icon, shape: BoxShape.circle)),
              ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.icon.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(notification.icon, size: 20, color: colors.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                        color: isRead ? AppColors.textSecondary : AppColors.textPrimary,
                      )),
                  const SizedBox(height: 4),
                  Text(notification.message,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      )),
                  const SizedBox(height: 6),
                  Text(
                    DateFormatter.formatWithTime(notification.createdAt),
                    style: TextStyle(fontSize: 10, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  _NotifColors _getColors(String type) => switch (type) {
    'stock_critical' => _NotifColors(AppColors.errorLight, AppColors.error, AppColors.error.withValues(alpha: 0.3)),
    'stock_low' => _NotifColors(AppColors.warningLight, AppColors.warning, AppColors.warning.withValues(alpha: 0.3)),
    'transaction' => _NotifColors(AppColors.successLight, AppColors.success, AppColors.success.withValues(alpha: 0.3)),
    _ => _NotifColors(AppColors.infoLight, AppColors.info, AppColors.info.withValues(alpha: 0.3)),
  };
}
