import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'connectivity_service.dart';
import 'supabase_service.dart';

/// Provider untuk sync service
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncService(db);
});

/// Provider untuk database
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'databaseProvider harus di-override di ProviderScope',
  );
});

/// Service sinkronisasi offline-first
/// Mengirim perubahan lokal ke Supabase saat online
class SyncService {
  final AppDatabase _db;
  Timer? _syncTimer;

  SyncService(this._db);

  /// Mulai periodic sync setiap 30 detik
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => syncPendingChanges(),
    );
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Tambah entry ke antrian sync
  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    await _db.addToSyncQueue(
      SyncQueueCompanion.insert(
        syncTableName: tableName,
        recordId: recordId,
        operation: operation,
        data: jsonEncode(data),
      ),
    );
  }

  /// Proses semua pending sync items
  Future<void> syncPendingChanges() async {
    final isOnline = await ConnectivityService.isOnline();
    if (!isOnline) return;

    // final session = SupabaseService.client.auth.currentSession;
    // if (session == null) return; // Harus login untuk sync

    final pendingItems = await _db.getPendingSyncItems();
    if (pendingItems.isEmpty) return;

    final client = SupabaseService.client;

    for (final item in pendingItems) {
      if (item.retryCount >= 5) continue; // Skip jika sudah gagal 5 kali

      try {
        final data = jsonDecode(item.data) as Map<String, dynamic>;

        switch (item.operation) {
          case 'create':
            await client.from(item.syncTableName).upsert(data); // Gunakan upsert agar lebih aman
            break;
          case 'update':
            await client
                .from(item.syncTableName)
                .update(data)
                .eq('id', item.recordId);
            break;
          case 'delete':
            await client
                .from(item.syncTableName)
                .delete()
                .eq('id', item.recordId);
            break;
        }

        await _db.markSynced(item.id);
      } catch (e) {
        debugPrint('Sync failed for item ${item.id} (${item.syncTableName}): $e');
        await _db.markSyncFailed(item.id, e.toString());
      }
    }
  }

  /// Ambil data dari server (untuk login di HP baru)
  Future<void> downloadUserData() async {
    final isOnline = await ConnectivityService.isOnline();
    if (!isOnline) return;

    // final session = SupabaseService.client.auth.currentSession;
    // if (session == null) return;

    final client = SupabaseService.client;

    try {
      await _db.batch((batch) async {
        // 1. Download Categories
        final catData = await client.from('categories').select();
        for (final row in catData) {
          batch.insert(_db.categories, CategoriesCompanion.insert(
            id: row['id'],
            name: row['name'],
            slug: row['slug'],
            parentId: Value(row['parent_id']),
          ), mode: InsertMode.insertOrReplace);
        }

        // 2. Download Products
        final prodData = await client.from('products').select();
        for (final row in prodData) {
          batch.insert(_db.products, ProductsCompanion.insert(
            id: row['id'],
            name: row['name'],
            sku: Value(row['sku']),
            barcode: Value(row['barcode']),
            categoryId: Value(row['category_id']),
            brand: Value(row['brand']),
            motorType: Value(row['motor_type']),
            stockQty: Value(row['stock_qty'] ?? 0),
            stockMin: Value(row['stock_min'] ?? 5),
            costPrice: Value((row['cost_price'] as num?)?.toDouble() ?? 0.0),
            sellPrice: Value((row['sell_price'] as num?)?.toDouble() ?? 0.0),
            unit: Value(row['unit'] ?? 'pcs'),
            imageUrl: Value(row['image_url']),
            isActive: Value(row['is_active'] ?? true),
          ), mode: InsertMode.insertOrReplace);
        }

        // 3. Download Transactions
        final txnData = await client.from('transactions').select();
        for (final row in txnData) {
          batch.insert(_db.transactions, TransactionsCompanion.insert(
            id: row['id'],
            invoiceNo: row['invoice_no'],
            userId: row['user_id'],
            paymentMethod: Value(row['payment_method'] ?? 'cash'),
            subtotal: Value((row['subtotal'] as num?)?.toDouble() ?? 0.0),
            discount: Value((row['discount'] as num?)?.toDouble() ?? 0.0),
            total: Value((row['total'] as num?)?.toDouble() ?? 0.0),
            paidAmount: Value((row['paid_amount'] as num?)?.toDouble() ?? 0.0),
            changeAmount: Value((row['change_amount'] as num?)?.toDouble() ?? 0.0),
            status: Value(row['status'] ?? 'completed'),
            createdAt: Value(DateTime.parse(row['created_at'])),
          ), mode: InsertMode.insertOrReplace);
        }

        // 4. Download Transaction Items
        final itemData = await client.from('transaction_items').select();
        for (final row in itemData) {
          batch.insert(_db.transactionItems, TransactionItemsCompanion.insert(
            id: row['id'],
            transactionId: row['transaction_id'],
            productId: row['product_id'],
            qty: row['qty'],
            unitPrice: (row['unit_price'] as num).toDouble(),
            discount: Value((row['discount'] as num?)?.toDouble() ?? 0.0),
            subtotal: (row['subtotal'] as num).toDouble(),
          ), mode: InsertMode.insertOrReplace);
        }
      });
      debugPrint('Download user data completed');
    } catch (e) {
      debugPrint('Error downloading user data: $e');
    }
  }
}
