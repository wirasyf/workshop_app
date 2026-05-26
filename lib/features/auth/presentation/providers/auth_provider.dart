import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/firebase_auth_service.dart';
import 'package:dnd_markasban_app/main.dart';

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  return FirebaseAuthService(settings);
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
      final authService = ref.watch(firebaseAuthServiceProvider);
      return AuthNotifier(authService);
    });

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value != null;
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final FirebaseAuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final user = await _authService.getCurrentUserData();
      state = AsyncValue.data(user);
    } catch (e) {
      state = const AsyncValue.data(null);
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      state = const AsyncValue.loading();
      final user = await _authService.signIn(email, password);
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
      state = AsyncValue.data(user);
      return true;
    } catch (e) {
      state = const AsyncValue.data(null);
      throw e.toString();
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }

  void setUser(UserModel user) {
    state = AsyncValue.data(user);
  }
}
