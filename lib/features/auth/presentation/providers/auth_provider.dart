import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../main.dart';

/// Provider untuk auth state — menyimpan user yang sedang login
final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  final db = ref.watch(databaseProvider);
  final settings = ref.watch(settingsServiceProvider);
  return AuthNotifier(db, settings);
});

/// Provider untuk cek apakah sedang login
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});

/// Provider untuk role user
final currentRoleProvider = Provider<String>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.role ?? 'kasir';
});

/// Notifier untuk mengelola state autentikasi
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AppDatabase _db;
  final SettingsService _settings;

  AuthNotifier(this._db, this._settings) : super(const AsyncValue.loading()) {
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

  /// Login dengan email dan password (offline-first via lokal DB)
  Future<bool> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _db.getUserByEmail(email);
      if (user == null) {
        state = AsyncValue.error('Email tidak ditemukan', StackTrace.current);
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
      
      // Save session
      await _settings.setUserId(user.id);
      
      state = AsyncValue.data(user);
      return true;
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
