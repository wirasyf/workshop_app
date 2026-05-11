import 'package:drift/drift.dart';

// ═══════════════════════════════════════════════════════════════
// TABLE DEFINITIONS — 14 tabel + 1 sync queue
// ═══════════════════════════════════════════════════════════════

/// Tabel pengguna (owner / kasir)
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 100)();
  TextColumn get username => text().unique()();
  TextColumn get email => text().unique()();
  TextColumn get passwordHash => text()();
  TextColumn get role => text().withDefault(const Constant('kasir'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get supabaseUid => text().nullable()();
}

/// Kategori produk
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 100)();
  TextColumn get slug => text().withLength(max: 100)();
  IntColumn get parentId => integer().nullable()();
}

/// Produk spare part
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 200)();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
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
}

/// Supplier
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 200)();
  TextColumn get contactName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
}

/// Relasi produk-supplier
class ProductSuppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  RealColumn get lastCost => real().nullable()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
}

/// Pelanggan
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 200)();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  IntColumn get loyaltyPoints => integer().withDefault(const Constant(0))();
}

/// Transaksi penjualan (header)
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNo => text().unique()();
  IntColumn get cashierId => integer().references(Users, #id)();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  RealColumn get changeAmount => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Item transaksi (detail)
class TransactionItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(Transactions, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get qty => integer()();
  RealColumn get unitPrice => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get subtotal => real()();
}

/// Purchase Order (header)
class PurchaseOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get poNumber => text().unique()();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  IntColumn get createdBy => integer().references(Users, #id)();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get expectedDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Item PO (detail)
class PoItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get poId => integer().references(PurchaseOrders, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get qtyOrdered => integer()();
  IntColumn get qtyReceived => integer().withDefault(const Constant(0))();
  RealColumn get costPrice => real()();
}

/// Penyesuaian stok manual
class StockAdjustments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get type => text()();
  IntColumn get qtyChange => integer()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Retur (header)
class Returns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().nullable().references(Transactions, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get returnType => text()();
  TextColumn get reason => text().nullable()();
  RealColumn get refundAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Item retur (detail)
class ReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get returnId => integer().references(Returns, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get qty => integer()();
  RealColumn get unitPrice => real()();
}

/// Antrian sinkronisasi offline-first
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncTableName => text()();
  IntColumn get recordId => integer()();
  TextColumn get operation => text()();
  TextColumn get data => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}
