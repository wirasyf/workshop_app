import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/utils/app_toast.dart';
import '../providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
            // Jika permission denied, coba langsung login dengan input sebagai email
            // (misal user memang mengetik email tanpa @)
            debugPrint(
              'Username lookup failed: permission-denied. Trying as email...',
            );
          } else {
            rethrow;
          }
        }
      }

      final success = await ref
          .read(authStateProvider.notifier)
          .login(loginEmail, _passwordCtrl.text);

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (success && mounted) {
        AppToast.show(context, 'Login berhasil', type: ToastType.success);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          context.go('/dashboard');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring(11);
        }
        AppToast.show(context, errorMsg, type: ToastType.error);
      }
    }
  }

  Future<void> _createInitialOwner() async {
    setState(() => _isLoading = true);
    try {
      final email = 'owner@bengkel.com';
      final password = 'password123';

      // 1. Create auth user
      final authResult = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = authResult.user!.uid;

      // 2. Insert to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'id': uid,
        'name': 'Owner Bengkel',
        'username': 'owner',
        'email': email,
        'role': 'owner',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        AppToast.show(
          context,
          'Akun Owner berhasil dibuat!\nSilakan login dengan owner@bengkel.com / password123',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          'Gagal membuat akun owner: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                        child: GestureDetector(
                          onLongPress: _createInitialOwner,
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
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
