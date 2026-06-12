import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider untuk layanan notifikasi lokal (OS-Level)
final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError(
    'notificationServiceProvider harus di-override di ProviderScope',
  );
});

/// Layanan untuk mengelola notifikasi pop-up/banner di OS (Android & iOS)
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Inisialisasi plugin notifikasi
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/logo');

      // Pengaturan untuk iOS
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      // Meminta izin notifikasi untuk Android 13+
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await androidImplementation
            ?.requestNotificationsPermission();
        debugPrint('Notification permission granted: $granted');

        // Buat channel khusus untuk FCM Push Notification (High Priority)
        const AndroidNotificationChannel fcmChannel =
            AndroidNotificationChannel(
              'high_importance_channel',
              'Notifikasi Penting',
              description: 'Channel untuk notifikasi push dari kasir ke owner',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            );
        await androidImplementation?.createNotificationChannel(fcmChannel);
        debugPrint('✅ FCM notification channel created');
      }

      _isInitialized = true;
      debugPrint('✅ Notification service initialized successfully');
    } catch (e, st) {
      debugPrint('❌ Error initializing notification service: $e');
      debugPrint('Stack trace: $st');
    }
  }

  /// Menampilkan notifikasi peringatan stok menipis atau habis
  Future<void> showStockWarning({
    required int id,
    required String title,
    required String body,
    required bool isCritical,
  }) async {
    await _showNotification(
      id: id,
      title: title,
      body: body,
      channelId: 'stock_warnings_channel',
      channelName: 'Peringatan Stok',
      channelDescription:
          'Notifikasi saat stok barang menipis atau habis di toko',
      color: isCritical ? const Color(0xFFD32F2F) : const Color(0xFFF57C00),
    );
  }

  /// Menampilkan notifikasi transaksi baru dari kasir
  Future<void> showTransactionNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _showNotification(
      id: id,
      title: title,
      body: body,
      channelId: 'transactions_channel',
      channelName: 'Transaksi',
      channelDescription: 'Notifikasi saat ada transaksi baru dari kasir',
      color: const Color(0xFF4CAF50),
    );
  }

  /// Menampilkan notifikasi persetujuan jasa
  Future<void> showApprovalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _showNotification(
      id: id,
      title: title,
      body: body,
      channelId: 'approval_channel',
      channelName: 'Persetujuan Jasa',
      channelDescription:
          'Notifikasi saat ada jasa yang membutuhkan persetujuan',
      color: const Color(0xFF2196F3),
    );
  }

  /// Menampilkan notifikasi umum dari Firebase Cloud Messaging
  Future<void> showFCMNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _showNotification(
      id: id,
      title: title,
      body: body,
      channelId: 'fcm_channel',
      channelName: 'Notifikasi Sistem',
      channelDescription: 'Notifikasi sistem dari aplikasi',
      color: const Color(0xFF2196F3),
    );
  }

  /// Method internal untuk menampilkan notifikasi
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required Color color,
  }) async {
    if (!_isInitialized) {
      debugPrint(
        '⚠️ NotificationService belum diinisialisasi, mencoba init()...',
      );
      await init();
    }

    if (!_isInitialized) {
      debugPrint(
        '❌ NotificationService gagal diinisialisasi, notifikasi tidak bisa ditampilkan',
      );
      return;
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          color: color,
          icon: '@mipmap/logo',
          enableVibration: true,
          playSound: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.show(id: id, title: title, body: body, notificationDetails: details);
      debugPrint('✅ Notification shown: [$channelId] $title');
    } catch (e, st) {
      debugPrint('❌ Error showing local notification: $e');
      debugPrint('Stack trace: $st');
    }
  }
}
