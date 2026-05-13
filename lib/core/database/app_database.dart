import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../constants/app_constants.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Users, Categories, Products,
  Transactions, TransactionItems,
  StockAdjustments, SyncQueue, Notifications,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          // Tambahkan kolom baru ke tabel yang sudah ada
          await m.addColumn(users, users.avatarUrl);
          await m.addColumn(products, products.sellPriceWholesale);
          await m.addColumn(products, products.updatedAt);
        }
        if (from < 3) {
          await m.createTable(notifications);
        }
        if (from < 4) {
          // PERINGATAN: Perubahan PK dari Int ke String memerlukan penghapusan data 
          // karena SQLite tidak mendukung penggantian PK secara langsung.
          // Untuk pengembangan, kita asumsikan database di-reset atau tabel dibuat ulang.
        }
      },
      beforeOpen: (details) async {
        // Optional: Logika tambahan sebelum database dibuka
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: AppConstants.dbName);
  }

  // ── Users ──
  Future<List<User>> getAllUsers() => select(users).get();
  Future<User?> getUserByEmail(String email) =>
      (select(users)..where((u) => u.email.equals(email))).getSingleOrNull();
  Future<User?> getUserByUsername(String username) =>
      (select(users)..where((u) => u.username.equals(username))).getSingleOrNull();
  Future<User?> getUserById(String id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();
  Future<String> insertUser(UsersCompanion user) => into(users).insert(user).then((_) => user.id.value);

  // ── Categories ──
  Future<List<Category>> getAllCategories() => select(categories).get();
  Future<String> insertCategory(CategoriesCompanion c) => into(categories).insert(c).then((_) => c.id.value);
  Future<bool> updateCategory(CategoriesCompanion c) =>
      update(categories).replace(c);
  Future<int> deleteCategory(String id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  // ── Products ──
  Future<List<Product>> getAllProducts({bool activeOnly = true}) {
    final q = select(products);
    if (activeOnly) q.where((p) => p.isActive.equals(true));
    return q.get();
  }
  Future<Product?> getProductById(String id) =>
      (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();
  Future<Product?> getProductByBarcode(String barcode) =>
      (select(products)..where((p) => p.barcode.equals(barcode))).getSingleOrNull();
  Future<List<Product>> searchProducts(String query) =>
      (select(products)..where((p) =>
          p.name.like('%$query%') | 
          p.sku.like('%$query%') |
          p.barcode.like('%$query%') | 
          p.brand.like('%$query%') |
          p.motorType.like('%$query%'))).get();
  Future<List<Product>> getProductsByCategory(String catId) =>
      (select(products)..where((p) => p.categoryId.equals(catId))).get();

  /// Produk dengan stok <= stok minimum
  Future<List<Product>> getLowStockProducts() {
    return (select(products)
      ..where((p) => p.isActive.equals(true) &
          p.stockQty.isSmallerOrEqual(p.stockMin)))
        .get();
  }

  Future<String> insertProduct(ProductsCompanion p) => into(products).insert(p).then((_) => p.id.value);
  Future<bool> updateProduct(ProductsCompanion p) =>
      (update(products)..where((t) => t.id.equals(p.id.value))).write(p).then((r) => r > 0);
  Future<void> updateStock(String productId, int qtyChange) async {
    final p = await (select(products)..where((t) => t.id.equals(productId))).getSingle();
    await update(products).replace(p.copyWith(
      stockQty: p.stockQty + qtyChange,
      updatedAt: Value(DateTime.now()),
    ));
  }
  Future<int> deleteProduct(String id) =>
      (delete(products)..where((p) => p.id.equals(id))).go();

  // ── Transactions ──
  Future<String> insertTransaction(TransactionsCompanion t) => into(transactions).insert(t).then((_) => t.id.value);
  Future<String> insertTransactionItem(TransactionItemsCompanion i) => into(transactionItems).insert(i).then((_) => i.id.value);
  Future<List<Transaction>> getTransactionsByDate(DateTime start, DateTime end) =>
      (select(transactions)
        ..where((t) => t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerOrEqualValue(end))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  Future<List<Transaction>> getTransactionsByUser(String userId, DateTime start, DateTime end) =>
      (select(transactions)
        ..where((t) => t.userId.equals(userId) &
            t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerOrEqualValue(end))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  Future<List<TransactionItem>> getTransactionItems(String txnId) =>
      (select(transactionItems)..where((i) => i.transactionId.equals(txnId))).get();

  /// Total omzet
  Future<double> getTotalSales(DateTime start, DateTime end) async {
    final r = await customSelect(
      'SELECT COALESCE(SUM(total), 0.0) as total FROM transactions WHERE created_at>=? AND created_at<=? AND status=?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end), Variable.withString('completed')],
      readsFrom: {transactions},
    ).getSingle();
    return r.read<double>('total');
  }

  Future<int> getTransactionCount(DateTime start, DateTime end) async {
    final r = await customSelect(
      'SELECT COUNT(*) as cnt FROM transactions WHERE created_at>=? AND created_at<=? AND status=?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end), Variable.withString('completed')],
      readsFrom: {transactions},
    ).getSingle();
    return r.read<int>('cnt');
  }

  /// Produk terlaris
  Future<List<Map<String, dynamic>>> getTopProducts(DateTime start, DateTime end, {int limit = 10}) async {
    final rows = await customSelect(
      'SELECT p.id,p.name,p.image_url,SUM(ti.qty) as total_qty,SUM(ti.subtotal) as total_revenue '
      'FROM transaction_items ti JOIN products p ON p.id=ti.product_id '
      'JOIN transactions t ON t.id=ti.transaction_id '
      'WHERE t.created_at>=? AND t.created_at<=? AND t.status=\'completed\' '
      'GROUP BY p.id ORDER BY total_qty DESC LIMIT ?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end), Variable.withInt(limit)],
      readsFrom: {transactionItems, products, transactions},
    ).get();
    return rows.map((r) => {
      'id': r.read<String>('id'), 'name': r.read<String>('name'),
      'imageUrl': r.readNullable<String>('image_url'),
      'totalQty': r.read<int>('total_qty'), 'totalRevenue': r.read<double>('total_revenue'),
    }).toList();
  }

  /// Penjualan harian (chart)
  Future<List<Map<String, dynamic>>> getDailySales(int days) async {
    final rows = await customSelect(
      'SELECT DATE(created_at, \'unixepoch\', \'localtime\') as sale_date,COALESCE(SUM(total),0.0) as daily_total,COUNT(*) as txn_count '
      'FROM transactions WHERE created_at>=? AND status=\'completed\' '
      'GROUP BY DATE(created_at, \'unixepoch\', \'localtime\') ORDER BY sale_date ASC',
      variables: [Variable.withDateTime(DateTime.now().subtract(Duration(days: days)))],
      readsFrom: {transactions},
    ).get();
    return rows.map((r) => {
      'date': r.readNullable<String>('sale_date') ?? '',
      'total': r.read<double>('daily_total'), 
      'count': r.read<int>('txn_count'),
    }).toList();
  }

  // ── Stock Adjustments ──
  Future<String> insertStockAdjustment(StockAdjustmentsCompanion a) => into(stockAdjustments).insert(a).then((_) => a.id.value);
  Future<List<StockAdjustment>> getStockAdjustments(String productId) =>
      (select(stockAdjustments)..where((a) => a.productId.equals(productId))
        ..orderBy([(a) => OrderingTerm.desc(a.createdAt)])).get();


  // ── Sync Queue ──
  Future<int> addToSyncQueue(SyncQueueCompanion e) => into(syncQueue).insert(e);
  Future<List<SyncQueueData>> getPendingSyncItems() =>
      (select(syncQueue)..where((s) => s.synced.equals(false))
        ..orderBy([(s) => OrderingTerm.asc(s.createdAt)])).get();
  Future<void> markSynced(int id) =>
      (update(syncQueue)..where((s) => s.id.equals(id)))
          .write(const SyncQueueCompanion(synced: Value(true)));

  Future<void> markSyncFailed(int id, String error) async {
    final item = await (select(syncQueue)..where((s) => s.id.equals(id))).getSingle();
    await (update(syncQueue)..where((s) => s.id.equals(id)))
        .write(SyncQueueCompanion(
          retryCount: Value(item.retryCount + 1),
          lastError: Value(error),
        ));
  }

  // ── Notifications ──
  Future<List<Notification>> getAllNotifications() => 
      (select(notifications)..orderBy([(n) => OrderingTerm.desc(n.createdAt)])).get();
  Future<int> insertNotification(NotificationsCompanion n) => into(notifications).insert(n);
  Future<void> markNotificationRead(int id) =>
      (update(notifications)..where((n) => n.id.equals(id)))
          .write(const NotificationsCompanion(isRead: Value(true)));
  Future<void> deleteAllNotifications() => delete(notifications).go();
  Future<void> deleteNotification(int id) =>
      (delete(notifications)..where((n) => n.id.equals(id))).go();

  /// Hapus semua data (untuk reset aplikasi)
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(notifications).go();
      await delete(syncQueue).go();
      await delete(transactionItems).go();
      await delete(transactions).go();
      await delete(stockAdjustments).go();
      await delete(products).go();
      await delete(categories).go();
      await delete(users).go();
    });
  }
}
