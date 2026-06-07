import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/firebase_auth_service.dart';
import 'package:dnd_markasban_app/main.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/settings_service.dart';

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  return FirebaseAuthService(settings);
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
      final authService = ref.watch(firebaseAuthServiceProvider);
      final settingsService = ref.watch(settingsServiceProvider);
      return AuthNotifier(authService, settingsService, FirebaseFirestore.instance);
    });

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value != null;
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final FirebaseAuthService _authService;
  final SettingsService _settings;
  final FirebaseFirestore _firestore;
  StreamSubscription? _sessionSub;

  AuthNotifier(this._authService, this._settings, this._firestore) : super(const AsyncValue.loading()) {
    _loadSession();
  }

  void _setupSessionListener(String userId) {
    _sessionSub?.cancel();
    _sessionSub = _firestore.collection('users').doc(userId).snapshots().listen((doc) {
      if (doc.exists) {
        final dbSessionId = doc.data()?['currentSessionId'];
        final localSessionId = _settings.sessionId;
        if (dbSessionId != null && localSessionId != null && dbSessionId != localSessionId) {
          logout();
        }
      }
    }, onError: (e) {
      // Jangan crash jika permission denied — tetap jalankan aplikasi
      debugPrint('Session listener error: $e');
    });
  }

  Future<void> _loadSession() async {
    try {
      final user = await _authService.getCurrentUserData();
      if (user != null) _setupSessionListener(user.id);
      state = AsyncValue.data(user);
    } catch (e) {
      state = const AsyncValue.data(null);
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      state = const AsyncValue.loading();
      final user = await _authService.signIn(email, password);
      _setupSessionListener(user.id);
      state = AsyncValue.data(user);
      return true;
    } catch (e) {
      state = const AsyncValue.data(null);
      throw e.toString();
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
      _setupSessionListener(user.id);
      state = AsyncValue.data(user);
      return true;
    } catch (e) {
      state = const AsyncValue.data(null);
      throw e.toString();
    }
  }

  Future<void> logout() async {
    _sessionSub?.cancel();
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }

  void setUser(UserModel user) {
    state = AsyncValue.data(user);
  }
}
