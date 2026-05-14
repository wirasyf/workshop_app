import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';

/// Tipe item di keranjang
enum CartItemType { product, service }

/// Item dalam keranjang — mendukung produk DAN jasa
class CartItem {
  final String productId; // ID produk ATAU ID jasa
  final String name;
  final double unitPrice;
  final String unit;
  final CartItemType type;
  int qty;
  double discount;

  CartItem({
    required this.productId, required this.name, required this.unitPrice,
    required this.unit, this.type = CartItemType.product, this.qty = 1, this.discount = 0,
  });

  double get subtotal => (unitPrice * qty) - discount;

  CartItem copyWith({int? qty, double? discount}) =>
      CartItem(productId: productId, name: name, unitPrice: unitPrice,
          unit: unit, type: type, qty: qty ?? this.qty, discount: discount ?? this.discount);
}

/// Detail item transaksi (untuk riwayat)
class TransactionDetail {
  final TransactionItem item;
  final String productName;
  final String itemType;

  TransactionDetail({required this.item, required this.productName, this.itemType = 'product'});
}

/// Provider keranjang belanja
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());

/// Provider subtotal
final cartSubtotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + item.subtotal);
});

/// Provider subtotal jasa
final cartServiceSubtotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.where((i) => i.type == CartItemType.service).fold(0.0, (sum, item) => sum + item.subtotal);
});

/// Provider subtotal sparepart
final cartPartsSubtotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.where((i) => i.type == CartItemType.product).fold(0.0, (sum, item) => sum + item.subtotal);
});

/// Provider diskon keseluruhan
final cartDiscountProvider = StateProvider<double>((ref) => 0);

/// Provider total (subtotal - diskon, tanpa pajak)
final cartTotalProvider = Provider<double>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final discount = ref.watch(cartDiscountProvider);
  return subtotal - discount;
});

/// Provider metode bayar
final paymentMethodProvider = StateProvider<String>((ref) => 'cash');

/// Provider jumlah bayar
final paidAmountProvider = StateProvider<double>((ref) => 0);

/// Provider kembalian
final changeAmountProvider = Provider<double>((ref) {
  final total = ref.watch(cartTotalProvider);
  final paid = ref.watch(paidAmountProvider);
  return paid - total;
});

/// Provider riwayat transaksi
final transactionHistoryProvider = FutureProvider.family<List<Transaction>, ({DateTime start, DateTime end})>((ref, range) {
  final db = ref.watch(databaseProvider);
  return db.getTransactionsByDate(range.start, range.end);
});

/// Provider detail item transaksi
final transactionItemsProvider = FutureProvider.family<List<TransactionDetail>, String>((ref, txnId) async {
  final db = ref.watch(databaseProvider);
  final results = await db.getTransactionItemsWithProduct(txnId);
  return results.map((r) {
    final ti = r.readTable(db.transactionItems);
    final itemType = ti.itemType;
    String name;
    if (itemType == 'service') {
      final service = r.readTableOrNull(db.services);
      name = service?.name ?? 'Jasa';
    } else {
      final product = r.readTableOrNull(db.products);
      name = product?.name ?? 'Produk';
    }
    return TransactionDetail(item: ti, productName: name, itemType: itemType);
  }).toList();
});

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(CartItem item) {
    final idx = state.indexWhere((i) => i.productId == item.productId && i.type == item.type);
    if (idx >= 0) {
      state = [...state]..[idx] = state[idx].copyWith(qty: state[idx].qty + (item.qty > 1 ? item.qty - 1 : 1));
    } else {
      state = [...state, item];
    }
  }

  void toggleItem(CartItem item) {
    final idx = state.indexWhere((i) => i.productId == item.productId && i.type == item.type);
    if (idx >= 0) {
      removeItem(item.productId, item.type);
    } else {
      state = [...state, item];
    }
  }

  void removeItem(String productId, [CartItemType? type]) {
    state = state.where((i) => !(i.productId == productId && (type == null || i.type == type))).toList();
  }

  void updateQty(String productId, int qty, [CartItemType? type]) {
    if (qty <= 0) { removeItem(productId, type); return; }
    state = state.map((i) => (i.productId == productId && (type == null || i.type == type)) ? i.copyWith(qty: qty) : i).toList();
  }

  void clear() => state = [];

  int get totalItems => state.fold(0, (sum, i) => sum + i.qty);
}
