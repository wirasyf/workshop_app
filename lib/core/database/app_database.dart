import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../constants/app_constants.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Users, Categories, Products, Suppliers, ProductSuppliers, Customers,
  Transactions, TransactionItems, PurchaseOrders, PoItems,
  StockAdjustments, Returns, ReturnItems, SyncQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: AppConstants.dbName);
  }

  // ── Users ──
  Future<List<User>> getAllUsers() => select(users).get();
  Future<User?> getUserByEmail(String email) =>
      (select(users)..where((u) => u.email.equals(email))).getSingleOrNull();
  Future<User?> getUserByUsername(String username) =>
      (select(users)..where((u) => u.username.equals(username))).getSingleOrNull();
  Future<User?> getUserById(int id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();
  Future<int> insertUser(UsersCompanion user) => into(users).insert(user);

  // ── Categories ──
  Future<List<Category>> getAllCategories() => select(categories).get();
  Future<int> insertCategory(CategoriesCompanion c) => into(categories).insert(c);
  Future<bool> updateCategory(CategoriesCompanion c) =>
      update(categories).replace(c);
  Future<int> deleteCategory(int id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  // ── Products ──
  Future<List<Product>> getAllProducts({bool activeOnly = true}) {
    final q = select(products);
    if (activeOnly) q.where((p) => p.isActive.equals(true));
    return q.get();
  }
  Future<Product?> getProductById(int id) =>
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
  Future<List<Product>> getProductsByCategory(int catId) =>
      (select(products)..where((p) => p.categoryId.equals(catId))).get();

  /// Produk dengan stok <= stok minimum
  Future<List<Product>> getLowStockProducts() {
    return (select(products)
      ..where((p) => p.isActive.equals(true) &
          p.stockQty.isSmallerOrEqual(p.stockMin)))
        .get();
  }

  Future<int> insertProduct(ProductsCompanion p) => into(products).insert(p);
  Future<bool> updateProduct(ProductsCompanion p) =>
      (update(products)..where((t) => t.id.equals(p.id.value))).write(p).then((r) => r > 0);
  Future<void> updateStock(int productId, int qtyChange) async {
    final p = await (select(products)..where((t) => t.id.equals(productId))).getSingle();
    await update(products).replace(p.copyWith(
      stockQty: p.stockQty + qtyChange,
      updatedAt: Value(DateTime.now()),
    ));
  }
  Future<int> deleteProduct(int id) =>
      (delete(products)..where((p) => p.id.equals(id))).go();

  // ── Transactions ──
  Future<int> insertTransaction(TransactionsCompanion t) => into(transactions).insert(t);
  Future<int> insertTransactionItem(TransactionItemsCompanion i) => into(transactionItems).insert(i);
  Future<List<Transaction>> getTransactionsByDate(DateTime start, DateTime end) =>
      (select(transactions)
        ..where((t) => t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerOrEqualValue(end))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  Future<List<Transaction>> getTransactionsByCashier(int cashierId, DateTime start, DateTime end) =>
      (select(transactions)
        ..where((t) => t.cashierId.equals(cashierId) &
            t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerOrEqualValue(end))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  Future<List<TransactionItem>> getTransactionItems(int txnId) =>
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
      'id': r.read<int>('id'), 'name': r.read<String>('name'),
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
  Future<int> insertStockAdjustment(StockAdjustmentsCompanion a) => into(stockAdjustments).insert(a);
  Future<List<StockAdjustment>> getStockAdjustments(int productId) =>
      (select(stockAdjustments)..where((a) => a.productId.equals(productId))
        ..orderBy([(a) => OrderingTerm.desc(a.createdAt)])).get();

  // ── Suppliers & Customers ──
  Future<List<Supplier>> getAllSuppliers() => select(suppliers).get();
  Future<int> insertSupplier(SuppliersCompanion s) => into(suppliers).insert(s);
  Future<List<Customer>> getAllCustomers() => select(customers).get();
  Future<int> insertCustomer(CustomersCompanion c) => into(customers).insert(c);

  // ── Sync Queue ──
  Future<int> addToSyncQueue(SyncQueueCompanion e) => into(syncQueue).insert(e);
  Future<List<SyncQueueData>> getPendingSyncItems() =>
      (select(syncQueue)..where((s) => s.synced.equals(false))
        ..orderBy([(s) => OrderingTerm.asc(s.createdAt)])).get();
  Future<void> markSynced(int id) =>
      (update(syncQueue)..where((s) => s.id.equals(id)))
          .write(const SyncQueueCompanion(synced: Value(true)));

  /// Hapus semua data (untuk reset aplikasi)
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(syncQueue).go();
      await delete(transactionItems).go();
      await delete(transactions).go();
      await delete(stockAdjustments).go();
      await delete(productSuppliers).go();
      await delete(poItems).go();
      await delete(purchaseOrders).go();
      await delete(returnItems).go();
      await delete(returns).go();
      await delete(products).go();
      await delete(categories).go();
      await delete(suppliers).go();
      await delete(customers).go();
      await delete(users).go();
    });
  }
}
