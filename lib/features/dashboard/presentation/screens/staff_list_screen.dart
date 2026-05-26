import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/password_service.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final staffProvider = StreamProvider<List<UserModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .where('role', whereIn: ['cashier', 'mechanic'])
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();
      });
});

class StaffListScreen extends ConsumerWidget {
  const StaffListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffProvider);
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final target = from == 'dashboard' ? '/dashboard' : '/settings';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(target);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kelola Karyawan & Mekanik'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => context.go(target),
          ),
        ),
        body: staffAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (staff) {
            if (staff.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.people_outline_rounded,
                title: 'Belum ada data',
                subtitle: 'Tambahkan akun kasir atau pekerja/mekanik',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: staff.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final user = staff[index];
                final isMechanic = user.role == 'mechanic';
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          (isMechanic ? AppColors.success : AppColors.primary)
                              .withValues(alpha: 0.1),
                      child: Icon(
                        isMechanic ? Icons.build_rounded : Icons.person_rounded,
                        color: isMechanic
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isMechanic
                                        ? AppColors.success
                                        : AppColors.primary)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isMechanic ? 'Mekanik' : 'Kasir',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isMechanic
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: isMechanic
                        ? const Text(
                            'Pekerja Jasa (Tanpa Akun Login)',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          )
                        : Text(
                            '@${user.username} • ${user.email}',
                            style: const TextStyle(fontSize: 12),
                          ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                      onPressed: () => _showDeleteConfirm(context, ref, user),
                    ),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const _AddStaffDialog(),
            );
          },
          label: const Text('Tambah Data'),
          icon: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, UserModel user) {
    final isMechanic = user.role == 'mechanic';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isMechanic ? 'Hapus Mekanik' : 'Hapus Karyawan'),
        content: Text('Apakah Anda yakin ingin menghapus data ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.id)
                  .delete();
              if (context.mounted) {
                Navigator.pop(context);
                AppToast.show(
                  context,
                  isMechanic ? 'Mekanik dihapus' : 'Karyawan dihapus',
                );
              }
            },
            child: const Text(
              'Hapus',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddStaffDialog extends ConsumerStatefulWidget {
  const _AddStaffDialog();

  @override
  ConsumerState<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends ConsumerState<_AddStaffDialog> {
  String _selectedRole = 'cashier';
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Data'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        'Kasir (Akses POS)',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: 'cashier',
                      groupValue: _selectedRole,
                      onChanged: (v) => setState(() => _selectedRole = v!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        'Mekanik / Pekerja',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: 'mechanic',
                      groupValue: _selectedRole,
                      onChanged: (v) => setState(() => _selectedRole = v!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
              ),
              if (_selectedRole == 'cashier') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    String id = const Uuid().v4();
    final isMechanic = _selectedRole == 'mechanic';

    final shortUuid = id.substring(0, 8);
    final username = isMechanic
        ? 'mekanik_$shortUuid'
        : _usernameCtrl.text.trim();
    final email = isMechanic
        ? 'mekanik_$shortUuid@bengkel.com'
        : _emailCtrl.text.trim();
    final rawPassword = isMechanic ? '123456' : _passwordCtrl.text;
    PasswordService.hashPassword(rawPassword);

    try {
      if (!isMechanic) {
        final tempApp = await Firebase.initializeApp(
          name: 'temp_auth_${DateTime.now().millisecondsSinceEpoch}',
          options: Firebase.app().options,
        );
        try {
          final authResult = await FirebaseAuth.instanceFor(app: tempApp).createUserWithEmailAndPassword(
            email: email,
            password: rawPassword,
          );
          id = authResult.user!.uid;
        } finally {
          await tempApp.delete();
        }
      }

      final user = UserModel(
        id: id,
        name: _nameCtrl.text.trim(),
        username: username,
        email: email,
        role: _selectedRole,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .set(user.toMap());

      if (mounted) {
        Navigator.pop(context);
        AppToast.show(
          context,
          isMechanic
              ? 'Mekanik berhasil ditambahkan'
              : 'Karyawan berhasil ditambahkan',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Error: $e', type: ToastType.error);
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
