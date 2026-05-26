import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'settings_service.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';

class FirebaseMessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SettingsService _settings;
  final NotificationService _notificationService;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  FirebaseMessagingService(this._settings, this._notificationService);

  Future<void> init() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
      await _updateToken();
      
      // Listen to token refresh
      _messaging.onTokenRefresh.listen((token) {
        _saveTokenToFirestore(token);
      });
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');
      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        _notificationService.showFCMNotification(
          id: message.messageId.hashCode,
          title: message.notification!.title ?? 'Notifikasi',
          body: message.notification!.body ?? '',
        );
      }
    });

    // Handle token updates when user logs in
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _updateToken();
        _startFirestoreNotificationListener();
      } else {
        _notificationSubscription?.cancel();
      }
    });
  }

  Future<void> _updateToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final userId = _settings.userId;
    if (userId != null && userId.isNotEmpty) {
      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token])
      });
    }
  }

  void _startFirestoreNotificationListener() {
    _notificationSubscription?.cancel();

    final userId = _settings.userId;
    final role = _settings.userRole;
    final now = DateTime.now();

    _notificationSubscription = _firestore
        .collection('notifications')
        .where(
          Filter.or(
            Filter('targetUserId', isEqualTo: userId),
            Filter('targetRole', isEqualTo: role),
          )
        )
        // Hanya notifikasi yang masuk setelah aplikasi/listener berjalan (agar tidak spam notifikasi lama)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(now))
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final title = data['title'] ?? 'Notifikasi Baru';
            final body = data['message'] ?? '';
            final type = data['type'] ?? 'system';
            final id = change.doc.id.hashCode;

            // Jangan tampilkan notifikasi sistem jika ini dari aksi diri sendiri
            final senderId = data['senderId'];
            if (senderId == userId) continue;

            if (type == 'transaction') {
              _notificationService.showTransactionNotification(
                id: id,
                title: title,
                body: body,
              );
            } else if (type == 'stock_alert') {
              _notificationService.showStockWarning(
                id: id,
                title: title,
                body: body,
                isCritical: true,
              );
            } else if (type == 'service_approval') {
              _notificationService.showApprovalNotification(
                id: id,
                title: title,
                body: body,
              );
            } else {
              _notificationService.showFCMNotification(
                id: id,
                title: title,
                body: body,
              );
            }
          }
        }
      }
    });
  }
  
  Stream<List<NotificationModel>> getMyNotifications() {
    final userId = _settings.userId;
    final role = _settings.userRole;
    
    return _firestore
        .collection('notifications')
        .where(
          Filter.or(
            Filter('targetUserId', isEqualTo: userId),
            Filter('targetRole', isEqualTo: role),
          )
        )
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList();
    });
  }
  
  Future<void> markAsRead(String id) async {
    await _firestore.collection('notifications').doc(id).update({'isRead': true});
  }

  Future<void> deleteNotification(String id) async {
    await _firestore.collection('notifications').doc(id).delete();
  }
}
