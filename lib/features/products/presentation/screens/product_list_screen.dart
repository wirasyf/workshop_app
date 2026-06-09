import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../../core/services/excel_export_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../widgets/stock_badge.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final filter = ref.watch(stockFilterProvider);
    final from = GoRouterState.of(context).uri.queryParameters['from'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Stok'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => context.go(from == 'dashboard' ? '/dashboard' : '/settings'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () async {
              final items = productsAsync.valueOrNull;
              if (items == null || items.isEmpty) {
                AppToast.show(context, 'Tidak ada data untuk diekspor', type: ToastType.warning);
                return;
              }
              final user = ref.read(authStateProvider).value;
              final isAdmin = user?.role == 'owner';
              try {
                AppToast.show(context, 'Menyiapkan file Excel...', type: ToastType.info);
                await ExcelExportService.exportProducts(products: items, isAdmin: isAdmin);
              } catch (e) {
                if (context.mounted) {
                  AppToast.show(context, 'Gagal mengekspor: $e', type: ToastType.error);
                }
              }
            },
            tooltip: 'Export ke Excel',
          ),
          IconButton(
            icon: const Icon(Icons.category_rounded),
            onPressed: () => context.go('/products/categories${from == 'dashboard' ? '?from=dashboard' : ''}'),
            tooltip: 'Kelola Kategori',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              onChanged: (v) => ref.read(productSearchProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Cari produk, SKU, barcode...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: StockFilter.values.map((f) {
                final selected = filter == f;
                final label = switch (f) {
                  StockFilter.all => 'Semua',
                  StockFilter.low => 'Menipis',
                  StockFilter.empty => 'Habis',
                };
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => ref.read(stockFilterProvider.notifier).state = f,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.infoLight,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.primary,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
                    ),
                    side: const BorderSide(color: Colors.transparent),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Product list
          Expanded(
            child: productsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LoadingWidget(),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.inventory_2_rounded,
                    title: 'Belum ada produk',
                    subtitle: 'Tambah produk pertama Anda menggunakan tombol di bawah',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(productsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      return _ProductTile(product: items[i]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/products/add${from == 'dashboard' ? '?from=dashboard' : ''}'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Produk Baru'),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final dynamic product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    return GestureDetector(
      onTap: () => context.go('/products/${product.id}${from == 'dashboard' ? '?from=dashboard' : ''}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Gambar produk placeholder
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: product.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: product.imageUrl!.startsWith('data:image')
                        ? Image.memory(
                            base64Decode(product.imageUrl!.split(',').last),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.settings_rounded, color: AppColors.primary, size: 28),
                          )
                        : product.imageUrl!.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              errorWidget: (_, _, _) => const Icon(Icons.error_rounded, size: 20),
                            )
                          : Image.file(
                              File(product.imageUrl!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.settings_rounded, color: AppColors.primary, size: 28),
                            ),
                    )
                  : const Icon(Icons.settings_rounded, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(product.sku ?? '-', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(CurrencyFormatter.format(product.sellPrice), style: theme.textTheme.titleSmall?.copyWith(color: AppColors.primary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StockBadge(qty: product.stockQty, minQty: product.stockMin),
                const SizedBox(height: 4),
                Text('${product.stockQty} ${product.unit}', style: theme.textTheme.labelMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
