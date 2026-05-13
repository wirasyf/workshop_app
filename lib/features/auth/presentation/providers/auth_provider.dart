import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/supabase_service.dart';
import 'package:uuid/uuid.dart';
import '../../../../main.dart';

/// Provider untuk auth state — menyimpan user yang sedang login
final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  final db = ref.watch(databaseProvider);
  final settings = ref.watch(settingsServiceProvider);
  final sync = ref.watch(syncServiceProvider);
  return AuthNotifier(db, settings, sync);
});

/// Provider untuk cek apakah sedang login
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value != null;
});


/// Notifier untuk mengelola state autentikasi
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AppDatabase _db;
  final SettingsService _settings;
  final SyncService _sync;

  AuthNotifier(this._db, this._settings, this._sync) : super(const AsyncValue.loading()) {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final savedId = _settings.userId;
    if (savedId != null) {
      try {
        final user = await _db.getUserById(savedId);
        if (user != null && user.isActive) {
          state = AsyncValue.data(user);
          return;
        }
      } catch (_) {}
    }
    state = const AsyncValue.data(null);
  }

  /// Login dengan username/email dan password (offline-first via lokal DB)
  Future<bool> login(String identifier, String password) async {
    state = const AsyncValue.loading();
    try {
      final trimmedIdentifier = identifier.trim();
      
      // 1. Cek di database lokal dulu
      User? user = await _db.getUserByUsername(trimmedIdentifier);
      user ??= await _db.getUserByEmail(trimmedIdentifier);
      
      // 2. Jika tidak ada lokal, coba cari di Supabase
      if (user == null) {
        try {
          final client = SupabaseService.client;
          final response = await client
              .from('users')
              .select()
              .or('username.eq.$trimmedIdentifier,email.eq.$trimmedIdentifier')
              .maybeSingle();

          if (response != null) {
            // User ditemukan di Supabase, simpan ke lokal
            final companion = UsersCompanion.insert(
              id: response['id'], // Gunakan ID dari server
              name: response['name'],
              username: response['username'],
              email: response['email'],
              passwordHash: response['password_hash'],
              isActive: Value(response['is_active'] ?? true),
              createdAt: Value(DateTime.parse(response['created_at'])),
            );
            
            await _db.insertUser(companion);
            user = await _db.getUserById(response['id']);
          }
        } catch (e) {
          // Gagal cek Supabase (mungkin offline), lanjut ke error user null
          debugPrint('Supabase login check failed: $e');
        }
      }
      
      if (user == null) {
        state = AsyncValue.error('User tidak ditemukan', StackTrace.current);
        return false;
      }
      if (user.passwordHash != password) {
        state = AsyncValue.error('Password salah', StackTrace.current);
        return false;
      }
      if (!user.isActive) {
        state = AsyncValue.error('Akun tidak aktif', StackTrace.current);
        return false;
      }
      
      // 3. Download data user (produk, kategori, dll) dari server
      await _sync.downloadUserData();
      
      // Save session
      await _settings.setUserId(user.id);
      
      state = AsyncValue.data(user);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Signup user baru
  Future<bool> signup({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final trimmedUsername = username.trim();
      final trimmedEmail = email.trim();

      // Cek apakah username sudah terdaftar
      final existingUser = await _db.getUserByUsername(trimmedUsername);
      if (existingUser != null) {
        state = AsyncValue.error('Username sudah digunakan', StackTrace.current);
        return false;
      }

      // Cek apakah email sudah terdaftar
      final existingEmail = await _db.getUserByEmail(trimmedEmail);
      if (existingEmail != null) {
        state = AsyncValue.error('Email sudah terdaftar', StackTrace.current);
        return false;
      }

      final id = const Uuid().v4();
      final companion = UsersCompanion.insert(
        id: id,
        name: name.trim(),
        username: trimmedUsername,
        email: trimmedEmail,
        passwordHash: password,
        isActive: const Value(true),
        createdAt: Value(DateTime.now()),
      );

      await _db.insertUser(companion);
      final user = await _db.getUserById(id);

      if (user != null) {
        // Enqueue sync ke Supabase
        await _sync.enqueue(
          tableName: 'users',
          recordId: id,
          operation: 'create',
          data: {
            'id': id,
            'name': name.trim(),
            'username': trimmedUsername,
            'email': trimmedEmail,
            'password_hash': password,
            'created_at': DateTime.now().toIso8601String(),
          },
        );
        
        // Save session otomatis setelah signup
        await _settings.setUserId(id);
        state = AsyncValue.data(user);
        return true;
      }
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _settings.setUserId(null);
    state = const AsyncValue.data(null);
  }

  /// Set user langsung
  void setUser(User user) {
    state = AsyncValue.data(user);
  }
}
