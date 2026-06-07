import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceModel {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int estimatedMinutes;
  final String? categoryId;
  final String category;
  final bool isActive;
  final DateTime createdAt;

  ServiceModel({
    required this.id,
    required this.name,
    this.description,
    this.price = 0.0,
    this.estimatedMinutes = 30,
    this.categoryId,
    this.category = 'umum',
    this.isActive = true,
    required this.createdAt,
  });

  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      estimatedMinutes: data['estimatedMinutes'] ?? 30,
      categoryId: data['categoryId'],
      category: data['category'] ?? 'umum',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'estimatedMinutes': estimatedMinutes,
      'categoryId': categoryId,
      'category': category,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
