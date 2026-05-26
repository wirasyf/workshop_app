import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/vehicle_model.dart';
import '../../../../core/models/work_order_model.dart';
import '../../data/workshop_repository.dart';

final vehiclesProvider = StreamProvider<List<VehicleModel>>((ref) {
  final repo = ref.watch(workshopRepositoryProvider);
  return repo.getVehicles();
});

final workOrdersProvider = StreamProvider<List<WorkOrderModel>>((ref) {
  final repo = ref.watch(workshopRepositoryProvider);
  return repo.getWorkOrders();
});

final activeWorkOrdersProvider = StreamProvider<List<WorkOrderModel>>((ref) {
  final repo = ref.watch(workshopRepositoryProvider);
  return repo.getActiveWorkOrders();
});

final todayWorkOrdersProvider = StreamProvider<List<WorkOrderModel>>((ref) {
  final repo = ref.watch(workshopRepositoryProvider);
  return repo.getWorkOrders().map((orders) {
    final now = DateTime.now();
    return orders.where((w) => 
      w.createdAt.year == now.year && 
      w.createdAt.month == now.month && 
      w.createdAt.day == now.day
    ).toList();
  });
});

final workOrdersByStatusProvider = StreamProvider.family<List<WorkOrderModel>, String?>((ref, status) {
  final repo = ref.watch(workshopRepositoryProvider);
  return repo.getWorkOrders().map((orders) {
    if (status == null) return orders;
    return orders.where((w) => w.status == status).toList();
  });
});

final workOrderDetailProvider = StreamProvider.family<WorkOrderModel?, String>((ref, id) {
  final repo = ref.watch(workshopRepositoryProvider);
  return repo.getWorkOrders().map((orders) {
    try {
      return orders.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  });
});

final vehicleDetailProvider = StreamProvider.family<VehicleModel?, String>((ref, id) {
  final repo = ref.watch(workshopRepositoryProvider);
  return repo.getVehicles().map((vehicles) {
    try {
      return vehicles.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  });
});

final vehicleSearchProvider = StateProvider<String>((ref) => '');

final filteredVehiclesProvider = StreamProvider<List<VehicleModel>>((ref) {
  final search = ref.watch(vehicleSearchProvider);
  final repo = ref.watch(workshopRepositoryProvider);
  
  return repo.getVehicles().map((vehicles) {
    if (search.isEmpty) return vehicles;
    final query = search.toLowerCase();
    return vehicles.where((v) => 
      v.customerName.toLowerCase().contains(query) ||
      v.plateNumber.toLowerCase().contains(query) ||
      (v.phoneNumber?.contains(query) ?? false) ||
      (v.vehicleBrand?.toLowerCase().contains(query) ?? false)
    ).toList();
  });
});

final workOrderStatusFilterProvider = StateProvider<String?>((ref) => null);

class WorkOrderStatus {
  static const String waiting = 'waiting';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String paid = 'paid';
  static const String cancelled = 'cancelled';

  static const List<Map<String, String>> all = [
    {'value': 'waiting', 'label': 'Menunggu'},
    {'value': 'in_progress', 'label': 'Dikerjakan'},
    {'value': 'completed', 'label': 'Selesai'},
    {'value': 'paid', 'label': 'Dibayar'},
    {'value': 'cancelled', 'label': 'Dibatalkan'},
  ];

  static String getLabel(String value) {
    return all.firstWhere(
      (s) => s['value'] == value,
      orElse: () => {'label': value},
    )['label']!;
  }
}
