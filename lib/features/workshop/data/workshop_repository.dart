import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/work_order_model.dart';
import '../../../core/models/vehicle_model.dart';

final workshopRepositoryProvider = Provider<WorkshopRepository>((ref) {
  return WorkshopRepository(FirebaseFirestore.instance);
});

class WorkshopRepository {
  final FirebaseFirestore _firestore;

  WorkshopRepository(this._firestore);

  Stream<List<WorkOrderModel>> getWorkOrders() {
    return _firestore
        .collection('work_orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => WorkOrderModel.fromFirestore(doc)).toList();
    });
  }

  Stream<WorkOrderModel?> getWorkOrderById(String id) {
    return _firestore
        .collection('work_orders')
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? WorkOrderModel.fromFirestore(doc) : null);
  }

  Stream<List<WorkOrderModel>> getActiveWorkOrders() {
    return _firestore
        .collection('work_orders')
        .where('status', whereIn: ['waiting', 'in_progress'])
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => WorkOrderModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> addWorkOrder(WorkOrderModel workOrder) async {
    await _firestore.collection('work_orders').doc(workOrder.id).set(workOrder.toMap());
  }

  Future<void> updateWorkOrder(WorkOrderModel workOrder) async {
    await _firestore.collection('work_orders').doc(workOrder.id).update(workOrder.toMap());
  }

  Future<void> updateWorkOrderStatus(String id, String status) async {
    await _firestore.collection('work_orders').doc(id).update({
      'status': status,
      if (status == 'completed') 'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<VehicleModel>> getVehicles() {
    return _firestore
        .collection('vehicles')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => VehicleModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> addVehicle(VehicleModel vehicle) async {
    await _firestore.collection('vehicles').doc(vehicle.id).set(vehicle.toMap());
  }
}
