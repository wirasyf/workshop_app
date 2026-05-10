import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/barcode_scanner_dialog.dart';

/// Layar POS — pilih produk
class PosProductScreen extends ConsumerWidget {
  const PosProductScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final cart = ref.watch(cartProvider);
    final cartItemCount = cart.fold<int>(0, (sum, item) => sum + item.qty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir / POS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner), 
            onPressed: () async {
              final code = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const BarcodeScannerDialog()),
              );
              if (code != null) {
                ref.read(productSearchProvider.notifier).state = code;
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (v) => ref.read(productSearchProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),

          // Categories horizontal list
          _CategoryFilterBar(),
          const SizedBox(height: 12),

          // Product grid
          Expanded(
            child: products.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: LoadingWidget()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyStateWidget(icon: Icons.inventory_2_outlined, title: 'Tidak ada produk');
                }
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.82,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _PosProductCard(product: items[i]),
                );
              },
            ),
          ),
        ],
      ),

      // Floating cart button
      floatingActionButton: cartItemCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/pos/cart'),
              icon: const Icon(Icons.shopping_cart),
              label: Text('Keranjang ($cartItemCount)'),
              backgroundColor: AppColors.secondary,
            )
          : null,
    );
  }
}

class _PosProductCard extends ConsumerWidget {
  final dynamic product;
  const _PosProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isOutOfStock = product.stockQty <= 0;

    final cart = ref.watch(cartProvider);
    final cartItem = cart.where((i) => i.productId == product.id).firstOrNull;
    final inCartQty = cartItem?.qty ?? 0;

    return GestureDetector(
      onTap: isOutOfStock ? null : () {
        final notifier = ref.read(cartProvider.notifier);
        final item = CartItem(
          productId: product.id,
          name: product.name,
          unitPrice: product.sellPrice,
          unit: product.unit,
        );

        if (inCartQty > 0) {
          notifier.removeItem(product.id);
          AppToast.show(context, '${product.name} dihapus dari keranjang', type: ToastType.info, duration: const Duration(milliseconds: 1500));
        } else {
          notifier.addItem(item);
          AppToast.show(context, '${product.name} ditambah ke keranjang', type: ToastType.success, duration: const Duration(milliseconds: 1500));
        }
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inCartQty > 0 ? AppColors.primary : (isOutOfStock ? AppColors.error.withValues(alpha: 0.3) : AppColors.border),
            width: inCartQty > 0 ? 1.5 : 1,
          ),
          boxShadow: inCartQty > 0 ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: product.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(product.imageUrl!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => 
                              Icon(Icons.settings_outlined, size: 36, color: isOutOfStock ? AppColors.textHint : AppColors.primary)),
                          )
                        : Icon(Icons.settings_outlined, size: 36,
                            color: isOutOfStock ? AppColors.textHint : AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(product.name, style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(CurrencyFormatter.format(product.sellPrice),
                    style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(isOutOfStock ? 'Stok habis' : 'Stok: ${product.stockQty}',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: isOutOfStock ? AppColors.error : AppColors.textSecondary)),
              ],
            ),
            // Badge Quantity
            if (inCartQty > 0)
              Positioned(
                top: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$inCartQty', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final selectedId = ref.watch(selectedCategoryProvider);

    return categories.when(
      loading: () => const SizedBox(height: 48),
      error: (_, __) => const SizedBox(),
      data: (items) {
        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // "Semua" option
              _CategoryChip(
                label: 'Semua',
                isSelected: selectedId == null,
                onTap: () => ref.read(selectedCategoryProvider.notifier).state = null,
              ),
              ...items.map((c) => _CategoryChip(
                label: c.name,
                isSelected: selectedId == c.id,
                onTap: () => ref.read(selectedCategoryProvider.notifier).state = c.id,
              )),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.infoLight,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.primary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: 13,
        ),
        side: const BorderSide(color: Colors.transparent),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
