import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../services/presentation/providers/service_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/barcode_scanner_dialog.dart';

/// Provider untuk toggle mode POS: sparepart atau jasa
final posTabProvider = StateProvider<int>(
  (ref) => 0,
); // 0 = sparepart, 1 = jasa

/// Layar POS — pilih produk / jasa
class PosProductScreen extends ConsumerWidget {
  const PosProductScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cartItemCount = cart.fold<int>(0, (sum, item) => sum + item.qty);
    final posTab = ref.watch(posTabProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir / POS'),
        actions: [
          if (posTab == 0)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: () async {
                final code = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BarcodeScannerDialog(),
                  ),
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
          // Toggle: Sparepart | Jasa
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _TabButton(
                    label: 'Sparepart',
                    icon: Icons.settings_rounded,
                    isSelected: posTab == 0,
                    onTap: () => ref.read(posTabProvider.notifier).state = 0,
                  ),
                  _TabButton(
                    label: 'Jasa',
                    icon: Icons.build_rounded,
                    isSelected: posTab == 1,
                    onTap: () => ref.read(posTabProvider.notifier).state = 1,
                  ),
                ],
              ),
            ),
          ),

          // Content based on tab
          if (posTab == 0) ...[
            // Search bar (produk)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                onChanged: (v) =>
                    ref.read(productSearchProvider.notifier).state = v,
                decoration: const InputDecoration(
                  hintText: 'Cari produk...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            _CategoryFilterBar(),
            const SizedBox(height: 12),
            const Expanded(child: _ProductGrid()),
          ] else ...[
            // Search bar (jasa)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                onChanged: (v) =>
                    ref.read(serviceSearchProvider.notifier).state = v,
                decoration: const InputDecoration(
                  hintText: 'Cari jasa...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            _ServiceCategoryFilterBar(),
            const SizedBox(height: 12),
            const Expanded(child: _ServiceGrid()),
          ],
        ],
      ),

      // Floating cart button
      floatingActionButton: cartItemCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/pos/cart'),
              icon: const Icon(Icons.shopping_cart_rounded),
              label: Text('Keranjang ($cartItemCount)'),
              backgroundColor: AppColors.secondary,
            )
          : null,
    );
  }
}

/// Tab button for Sparepart/Jasa toggle
class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid produk (sparepart)
class _ProductGrid extends ConsumerWidget {
  const _ProductGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);

    return products.when(
      loading: () =>
          const Padding(padding: EdgeInsets.all(16), child: LoadingWidget()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.inventory_2_rounded,
            title: 'Tidak ada produk',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _PosProductCard(product: items[i]),
        );
      },
    );
  }
}

/// Grid jasa
class _ServiceGrid extends ConsumerWidget {
  const _ServiceGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(filteredServicesProvider);

    return servicesAsync.when(
      loading: () =>
          const Padding(padding: EdgeInsets.all(16), child: LoadingWidget()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.build_rounded,
            title: 'Tidak ada jasa',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _PosServiceCard(service: items[i]),
        );
      },
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
    final cartItem = cart
        .where(
          (i) => i.productId == product.id && i.type == CartItemType.product,
        )
        .firstOrNull;
    final inCartQty = cartItem?.qty ?? 0;

    return GestureDetector(
      onTap: isOutOfStock
          ? null
          : () {
              final notifier = ref.read(cartProvider.notifier);
              final item = CartItem(
                productId: product.id,
                name: product.name,
                unitPrice: product.sellPrice,
                unit: product.unit,
                costPrice: product.costPrice,
                type: CartItemType.product,
              );

              notifier.toggleItem(item);
              AppToast.show(
                context,
                inCartQty > 0
                    ? '${product.name} dihapus dari keranjang'
                    : '${product.name} ditambah ke keranjang',
                type: ToastType.success,
                duration: const Duration(milliseconds: 1000),
              );
              HapticFeedback.lightImpact();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inCartQty > 0
                ? AppColors.primary
                : (isOutOfStock
                      ? AppColors.error.withValues(alpha: 0.3)
                      : AppColors.border),
            width: inCartQty > 0 ? 1.5 : 1,
          ),
          boxShadow: inCartQty > 0
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            child: product.imageUrl!.startsWith('http')
                                ? CachedNetworkImage(
                                    imageUrl: product.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.error_rounded,
                                      size: 20,
                                    ),
                                  )
                                : Image.file(
                                    File(product.imageUrl!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.settings_rounded,
                                      size: 36,
                                      color: isOutOfStock
                                          ? AppColors.textHint
                                          : AppColors.primary,
                                    ),
                                  ),
                          )
                        : Icon(
                            Icons.settings_rounded,
                            size: 36,
                            color: isOutOfStock
                                ? AppColors.textHint
                                : AppColors.primary,
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(product.sellPrice),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOutOfStock ? 'Stok habis' : 'Stok: ${product.stockQty}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isOutOfStock
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (inCartQty > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$inCartQty',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PosServiceCard extends ConsumerWidget {
  final dynamic service;
  const _PosServiceCard({required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cart = ref.watch(cartProvider);
    final inCartItems = cart
        .where(
          (i) => i.productId == service.id && i.type == CartItemType.service,
        )
        .toList();
    final totalInCartQty = inCartItems.fold<int>(0, (sum, i) => sum + i.qty);

    return GestureDetector(
      onTap: () {
        final notifier = ref.read(cartProvider.notifier);
        final item = CartItem(
          productId: service.id,
          name: service.name,
          unitPrice: service.price,
          unit: 'jasa',
          type: CartItemType.service,
        );
        notifier.toggleItem(item);
        AppToast.show(
          context,
          totalInCartQty > 0
              ? '${service.name} dihapus dari keranjang'
              : '${service.name} ditambah ke keranjang',
          type: ToastType.success,
        );
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: totalInCartQty > 0 ? AppColors.info : AppColors.border,
            width: totalInCartQty > 0 ? 1.5 : 1,
          ),
          boxShadow: totalInCartQty > 0
              ? [
                  BoxShadow(
                    color: AppColors.info.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.build_rounded,
                      size: 36,
                      color: AppColors.info,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  service.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(service.price),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '~${service.estimatedMinutes} menit',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (totalInCartQty > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalInCartQty',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
              _ChipWidget(
                label: 'Semua',
                isSelected: selectedId == null,
                onTap: () =>
                    ref.read(selectedCategoryProvider.notifier).state = null,
              ),
              ...items.map(
                (c) => _ChipWidget(
                  label: c.name,
                  isSelected: selectedId == c.id,
                  onTap: () =>
                      ref.read(selectedCategoryProvider.notifier).state = c.id,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServiceCategoryFilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(serviceSelectedCategoryProvider);
    final categoriesAsync = ref.watch(serviceCategoriesProvider);

    return categoriesAsync.when(
      loading: () => const SizedBox(height: 48),
      error: (_, __) => const SizedBox(),
      data: (items) {
        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _ChipWidget(
                label: 'Semua',
                isSelected: selectedCategory == null,
                onTap: () =>
                    ref.read(serviceSelectedCategoryProvider.notifier).state =
                        null,
              ),
              ...items.map(
                (c) => _ChipWidget(
                  label: c.name,
                  isSelected: selectedCategory == c.id,
                  onTap: () =>
                      ref.read(serviceSelectedCategoryProvider.notifier).state =
                          c.id,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChipWidget extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ChipWidget({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

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
