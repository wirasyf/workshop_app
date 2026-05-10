import 'package:drift/drift.dart';
import 'app_database.dart';

/// Seed data untuk testing & demo
class SeedData {
  static Future<void> seedIfEmpty(AppDatabase db) async {
    final existingUsers = await db.getAllUsers();
    if (existingUsers.isNotEmpty) return; // sudah pernah di-seed

    // ── Users ──
    await db.insertUser(UsersCompanion.insert(
      name: 'Admin Owner', email: 'owner@spareart.com',
      passwordHash: 'owner123', role: const Value('owner'),
    ));
    await db.insertUser(UsersCompanion.insert(
      name: 'Kasir Budi', email: 'kasir@spareart.com',
      passwordHash: 'kasir123', role: const Value('kasir'),
    ));

    // ── Categories ──
    final catOli = await db.insertCategory(CategoriesCompanion.insert(name: 'Oli & Pelumas', slug: 'oli-pelumas'));
    final catRem = await db.insertCategory(CategoriesCompanion.insert(name: 'Rem', slug: 'rem'));
    final catFilter = await db.insertCategory(CategoriesCompanion.insert(name: 'Filter', slug: 'filter'));
    final catListrik = await db.insertCategory(CategoriesCompanion.insert(name: 'Kelistrikan', slug: 'kelistrikan'));
    final catMesin = await db.insertCategory(CategoriesCompanion.insert(name: 'Mesin', slug: 'mesin'));
    final catBody = await db.insertCategory(CategoriesCompanion.insert(name: 'Body & Cover', slug: 'body-cover'));
    final catBan = await db.insertCategory(CategoriesCompanion.insert(name: 'Ban & Velg', slug: 'ban-velg'));
    final catRantai = await db.insertCategory(CategoriesCompanion.insert(name: 'Rantai & Gear', slug: 'rantai-gear'));

    // ── Products (20 produk sample) ──
    final productSeeds = <ProductsCompanion>[
      ProductsCompanion.insert(name: 'Oli Yamalube 0.8L', sku: Value('OLI-001'), barcode: Value('8991111000101'),
        categoryId: Value(catOli), brand: Value('Yamalube'), motorType: Value('Yamaha NMAX'),
        stockQty: Value(45), stockMin: Value(10), costPrice: Value(32000), sellPrice: Value(45000),
        sellPriceWholesale: Value(42000), unit: Value('botol')),
      ProductsCompanion.insert(name: 'Oli MPX2 0.8L', sku: Value('OLI-002'), barcode: Value('8991111000102'),
        categoryId: Value(catOli), brand: Value('Honda'), motorType: Value('Honda Beat'),
        stockQty: Value(38), stockMin: Value(10), costPrice: Value(28000), sellPrice: Value(40000), unit: Value('botol')),
      ProductsCompanion.insert(name: 'Oli Enduro 4T 1L', sku: Value('OLI-003'), barcode: Value('8991111000103'),
        categoryId: Value(catOli), brand: Value('Pertamina'), motorType: Value('Universal'),
        stockQty: Value(3), stockMin: Value(10), costPrice: Value(35000), sellPrice: Value(50000), unit: Value('botol')),
      ProductsCompanion.insert(name: 'Kampas Rem Depan Beat', sku: Value('REM-001'), barcode: Value('8991111000201'),
        categoryId: Value(catRem), brand: Value('Aspira'), motorType: Value('Honda Beat'),
        stockQty: Value(20), stockMin: Value(5), costPrice: Value(18000), sellPrice: Value(30000), unit: Value('set')),
      ProductsCompanion.insert(name: 'Kampas Rem Belakang NMAX', sku: Value('REM-002'), barcode: Value('8991111000202'),
        categoryId: Value(catRem), brand: Value('TDR'), motorType: Value('Yamaha NMAX'),
        stockQty: Value(2), stockMin: Value(5), costPrice: Value(45000), sellPrice: Value(65000), unit: Value('set')),
      ProductsCompanion.insert(name: 'Disc Brake Depan Vario', sku: Value('REM-003'), barcode: Value('8991111000203'),
        categoryId: Value(catRem), brand: Value('Indoparts'), motorType: Value('Honda Vario'),
        stockQty: Value(8), stockMin: Value(3), costPrice: Value(85000), sellPrice: Value(120000), unit: Value('pcs')),
      ProductsCompanion.insert(name: 'Filter Udara Beat FI', sku: Value('FIL-001'), barcode: Value('8991111000301'),
        categoryId: Value(catFilter), brand: Value('Aspira'), motorType: Value('Honda Beat FI'),
        stockQty: Value(15), stockMin: Value(5), costPrice: Value(12000), sellPrice: Value(22000), unit: Value('pcs')),
      ProductsCompanion.insert(name: 'Filter Oli NMAX', sku: Value('FIL-002'), barcode: Value('8991111000302'),
        categoryId: Value(catFilter), brand: Value('Yamalube'), motorType: Value('Yamaha NMAX'),
        stockQty: Value(0), stockMin: Value(5), costPrice: Value(15000), sellPrice: Value(25000), unit: Value('pcs')),
      ProductsCompanion.insert(name: 'Busi NGK CPR9EA', sku: Value('LIS-001'), barcode: Value('8991111000401'),
        categoryId: Value(catListrik), brand: Value('NGK'), motorType: Value('Universal'),
        stockQty: Value(50), stockMin: Value(10), costPrice: Value(22000), sellPrice: Value(35000), unit: Value('pcs')),
      ProductsCompanion.insert(name: 'CDI Racing Supra X', sku: Value('LIS-002'), barcode: Value('8991111000402'),
        categoryId: Value(catListrik), brand: Value('Rextor'), motorType: Value('Honda Supra X'),
        stockQty: Value(5), stockMin: Value(2), costPrice: Value(150000), sellPrice: Value(220000), unit: Value('pcs')),
      ProductsCompanion.insert(name: 'Lampu LED H6 Putih', sku: Value('LIS-003'), barcode: Value('8991111000403'),
        categoryId: Value(catListrik), brand: Value('Autovision'), motorType: Value('Universal'),
        stockQty: Value(25), stockMin: Value(5), costPrice: Value(45000), sellPrice: Value(75000), unit: Value('pcs')),
      ProductsCompanion.insert(name: 'Piston Kit Vario 150', sku: Value('MSN-001'), barcode: Value('8991111000501'),
        categoryId: Value(catMesin), brand: Value('NPP'), motorType: Value('Honda Vario 150'),
        stockQty: Value(4), stockMin: Value(3), costPrice: Value(180000), sellPrice: Value(250000), unit: Value('set')),
      ProductsCompanion.insert(name: 'Packing Set Beat', sku: Value('MSN-002'), barcode: Value('8991111000502'),
        categoryId: Value(catMesin), brand: Value('KGS'), motorType: Value('Honda Beat'),
        stockQty: Value(10), stockMin: Value(3), costPrice: Value(25000), sellPrice: Value(40000), unit: Value('set')),
      ProductsCompanion.insert(name: 'Spion Standar Beat', sku: Value('BDY-001'), barcode: Value('8991111000601'),
        categoryId: Value(catBody), brand: Value('AHM'), motorType: Value('Honda Beat'),
        stockQty: Value(12), stockMin: Value(4), costPrice: Value(35000), sellPrice: Value(55000), unit: Value('pcs')),
      ProductsCompanion.insert(name: 'Cover Body Depan Vario', sku: Value('BDY-002'), barcode: Value('8991111000602'),
        categoryId: Value(catBody), brand: Value('Win'), motorType: Value('Honda Vario'),
        stockQty: Value(3), stockMin: Value(2), costPrice: Value(95000), sellPrice: Value(140000), unit: Value('pcs')),
      ProductsCompanion.insert(name: 'Ban Luar 80/90-14 IRC', sku: Value('BAN-001'), barcode: Value('8991111000701'),
        categoryId: Value(catBan), brand: Value('IRC'), motorType: Value('Universal Matic'),
        stockQty: Value(8), stockMin: Value(3), costPrice: Value(95000), sellPrice: Value(135000), unit: Value('pcs')),
      ProductsCompanion.insert(name: 'Ban Dalam 14 inch', sku: Value('BAN-002'), barcode: Value('8991111000702'),
        categoryId: Value(catBan), brand: Value('Swallow'), motorType: Value('Universal Matic'),
        stockQty: Value(20), stockMin: Value(5), costPrice: Value(18000), sellPrice: Value(30000), unit: Value('pcs')),
      ProductsCompanion.insert(name: 'Rantai 428H Gold', sku: Value('RNT-001'), barcode: Value('8991111000801'),
        categoryId: Value(catRantai), brand: Value('SSS'), motorType: Value('Universal Bebek'),
        stockQty: Value(6), stockMin: Value(3), costPrice: Value(75000), sellPrice: Value(110000), unit: Value('pcs')),
      ProductsCompanion.insert(name: 'Gear Set Supra X', sku: Value('RNT-002'), barcode: Value('8991111000802'),
        categoryId: Value(catRantai), brand: Value('Indoparts'), motorType: Value('Honda Supra X'),
        stockQty: Value(4), stockMin: Value(2), costPrice: Value(120000), sellPrice: Value(175000), unit: Value('set')),
      ProductsCompanion.insert(name: 'V-Belt NMAX Original', sku: Value('MSN-003'), barcode: Value('8991111000503'),
        categoryId: Value(catMesin), brand: Value('Yamaha'), motorType: Value('Yamaha NMAX'),
        stockQty: Value(7), stockMin: Value(3), costPrice: Value(185000), sellPrice: Value(260000), unit: Value('pcs')),
    ];
    for (final p in productSeeds) {
      await db.insertProduct(p);
    }

    // ── Suppliers ──
    await db.insertSupplier(SuppliersCompanion.insert(
      name: 'PT Astra Honda Motor', contactName: Value('Pak Dedi'),
      phone: Value('021-88881234'), address: Value('Jakarta Utara')));
    await db.insertSupplier(SuppliersCompanion.insert(
      name: 'CV Yamaha Parts Jaya', contactName: Value('Bu Sari'),
      phone: Value('021-77775678'), address: Value('Tangerang')));
    await db.insertSupplier(SuppliersCompanion.insert(
      name: 'UD Spare Part Sejahtera', contactName: Value('Pak Anton'),
      phone: Value('0812-3456-7890'), address: Value('Bandung')));

    // ── Customers ──
    await db.insertCustomer(CustomersCompanion.insert(
      name: 'Bengkel Jaya Motor', phone: Value('0812-1111-2222'), address: Value('Jl. Raya Bogor No.45')));
    await db.insertCustomer(CustomersCompanion.insert(
      name: 'Pak Hendra', phone: Value('0857-3333-4444')));
    await db.insertCustomer(CustomersCompanion.insert(
      name: 'Bengkel Maju Terus', phone: Value('0878-5555-6666'), address: Value('Jl. Sudirman No.12')));
  }
}
