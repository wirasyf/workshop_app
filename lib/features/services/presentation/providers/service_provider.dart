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
  final db = ref.watch(databaseProvider);
  final search = ref.watch(serviceSearchProvider);
  final category = ref.watch(serviceSelectedCategoryProvider);

  return db.getAllServices().then((allServices) {
    var filtered = allServices;
    
    if (search.isNotEmpty) {
      filtered = filtered.where((s) =>
          s.name.toLowerCase().contains(search.toLowerCase()) ||
          (s.description?.toLowerCase().contains(search.toLowerCase()) ?? false)
      ).toList();
    }
    
    if (category != null) {
      filtered = filtered.where((s) => s.category == category).toList();
    }
    
    return filtered;
  });
});

/// Kategori jasa yang tersedia
class ServiceCategories {
  static const List<Map<String, String>> all = [
    {'value': 'servis_rutin', 'label': 'Servis Rutin'},
    {'value': 'perbaikan', 'label': 'Perbaikan'},
    {'value': 'tune_up', 'label': 'Tune Up'},
    {'value': 'body', 'label': 'Body & Cat'},
    {'value': 'umum', 'label': 'Umum'},
  ];

  static String getLabel(String value) {
    return all.firstWhere(
      (c) => c['value'] == value,
      orElse: () => {'label': value},
    )['label']!;
  }
}
