import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';

/// Item dalam keranjang
class CartItem {
  final String productId;
  final String name;
  final double unitPrice;
  final String unit;
  int qty;
  double discount;

  CartItem({
    required this.productId, required this.name, required this.unitPrice,
    required this.unit, this.qty = 1, this.discount = 0,
  });

  double get subtotal => (unitPrice * qty) - discount;

  CartItem copyWith({int? qty, double? discount}) =>
      CartItem(productId: productId, name: name, unitPrice: unitPrice,
          unit: unit, qty: qty ?? this.qty, discount: discount ?? this.discount);
}

/// Detail item transaksi (untuk riwayat)
class TransactionDetail {
  final TransactionItem item;
  final String productName;

  TransactionDetail({required this.item, required this.productName});
}

/// Provider keranjang belanja
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());

/// Provider subtotal
final cartSubtotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + item.subtotal);
});

/// Provider diskon keseluruhan
final cartDiscountProvider = StateProvider<double>((ref) => 0);

/// Provider pajak (11% dari subtotal setelah diskon)
final cartTaxProvider = Provider<double>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final discount = ref.watch(cartDiscountProvider);
  final taxableAmount = subtotal - discount;
  return taxableAmount > 0 ? taxableAmount * 0.11 : 0; // Menggunakan 0.11 langsung atau AppConstants
});

/// Provider total (subtotal - diskon + pajak)
final cartTotalProvider = Provider<double>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final discount = ref.watch(cartDiscountProvider);
  final tax = ref.watch(cartTaxProvider);
  return subtotal - discount + tax;
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

class CartConstants {
  static const int receiptWidth = 32; // karakter per baris struk thermal 58mm
  static const double taxRate = 0.11; // 11% PPN
}

/// Provider riwayat transaksi
final transactionHistoryProvider = FutureProvider.family<List<Transaction>, ({DateTime start, DateTime end})>((ref, range) {
  final db = ref.watch(databaseProvider);
  return db.getTransactionsByDate(range.start, range.end);
});

/// Provider detail item transaksi
final transactionItemsProvider = FutureProvider.family<List<TransactionDetail>, String>((ref, txnId) async {
  final db = ref.watch(databaseProvider);
  final results = await db.getTransactionItemsWithProduct(txnId);
  return results.map((r) => TransactionDetail(
    item: r.readTable(db.transactionItems),
    productName: r.readTable(db.products).name,
  )).toList();
});

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(CartItem item) {
    final idx = state.indexWhere((i) => i.productId == item.productId);
    if (idx >= 0) {
      state = [...state]..[idx] = state[idx].copyWith(qty: state[idx].qty + 1);
    } else {
      state = [...state, item];
    }
  }

  void toggleItem(CartItem item) {
    final idx = state.indexWhere((i) => i.productId == item.productId);
    if (idx >= 0) {
      removeItem(item.productId);
    } else {
      state = [...state, item];
    }
  }

  void removeItem(String productId) {
    state = state.where((i) => i.productId != productId).toList();
  }

  void updateQty(String productId, int qty) {
    if (qty <= 0) { removeItem(productId); return; }
    state = state.map((i) => i.productId == productId ? i.copyWith(qty: qty) : i).toList();
  }

  void clear() => state = [];

  int get totalItems => state.fold(0, (sum, i) => sum + i.qty);
}
