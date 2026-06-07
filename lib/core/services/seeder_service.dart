import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service untuk membuat akun owner secara otomatis saat pertama kali
/// aplikasi dijalankan (seeder).
///
/// Menggunakan Firebase Auth dan Firestore utama (bukan secondary app)
/// karena secondary app di Android menyebabkan native crash saat dihapus.
///
/// PENTING: Seeder ini harus dipanggil SEBELUM FirebaseMessagingService.init()
/// agar authStateChanges listener belum aktif saat seeder melakukan sign-in/out.
class SeederService {
  static Future<void> seedOwnerAccount() async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    const email = 'owner@gmail.com';
    const password = 'password';

    try {
      debugPrint('Checking/Seeding owner account...');

      // Simpan user yang sedang login (jika ada) agar bisa di-restore
      final previousUser = auth.currentUser;

      UserCredential authResult;

      // 1. Coba buat akun baru
      try {
        authResult = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint('Owner auth account created.');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // 2. Akun sudah ada di Auth, coba sign in untuk cek Firestore
          try {
            authResult = await auth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
          } catch (signInError) {
            // Password tidak cocok atau error lain — skip seeder
            debugPrint(
              'Owner account exists but cannot sign in (password mismatch?). '
              'Skipping seeder. Error: $signInError',
            );
            return;
          }
        } else {
          debugPrint(
            'FirebaseAuth error during seed: ${e.code} - ${e.message}',
          );
          return;
        }
      }

      final uid = authResult.user!.uid;

      // 3. Cek apakah dokumen user sudah ada di Firestore
      final doc = await firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        await firestore.collection('users').doc(uid).set({
          'id': uid,
          'name': 'Owner Bengkel',
          'username': 'owner',
          'email': email,
          'role': 'owner',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'currentSessionId': null,
        });
        debugPrint('Owner document seeded in Firestore.');
      } else {
        debugPrint('Owner document already exists in Firestore. Skipping.');
      }

      // 4. Sign out agar tidak auto-login sebagai owner
      //    Pengguna harus login secara manual melalui halaman login.
      if (previousUser == null) {
        // Tidak ada user yang login sebelumnya, sign out owner
        await auth.signOut();
        debugPrint('Signed out after seeding (no previous user).');
      } else if (previousUser.uid != uid) {
        // Ada user lain yang login sebelumnya — ini seharusnya tidak terjadi
        // karena seeder dipanggil saat startup, tapi sebagai pengaman
        await auth.signOut();
        debugPrint('Signed out after seeding (different user was logged in).');
      }
      // Jika previousUser.uid == uid, berarti owner sudah login — biarkan saja
    } catch (e) {
      debugPrint('Failed to seed owner account: $e');
    }
  }
}
