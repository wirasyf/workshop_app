import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import 'package:uuid/uuid.dart';

final categoriesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('categories').snapshots().map(
    (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList()
  );
});

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final target = from == 'dashboard' ? '/products?from=dashboard' : '/products';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(target);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kelola Kategori'),
          leading: IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => context.go(target)),
        ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: EmptyStateWidget(
                icon: Icons.category_rounded,
                title: 'Belum ada kategori',
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

  void _showCategoryDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? category}) {
    final nameCtrl = TextEditingController(text: category?['name']);
    final isEditing = category != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Kategori' : 'Tambah Kategori'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Nama Kategori', hintText: 'Contoh: Aki, Ban, Oli...'),
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
              
              try {
                if (isEditing) {
                  await FirebaseFirestore.instance.collection('categories').doc(category['id']).update({
                    'name': name,
                    'slug': slug,
                  });
                } else {
                  final id = const Uuid().v4();
                  await FirebaseFirestore.instance.collection('categories').doc(id).set({
                    'id': id,
                    'name': name,
                    'slug': slug,
                  });
                }
                
                if (context.mounted) {
                  Navigator.pop(context);
                  AppToast.show(context, 'Kategori berhasil disimpan', type: ToastType.success);
                }
              } catch (e) {
                if (context.mounted) AppToast.show(context, 'Gagal menyimpan kategori', type: ToastType.error);
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
  final Map<String, dynamic> category;
  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: ListTile(
        title: Text(category['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.primary), onPressed: () => const CategoryListScreen()._showCategoryDialog(context, ref, category: category)),
            IconButton(icon: const Icon(Icons.delete_rounded, size: 20, color: AppColors.error), onPressed: () => _confirmDelete(context, ref)),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Apakah Anda yakin ingin menghapus kategori "${category['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('categories').doc(category['id']).delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  AppToast.show(context, 'Kategori dihapus', type: ToastType.success);
                }
              } catch (e) {
                if (context.mounted) AppToast.show(context, 'Gagal menghapus kategori', type: ToastType.error);
              }
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
