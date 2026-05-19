import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import 'package:drift/drift.dart' as drift;

final staffProvider = FutureProvider<List<User>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getStaffUsers();
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
                  side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (isMechanic ? AppColors.success : AppColors.primary).withValues(alpha: 0.1),
                    child: Icon(isMechanic ? Icons.build_rounded : Icons.person_rounded, color: isMechanic ? AppColors.success : AppColors.primary),
                  ),
                  title: Row(
                    children: [
                      Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isMechanic ? AppColors.success : AppColors.primary).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isMechanic ? 'Mekanik' : 'Kasir',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isMechanic ? AppColors.success : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: isMechanic
                      ? const Text('Pekerja Jasa (Tanpa Akun Login)', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12))
                      : Text('@${user.username} • ${user.email}', style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
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
    ));
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, User user) {
    final isMechanic = user.role == 'mechanic';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isMechanic ? 'Hapus Mekanik' : 'Hapus Karyawan'),
        content: Text('Apakah Anda yakin ingin menghapus data ${user.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              final syncService = ref.read(syncServiceProvider);

              await db.deleteUser(user.id);
              await syncService.enqueue(
                tableName: 'users',
                recordId: user.id,
                operation: 'delete',
                data: {'id': user.id},
              );

              ref.invalidate(staffProvider);
              if (context.mounted) {
                Navigator.pop(context);
                AppToast.show(context, isMechanic ? 'Mekanik dihapus' : 'Karyawan dihapus');
              }
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
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
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

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
              // Pemilihan Role
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Kasir (Akses POS)', style: TextStyle(fontSize: 12)),
                      value: 'cashier',
                      groupValue: _selectedRole,
                      onChanged: (v) => setState(() => _selectedRole = v!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Mekanik / Pekerja', style: TextStyle(fontSize: 12)),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final db = ref.read(databaseProvider);
    final syncService = ref.read(syncServiceProvider);
    final id = const Uuid().v4();
    final isMechanic = _selectedRole == 'mechanic';

    final shortUuid = id.substring(0, 8);
    final username = isMechanic ? 'mekanik_$shortUuid' : _usernameCtrl.text.trim();
    final email = isMechanic ? 'mekanik_$shortUuid@bengkel.com' : _emailCtrl.text.trim();
    final password = isMechanic ? '123456' : _passwordCtrl.text;

    try {
      await db.insertUser(UsersCompanion.insert(
        id: id,
        name: _nameCtrl.text.trim(),
        username: username,
        email: email,
        passwordHash: password,
        role: drift.Value(_selectedRole),
        isActive: const drift.Value(true),
      ));

      await syncService.enqueue(
        tableName: 'users',
        recordId: id,
        operation: 'create',
        data: {
          'id': id,
          'name': _nameCtrl.text.trim(),
          'username': username,
          'email': email,
          'password_hash': password,
          'role': _selectedRole,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      ref.invalidate(staffProvider);
      if (mounted) {
        Navigator.pop(context);
        AppToast.show(context, isMechanic ? 'Mekanik berhasil ditambahkan' : 'Karyawan berhasil ditambahkan', type: ToastType.success);
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
