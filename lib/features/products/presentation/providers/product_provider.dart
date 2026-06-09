import 'package:dnd_markasban_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/models/category_model.dart';
import '../../data/product_repository.dart';

enum StockFilter { all, low, empty }

final stockFilterProvider = StateProvider<StockFilter>(
  (ref) => StockFilter.all,
);
final productSearchProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final categoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.isLoading) return const Stream.empty();
  if (authState.value == null) return Stream.value([]);
  final repo = ref.watch(productRepositoryProvider);
  return repo.getCategories();
});

final productsProvider = StreamProvider<List<ProductModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.isLoading) return const Stream.empty();
  if (authState.value == null) return Stream.value([]);
  final repo = ref.watch(productRepositoryProvider);
  final search = ref.watch(productSearchProvider);
  final filter = ref.watch(stockFilterProvider);
  final categoryId = ref.watch(selectedCategoryProvider);

  return repo.getProducts().map((products) {
    var filtered = products;

    if (search.isNotEmpty) {
      final query = search.toLowerCase();
      filtered = filtered
          .where(
            (p) =>
                p.name.toLowerCase().contains(query) ||
                (p.barcode != null && p.barcode!.contains(query)) ||
                (p.sku != null && p.sku!.toLowerCase().contains(query)),
          )
          .toList();
    }

    if (categoryId != null) {
      filtered = filtered.where((p) => p.categoryId == categoryId).toList();
    }

    switch (filter) {
      case StockFilter.low:
        filtered = filtered
            .where((p) => p.stockQty > 0 && p.stockQty <= p.stockMin)
            .toList();
        break;
      case StockFilter.empty:
        filtered = filtered.where((p) => p.stockQty <= 0).toList();
        break;
      case StockFilter.all:
        break;
    }

    return filtered;
  });
});

final productDetailProvider = StreamProvider.family<ProductModel?, String>((
  ref,
  id,
) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.getProductById(id);
});

final lowStockProvider = StreamProvider<List<ProductModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.isLoading) return const Stream.empty();
  if (authState.value == null) return Stream.value([]);
  final repo = ref.watch(productRepositoryProvider);
  return repo.getProducts().map((products) {
    return products
        .where((p) => p.isActive && p.stockQty <= p.stockMin)
        .toList();
  });
});
