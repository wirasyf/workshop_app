import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';

/// Provider daftar semua kendaraan
final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getAllVehicles();
});

/// Provider semua work orders
final workOrdersProvider = FutureProvider<List<WorkOrder>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getAllWorkOrders();
});

/// Provider work orders aktif (waiting + in_progress)
final activeWorkOrdersProvider = FutureProvider<List<WorkOrder>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getActiveWorkOrders();
});

/// Provider work orders hari ini
final todayWorkOrdersProvider = FutureProvider<List<WorkOrder>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getTodayWorkOrders();
});

/// Provider work orders berdasarkan status
final workOrdersByStatusProvider = FutureProvider.family<List<WorkOrder>, String?>((ref, status) {
  final db = ref.watch(databaseProvider);
  if (status == null) return db.getAllWorkOrders();
  return db.getWorkOrdersByStatus(status);
});

/// Provider work order detail by ID
final workOrderDetailProvider = FutureProvider.family<WorkOrder?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.getWorkOrderById(id);
});

/// Provider vehicle by ID
final vehicleDetailProvider = FutureProvider.family<Vehicle?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.getVehicleById(id);
});

/// Provider search kendaraan
final vehicleSearchProvider = StateProvider<String>((ref) => '');

/// Provider filtered vehicles
final filteredVehiclesProvider = FutureProvider<List<Vehicle>>((ref) {
  final db = ref.watch(databaseProvider);
  final search = ref.watch(vehicleSearchProvider);
  if (search.isEmpty) return db.getAllVehicles();
  return db.searchVehicles(search);
});

/// Provider filter status work order
final workOrderStatusFilterProvider = StateProvider<String?>((ref) => null);

/// Status work order constants
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
