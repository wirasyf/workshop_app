import 'package:drift/drift.dart';

// ═══════════════════════════════════════════════════════════════
// TABLE DEFINITIONS — Sistem Manajemen Bengkel
// ═══════════════════════════════════════════════════════════════

/// Tabel pengguna (Owner)
class Users extends Table {
  TextColumn get id => text()(); // UUID as PK
  TextColumn get name => text().withLength(max: 100)();
  TextColumn get username => text().unique()();
  TextColumn get email => text().unique()();
  TextColumn get passwordHash => text()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get role => text().withDefault(const Constant('owner'))(); // 'owner', 'cashier'
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get supabaseUid => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kategori produk
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(max: 100)();
  TextColumn get slug => text().withLength(max: 100)();
  TextColumn get parentId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Produk spare part
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(max: 200)();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get brand => text().nullable()();
  TextColumn get motorType => text().nullable()();
  IntColumn get stockQty => integer().withDefault(const Constant(0))();
  IntColumn get stockMin => integer().withDefault(const Constant(5))();
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  RealColumn get sellPrice => real().withDefault(const Constant(0.0))();
  RealColumn get sellPriceWholesale => real().nullable()();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kategori jasa
class ServiceCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(max: 100)();
  TextColumn get slug => text().withLength(max: 100)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Katalog Jasa Bengkel
class Services extends Table {
  TextColumn get id => text()();           // UUID
  TextColumn get name => text().withLength(max: 200)();
  TextColumn get description => text().nullable()();
  RealColumn get price => real().withDefault(const Constant(0.0))();
  IntColumn get estimatedMinutes => integer().withDefault(const Constant(30))();
  TextColumn get categoryId => text().nullable().references(ServiceCategories, #id)();
  TextColumn get category => text().withDefault(const Constant('umum'))();
  // category: 'servis_rutin', 'perbaikan', 'tune_up', 'body', 'umum'
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kendaraan Pelanggan
class Vehicles extends Table {
  TextColumn get id => text()();           // UUID
  TextColumn get customerName => text().withLength(max: 200)();
  TextColumn get phoneNumber => text().nullable()();
  TextColumn get plateNumber => text().withLength(max: 15)();
  TextColumn get vehicleBrand => text().nullable()(); // Honda, Yamaha, dst
  TextColumn get vehicleType => text().nullable()();  // Beat, Vario, NMAX, dst
  IntColumn get vehicleYear => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Transaksi penjualan (header)
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNo => text().unique()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text().nullable()(); // Nama pelanggan langsung
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  RealColumn get changeAmount => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Item transaksi (detail) — mendukung produk DAN jasa
class TransactionItems extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get itemType => text().withDefault(const Constant('product'))();
  // 'product' atau 'service'
  TextColumn get productId => text().nullable().references(Products, #id)();
  // Null jika itemType = 'service'
  TextColumn get serviceId => text().nullable().references(Services, #id)();
  // Null jika itemType = 'product'
  IntColumn get qty => integer()();
  RealColumn get unitPrice => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get subtotal => real()();
  BoolColumn get isApproved => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Work Order (Antrian Bengkel)
class WorkOrders extends Table {
  TextColumn get id => text()();           // UUID
  TextColumn get orderNo => text().unique()();   // WO-001, WO-002
  TextColumn get vehicleId => text().references(Vehicles, #id)();
  TextColumn get userId => text().references(Users, #id)(); // kasir/admin
  TextColumn get status => text().withDefault(const Constant('waiting'))();
  // status: 'waiting', 'in_progress', 'completed', 'paid', 'cancelled'
  TextColumn get complaint => text().nullable()(); // keluhan pelanggan
  TextColumn get diagnosis => text().nullable()(); // diagnosa mekanik
  RealColumn get totalService => real().withDefault(const Constant(0.0))();
  RealColumn get totalParts => real().withDefault(const Constant(0.0))();
  RealColumn get grandTotal => real().withDefault(const Constant(0.0))();
  TextColumn get transactionId => text().nullable().references(Transactions, #id)();
  // Link ke transaksi POS setelah pembayaran
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Penyesuaian stok manual
class StockAdjustments extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get type => text()();
  IntColumn get qtyChange => integer()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Antrian sinkronisasi offline-first
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()(); // ID antrian tetap integer
  TextColumn get syncTableName => text()();
  TextColumn get recordId => text()(); // Record ID yang disinkronkan sekarang String (UUID)
  TextColumn get operation => text()();
  TextColumn get data => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

/// Notifikasi sistem & riwayat alert
class Notifications extends Table {
  IntColumn get id => integer().autoIncrement()(); // Notifikasi lokal tetap auto-increment
  TextColumn get title => text().withLength(max: 200)();
  TextColumn get message => text()();
  TextColumn get type => text()(); // 'stock_critical', 'stock_low', 'transaction', 'info'
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
