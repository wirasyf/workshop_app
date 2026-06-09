import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/file_storage_service.dart';
import 'dart:convert';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
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
      _currentAvatarUrl = user.avatarUrl;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 200,
      maxHeight: 200,
      imageQuality: 40,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('User tidak ditemukan');

      String? newAvatarUrl = _currentAvatarUrl;
      if (_imageFile != null) {
        newAvatarUrl = await FileStorageService.saveProductImage(_imageFile!);
      }

      // Update in Firestore directly
      await FirebaseFirestore.instance.collection('users').doc(user.id).update({
        'name': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        if (newAvatarUrl != null) 'avatarUrl': newAvatarUrl,
      });

      // Update session locally
      final updatedUser = user.copyWith(
        name: _nameCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        avatarUrl: newAvatarUrl,
      );
      ref.read(authStateProvider.notifier).setUser(updatedUser);

      if (mounted) {
        AppToast.show(context, 'Profil berhasil diperbarui', type: ToastType.success);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) context.go('/settings');
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/settings');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profil'),
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
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: _imageFile != null 
                        ? FileImage(_imageFile!) 
                        : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty 
                            ? (_currentAvatarUrl!.startsWith('data:image')
                                ? MemoryImage(base64Decode(_currentAvatarUrl!.split(',').last))
                                : _currentAvatarUrl!.startsWith('http') 
                                  ? CachedNetworkImageProvider(_currentAvatarUrl!) 
                                  : (File(_currentAvatarUrl!).existsSync() ? FileImage(File(_currentAvatarUrl!)) : null)) 
                            : null) as ImageProvider?,
                    child: (_imageFile == null && (_currentAvatarUrl == null || _currentAvatarUrl!.isEmpty))
                        ? const Icon(Icons.person_rounded, size: 50, color: AppColors.primary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
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
              validator: (v) {
                 if (v == null || v.isEmpty) return 'Wajib diisi';
                 if (v.contains(' ')) return 'Username tidak boleh spasi';
                 return null;
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Simpan Profil'),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
