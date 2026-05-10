import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/database/app_database.dart';
import 'core/database/seed_data.dart';
import 'core/router/app_router.dart';
import 'core/services/sync_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/settings_service.dart';
import 'core/theme/app_theme.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) => throw UnimplementedError());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi data lokalisasi (Indonesian)
  await initializeDateFormatting('id_ID', null);

  final settingsService = SettingsService();
  await settingsService.init();

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

  // Seed data demo (hanya sekali saat pertama kali)
  await SeedData.seedIfEmpty(database);

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWithValue(settingsService),
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

    return MaterialApp.router(
      title: 'SpareArt Motor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
