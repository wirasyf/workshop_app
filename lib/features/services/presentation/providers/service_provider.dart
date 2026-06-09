import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/service_model.dart';
import '../../../../core/models/category_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/service_repository.dart';

final servicesProvider = StreamProvider<List<ServiceModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.isLoading) return const Stream.empty();
  if (authState.value == null) return Stream.value([]);
  final repo = ref.watch(serviceRepositoryProvider);
  return repo.getServices();
});

final allServicesProvider = StreamProvider<List<ServiceModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.isLoading) return const Stream.empty();
  if (authState.value == null) return Stream.value([]);
  final repo = ref.watch(serviceRepositoryProvider);
  return repo.getServices(activeOnly: false);
});

final serviceSearchProvider = StateProvider<String>((ref) => '');

final serviceSelectedCategoryProvider = StateProvider<String?>((ref) => null);

final filteredServicesProvider = Provider<AsyncValue<List<ServiceModel>>>((ref) {
  final search = ref.watch(serviceSearchProvider);
  final categoryId = ref.watch(serviceSelectedCategoryProvider);
  final servicesAsync = ref.watch(servicesProvider);

  return servicesAsync.whenData((allServices) {
    var filtered = allServices.toList();
    
    if (search.isNotEmpty) {
      final query = search.toLowerCase();
      filtered = filtered.where((s) =>
          s.name.toLowerCase().contains(query) ||
          (s.description?.toLowerCase().contains(query) ?? false)
      ).toList();
    }
    
    if (categoryId != null) {
      filtered = filtered.where((s) => s.categoryId == categoryId).toList();
    }
    
    return filtered;
  });
});

final serviceCategoriesProvider = StreamProvider<List<ServiceCategoryModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.isLoading) return const Stream.empty();
  if (authState.value == null) return Stream.value([]);
  final repo = ref.watch(serviceRepositoryProvider);
  return repo.getServiceCategories();
});
