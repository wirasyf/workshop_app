import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/transaction_model.dart';
import '../../data/transaction_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

enum CartItemType { product, service }

class CartItem {
  final String productId;
  final String name;
  final double unitPrice;
  final String unit;
  final double costPrice;
  final CartItemType type;
  int qty;
  double discount;
  bool isApproved;
  final String? workerName;

  CartItem({
    required this.productId, required this.name, required this.unitPrice,
    required this.unit, this.costPrice = 0.0, this.type = CartItemType.product, this.qty = 1, this.discount = 0,
    this.isApproved = true, this.workerName,
  });

  double get subtotal => (unitPrice * qty) - discount;

  CartItem copyWith({int? qty, double? discount, bool? isApproved, String? workerName}) =>
      CartItem(productId: productId, name: name, unitPrice: unitPrice,
          unit: unit, costPrice: costPrice, type: type, qty: qty ?? this.qty, discount: discount ?? this.discount,
          isApproved: isApproved ?? this.isApproved, workerName: workerName ?? this.workerName);
}

class TransactionDetail {
  final TransactionItemModel item;
  final String productName;
  final String itemType;
  final String? workerName;

  TransactionDetail({required this.item, required this.productName, this.itemType = 'product', this.workerName});
}

final cartSelectedWorkerProvider = StateProvider<String?>((ref) => null);

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

final cartSubtotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + item.subtotal);
});

final cartServiceSubtotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.where((i) => i.type == CartItemType.service).fold(0.0, (sum, item) => sum + item.subtotal);
});

final cartPartsSubtotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.where((i) => i.type == CartItemType.product).fold(0.0, (sum, item) => sum + item.subtotal);
});

final cartDiscountProvider = StateProvider<double>((ref) => 0);

final cartTotalProvider = Provider<double>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final discount = ref.watch(cartDiscountProvider);
  return (subtotal - discount).clamp(0.0, double.infinity);
});

final paymentMethodProvider = StateProvider<String>((ref) => 'cash');
final cartWorkOrderIdProvider = StateProvider<String?>((ref) => null);

final paidAmountProvider = StateProvider<double>((ref) => 0);

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

final transactionHistoryProvider = StreamProvider<List<TransactionModel>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final range = ref.watch(historyDateRangeProvider);
  final user = ref.watch(authStateProvider).value;
  
  // Temporary: get recent and filter locally, in real app use firestore compound queries
  return repo.getRecentTransactions(100).map((transactions) {
    return transactions.where((t) {
      bool inRange = !t.createdAt.isBefore(range.start) && !t.createdAt.isAfter(range.end);
      bool isUser = user?.role == 'cashier' ? t.userId == user?.id : true;
      return inRange && isUser;
    }).toList();
  });
});

final transactionItemsProvider = FutureProvider.family<List<TransactionDetail>, String>((ref, txnId) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final items = await repo.getTransactionItems(txnId);
  return items.map((i) {
    return TransactionDetail(
      item: i,
      productName: i.productName ?? (i.itemType == 'service' ? 'Jasa' : 'Produk'),
      itemType: i.itemType,
      workerName: i.workerName,
    );
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
