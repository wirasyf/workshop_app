import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/firebase_auth_service.dart';
import 'package:dnd_markasban_app/main.dart';
import '../../../../core/services/settings_service.dart';

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  final settings = ref.read(settingsServiceProvider);
  return FirebaseAuthService(settings);
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
      final authService = ref.read(firebaseAuthServiceProvider);
      final settingsService = ref.read(settingsServiceProvider);
      return AuthNotifier(authService, settingsService);
    });

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value != null;
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final FirebaseAuthService _authService;
  final SettingsService _settings;

  AuthNotifier(this._authService, this._settings)
      : super(const AsyncValue.loading()) {
    _loadSession();
  }

  /// Memuat sesi saat app dibuka.
  ///
  /// Strategi dua lapis:
  /// 1. Coba Firebase Auth — jika sesi tersimpan, langsung restore.
  /// 2. Fallback ke SharedPreferences — jika Firebase gagal baca sesi
  ///    (misalnya karena FirebearStorageCryptoHelper error), coba
  ///    re-authenticate silent menggunakan data yang tersimpan lokal.
  Future<void> _loadSession() async {
    try {
      debugPrint('🔑 _loadSession: menunggu authStateChanges...');
      // Tunggu stream auth Firebase stabil di awal
      final firebaseUser = await _authService.authStateChanges.first;
      debugPrint(
        '🔑 _loadSession: firebaseUser=${firebaseUser?.uid ?? 'null'}',
      );

      if (!mounted) return;

      if (firebaseUser != null) {
        // Firebase Auth berhasil restore sesi
        final user = await _authService.getCurrentUserData();
        debugPrint(
          '🔑 _loadSession: user=${user?.id ?? 'null'}, role=${user?.role ?? 'null'}',
        );
        if (!mounted) return;
        state = AsyncValue.data(user);
        if (user != null) {
          debugPrint('✅ Auto-login berhasil via Firebase Auth: ${user.email}');
        }
        return;
      }

      // Firebase Auth null — coba fallback dari SharedPreferences
      debugPrint('🔑 Firebase user null, coba fallback dari SharedPreferences...');
      await _tryRestoreFromLocalSession();
    } catch (e) {
      debugPrint('🔑 _loadSession error: $e');
      if (!mounted) return;
      // Tetap coba fallback lokal sebelum menyerah
      await _tryRestoreFromLocalSession();
    }
  }

  /// Coba restore sesi dari data lokal (SharedPreferences).
  /// Jika ada userId & role tersimpan, buat UserModel sementara
  /// dan sekaligus coba re-login silent ke Firebase di background.
  Future<void> _tryRestoreFromLocalSession() async {
    if (!mounted) return;

    final savedUserId = _settings.userId;
    final savedUserName = _settings.userName;
    final savedUserRole = _settings.userRole;

    if (savedUserId == null || savedUserRole == null) {
      debugPrint('🔑 Tidak ada sesi lokal → tampilkan login');
      state = const AsyncValue.data(null);
      return;
    }

    debugPrint('📦 Restore sesi dari SharedPreferences: $savedUserId, role=$savedUserRole');

    // Restore state segera dari data lokal agar UI tidak stuck di loading
    final localUser = UserModel(
      id: savedUserId,
      name: savedUserName ?? 'User',
      username: savedUserName ?? 'user',
      email: savedUserRole == 'owner' ? OwnerConfig.email : '',
      role: savedUserRole,
      isActive: true,
      createdAt: DateTime.now(),
    );

    if (!mounted) return;
    state = AsyncValue.data(localUser);
    debugPrint('✅ Auto-login berhasil via SharedPreferences: role=$savedUserRole');

    // Re-authenticate ke Firebase di background agar sesi Firebase
    // juga tersimpan dengan benar untuk request selanjutnya.
    _silentReauth(savedUserRole);
  }

  /// Re-authenticate ke Firebase di background tanpa mengubah state UI.
  Future<void> _silentReauth(String role) async {
    try {
      if (role == 'owner') {
        debugPrint('🔄 Silent re-auth sebagai owner...');
        // Pastikan akun owner ada di Firebase (mungkin sudah dihapus)
        // sebelum mencoba login. ensureOwnerAccount akan membuat ulang
        // jika akun tidak ditemukan.
        await _authService.ensureOwnerAccount();
        final user = await _authService.signIn(
          OwnerConfig.email,
          OwnerConfig.password,
        );
        if (mounted) {
          state = AsyncValue.data(user);
          debugPrint('✅ Silent re-auth owner berhasil');
        }
      }
      // Untuk role lain (karyawan/cashier), tidak bisa silent re-auth
      // tanpa password — state lokal sudah cukup untuk navigasi.
    } catch (e) {
      debugPrint('⚠️ Silent re-auth gagal (tidak masalah): $e');
      // State lokal tetap dipertahankan — user sudah masuk
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      state = const AsyncValue.loading();
      final user = await _authService.signIn(email, password);
      if (!mounted) return false;
      state = AsyncValue.data(user);
      return true;
    } catch (e) {
      debugPrint('login() error: $e');
      if (mounted) state = const AsyncValue.data(null);
      rethrow;
    }
  }

  Future<bool> signup({
    required String name,
    required String username,
    required String email,
    required String password,
    String role = 'owner',
  }) async {
    try {
      state = const AsyncValue.loading();
      final user = await _authService.signUp(
        name: name,
        username: username,
        email: email,
        password: password,
        role: role,
      );
      if (!mounted) return false;
      state = AsyncValue.data(user);
      return true;
    } catch (e) {
      if (mounted) state = const AsyncValue.data(null);
      rethrow;
    }
  }

  /// Logout eksplisit — hanya terjadi jika user menekan tombol logout.
  /// Tidak ada auto-logout yang dipicu dari listener atau lifecycle.
  Future<void> logout() async {
    await _authService.signOut();
    if (mounted) state = const AsyncValue.data(null);
  }

  void setUser(UserModel user) {
    state = AsyncValue.data(user);
  }
}
