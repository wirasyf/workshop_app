import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/utils/app_toast.dart';
import '../providers/product_provider.dart';
import '../widgets/stock_badge.dart';
import '../../data/product_repository.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, dynamic product, String? from) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produk / Stok'),
        content: Text('Apakah Anda yakin ingin menghapus "${product.name}" beserta data stoknya? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final repo = ref.read(productRepositoryProvider);

    try {
      await repo.deleteProduct(product.id);

      if (context.mounted) {
        AppToast.show(context, '${product.name} berhasil dihapus', type: ToastType.success);
        context.go(from == 'dashboard' ? '/products?from=dashboard' : '/products');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Gagal menghapus produk: $e', type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailProvider(productId));
    final theme = Theme.of(context);
    final from = GoRouterState.of(context).uri.queryParameters['from'];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(from == 'dashboard' ? '/products?from=dashboard' : '/products');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detail Produk'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => context.go(from == 'dashboard' ? '/products?from=dashboard' : '/products'),
          ),
        ),
        body: productAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (product) {
            if (product == null) return const Center(child: Text('Produk tidak ditemukan'));
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.08), AppColors.primaryLight.withValues(alpha: 0.05)]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: product.imageUrl!.startsWith('http')
                                      ? CachedNetworkImage(imageUrl: product.imageUrl!, fit: BoxFit.cover, placeholder: (_, __) => const Center(child: CircularProgressIndicator()), errorWidget: (_, __, ___) => const Icon(Icons.error_rounded, size: 40))
                                      : Image.file(File(product.imageUrl!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.settings_rounded, size: 40, color: AppColors.primary)),
                                )
                              : const Icon(Icons.settings_rounded, size: 40, color: AppColors.primary),
                        ),
                        const SizedBox(height: 12),
                        Text(product.name, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                        const SizedBox(height: 4),
                        Text(product.sku ?? '-', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        StockBadge(qty: product.stockQty, minQty: product.stockMin),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoSection(theme, 'Informasi Produk', [
                    _infoRow('Barcode', product.barcode ?? '-'),
                    _infoRow('Merek', product.brand ?? '-'),
                    _infoRow('Tipe Motor', product.motorType ?? '-'),
                    _infoRow('Satuan', product.unit),
                  ]),
                  const SizedBox(height: 16),
                  _buildInfoSection(theme, 'Harga', [
                    _infoRow('Harga Beli', CurrencyFormatter.format(product.costPrice)),
                    _infoRow('Harga Jual', CurrencyFormatter.format(product.sellPrice)),
                    _infoRow('Harga Karyawan', CurrencyFormatter.format(product.workerPrice)),
                    _infoRow('Margin', product.costPrice > 0
                        ? '${((product.sellPrice - product.costPrice) / product.costPrice * 100).toStringAsFixed(0)}%'
                        : '-'),
                  ]),
                  const SizedBox(height: 16),
                  _buildInfoSection(theme, 'Stok', [
                    _infoRow('Stok Saat Ini', '${product.stockQty} ${product.unit}'),
                    _infoRow('Stok Minimum', '${product.stockMin} ${product.unit}'),
                  ]),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(onPressed: () => context.go('/products/$productId/adjust${from == 'dashboard' ? '?from=dashboard' : ''}'), icon: const Icon(Icons.tune_rounded, size: 18), label: const Text('Sesuaikan Stok'))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton.icon(onPressed: () => context.go('/products/$productId/edit${from == 'dashboard' ? '?from=dashboard' : ''}'), icon: const Icon(Icons.edit_rounded, size: 18), label: const Text('Edit Produk'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _confirmDelete(context, ref, product, from),
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                      label: const Text('Hapus Produk & Stok', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)))),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoSection(ThemeData theme, String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 12), ...children]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)), Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))]),
    );
  }
}
