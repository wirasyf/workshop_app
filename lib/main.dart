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

final settingsServiceProvider = Provider<SettingsService>((ref) => throw UnimplementedError());

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
  SyncService(database).startPeriodicSync();

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

    return MaterialApp.router(
      title: 'SpareArt Motor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
