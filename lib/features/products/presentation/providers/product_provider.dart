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
final selectedCategoryProvider = StateProvider<int?>((ref) => null);

/// Provider daftar kategori
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getAllCategories();
});

/// Provider daftar produk (dengan filter)
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final db = ref.watch(databaseProvider);
  final search = ref.watch(productSearchProvider);
  final filter = ref.watch(stockFilterProvider);
  final categoryId = ref.watch(selectedCategoryProvider);

  List<Product> products;

  if (search.isNotEmpty) {
    products = await db.searchProducts(search);
  } else if (categoryId != null) {
    products = await db.getProductsByCategory(categoryId);
  } else {
    products = await db.getAllProducts();
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

  return products;
});

/// Provider detail produk
final productDetailProvider = FutureProvider.family<Product?, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.getProductById(id);
});

/// Provider riwayat penyesuaian stok
final stockAdjustmentsProvider = FutureProvider.family<List<StockAdjustment>, int>((ref, productId) {
  final db = ref.watch(databaseProvider);
  return db.getStockAdjustments(productId);
});

/// Provider produk stok menipis
final lowStockProvider = FutureProvider<List<Product>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getLowStockProducts();
});
