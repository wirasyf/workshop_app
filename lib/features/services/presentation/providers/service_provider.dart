import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';

/// Provider daftar semua jasa aktif
final servicesProvider = FutureProvider<List<Service>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getAllServices();
});

/// Provider daftar semua jasa (termasuk nonaktif) untuk manajemen
final allServicesProvider = FutureProvider<List<Service>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getAllServices(activeOnly: false);
});

/// Provider pencarian jasa
final serviceSearchProvider = StateProvider<String>((ref) => '');

/// Provider filter kategori jasa
final serviceSelectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Provider filtered services (berdasarkan search + category)
final filteredServicesProvider = FutureProvider<List<Service>>((ref) {
  final search = ref.watch(serviceSearchProvider);
  final categoryId = ref.watch(serviceSelectedCategoryProvider);

  return ref.watch(servicesProvider.future).then((allServices) {
    var filtered = allServices;
    
    if (search.isNotEmpty) {
      filtered = filtered.where((s) =>
          s.name.toLowerCase().contains(search.toLowerCase()) ||
          (s.description?.toLowerCase().contains(search.toLowerCase()) ?? false)
      ).toList();
    }
    
    if (categoryId != null) {
      filtered = filtered.where((s) => s.categoryId == categoryId).toList();
    }
    
    return filtered;
  });
});

/// Provider kategori jasa dari database
final serviceCategoriesProvider = FutureProvider<List<ServiceCategory>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getAllServiceCategories();
});
