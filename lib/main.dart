import 'package:dnd_markasban_app/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/router/app_router.dart';
import 'core/services/settings_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/services/firebase_auth_service.dart';
import 'core/constants/app_theme.dart';

final settingsServiceProvider = ChangeNotifierProvider<SettingsService>(
  (ref) => throw UnimplementedError(),
);

final firebaseMessagingServiceProvider = Provider<FirebaseMessagingService>(
  (ref) => throw UnimplementedError(),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Inisialisasi data lokalisasi (Indonesian)
  await initializeDateFormatting('id_ID', null);

  final settingsService = SettingsService();
  await settingsService.init();

  // Inisialisasi Notification Service lokal
  final notificationService = NotificationService();
  await notificationService.init();

  // Inisialisasi Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Aktifkan Firestore persistence — data di-cache lokal sehingga
    // loading lebih cepat (data dari cache dulu, lalu sync dari server)
    // dan aplikasi tetap berfungsi saat offline.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  // Pastikan akun owner tersedia di Firebase Auth.
  // Ini akan membuat akun owner@gmail.com / password123 jika belum ada.
  try {
    final authService = FirebaseAuthService(settingsService);
    await authService.ensureOwnerAccount();
  } catch (e) {
    debugPrint('ensureOwnerAccount failed: $e');
  }

  // Init FCM secara async — tidak memblokir cold-start UI.
  final fcmService = FirebaseMessagingService(
    settingsService,
    notificationService,
  );
  Future(() async {
    try {
      await fcmService.init();
    } catch (e) {
      debugPrint('FCM init failed: $e');
    }
  });

  runApp(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) => settingsService),
        notificationServiceProvider.overrideWithValue(notificationService),
        firebaseMessagingServiceProvider.overrideWithValue(fcmService),
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
