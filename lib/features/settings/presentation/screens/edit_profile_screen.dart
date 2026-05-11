import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      _nameCtrl.text = user.name;
      _usernameCtrl.text = user.username;
      _emailCtrl.text = user.email;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('User tidak ditemukan');

      final db = ref.read(databaseProvider);
      
      // Update in DB
      await (db.update(db.users)..where((u) => u.id.equals(user.id))).write(
        UsersCompanion(
          name: Value(_nameCtrl.text.trim()),
          username: Value(_usernameCtrl.text.trim()),
          email: Value(_emailCtrl.text.trim()),
        ),
      );

      // Refresh session
      final updatedUser = await db.getUserById(user.id);
      if (updatedUser != null) {
        ref.read(authStateProvider.notifier).setUser(updatedUser);
      }

      if (mounted) {
        AppToast.show(context, 'Profil berhasil diperbarui', type: ToastType.success);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) context.pop();
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Gagal memperbarui profil: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.person, size: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Lengkap'),
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(labelText: 'Username'),
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Wajib diisi';
                if (!v.contains('@')) return 'Email tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Simpan Profil'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
