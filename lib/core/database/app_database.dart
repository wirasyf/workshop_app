import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
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

  // ── Migration Helpers ──

  /// Cek apakah kolom sudah ada di tabel
  Future<bool> _columnExists(String table, String column) async {
    try {
      final result = await customSelect(
        "PRAGMA table_info($table)",
        readsFrom: {},
      ).get();
      return result.any((r) => r.read<String>('name') == column);
    } catch (_) {
      return false;
    }
  }

  /// Cek apakah tabel sudah ada
  Future<bool> _tableExists(String table) async {
    try {
      final result = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        variables: [Variable.withString(table)],
        readsFrom: {},
      ).get();
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        // ── v1 → v2 ──
        if (from < 2) {
          try {
            if (!await _columnExists('users', 'avatar_url')) {
              await m.addColumn(users, users.avatarUrl);
            }
            if (!await _columnExists('products', 'sell_price_wholesale')) {
              await m.addColumn(products, products.sellPriceWholesale);
            }
            if (!await _columnExists('products', 'updated_at')) {
              await m.addColumn(products, products.updatedAt);
            }
          } catch (e) {
            debugPrint('Migration v2 error (non-fatal): $e');
          }
        }

        // ── v2 → v3 ──
        if (from < 3) {
          try {
            if (!await _tableExists('notifications')) {
              await m.createTable(notifications);
            }
          } catch (e) {
            debugPrint('Migration v3 error (non-fatal): $e');
          }
        }

        // ── v3 → v4 ──
        if (from < 4) {
          // PK change dari Int ke String — handled by schema recreation
          debugPrint('Migration v4: PK change acknowledged');
        }

        // ── v4 → v5: Workshop tables + transaction_items recreate ──
        if (from < 5) {
          try {
            if (!await _tableExists('services')) {
              await m.createTable(services);
            }
            if (!await _tableExists('vehicles')) {
              await m.createTable(vehicles);
            }
            if (!await _tableExists('work_orders')) {
              await m.createTable(workOrders);
            }
            if (!await _columnExists('transactions', 'customer_name')) {
              await m.addColumn(transactions, transactions.customerName);
            }
            if (!await _columnExists('transactions', 'customer_id')) {
              await m.addColumn(transactions, transactions.customerId);
            }

            // Recreate transaction_items dengan product_id nullable + service support
            await _recreateTransactionItems(includeApproval: false, includeWorker: false);
          } catch (e) {
            debugPrint('Migration v5 error (non-fatal): $e');
          }
        }

        // ── v5 → v6: Fix product_id nullable ──
        if (from == 5) {
          try {
            // Recreate jika product_id masih NOT NULL
            await _recreateTransactionItems(includeApproval: false, includeWorker: false);
          } catch (e) {
            debugPrint('Migration v6 fix error (non-fatal): $e');
          }
        }

        // ── v6 → v7: Role + approval ──
        if (from < 7) {
          try {
            if (!await _columnExists('users', 'role')) {
              await m.addColumn(users, users.role);
            }
            if (!await _columnExists('transaction_items', 'is_approved')) {
              await m.addColumn(transactionItems, transactionItems.isApproved);
            }
          } catch (e) {
            debugPrint('Migration v7 error (non-fatal): $e');
          }
        }

        // ── v7 → v8: Service categories ──
        if (from < 8) {
          try {
            if (!await _tableExists('service_categories')) {
              await m.createTable(serviceCategories);
            }
            if (!await _columnExists('services', 'category_id')) {
              await m.addColumn(services, services.categoryId);
            }
          } catch (e) {
            debugPrint('Migration v8 error (non-fatal): $e');
          }
        }

        // ── v8 → v9: Worker name ──
        if (from < 9) {
          try {
            if (!await _columnExists('transaction_items', 'worker_name')) {
              await m.addColumn(transactionItems, transactionItems.workerName);
            }
          } catch (e) {
            debugPrint('Migration v9 error (non-fatal): $e');
          }
        }
      },
      beforeOpen: (details) async {
        // Validasi schema setelah migration selesai
        try {
          await _validateAndRepairSchema();
        } catch (e) {
          debugPrint('Schema validation error: $e');
          // Jika validasi gagal total, recreate semua tabel
          if (details.wasCreated) return;
          try {
            debugPrint('Attempting destructive migration fallback...');
            final m = createMigrator();
            await m.createAll();
            debugPrint('Destructive migration fallback completed');
          } catch (e2) {
            debugPrint('Destructive migration fallback failed: $e2');
          }
        }
      },
    );
  }

  /// Recreate transaction_items dengan schema yang benar
  Future<void> _recreateTransactionItems({
    required bool includeApproval,
    required bool includeWorker,
  }) async {
    final hasOldTable = await _tableExists('transaction_items');
    if (!hasOldTable) return;

    final approvalCol = includeApproval ? ', is_approved INTEGER NOT NULL DEFAULT 1' : '';
    final workerCol = includeWorker ? ', worker_name TEXT' : '';

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
        $approvalCol
        $workerCol
      )
    ''');

    // Copy data dari tabel lama
    final hasItemType = await _columnExists('transaction_items', 'item_type');
    final hasServiceId = await _columnExists('transaction_items', 'service_id');
    final hasDiscount = await _columnExists('transaction_items', 'discount');

    final itemTypeSelect = hasItemType ? "COALESCE(item_type, 'product')" : "'product'";
    final serviceIdSelect = hasServiceId ? 'service_id' : 'NULL';
    final discountSelect = hasDiscount ? 'COALESCE(discount, 0.0)' : '0.0';

    await customStatement('''
      INSERT OR IGNORE INTO transaction_items_new 
        (id, transaction_id, item_type, product_id, service_id, qty, unit_price, discount, subtotal)
      SELECT id, transaction_id, $itemTypeSelect, product_id, $serviceIdSelect, 
        qty, unit_price, $discountSelect, subtotal
      FROM transaction_items
    ''');

    await customStatement('DROP TABLE transaction_items');
    await customStatement('ALTER TABLE transaction_items_new RENAME TO transaction_items');
  }

  /// Validasi schema — pastikan semua kolom kritikal ada
  Future<void> _validateAndRepairSchema() async {
    // Validasi kolom penting di transactions
    if (await _tableExists('transactions')) {
      if (!await _columnExists('transactions', 'customer_name')) {
        await customStatement('ALTER TABLE transactions ADD COLUMN customer_name TEXT');
      }
      if (!await _columnExists('transactions', 'customer_id')) {
        await customStatement('ALTER TABLE transactions ADD COLUMN customer_id TEXT');
      }
    }

    // Validasi kolom penting di transaction_items
    if (await _tableExists('transaction_items')) {
      if (!await _columnExists('transaction_items', 'is_approved')) {
        await customStatement('ALTER TABLE transaction_items ADD COLUMN is_approved INTEGER NOT NULL DEFAULT 1');
      }
      if (!await _columnExists('transaction_items', 'worker_name')) {
        await customStatement('ALTER TABLE transaction_items ADD COLUMN worker_name TEXT');
      }
      if (!await _columnExists('transaction_items', 'item_type')) {
        await customStatement("ALTER TABLE transaction_items ADD COLUMN item_type TEXT NOT NULL DEFAULT 'product'");
      }
      if (!await _columnExists('transaction_items', 'service_id')) {
        await customStatement('ALTER TABLE transaction_items ADD COLUMN service_id TEXT');
      }
    }

    // Validasi kolom penting di users
    if (await _tableExists('users')) {
      if (!await _columnExists('users', 'role')) {
        await customStatement("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'owner'");
      }
      if (!await _columnExists('users', 'avatar_url')) {
        await customStatement('ALTER TABLE users ADD COLUMN avatar_url TEXT');
      }
    }

    // Validasi kolom penting di services
    if (await _tableExists('services')) {
      if (!await _columnExists('services', 'category_id')) {
        await customStatement('ALTER TABLE services ADD COLUMN category_id TEXT');
      }
    }

    // Validasi tabel yang harus ada
    final requiredTables = [
      'notifications', 'services', 'vehicles', 'work_orders',
      'service_categories', 'stock_adjustments', 'sync_queue',
    ];
    for (final table in requiredTables) {
      if (!await _tableExists(table)) {
        debugPrint('Missing table detected: $table — will be created by fallback');
        throw Exception('Missing required table: $table');
      }
    }
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
  Future<List<Product>> getAllProducts({bool activeOnly = true, int? limit, int? offset}) {
    final q = select(products);
    if (activeOnly) q.where((p) => p.isActive.equals(true));
    if (limit != null) q.limit(limit, offset: offset);
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
  Future<List<TypedResult>> getWorkOrdersWithVehicle({String? statusFilter, int? limit, int? offset}) {
    final q = select(
      workOrders,
    ).join([innerJoin(vehicles, vehicles.id.equalsExp(workOrders.vehicleId))]);
    if (statusFilter != null) {
      q.where(workOrders.status.equals(statusFilter));
    }
    q.orderBy([OrderingTerm.desc(workOrders.createdAt)]);
    if (limit != null) q.limit(limit, offset: offset);
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
    DateTime end, {
    String? userId,
    int? limit,
    int? offset,
  }) {
      final q = select(transactions)
            ..where(
              (t) =>
                  t.createdAt.isBiggerOrEqualValue(start) &
                  t.createdAt.isSmallerOrEqualValue(end),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
      if (userId != null) q.where((t) => t.userId.equals(userId));
      if (limit != null) q.limit(limit, offset: offset);
      return q.get();
  }
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

  /// Penjualan berdasarkan rentang tanggal
  Future<List<Map<String, dynamic>>> getSalesByDateRange(DateTime start, DateTime end) async {
    final rows = await customSelect(
      'SELECT DATE(t.created_at, \'unixepoch\', \'localtime\') as sale_date, COALESCE(SUM(ti.subtotal), 0.0) as daily_total, COUNT(DISTINCT t.id) as txn_count '
      'FROM transactions t JOIN transaction_items ti ON t.id=ti.transaction_id '
      'WHERE t.created_at>=? AND t.created_at<=? AND t.status=\'completed\' AND ti.is_approved=1 '
      'GROUP BY DATE(t.created_at, \'unixepoch\', \'localtime\') ORDER BY sale_date ASC',
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
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
