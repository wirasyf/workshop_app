import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePass = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _newEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('User tidak ditemukan');
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser == null || fbUser.email == null)
        throw Exception('User tidak login di Firebase');

      // 1. Re-authenticate
      try {
        final credential = EmailAuthProvider.credential(
          email: fbUser.email!,
          password: _passwordCtrl.text,
        );
        await fbUser.reauthenticateWithCredential(credential);
      } catch (e) {
        if (mounted) {
          AppToast.show(
            context,
            'Password saat ini salah',
            type: ToastType.error,
          );
        }
        return;
      }

      // 2. Update Firebase Auth Email
      final newEmail = _newEmailCtrl.text.trim();
      try {
        await fbUser.verifyBeforeUpdateEmail(newEmail);
        if (mounted) {
          AppToast.show(
            context,
            'Tautan verifikasi telah dikirim ke $newEmail. Cek Inbox/Spam Anda.',
            type: ToastType.info,
          );
          context.go('/settings');
        }
        return; // Hentikan eksekusi, Firestore baru diupdate setelah user verifikasi
      } catch (e) {
        throw Exception('Firebase menolak: $e');
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Gagal ganti email: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/settings');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ganti Email'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => context.go('/settings'),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _newEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Baru'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Wajib diisi';
                  final emailRegex = RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  );
                  if (!emailRegex.hasMatch(v)) return 'Email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  labelText: 'Password Saat Ini',
                  helperText: 'Masukkan password saat ini untuk keamanan',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Simpan Email Baru'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
