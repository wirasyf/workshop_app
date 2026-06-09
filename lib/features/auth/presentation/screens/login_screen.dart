import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/utils/app_toast.dart';
import '../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Layar login — email + password
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String loginEmail = _emailCtrl.text.trim();

      // Jika input tidak memiliki '@', asumsikan sebagai username
      if (!loginEmail.contains('@')) {
        try {
          final querySnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: loginEmail)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            loginEmail = querySnapshot.docs.first.data()['email'] as String;
          } else {
            throw Exception('Username tidak ditemukan');
          }
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            debugPrint('Username lookup failed: permission-denied. Trying as email...');
          } else {
            rethrow;
          }
        }
      }

      debugPrint('🔐 Mencoba login dengan email: $loginEmail');

      final success = await ref
          .read(authStateProvider.notifier)
          .login(loginEmail, _passwordCtrl.text);

      debugPrint('🔐 Login result: $success');

      if (mounted) {
        setState(() => _isLoading = false);
      }

      // Navigasi ke dashboard ditangani otomatis oleh GoRouter redirect
      // saat authStateProvider berubah — tidak perlu context.go() manual.
      if (success && mounted) {
        AppToast.show(context, 'Login berhasil', type: ToastType.success);
      }
    } catch (e) {
      debugPrint('🔐 Login exception: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMsg = e.toString();
        // Bersihkan prefix exception bawaan Dart/Firebase
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring(11);
        }
        if (errorMsg.startsWith('[firebase_auth/')) {
          // Format: [firebase_auth/error-code] Pesan error
          final msgStart = errorMsg.indexOf('] ');
          if (msgStart != -1) errorMsg = errorMsg.substring(msgStart + 2);
        }
        AppToast.show(context, errorMsg, type: ToastType.error);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo & Branding
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppConstants.appName,
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manajemen Toko Spare Part',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 40),

                    // Email field
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username atau Email',
                        hintText: 'Masukkan username atau email',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Email wajib diisi';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Masukkan password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Password wajib diisi';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Masuk'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
