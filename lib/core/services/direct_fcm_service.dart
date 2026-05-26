import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DirectFcmService {
  static const _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  /// Mengirim Push Notification langsung ke owner via FCM HTTP v1 API
  static Future<void> sendPushNotification({
    required String targetRole,
    required String title,
    required String body,
    String type = 'system',
    String? senderId,
  }) async {
    try {
      // 1. Ambil token FCM dari Firestore untuk role tujuan
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: targetRole)
          .get();

      List<String> tokens = [];
      for (var doc in usersSnap.docs) {
        if (doc.id == senderId) continue;
        final data = doc.data();
        if (data['fcmTokens'] != null) {
          final userTokens = List<String>.from(data['fcmTokens']);
          tokens.addAll(userTokens);
        }
      }

      if (tokens.isEmpty) {
        debugPrint('⚠️ FCM: Tidak ada token FCM untuk role $targetRole');
        return;
      }

      debugPrint('📨 FCM: Mengirim ke ${tokens.length} token...');

      // 2. Bangun Service Account credentials dari .env
      final projectId = dotenv.env['FCM_PROJECT_ID'];
      final clientId = dotenv.env['FCM_CLIENT_ID'];
      final clientEmail = dotenv.env['FCM_CLIENT_EMAIL'];
      final privateKeyRaw = dotenv.env['FCM_PRIVATE_KEY'];

      if (projectId == null || clientId == null || clientEmail == null || privateKeyRaw == null) {
        debugPrint('❌ FCM: FCM_PROJECT_ID / FCM_CLIENT_ID / FCM_CLIENT_EMAIL / FCM_PRIVATE_KEY tidak ditemukan di .env');
        return;
      }

      // flutter_dotenv membaca \n sebagai literal string, perlu dikonversi ke newline asli
      final privateKey = privateKeyRaw.replaceAll('\\n', '\n');

      final serviceAccountJson = {
        "type": "service_account",
        "project_id": projectId,
        "private_key": privateKey,
        "client_email": clientEmail,
        "client_id": clientId,
        "token_uri": "https://oauth2.googleapis.com/token",
      };

      final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

      // 3. Dapatkan Auth Client
      final client = await clientViaServiceAccount(credentials, _scopes);

      // 4. Kirim FCM messages
      int successCount = 0;
      for (String token in tokens) {
        try {
          final payload = {
            'message': {
              'token': token,
              'notification': {
                'title': title,
                'body': body,
              },
              'data': {
                'type': type,
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
              'android': {
                'priority': 'high',
                'notification': {
                  'channel_id': 'high_importance_channel',
                  'default_sound': true,
                  'default_vibrate_timings': true,
                },
              },
            }
          };

          final response = await client.post(
            Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );

          if (response.statusCode == 200) {
            successCount++;
          } else {
            debugPrint('❌ FCM: Gagal kirim ke token (${response.statusCode}): ${response.body}');
            
            // Jika token tidak valid lagi (UNREGISTERED) hapus dari Firestore
            if (response.statusCode == 404 || 
               (response.statusCode == 400 && response.body.contains('UNREGISTERED')) ||
               (response.statusCode == 400 && response.body.contains('INVALID_ARGUMENT') && response.body.contains('token'))) {
              _removeInvalidToken(token, targetRole);
            }
          }
        } catch (e) {
          debugPrint('❌ FCM: Error kirim ke token: $e');
        }
      }

      client.close();
      debugPrint('✅ FCM: $successCount/${tokens.length} notifikasi berhasil dikirim');
    } catch (e, st) {
      debugPrint('❌ FCM Error: $e');
      debugPrint('Stack: $st');
    }
  }

  /// Hapus token FCM yang sudah tidak valid dari Firestore
  static Future<void> _removeInvalidToken(String token, String role) async {
    try {
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role)
          .get();

      for (var doc in usersSnap.docs) {
        final data = doc.data();
        final tokens = List<String>.from(data['fcmTokens'] ?? []);
        if (tokens.contains(token)) {
          await doc.reference.update({
            'fcmTokens': FieldValue.arrayRemove([token]),
          });
          debugPrint('🗑️ FCM: Token tidak valid dihapus dari user ${doc.id}');
        }
      }
    } catch (e) {
      debugPrint('⚠️ FCM: Gagal menghapus token invalid: $e');
    }
  }
}
