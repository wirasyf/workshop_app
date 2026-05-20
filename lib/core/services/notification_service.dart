import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider untuk layanan notifikasi lokal (OS-Level)
final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('notificationServiceProvider harus di-override di ProviderScope');
});

/// Layanan untuk mengelola notifikasi pop-up/banner di OS (Android & iOS)
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Inisialisasi plugin notifikasi
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      // Icon launcher standar untuk notifikasi Android
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Pengaturan untuk iOS
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
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
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('Notification service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  /// Menampilkan notifikasi peringatan stok menipis atau habis
  Future<void> showStockWarning({
    required int id,
    required String title,
    required String body,
    required bool isCritical,
  }) async {
    if (!_isInitialized) {
      await init();
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'stock_warnings_channel',
      'Peringatan Stok',
      channelDescription: 'Notifikasi saat stok barang menipis atau habis di toko',
      importance: Importance.max,
      priority: Priority.high,
      color: isCritical ? const Color(0xFFD32F2F) : const Color(0xFFF57C00),
      icon: '@mipmap/ic_launcher',
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
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
      debugPrint('Stock warning notification shown: $title');
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }
}
