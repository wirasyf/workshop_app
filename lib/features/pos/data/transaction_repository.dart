import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/transaction_model.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(FirebaseFirestore.instance);
});

class TransactionRepository {
  final FirebaseFirestore _firestore;

  TransactionRepository(this._firestore);

  Stream<List<TransactionModel>> getRecentTransactions(int limit) {
    return _firestore
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();
    });
  }

  Stream<List<TransactionModel>> getTodayTransactionsStream() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return _firestore
        .collection('transactions')
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> saveTransaction(TransactionModel transaction, List<TransactionItemModel> items) async {
    await _firestore.runTransaction((tx) async {
      // 1. Read all required products first (Firestore requirement: reads before writes)
      final productDocs = <String, DocumentSnapshot>{};
      for (final item in items) {
        if (item.itemType == 'product' && item.productId != null) {
          final productRef = _firestore.collection('products').doc(item.productId);
          final doc = await tx.get(productRef);
          if (!doc.exists) {
            throw Exception('Produk ${item.productName ?? 'Unknown'} tidak ditemukan');
          }
          productDocs[item.productId!] = doc;
        }
      }

      // 2. Validate stock and prepare updates
      for (final item in items) {
        if (item.itemType == 'product' && item.productId != null) {
          final doc = productDocs[item.productId!]!;
          final data = doc.data() as Map<String, dynamic>;
          final currentStock = (data['stockQty'] as num?)?.toInt() ?? 0;
          
          if (currentStock < item.qty) {
            throw Exception('Stok tidak cukup untuk ${item.productName ?? 'Unknown'}. Sisa: $currentStock');
          }
          
          tx.update(doc.reference, {
            'stockQty': currentStock - item.qty,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // 3. Save transaction & items
      final txRef = _firestore.collection('transactions').doc(transaction.id);
      tx.set(txRef, transaction.toMap());
      
      for (final item in items) {
        final itemRef = _firestore.collection('transaction_items').doc(item.id);
        tx.set(itemRef, item.toMap());
      }
    });
  }

  Future<List<TransactionItemModel>> getTransactionItems(String transactionId) async {
    final snapshot = await _firestore
        .collection('transaction_items')
        .where('transactionId', isEqualTo: transactionId)
        .get();
        
    return snapshot.docs.map((doc) => TransactionItemModel.fromFirestore(doc)).toList();
  }

  Future<double> getTotalSales(DateTime start, DateTime end) async {
    final snapshot = await _firestore
        .collection('transactions')
        .where('status', isEqualTo: 'completed')
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .get();
        
    double total = 0;
    for (final doc in snapshot.docs) {
      total += (doc.data()['total'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  Future<List<TransactionModel>> getTransactionsByDateRange(DateTime start, DateTime end) async {
    final snapshot = await _firestore
        .collection('transactions')
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .orderBy('createdAt', descending: true)
        .get();
        
    return snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();
  }

  Stream<List<TransactionModel>> getTransactionsByDateRangeStream(DateTime start, DateTime end) {
    return _firestore
        .collection('transactions')
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> returnTransactionItem(String transactionId, TransactionItemModel item) async {
    final batch = _firestore.batch();
    
    // Mark item as returned
    final itemRef = _firestore.collection('transaction_items').doc(item.id);
    batch.update(itemRef, {'isReturned': true});
    
    // If it's a product, restore stock
    if (item.itemType == 'product' && item.productId != null) {
      final productRef = _firestore.collection('products').doc(item.productId);
      batch.update(productRef, {
        'stockQty': FieldValue.increment(item.qty),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
  }
  Future<void> returnTransaction(String transactionId, List<TransactionItemModel> items) async {
    final batch = _firestore.batch();
    
    // Mark transaction as returned
    final txRef = _firestore.collection('transactions').doc(transactionId);
    batch.update(txRef, {'status': 'returned'});
    
    // Process all items
    for (final item in items) {
      if (!item.isReturned) {
        // Mark item as returned
        final itemRef = _firestore.collection('transaction_items').doc(item.id);
        batch.update(itemRef, {'isReturned': true});
        
        // If it's a product, restore stock
        if (item.itemType == 'product' && item.productId != null) {
          final productRef = _firestore.collection('products').doc(item.productId);
          batch.update(productRef, {
            'stockQty': FieldValue.increment(item.qty),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }
    
    await batch.commit();
  }
}
