import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/database/app_database.dart';
import 'core/router/app_router.dart';
import 'core/services/sync_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
final settingsServiceProvider = Provider<SettingsService>(
  (ref) => throw UnimplementedError(),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Inisialisasi data lokalisasi (Indonesian)
  await initializeDateFormatting('id_ID', null);

  final settingsService = SettingsService();
  await settingsService.init();

  // Inisialisasi Notification Service
  final notificationService = NotificationService();
  await notificationService.init();

  // Inisialisasi Supabase (aman gagal di offline)
  try {
    await SupabaseService.initialize();
  } catch (_) {
    debugPrint('Supabase init failed — running in offline mode');
  }

  // Inisialisasi Drift database
  final database = AppDatabase();

  // Jalankan sinkronisasi background (setiap 5 menit)
  SyncService(database, settingsService).startPeriodicSync();

  // Dengarkan notifikasi Realtime dari Supabase
  try {
    SupabaseService.client
        .channel('realtime_notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) async {
            try {
              debugPrint('🔔 Realtime: new notification received');
              final newRow = payload.newRecord;
              final targetRole = newRow['target_role'] as String?;
              if (targetRole == null) {
                debugPrint('⚠️ Notifikasi tanpa target_role, skip');
                return;
              }

              final userId = settingsService.userId;
              if (userId == null) {
                debugPrint('⚠️ userId belum diset, skip notifikasi');
                return;
              }

              final currentUser = await database.getUserById(userId);
              if (currentUser == null) {
                debugPrint('⚠️ User $userId tidak ditemukan di DB lokal');
                return;
              }

              if (currentUser.role != targetRole) {
                debugPrint('ℹ️ Notifikasi untuk role "$targetRole", user ini "${currentUser.role}" — skip');
                return;
              }

              final notifTitle = newRow['title']?.toString() ?? 'Notifikasi Sistem';
              final notifBody = newRow['message']?.toString() ?? '';
              final notifType = newRow['type']?.toString() ?? 'info';
              final notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

              // Tampilkan notifikasi OS berdasarkan tipe
              switch (notifType) {
                case 'transaction':
                  await notificationService.showTransactionNotification(
                    id: notifId,
                    title: notifTitle,
                    body: notifBody,
                  );
                  break;
                case 'approval_needed':
                  await notificationService.showApprovalNotification(
                    id: notifId,
                    title: notifTitle,
                    body: notifBody,
                  );
                  break;
                case 'stock_critical':
                case 'stock_low':
                  await notificationService.showStockWarning(
                    id: notifId,
                    title: notifTitle,
                    body: notifBody,
                    isCritical: notifType == 'stock_critical',
                  );
                  break;
                default:
                  await notificationService.showTransactionNotification(
                    id: notifId,
                    title: notifTitle,
                    body: notifBody,
                  );
              }

              // Simpan ke DB lokal agar muncul di halaman notifikasi
              await database.insertNotification(
                NotificationsCompanion.insert(
                  title: notifTitle,
                  message: notifBody,
                  type: notifType,
                ),
              );
              debugPrint('✅ Notifikasi disimpan dan ditampilkan: $notifTitle');
            } catch (e) {
              debugPrint('❌ Error handling realtime notification: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: (payload) {
            debugPrint('🔄 Realtime: products table changed');
            SyncService(database, settingsService).pullCloudChanges().catchError((_) {});
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (payload) {
            debugPrint('🔄 Realtime: transactions table changed');
            SyncService(database, settingsService).pullCloudChanges().catchError((_) {});
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transaction_items',
          callback: (payload) {
            debugPrint('🔄 Realtime: transaction_items table changed');
            SyncService(database, settingsService).pullCloudChanges().catchError((_) {});
          },
        )
        .subscribe();
    debugPrint('✅ Supabase Realtime channel subscribed');
  } catch (e) {
    debugPrint('❌ Supabase realtime init failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWithValue(settingsService),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const SpareArtApp(),
    ),
  );
}

class SpareArtApp extends ConsumerWidget {
  const SpareArtApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'D&D Markas Ban',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          routerConfig: router,
          builder: (context, routerChild) {
            return ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                top: false,
                bottom: true,
                left: false,
                right: false,
                child: routerChild ?? const SizedBox.shrink(),
              ),
            );
          },
        );
      },
    );
  }
}
