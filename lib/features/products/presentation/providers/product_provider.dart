import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';

/// Filter stok
enum StockFilter { all, low, empty }

/// Provider filter stok aktif
final stockFilterProvider = StateProvider<StockFilter>((ref) => StockFilter.all);

/// Provider search query
final productSearchProvider = StateProvider<String>((ref) => '');

/// Provider filter kategori
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Provider daftar kategori
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getAllCategories();
});

class ProductsPaginationNotifier extends AsyncNotifier<List<Product>> {
  int _offset = 0;
  final int _limit = 20;
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  @override
  Future<List<Product>> build() async {
    _offset = 0;
    _hasMore = true;
    
    // Listen to filter changes so it triggers a rebuild
    ref.watch(productSearchProvider);
    ref.watch(stockFilterProvider);
    ref.watch(selectedCategoryProvider);
    
    return _fetchProducts();
  }

  Future<List<Product>> _fetchProducts() async {
    final db = ref.read(databaseProvider);
    final search = ref.read(productSearchProvider);
    final filter = ref.read(stockFilterProvider);
    final categoryId = ref.read(selectedCategoryProvider);

    List<Product> products;

    if (search.isNotEmpty) {
      products = await db.searchProducts(search);
    } else if (categoryId != null) {
      products = await db.getProductsByCategory(categoryId);
    } else {
      products = await db.getAllProducts(limit: _limit, offset: _offset);
    }

    // Apply stock filter
    switch (filter) {
      case StockFilter.low:
        products = products.where((p) => p.stockQty > 0 && p.stockQty <= p.stockMin).toList();
      case StockFilter.empty:
        products = products.where((p) => p.stockQty == 0).toList();
      case StockFilter.all:
        break;
    }

    if (search.isEmpty && categoryId == null && filter == StockFilter.all) {
      _hasMore = products.length == _limit;
    } else {
      _hasMore = false;
    }

    return products;
  }

  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading) return;

    final currentProducts = state.value ?? [];
    _offset += _limit;

    try {
      final newProducts = await _fetchProducts();
      state = AsyncValue.data([...currentProducts, ...newProducts]);
    } catch (e, st) {
      _offset -= _limit;
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider daftar produk (dengan filter dan pagination)
final productsProvider = AsyncNotifierProvider<ProductsPaginationNotifier, List<Product>>(() {
  return ProductsPaginationNotifier();
});

/// Provider detail produk
final productDetailProvider = FutureProvider.family<Product?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.getProductById(id);
});

/// Provider riwayat penyesuaian stok
final stockAdjustmentsProvider = FutureProvider.family<List<StockAdjustment>, String>((ref, productId) {
  final db = ref.watch(databaseProvider);
  return db.getStockAdjustments(productId);
});

/// Provider produk stok menipis
final lowStockProvider = FutureProvider<List<Product>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getLowStockProducts();
});
