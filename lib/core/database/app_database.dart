import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../constants/app_constants.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Categories,
    Products,
    Services,
    Vehicles,
    Transactions,
    TransactionItems,
    WorkOrders,
    StockAdjustments,
    SyncQueue,
    Notifications,
    ServiceCategories,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 9;

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
        }
        if (from < 5) {
          // Tabel baru untuk bengkel
          await m.createTable(services);
          await m.createTable(vehicles);
          await m.createTable(workOrders);
          // Kolom baru di transactions
          await m.addColumn(transactions, transactions.customerName);

          // ── Recreate transaction_items ──
          // SQLite tidak bisa ALTER COLUMN untuk mengubah NOT NULL → nullable
          // Solusi: buat tabel baru, copy data, drop lama, rename baru
          await customStatement('''
            CREATE TABLE transaction_items_new (
              id TEXT NOT NULL PRIMARY KEY,
              transaction_id TEXT NOT NULL REFERENCES transactions(id),
              item_type TEXT NOT NULL DEFAULT 'product',
              product_id TEXT REFERENCES products(id),
              service_id TEXT REFERENCES services(id),
              qty INTEGER NOT NULL,
              unit_price REAL NOT NULL,
              discount REAL NOT NULL DEFAULT 0.0,
              subtotal REAL NOT NULL
            )
          ''');
          await customStatement('''
            INSERT INTO transaction_items_new (id, transaction_id, item_type, product_id, qty, unit_price, discount, subtotal)
            SELECT id, transaction_id, 'product', product_id, qty, unit_price, discount, subtotal
            FROM transaction_items
          ''');
          await customStatement('DROP TABLE transaction_items');
          await customStatement(
            'ALTER TABLE transaction_items_new RENAME TO transaction_items',
          );
        }
        if (from == 5) {
          // Fix untuk device yang sudah migrasi ke v5 tapi product_id masih NOT NULL
          // Recreate transaction_items dengan product_id nullable
          await customStatement('''
            CREATE TABLE IF NOT EXISTS transaction_items_new (
              id TEXT NOT NULL PRIMARY KEY,
              transaction_id TEXT NOT NULL REFERENCES transactions(id),
              item_type TEXT NOT NULL DEFAULT 'product',
              product_id TEXT REFERENCES products(id),
              service_id TEXT REFERENCES services(id),
              qty INTEGER NOT NULL,
              unit_price REAL NOT NULL,
              discount REAL NOT NULL DEFAULT 0.0,
              subtotal REAL NOT NULL
            )
          ''');
          await customStatement('''
            INSERT INTO transaction_items_new (id, transaction_id, item_type, product_id, service_id, qty, unit_price, discount, subtotal)
            SELECT id, transaction_id, 
              COALESCE(item_type, 'product'), 
              product_id, 
              service_id, 
              qty, unit_price, 
              COALESCE(discount, 0.0), 
              subtotal
            FROM transaction_items
          ''');
          await customStatement('DROP TABLE transaction_items');
          await customStatement(
            'ALTER TABLE transaction_items_new RENAME TO transaction_items',
          );
        }
        if (from < 7) {
          await m.addColumn(users, users.role);
          await m.addColumn(transactionItems, transactionItems.isApproved);
        }
        if (from < 8) {
          await m.createTable(serviceCategories);
          await m.addColumn(services, services.categoryId);
        }
        if (from < 9) {
          await m.addColumn(transactionItems, transactionItems.workerName);
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

  // ══════════════════════════════════════════════
  // ── Users ──
  // ══════════════════════════════════════════════
  Future<List<User>> getAllUsers() => select(users).get();
  Future<User?> getUserByEmail(String email) =>
      (select(users)..where((u) => u.email.equals(email))).getSingleOrNull();
  Future<User?> getUserByUsername(String username) => (select(
    users,
  )..where((u) => u.username.equals(username))).getSingleOrNull();
  Future<User?> getUserById(String id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();
  Future<List<User>> getUsersByRole(String role) =>
      (select(users)..where((u) => u.role.equals(role))).get();
  Future<List<User>> getStaffUsers() =>
      (select(users)..where((u) => u.role.equals('cashier') | u.role.equals('mechanic'))).get();
  Future<List<User>> getMechanicUsers() =>
      (select(users)..where((u) => u.role.equals('mechanic'))).get();
  Future<String> insertUser(UsersCompanion user) =>
      into(users).insert(user).then((_) => user.id.value);
  Future<bool> updateUser(UsersCompanion user) =>
      update(users).replace(user);
  Future<void> deleteUser(String id) =>
      (delete(users)..where((u) => u.id.equals(id))).go();

  // ══════════════════════════════════════════════
  // ── Categories ──
  // ══════════════════════════════════════════════
  Future<List<Category>> getAllCategories() => select(categories).get();
  Future<String> insertCategory(CategoriesCompanion c) =>
      into(categories).insert(c).then((_) => c.id.value);
  Future<bool> updateCategory(CategoriesCompanion c) =>
      update(categories).replace(c);
  Future<int> deleteCategory(String id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  // ══════════════════════════════════════════════
  // ── Products ──
  // ══════════════════════════════════════════════
  Future<List<Product>> getAllProducts({bool activeOnly = true}) {
    final q = select(products);
    if (activeOnly) q.where((p) => p.isActive.equals(true));
    return q.get();
  }

  Future<Product?> getProductById(String id) =>
      (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();
  Future<Product?> getProductByBarcode(String barcode) => (select(
    products,
  )..where((p) => p.barcode.equals(barcode))).getSingleOrNull();
  Future<List<Product>> searchProducts(String query) =>
      (select(products)..where(
            (p) =>
                p.name.like('%$query%') |
                p.sku.like('%$query%') |
                p.barcode.like('%$query%') |
                p.brand.like('%$query%') |
                p.motorType.like('%$query%'),
          ))
          .get();
  Future<List<Product>> getProductsByCategory(String catId) =>
      (select(products)..where((p) => p.categoryId.equals(catId))).get();

  /// Produk dengan stok <= stok minimum
  Future<List<Product>> getLowStockProducts() {
    return (select(products)..where(
          (p) =>
              p.isActive.equals(true) & p.stockQty.isSmallerOrEqual(p.stockMin),
        ))
        .get();
  }

  Future<String> insertProduct(ProductsCompanion p) =>
      into(products).insert(p).then((_) => p.id.value);
  Future<bool> updateProduct(ProductsCompanion p) => (update(
    products,
  )..where((t) => t.id.equals(p.id.value))).write(p).then((r) => r > 0);
  Future<void> updateStock(String productId, int qtyChange) async {
    final p = await (select(
      products,
    )..where((t) => t.id.equals(productId))).getSingle();
    await update(products).replace(
      p.copyWith(
        stockQty: p.stockQty + qtyChange,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteProduct(String id) =>
      (delete(products)..where((p) => p.id.equals(id))).go();

  // ══════════════════════════════════════════════
  // ── Services (Jasa Bengkel) ──
  // ══════════════════════════════════════════════
  Future<List<Service>> getAllServices({bool activeOnly = true}) {
    final q = select(services);
    if (activeOnly) q.where((s) => s.isActive.equals(true));
    return q.get();
  }

  Future<Service?> getServiceById(String id) =>
      (select(services)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<List<Service>> searchServices(String query) =>
      (select(services)..where(
            (s) =>
                s.name.like('%$query%') |
                s.description.like('%$query%') |
                s.category.like('%$query%'),
          ))
          .get();

  Future<List<Service>> getServicesByCategory(String category) => (select(
    services,
  )..where((s) => s.category.equals(category) & s.isActive.equals(true))).get();

  // ══════════════════════════════════════════════
  // ── Service Categories ──
  // ══════════════════════════════════════════════
  Future<List<ServiceCategory>> getAllServiceCategories() =>
      select(serviceCategories).get();
  Future<String> insertServiceCategory(ServiceCategoriesCompanion c) =>
      into(serviceCategories).insert(c).then((_) => c.id.value);
  Future<bool> updateServiceCategory(ServiceCategoriesCompanion c) =>
      update(serviceCategories).replace(c);
  Future<int> deleteServiceCategory(String id) =>
      (delete(serviceCategories)..where((c) => c.id.equals(id))).go();

  // ══════════════════════════════════════════════
  // ── Services ──
  // ══════════════════════════════════════════════

  Future<String> insertService(ServicesCompanion s) =>
      into(services).insert(s).then((_) => s.id.value);

  Future<bool> updateService(ServicesCompanion s) => (update(
    services,
  )..where((t) => t.id.equals(s.id.value))).write(s).then((r) => r > 0);

  Future<int> deleteService(String id) =>
      (delete(services)..where((s) => s.id.equals(id))).go();

  // ══════════════════════════════════════════════
  // ── Vehicles (Kendaraan Pelanggan) ──
  // ══════════════════════════════════════════════
  Future<List<Vehicle>> getAllVehicles() => (select(
    vehicles,
  )..orderBy([(v) => OrderingTerm.desc(v.createdAt)])).get();

  Future<Vehicle?> getVehicleById(String id) =>
      (select(vehicles)..where((v) => v.id.equals(id))).getSingleOrNull();

  Future<Vehicle?> getVehicleByPlateNumber(String plateNumber) => (select(
    vehicles,
  )..where((v) => v.plateNumber.equals(plateNumber))).getSingleOrNull();

  Future<List<Vehicle>> searchVehicles(String query) =>
      (select(vehicles)..where(
            (v) =>
                v.customerName.like('%$query%') |
                v.plateNumber.like('%$query%') |
                v.phoneNumber.like('%$query%') |
                v.vehicleBrand.like('%$query%') |
                v.vehicleType.like('%$query%'),
          ))
          .get();

  Future<String> insertVehicle(VehiclesCompanion v) =>
      into(vehicles).insert(v).then((_) => v.id.value);

  Future<bool> updateVehicle(VehiclesCompanion v) => (update(
    vehicles,
  )..where((t) => t.id.equals(v.id.value))).write(v).then((r) => r > 0);

  // ══════════════════════════════════════════════
  // ── Work Orders (Antrian Bengkel) ──
  // ══════════════════════════════════════════════
  Future<List<WorkOrder>> getAllWorkOrders() => (select(
    workOrders,
  )..orderBy([(w) => OrderingTerm.desc(w.createdAt)])).get();

  Future<List<WorkOrder>> getWorkOrdersByStatus(String status) =>
      (select(workOrders)
            ..where((w) => w.status.equals(status))
            ..orderBy([(w) => OrderingTerm.asc(w.createdAt)]))
          .get();

  Future<List<WorkOrder>> getActiveWorkOrders() =>
      (select(workOrders)
            ..where(
              (w) =>
                  w.status.equals('waiting') | w.status.equals('in_progress'),
            )
            ..orderBy([(w) => OrderingTerm.asc(w.createdAt)]))
          .get();

  Future<List<WorkOrder>> getTodayWorkOrders() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return (select(workOrders)
          ..where(
            (w) =>
                w.createdAt.isBiggerOrEqualValue(start) &
                w.createdAt.isSmallerThanValue(end),
          )
          ..orderBy([(w) => OrderingTerm.asc(w.createdAt)]))
        .get();
  }

  Future<WorkOrder?> getWorkOrderById(String id) =>
      (select(workOrders)..where((w) => w.id.equals(id))).getSingleOrNull();

  /// Generate nomor antrian harian: WO-YYYYMMDD-001
  Future<String> getNextOrderNo() async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = 'WO-$dateStr-';

    final result = await customSelect(
      "SELECT COUNT(*) as cnt FROM work_orders WHERE order_no LIKE ?",
      variables: [Variable.withString('$prefix%')],
      readsFrom: {workOrders},
    ).getSingle();

    final count = result.read<int>('cnt') + 1;
    return '$prefix${count.toString().padLeft(3, '0')}';
  }

  Future<String> insertWorkOrder(WorkOrdersCompanion w) =>
      into(workOrders).insert(w).then((_) => w.id.value);

  Future<bool> updateWorkOrder(WorkOrdersCompanion w) => (update(
    workOrders,
  )..where((t) => t.id.equals(w.id.value))).write(w).then((r) => r > 0);

  /// Get work order with vehicle info
  Future<List<TypedResult>> getWorkOrdersWithVehicle({String? statusFilter}) {
    final q = select(
      workOrders,
    ).join([innerJoin(vehicles, vehicles.id.equalsExp(workOrders.vehicleId))]);
    if (statusFilter != null) {
      q.where(workOrders.status.equals(statusFilter));
    }
    q.orderBy([OrderingTerm.desc(workOrders.createdAt)]);
    return q.get();
  }

  // ══════════════════════════════════════════════
  // ── Transactions ──
  // ══════════════════════════════════════════════
  Future<String> insertTransaction(TransactionsCompanion t) =>
      into(transactions).insert(t).then((_) => t.id.value);
  Future<String> insertTransactionItem(TransactionItemsCompanion i) =>
      into(transactionItems).insert(i).then((_) => i.id.value);
  Future<List<Transaction>> getTransactionsByDate(
    DateTime start,
    DateTime end,
  ) =>
      (select(transactions)
            ..where(
              (t) =>
                  t.createdAt.isBiggerOrEqualValue(start) &
                  t.createdAt.isSmallerOrEqualValue(end),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
  Future<List<Transaction>> getTransactionsByUser(
    String userId,
    DateTime start,
    DateTime end,
  ) =>
      (select(transactions)
            ..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.createdAt.isBiggerOrEqualValue(start) &
                  t.createdAt.isSmallerOrEqualValue(end),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
  Future<List<TransactionItem>> getTransactionItems(String txnId) => (select(
    transactionItems,
  )..where((i) => i.transactionId.equals(txnId))).get();

  /// Ambil item transaksi dengan info produk
  Future<List<TypedResult>> getTransactionItemsWithProduct(String txnId) {
    return (select(transactionItems).join([
      leftOuterJoin(
        products,
        products.id.equalsExp(transactionItems.productId),
      ),
      leftOuterJoin(
        services,
        services.id.equalsExp(transactionItems.serviceId),
      ),
    ])..where(transactionItems.transactionId.equals(txnId))).get();
  }

  /// Total omzet
  Future<double> getTotalSales(DateTime start, DateTime end) async {
    final r = await customSelect(
      'SELECT COALESCE(SUM(ti.subtotal), 0.0) as total '
      'FROM transaction_items ti JOIN transactions t ON t.id=ti.transaction_id '
      'WHERE t.created_at>=? AND t.created_at<=? AND t.status=? AND ti.is_approved=1',
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
        Variable.withString('completed'),
      ],
      readsFrom: {transactionItems, transactions},
    ).getSingle();
    return r.read<double>('total');
  }

  Future<int> getTransactionCount(DateTime start, DateTime end) async {
    final r = await customSelect(
      'SELECT COUNT(*) as cnt FROM transactions WHERE created_at>=? AND created_at<=? AND status=?',
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
        Variable.withString('completed'),
      ],
      readsFrom: {transactions},
    ).getSingle();
    return r.read<int>('cnt');
  }

  /// Ambil transaksi berdasarkan ID
  Future<Transaction?> getTransactionById(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Transaksi terbaru
  Future<List<Transaction>> getRecentTransactions(int limit) => (select(transactions)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(limit))
      .get();

  /// Produk terlaris
  Future<List<Map<String, dynamic>>> getTopProducts(
    DateTime start,
    DateTime end, {
    int limit = 10,
  }) async {
    final rows = await customSelect(
      'SELECT p.id,p.name,p.image_url,SUM(ti.qty) as total_qty,SUM(ti.subtotal) as total_revenue '
      'FROM transaction_items ti JOIN products p ON p.id=ti.product_id '
      'JOIN transactions t ON t.id=ti.transaction_id '
      'WHERE t.created_at>=? AND t.created_at<=? AND t.status=\'completed\' '
      'AND ti.item_type=\'product\' '
      'GROUP BY p.id ORDER BY total_qty DESC LIMIT ?',
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
        Variable.withInt(limit),
      ],
      readsFrom: {transactionItems, products, transactions},
    ).get();
    return rows
        .map(
          (r) => {
            'id': r.read<String>('id'),
            'name': r.read<String>('name'),
            'imageUrl': r.readNullable<String>('image_url'),
            'totalQty': r.read<int>('total_qty'),
            'totalRevenue': r.read<double>('total_revenue'),
          },
        )
        .toList();
  }

  /// Penjualan harian (chart)
  Future<List<Map<String, dynamic>>> getDailySales(int days) async {
    final rows = await customSelect(
      'SELECT DATE(t.created_at, \'unixepoch\', \'localtime\') as sale_date, COALESCE(SUM(ti.subtotal), 0.0) as daily_total, COUNT(DISTINCT t.id) as txn_count '
      'FROM transactions t JOIN transaction_items ti ON t.id=ti.transaction_id '
      'WHERE t.created_at>=? AND t.status=\'completed\' AND ti.is_approved=1 '
      'GROUP BY DATE(t.created_at, \'unixepoch\', \'localtime\') ORDER BY sale_date ASC',
      variables: [
        Variable.withDateTime(DateTime.now().subtract(Duration(days: days))),
      ],
      readsFrom: {transactions, transactionItems},
    ).get();
    return rows
        .map(
          (r) => {
            'date': r.readNullable<String>('sale_date') ?? '',
            'total': r.read<double>('daily_total'),
            'count': r.read<int>('txn_count'),
          },
        )
        .toList();
  }

  // ══════════════════════════════════════════════
  // ── Report Queries (Profit & Revenue) ──
  // ══════════════════════════════════════════════

  /// Pendapatan terpisah: jasa vs sparepart
  Future<Map<String, double>> getRevenueByType(
    DateTime start,
    DateTime end,
  ) async {
    final r = await customSelect(
      '''SELECT 
         COALESCE(SUM(CASE WHEN ti.item_type='service' THEN ti.subtotal ELSE 0 END), 0.0) as service_revenue,
         COALESCE(SUM(CASE WHEN ti.item_type='product' THEN ti.subtotal ELSE 0 END), 0.0) as parts_revenue
         FROM transaction_items ti
         JOIN transactions t ON t.id=ti.transaction_id
         WHERE t.created_at>=? AND t.created_at<=? AND t.status='completed' AND ti.is_approved=1 ''',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {transactionItems, transactions},
    ).getSingle();
    return {
      'serviceRevenue': r.read<double>('service_revenue'),
      'partsRevenue': r.read<double>('parts_revenue'),
    };
  }

  /// Total modal (HPP) dari produk yang terjual
  Future<double> getTotalCostOfGoods(DateTime start, DateTime end) async {
    final r = await customSelect(
      '''SELECT COALESCE(SUM(p.cost_price * ti.qty), 0.0) as total_cost
         FROM transaction_items ti
         JOIN products p ON p.id=ti.product_id
         JOIN transactions t ON t.id=ti.transaction_id
         WHERE t.created_at>=? AND t.created_at<=? AND t.status='completed'
         AND ti.item_type='product' ''',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {transactionItems, products, transactions},
    ).getSingle();
    return r.read<double>('total_cost');
  }

  /// Ringkasan profit
  Future<Map<String, double>> getSummaryProfit(
    DateTime start,
    DateTime end,
  ) async {
    final totalSales = await getTotalSales(start, end);
    final totalCost = await getTotalCostOfGoods(start, end);
    final revenue = await getRevenueByType(start, end);
    final grossProfit = totalSales - totalCost;
    final margin = totalSales > 0 ? (grossProfit / totalSales * 100) : 0.0;

    return {
      'totalSales': totalSales,
      'totalCost': totalCost,
      'grossProfit': grossProfit,
      'margin': margin,
      'serviceRevenue': revenue['serviceRevenue'] ?? 0.0,
      'partsRevenue': revenue['partsRevenue'] ?? 0.0,
    };
  }

  /// Detail item untuk laporan Excel
  Future<List<Map<String, dynamic>>> getDetailedTransactionItems(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await customSelect(
      '''SELECT ti.id, ti.item_type, ti.qty, ti.unit_price, ti.subtotal, ti.discount, ti.worker_name,
         CASE WHEN ti.item_type = 'product' THEN p.cost_price ELSE 0 END as cost_price,
         CASE WHEN ti.item_type = 'product' THEN p.name ELSE s.name END as item_name,
         t.invoice_no, t.created_at, t.customer_name
         FROM transaction_items ti
         LEFT JOIN products p ON p.id = ti.product_id
         LEFT JOIN services s ON s.id = ti.service_id
         JOIN transactions t ON t.id = ti.transaction_id
         WHERE t.created_at >= ? AND t.created_at <= ? AND t.status = 'completed' AND ti.is_approved = 1
         ORDER BY t.created_at DESC''',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {transactionItems, products, services, transactions},
    ).get();
    return rows
        .map(
          (r) => {
            'id': r.read<String>('id'),
            'itemType': r.read<String>('item_type'),
            'qty': r.read<int>('qty'),
            'unitPrice': r.read<double>('unit_price'),
            'subtotal': r.read<double>('subtotal'),
            'discount': r.read<double>('discount'),
            'workerName': r.readNullable<String>('worker_name') ?? '-',
            'costPrice': r.read<double>('cost_price'),
            'itemName': r.readNullable<String>('item_name') ?? '-',
            'invoiceNo': r.read<String>('invoice_no'),
            'createdAt': r.read<DateTime>('created_at'),
            'customerName': r.readNullable<String>('customer_name') ?? '-',
          },
        )
        .toList();
  }

  /// Work order count hari ini
  Future<int> getTodayWorkOrderCount() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final r = await customSelect(
      'SELECT COUNT(*) as cnt FROM work_orders WHERE created_at>=? AND created_at<?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {workOrders},
    ).getSingle();
    return r.read<int>('cnt');
  }

  /// Active work order count
  Future<int> getActiveWorkOrderCount() async {
    final r = await customSelect(
      "SELECT COUNT(*) as cnt FROM work_orders WHERE status IN ('waiting', 'in_progress')",
      readsFrom: {workOrders},
    ).getSingle();
    return r.read<int>('cnt');
  }

  /// Get all pending service approvals for admin
  Future<List<TypedResult>> getPendingServiceApprovals() {
    return (select(transactionItems).join([
      innerJoin(transactions, transactions.id.equalsExp(transactionItems.transactionId)),
      leftOuterJoin(services, services.id.equalsExp(transactionItems.serviceId)),
    ])..where(transactionItems.itemType.equals('service') & transactionItems.isApproved.equals(false)))
        .get();
  }

  /// Get all approved service approvals for history (limited to 50 latest)
  Future<List<TypedResult>> getApprovedServiceApprovals() {
    return (select(transactionItems).join([
      innerJoin(transactions, transactions.id.equalsExp(transactionItems.transactionId)),
      leftOuterJoin(services, services.id.equalsExp(transactionItems.serviceId)),
    ])
      ..where(transactionItems.itemType.equals('service') & transactionItems.isApproved.equals(true))
      ..orderBy([OrderingTerm.desc(transactions.createdAt)])
      ..limit(50))
        .get();
  }

  /// Approve a specific transaction item (service)
  Future<void> approveTransactionItem(String itemId) async {
    await (update(transactionItems)..where((ti) => ti.id.equals(itemId))).write(
      const TransactionItemsCompanion(isApproved: Value(true)),
    );
  }

  // ══════════════════════════════════════════════
  // ── Stock Adjustments ──
  // ══════════════════════════════════════════════
  Future<String> insertStockAdjustment(StockAdjustmentsCompanion a) =>
      into(stockAdjustments).insert(a).then((_) => a.id.value);
  Future<List<StockAdjustment>> getStockAdjustments(String productId) =>
      (select(stockAdjustments)
            ..where((a) => a.productId.equals(productId))
            ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
          .get();

  // ══════════════════════════════════════════════
  // ── Sync Queue ──
  // ══════════════════════════════════════════════
  Future<int> addToSyncQueue(SyncQueueCompanion e) => into(syncQueue).insert(e);
  Future<List<SyncQueueData>> getPendingSyncItems() =>
      (select(syncQueue)
            ..where((s) => s.synced.equals(false))
            ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
          .get();
  Future<void> markSynced(int id) =>
      (update(syncQueue)..where((s) => s.id.equals(id))).write(
        const SyncQueueCompanion(synced: Value(true)),
      );

  Future<void> markSyncFailed(int id, String error) async {
    final item = await (select(
      syncQueue,
    )..where((s) => s.id.equals(id))).getSingle();
    await (update(syncQueue)..where((s) => s.id.equals(id))).write(
      SyncQueueCompanion(
        retryCount: Value(item.retryCount + 1),
        lastError: Value(error),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // ── Notifications ──
  // ══════════════════════════════════════════════
  Future<List<Notification>> getAllNotifications() => (select(
    notifications,
  )..orderBy([(n) => OrderingTerm.desc(n.createdAt)])).get();
  Future<int> insertNotification(NotificationsCompanion n) =>
      into(notifications).insert(n);
  Future<void> markNotificationRead(int id) =>
      (update(notifications)..where((n) => n.id.equals(id))).write(
        const NotificationsCompanion(isRead: Value(true)),
      );
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
      await delete(workOrders).go();
      await delete(stockAdjustments).go();
      await delete(products).go();
      await delete(services).go();
      await delete(vehicles).go();
      await delete(categories).go();
      await delete(users).go();
    });
  }
}
