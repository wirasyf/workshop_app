import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String invoiceNo;
  final String userId;
  final String? cashierName;
  final String? customerId;
  final String? customerName;
  final String paymentMethod;
  final double subtotal;
  final double discount;
  final double total;
  final double paidAmount;
  final double changeAmount;
  final double totalCost;
  final String status;
  final DateTime createdAt;
  final List<TransactionItemModel>? items;

  TransactionModel({
    required this.id,
    required this.invoiceNo,
    required this.userId,
    this.cashierName,
    this.customerId,
    this.customerName,
    this.paymentMethod = 'cash',
    this.subtotal = 0.0,
    this.discount = 0.0,
    this.total = 0.0,
    this.paidAmount = 0.0,
    this.changeAmount = 0.0,
    this.totalCost = 0.0,
    this.status = 'completed',
    required this.createdAt,
    this.items,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      invoiceNo: data['invoiceNo'] ?? '',
      userId: data['userId'] ?? '',
      cashierName: data['cashierName'],
      customerId: data['customerId'],
      customerName: data['customerName'],
      paymentMethod: data['paymentMethod'] ?? 'cash',
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0.0,
      changeAmount: (data['changeAmount'] as num?)?.toDouble() ?? 0.0,
      totalCost: (data['totalCost'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'completed',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceNo': invoiceNo,
      'userId': userId,
      'cashierName': cashierName,
      'customerId': customerId,
      'customerName': customerName,
      'paymentMethod': paymentMethod,
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'paidAmount': paidAmount,
      'changeAmount': changeAmount,
      'totalCost': totalCost,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class TransactionItemModel {
  final String id;
  final String transactionId;
  final String itemType;
  final String? productId;
  final String? serviceId;
  final int qty;
  final double unitPrice;
  final double costPrice;
  final double discount;
  final double subtotal;
  final bool isApproved;
  final String? workerName;
  final String? productName;
  final bool isReturned;

  TransactionItemModel({
    required this.id,
    required this.transactionId,
    this.itemType = 'product',
    this.productId,
    this.serviceId,
    required this.qty,
    required this.unitPrice,
    this.costPrice = 0.0,
    this.discount = 0.0,
    required this.subtotal,
    this.isApproved = true,
    this.workerName,
    this.productName,
    this.isReturned = false,
  });

  factory TransactionItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionItemModel(
      id: doc.id,
      transactionId: data['transactionId'] ?? '',
      itemType: data['itemType'] ?? 'product',
      productId: data['productId'],
      serviceId: data['serviceId'],
      qty: data['qty'] ?? 1,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0.0,
      costPrice: (data['costPrice'] as num?)?.toDouble() ?? 0.0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      isApproved: data['isApproved'] ?? true,
      workerName: data['workerName'],
      productName: data['productName'],
      isReturned: data['isReturned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'itemType': itemType,
      'productId': productId,
      'serviceId': serviceId,
      'qty': qty,
      'unitPrice': unitPrice,
      'costPrice': costPrice,
      'discount': discount,
      'subtotal': subtotal,
      'isApproved': isApproved,
      'workerName': workerName,
      'productName': productName,
      'isReturned': isReturned,
    };
  }
}
