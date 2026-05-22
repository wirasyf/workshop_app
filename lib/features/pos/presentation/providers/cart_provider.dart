import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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
  bool isApproved;
  final String? workerName;

  CartItem({
    required this.productId, required this.name, required this.unitPrice,
    required this.unit, this.type = CartItemType.product, this.qty = 1, this.discount = 0,
    this.isApproved = true, this.workerName,
  });

  double get subtotal => (unitPrice * qty) - discount;

  CartItem copyWith({int? qty, double? discount, bool? isApproved, String? workerName}) =>
      CartItem(productId: productId, name: name, unitPrice: unitPrice,
          unit: unit, type: type, qty: qty ?? this.qty, discount: discount ?? this.discount,
          isApproved: isApproved ?? this.isApproved, workerName: workerName ?? this.workerName);
}

/// Detail item transaksi (untuk riwayat)
class TransactionDetail {
  final TransactionItem item;
  final String productName;
  final String itemType;
  final String? workerName;

  TransactionDetail({required this.item, required this.productName, this.itemType = 'product', this.workerName});
}

/// Provider pekerja yang dipilih untuk jasa di keranjang
final cartSelectedWorkerProvider = StateProvider<String?>((ref) => null);

/// Provider keranjang belanja
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  final notifier = CartNotifier();
  ref.listen(authStateProvider, (previous, next) {
    if (previous?.value?.id != next.value?.id) {
      notifier.clear();
      ref.read(cartDiscountProvider.notifier).state = 0;
      ref.read(paidAmountProvider.notifier).state = 0;
      ref.read(paymentMethodProvider.notifier).state = 'cash';
      ref.read(cartSelectedWorkerProvider.notifier).state = null;
    }
  });
  return notifier;
});

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

final historyDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  return DateTimeRange(
    start: DateTime(now.year, now.month, now.day),
    end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
  );
});

class TransactionHistoryNotifier extends AsyncNotifier<List<Transaction>> {
  int _offset = 0;
  final int _limit = 20;
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  @override
  Future<List<Transaction>> build() async {
    _offset = 0;
    _hasMore = true;
    
    // Listen to date range changes
    ref.watch(historyDateRangeProvider);
    
    return _fetchTransactions();
  }

  Future<List<Transaction>> _fetchTransactions() async {
    final db = ref.read(databaseProvider);
    final dateRange = ref.read(historyDateRangeProvider);
    final user = ref.read(authStateProvider).value;
    
    final transactions = await db.getTransactionsByDate(
      dateRange.start, 
      dateRange.end,
      userId: user?.role == 'cashier' ? user?.id : null,
      limit: _limit,
      offset: _offset,
    );

    _hasMore = transactions.length == _limit;
    return transactions;
  }

  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading) return;

    final currentTransactions = state.value ?? [];
    _offset += _limit;

    try {
      final newTransactions = await _fetchTransactions();
      state = AsyncValue.data([...currentTransactions, ...newTransactions]);
    } catch (e, st) {
      _offset -= _limit;
      state = AsyncValue.error(e, st);
    }
  }
}

final transactionHistoryProvider = AsyncNotifierProvider<TransactionHistoryNotifier, List<Transaction>>(() {
  return TransactionHistoryNotifier();
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
    return TransactionDetail(item: ti, productName: name, itemType: itemType, workerName: ti.workerName);
  }).toList();
});

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(CartItem item) {
    final idx = state.indexWhere((i) => i.productId == item.productId && i.type == item.type && i.workerName == item.workerName);
    if (idx >= 0) {
      state = [...state]..[idx] = state[idx].copyWith(qty: state[idx].qty + item.qty);
    } else {
      state = [...state, item];
    }
  }

  void toggleItem(CartItem item) {
    final idx = state.indexWhere((i) => i.productId == item.productId && i.type == item.type && i.workerName == item.workerName);
    if (idx >= 0) {
      removeItem(item.productId, item.type, item.workerName);
    } else {
      state = [...state, item];
    }
  }

  void removeItem(String productId, [CartItemType? type, String? workerName]) {
    state = state.where((i) => !(i.productId == productId && (type == null || i.type == type) && (workerName == null || i.workerName == workerName))).toList();
  }

  void updateQty(String productId, int qty, [CartItemType? type, String? workerName]) {
    if (qty <= 0) { removeItem(productId, type, workerName); return; }
    state = state.map((i) => (i.productId == productId && (type == null || i.type == type) && (workerName == null || i.workerName == workerName)) ? i.copyWith(qty: qty) : i).toList();
  }

  void clear() => state = [];

  int get totalItems => state.fold(0, (sum, i) => sum + i.qty);
}
