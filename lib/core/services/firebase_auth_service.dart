import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'settings_service.dart';

/// Konstanta akun owner yang hardcoded.
/// Akun ini akan dibuat otomatis di Firebase Auth jika belum ada.
class OwnerConfig {
  static const String email = 'owner@gmail.com';
  static const String password = 'password123';
  static const String name = 'Owner';
  static const String username = 'owner';
  static const String role = 'owner';
}

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SettingsService _settings;

  FirebaseAuthService(this._settings);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Memastikan akun owner tersedia di Firebase Auth dan Firestore.
  /// Dipanggil sekali saat app start dari main.dart.
  Future<void> ensureOwnerAccount() async {
    try {
      debugPrint('🔧 Memastikan akun owner tersedia...');

      // Cek apakah ada user yang sudah login — jika ada, simpan dulu
      // agar tidak terganggu oleh proses pengecekan owner account.
      final existingUser = _auth.currentUser;
      final hadExistingSession = existingUser != null;

      if (hadExistingSession) {
        debugPrint(
          '🔧 Ada sesi aktif (${existingUser.uid}), skip cek owner lewat signIn',
        );
        // Hanya pastikan dokumen Firestore owner ada — tanpa sign in ulang
        // karena itu akan mengganggu sesi yang sudah ada.
        await _ensureOwnerFirestoreDoc(null);
        return;
      }

      String? ownerUid;

      try {
        final result = await _auth.signInWithEmailAndPassword(
          email: OwnerConfig.email,
          password: OwnerConfig.password,
        );
        ownerUid = result.user?.uid;
        debugPrint('✅ Akun owner sudah ada di Firebase Auth: $ownerUid');
      } on FirebaseAuthException catch (e) {
        // 'user-not-found'      → akun belum pernah dibuat
        // 'invalid-credential'  → akun tidak ditemukan (Firebase SDK baru)
        //                         atau sudah dihapus dari Firebase Console
        // Kedua kasus ini ditangani sama: buat akun baru.
        if (e.code == 'user-not-found' ||
            e.code == 'invalid-credential' ||
            e.code == 'wrong-password') {
          debugPrint('⚠️ Akun owner tidak ditemukan (${e.code}), membuat ulang...');
          try {
            final result = await _auth.createUserWithEmailAndPassword(
              email: OwnerConfig.email,
              password: OwnerConfig.password,
            );
            ownerUid = result.user?.uid;
            debugPrint('✅ Akun owner berhasil dibuat: $ownerUid');
          } on FirebaseAuthException catch (createErr) {
            if (createErr.code == 'email-already-in-use') {
              // Race condition — akun sudah ada, coba login lagi
              debugPrint('⚠️ email-already-in-use, coba login ulang...');
              try {
                final result = await _auth.signInWithEmailAndPassword(
                  email: OwnerConfig.email,
                  password: OwnerConfig.password,
                );
                ownerUid = result.user?.uid;
                debugPrint('✅ Login ulang owner berhasil: $ownerUid');
              } catch (retryErr) {
                debugPrint('❌ Login ulang owner gagal: $retryErr');
              }
            } else {
              debugPrint('❌ Gagal membuat akun owner: $createErr');
            }
          }
        } else {
          debugPrint('⚠️ ensureOwnerAccount auth error: ${e.code} - ${e.message}');
        }
      }

      // Pastikan dokumen Firestore untuk owner ada dan lengkap
      if (ownerUid != null) {
        await _ensureOwnerFirestoreDoc(ownerUid);
      }

      // Sign out setelah cek/buat akun owner — user masih belum login
      // saat cold start, jadi kita sign out agar authStateChanges tetap null.
      await _auth.signOut();
      debugPrint('✅ ensureOwnerAccount selesai');
    } catch (e) {
      debugPrint('❌ ensureOwnerAccount error: $e');
      // Jangan crash app jika gagal — user masih bisa login manual
      try {
        await _auth.signOut();
      } catch (_) {}
    }
  }

  /// Memastikan dokumen Firestore untuk owner ada.
  /// Jika [ownerUid] null, coba query berdasarkan email.
  Future<void> _ensureOwnerFirestoreDoc(String? ownerUid) async {
    try {
      QueryDocumentSnapshot? ownerDoc;

      if (ownerUid != null) {
        final doc = await _firestore.collection('users').doc(ownerUid).get();
        if (!doc.exists) {
          await _firestore.collection('users').doc(ownerUid).set(
            UserModel(
              id: ownerUid,
              name: OwnerConfig.name,
              username: OwnerConfig.username,
              email: OwnerConfig.email,
              role: OwnerConfig.role,
              isActive: true,
              createdAt: DateTime.now(),
            ).toMap(),
          );
          debugPrint('✅ Dokumen owner dibuat di Firestore');
        } else {
          // Pastikan role dan isActive benar
          final data = doc.data() as Map<String, dynamic>;
          final updates = <String, dynamic>{};
          if (data['role'] != OwnerConfig.role) updates['role'] = OwnerConfig.role;
          if (data['isActive'] != true) updates['isActive'] = true;
          if (updates.isNotEmpty) {
            await _firestore.collection('users').doc(ownerUid).update(updates);
            debugPrint('✅ Dokumen owner diperbarui: $updates');
          }
        }
      } else {
        // Tidak tahu UID owner — coba query Firestore by email
        // (ini hanya berhasil jika Firestore rules mengizinkan)
        try {
          final snap = await _firestore
              .collection('users')
              .where('email', isEqualTo: OwnerConfig.email)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            ownerDoc = snap.docs.first;
            final data = ownerDoc.data() as Map<String, dynamic>;
            final updates = <String, dynamic>{};
            if (data['role'] != OwnerConfig.role) updates['role'] = OwnerConfig.role;
            if (data['isActive'] != true) updates['isActive'] = true;
            if (updates.isNotEmpty) {
              await ownerDoc.reference.update(updates);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Query owner by email failed: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ _ensureOwnerFirestoreDoc error: $e');
    }
  }

  Future<UserModel?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // Coba ambil dari server, fallback ke cache jika offline
      DocumentSnapshot doc;
      try {
        doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.cache));
      }

      if (!doc.exists) {
        debugPrint('getCurrentUserData: dokumen Firestore tidak ditemukan untuk ${user.uid}');
        // Auto-provision jika dokumen belum ada
        final isOwner = user.email?.toLowerCase() == OwnerConfig.email.toLowerCase();
        final userModel = UserModel(
          id: user.uid,
          name: isOwner ? OwnerConfig.name : (user.email?.split('@').first ?? 'User'),
          username: isOwner ? OwnerConfig.username : (user.email?.split('@').first ?? 'user'),
          email: user.email ?? '',
          role: isOwner ? OwnerConfig.role : 'karyawan',
          isActive: true,
          createdAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
        await _persistSession(userModel);
        return userModel;
      }

      final userModel = UserModel.fromFirestore(doc);

      // Jangan logout otomatis berdasarkan isActive — biarkan user tetap login.
      // Pengecekan isActive hanya pada saat login eksplisit.
      if (!userModel.isActive) {
        debugPrint('⚠️ Akun tidak aktif, tapi sesi tetap dipertahankan');
      }

      await _persistSession(userModel);
      return userModel;
    } catch (e) {
      debugPrint('getCurrentUserData error: $e');
      // Jika gagal total (cache kosong + offline), buat UserModel dari SharedPreferences
      final savedId = _settings.userId;
      final savedName = _settings.userName;
      final savedRole = _settings.userRole;
      if (savedId != null && savedId == user.uid) {
        debugPrint('📦 Menggunakan sesi dari SharedPreferences sebagai fallback');
        return UserModel(
          id: savedId,
          name: savedName ?? 'User',
          username: savedName ?? 'user',
          email: user.email ?? '',
          role: savedRole ?? 'owner',
          isActive: true,
          createdAt: DateTime.now(),
        );
      }
      return null;
    }
  }

  Future<void> _persistSession(UserModel user) async {
    await _settings.saveUserSession(
      userId: user.id,
      userName: user.name,
      userRole: user.role,
    );
  }

  Future<UserModel> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (_auth.currentUser == null) {
        debugPrint('signIn auth error: $e');
        rethrow;
      }
      debugPrint('signIn warning (auth succeeded): $e');
    }

    final uid = _auth.currentUser!.uid;
    DocumentSnapshot doc;
    try {
      doc = await _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache));
    } catch (_) {
      doc = await _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
    }

    if (!doc.exists) {
      // Auto-provision user pertama kali login
      final isOwner = email.toLowerCase() == OwnerConfig.email.toLowerCase();
      final userModel = UserModel(
        id: uid,
        name: isOwner ? OwnerConfig.name : email.split('@').first,
        username: isOwner ? OwnerConfig.username : email.split('@').first,
        email: email,
        role: isOwner ? OwnerConfig.role : 'karyawan',
        isActive: true,
        createdAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(uid).set(userModel.toMap());
      await _persistSession(userModel);
      debugPrint('✅ Auto-provision user: ${userModel.email}, role=${userModel.role}');
      return userModel;
    }

    final userModel = UserModel.fromFirestore(doc);
    if (!userModel.isActive) {
      await _auth.signOut();
      throw Exception('Akun ini telah dinonaktifkan.');
    }

    // Tidak perlu update sessionId — fitur single-session dihapus
    // agar tidak menyebabkan auto-logout di perangkat lain.
    await _persistSession(userModel);
    return userModel;
  }

  Future<UserModel> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
    required String role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final userModel = UserModel(
      id: credential.user!.uid,
      name: name,
      username: username,
      email: email,
      role: role,
      isActive: true,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .set(userModel.toMap());
    await _persistSession(userModel);
    return userModel;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _settings.clearUserSession();
  }
}
