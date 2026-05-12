import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/supabase_service.dart';
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
  File? _imageFile;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      _nameCtrl.text = user.name;
      _usernameCtrl.text = user.username;
      _emailCtrl.text = user.email;
      _currentAvatarUrl = user.avatarUrl;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadAvatar(int userId) async {
    if (_imageFile == null) return _currentAvatarUrl;

    try {
      final client = SupabaseService.client;
      final fileExt = _imageFile!.path.split('.').last;
      final fileName = 'avatar_$userId.$fileExt';

      // Upload directly to root of 'avatars' bucket
      await client.storage.from('avatars').upload(
        fileName,
        _imageFile!,
        fileOptions: const FileOptions(upsert: true),
      );

      // Get Public URL
      final publicUrl = client.storage.from('avatars').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      return _currentAvatarUrl;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('User tidak ditemukan');

      final db = ref.read(databaseProvider);
      
      // 1. Upload ke Supabase Storage jika ada foto baru
      final avatarUrl = await _uploadAvatar(user.id);

      // 2. Update di DB Lokal
      await (db.update(db.users)..where((u) => u.id.equals(user.id))).write(
        UsersCompanion(
          name: Value(_nameCtrl.text.trim()),
          username: Value(_usernameCtrl.text.trim()),
          email: Value(_emailCtrl.text.trim()),
          avatarUrl: Value(avatarUrl),
        ),
      );

      // 3. Enqueue sync ke tabel users di Supabase (untuk metadata)
      final sync = ref.read(syncServiceProvider);
      await sync.enqueue(
        tableName: 'users',
        recordId: user.id,
        operation: 'update',
        data: {
          'name': _nameCtrl.text.trim(),
          'username': _usernameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'avatar_url': avatarUrl,
        },
      );

      // Refresh session
      final updatedUser = await db.getUserById(user.id);
      if (updatedUser != null) {
        ref.read(authStateProvider.notifier).setUser(updatedUser);
        setState(() {
          _imageFile = null;
          _currentAvatarUrl = updatedUser.avatarUrl;
        });
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
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: _imageFile != null 
                        ? FileImage(_imageFile!) 
                        : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty 
                            ? (_currentAvatarUrl!.startsWith('http') 
                                ? CachedNetworkImageProvider(_currentAvatarUrl!) 
                                : (File(_currentAvatarUrl!).existsSync() ? FileImage(File(_currentAvatarUrl!)) : null)) 
                            : null) as ImageProvider?,
                    child: (_imageFile == null && (_currentAvatarUrl == null || _currentAvatarUrl!.isEmpty))
                        ? const Icon(Icons.person, size: 50, color: AppColors.primary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
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
