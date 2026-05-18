import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import 'package:drift/drift.dart' as drift;

final staffProvider = FutureProvider<List<User>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getUsersByRole('cashier');
});

class StaffListScreen extends ConsumerWidget {
  const StaffListScreen({super.key});

  void _showAddStaffDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Karyawan (Kasir)'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                  validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final db = ref.read(databaseProvider);
              final syncService = ref.read(syncServiceProvider);
              final id = const Uuid().v4();

              try {
                // 1. Simpan Lokal
                await db.insertUser(UsersCompanion.insert(
                  id: id,
                  name: nameCtrl.text.trim(),
                  username: usernameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  passwordHash: passwordCtrl.text,
                  role: const drift.Value('cashier'),
                  isActive: const drift.Value(true),
                ));

                // 2. Enqueue Sync
                await syncService.enqueue(
                  tableName: 'users',
                  recordId: id,
                  operation: 'create',
                  data: {
                    'id': id,
                    'name': nameCtrl.text.trim(),
                    'username': usernameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'password_hash': passwordCtrl.text,
                    'role': 'cashier',
                    'is_active': true,
                    'created_at': DateTime.now().toIso8601String(),
                  },
                );

                ref.invalidate(staffProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  AppToast.show(context, 'Karyawan berhasil ditambahkan', type: ToastType.success);
                }
              } catch (e) {
                if (context.mounted) {
                  AppToast.show(context, 'Error: $e', type: ToastType.error);
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Karyawan'),
      ),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (staff) {
          if (staff.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.people_outline_rounded,
              title: 'Belum ada karyawan',
              subtitle: 'Tambahkan akun kasir untuk karyawan Anda',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: staff.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = staff[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.person_rounded, color: AppColors.primary),
                  ),
                  title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('@${user.username} • ${user.email}'),
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
        onPressed: () => _showAddStaffDialog(context, ref),
        label: const Text('Tambah Karyawan'),
        icon: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Karyawan'),
        content: Text('Apakah Anda yakin ingin menghapus akun ${user.name}? Karyawan ini tidak akan bisa login lagi.'),
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
                AppToast.show(context, 'Karyawan dihapus');
              }
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
