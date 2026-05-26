import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/service_model.dart';
import '../../../core/models/category_model.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return ServiceRepository(FirebaseFirestore.instance);
});

class ServiceRepository {
  final FirebaseFirestore _firestore;

  ServiceRepository(this._firestore);

  Stream<List<ServiceModel>> getServices({bool activeOnly = true}) {
    Query query = _firestore.collection('services');
    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ServiceModel.fromFirestore(doc)).toList();
    });
  }

  Stream<ServiceModel?> getServiceById(String id) {
    return _firestore.collection('services').doc(id).snapshots().map((doc) {
      if (doc.exists) return ServiceModel.fromFirestore(doc);
      return null;
    });
  }

  Stream<List<ServiceCategoryModel>> getServiceCategories() {
    return _firestore.collection('service_categories').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ServiceCategoryModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> addService(ServiceModel service) async {
    await _firestore.collection('services').doc(service.id).set(service.toMap());
  }

  Future<void> updateService(ServiceModel service) async {
    await _firestore.collection('services').doc(service.id).update(service.toMap());
  }

  Future<void> deleteService(String id) async {
    await _firestore.collection('services').doc(id).delete();
  }
}
