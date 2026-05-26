import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/product_model.dart';
import '../../../core/models/category_model.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(FirebaseFirestore.instance);
});

class ProductRepository {
  final FirebaseFirestore _firestore;

  ProductRepository(this._firestore);

  Stream<List<ProductModel>> getProducts({bool activeOnly = true}) {
    Query query = _firestore.collection('products');
    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();
    });
  }

  Stream<ProductModel?> getProductById(String id) {
    return _firestore.collection('products').doc(id).snapshots().map((doc) {
      if (doc.exists) return ProductModel.fromFirestore(doc);
      return null;
    });
  }

  Future<void> addProduct(ProductModel product) async {
    await _firestore.collection('products').doc(product.id).set(product.toMap());
  }

  Future<void> updateProduct(ProductModel product) async {
    await _firestore.collection('products').doc(product.id).update(product.toMap());
  }

  Future<void> deleteProduct(String id) async {
    await _firestore.collection('products').doc(id).delete();
  }

  Stream<List<CategoryModel>> getCategories() {
    return _firestore.collection('categories').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> updateStock(String productId, int qtyChange) async {
    final docRef = _firestore.collection('products').doc(productId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Product not found');
      
      final currentStock = snapshot.data()?['stockQty'] ?? 0;
      transaction.update(docRef, {
        'stockQty': currentStock + qtyChange,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
