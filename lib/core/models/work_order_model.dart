import 'package:cloud_firestore/cloud_firestore.dart';

class WorkOrderModel {
  final String id;
  final String orderNo;
  final String vehicleId;
  final String userId;
  final String status;
  final String? complaint;
  final String? diagnosis;
  final double totalService;
  final double totalParts;
  final double grandTotal;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime? completedAt;

  WorkOrderModel({
    required this.id,
    required this.orderNo,
    required this.vehicleId,
    required this.userId,
    this.status = 'waiting',
    this.complaint,
    this.diagnosis,
    this.totalService = 0.0,
    this.totalParts = 0.0,
    this.grandTotal = 0.0,
    this.transactionId,
    required this.createdAt,
    this.completedAt,
  });

  factory WorkOrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkOrderModel(
      id: doc.id,
      orderNo: data['orderNo'] ?? '',
      vehicleId: data['vehicleId'] ?? '',
      userId: data['userId'] ?? '',
      status: data['status'] ?? 'waiting',
      complaint: data['complaint'],
      diagnosis: data['diagnosis'],
      totalService: (data['totalService'] as num?)?.toDouble() ?? 0.0,
      totalParts: (data['totalParts'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (data['grandTotal'] as num?)?.toDouble() ?? 0.0,
      transactionId: data['transactionId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderNo': orderNo,
      'vehicleId': vehicleId,
      'userId': userId,
      'status': status,
      'complaint': complaint,
      'diagnosis': diagnosis,
      'totalService': totalService,
      'totalParts': totalParts,
      'grandTotal': grandTotal,
      'transactionId': transactionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  WorkOrderModel copyWith({
    String? id,
    String? orderNo,
    String? vehicleId,
    String? userId,
    String? status,
    String? complaint,
    String? diagnosis,
    double? totalService,
    double? totalParts,
    double? grandTotal,
    String? transactionId,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return WorkOrderModel(
      id: id ?? this.id,
      orderNo: orderNo ?? this.orderNo,
      vehicleId: vehicleId ?? this.vehicleId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      complaint: complaint ?? this.complaint,
      diagnosis: diagnosis ?? this.diagnosis,
      totalService: totalService ?? this.totalService,
      totalParts: totalParts ?? this.totalParts,
      grandTotal: grandTotal ?? this.grandTotal,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
