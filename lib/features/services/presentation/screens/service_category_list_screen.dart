import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../shared/utils/app_toast.dart';
import 'package:uuid/uuid.dart';
import '../providers/service_provider.dart';

class ServiceCategoryListScreen extends ConsumerWidget {
  const ServiceCategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(serviceCategoriesProvider);
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final target = '/services${from == 'dashboard' ? '?from=dashboard' : ''}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(target);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kelola Kategori Jasa'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => context.go(target),
          ),
        ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_rounded, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('Belum ada kategori jasa', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return _CategoryTile(category: item);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kategori Baru'),
      ),
    ));
  }

  void _showCategoryDialog(BuildContext context, WidgetRef ref, {ServiceCategory? category}) {
    final nameCtrl = TextEditingController(text: category?.name);
    final isEditing = category != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Kategori Jasa' : 'Tambah Kategori Jasa'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nama Kategori',
            hintText: 'Contoh: Servis Rutin, Perbaikan, Tune Up...',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final slug = name.toLowerCase().replaceAll(' ', '-').replaceAll(RegExp(r'[^a-z0-z0-9-]'), '');
              final db = ref.read(databaseProvider);
              final sync = ref.read(syncServiceProvider);
              
              try {
                if (isEditing) {
                  await db.updateServiceCategory(ServiceCategoriesCompanion(
                    id: Value(category.id),
                    name: Value(name),
                    slug: Value(slug),
                  ));
                  await sync.enqueue(
                    tableName: 'service_categories',
                    recordId: category.id,
                    operation: 'update',
                    data: {'id': category.id, 'name': name, 'slug': slug},
                  );
                } else {
                  final id = const Uuid().v4();
                  await db.insertServiceCategory(ServiceCategoriesCompanion.insert(
                    id: id,
                    name: name,
                    slug: slug,
                  ));
                  await sync.enqueue(
                    tableName: 'service_categories',
                    recordId: id,
                    operation: 'create',
                    data: {'id': id, 'name': name, 'slug': slug},
                  );
                }
                
                ref.invalidate(serviceCategoriesProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  AppToast.show(context, 'Kategori jasa berhasil disimpan', type: ToastType.success);
                }
              } catch (e) {
                if (context.mounted) AppToast.show(context, 'Gagal menyimpan kategori jasa', type: ToastType.error);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final ServiceCategory category;
  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.primary),
              onPressed: () => const ServiceCategoryListScreen()._showCategoryDialog(context, ref, category: category),
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, size: 20, color: AppColors.error),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori Jasa'),
        content: Text('Apakah Anda yakin ingin menghapus kategori "${category.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              final sync = ref.read(syncServiceProvider);
              try {
                await db.deleteServiceCategory(category.id);
                await sync.enqueue(
                  tableName: 'service_categories',
                  recordId: category.id,
                  operation: 'delete',
                  data: {'id': category.id},
                );
                ref.invalidate(serviceCategoriesProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  AppToast.show(context, 'Kategori jasa dihapus', type: ToastType.success);
                }
              } catch (e) {
                if (context.mounted) AppToast.show(context, 'Gagal menghapus kategori jasa', type: ToastType.error);
              }
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
