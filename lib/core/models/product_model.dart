import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? categoryId;
  final String? brand;
  final String? motorType;
  final int stockQty;
  final int stockMin;
  final double costPrice;
  final double sellPrice;
  final double? sellPriceWholesale;
  final String unit;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ProductModel({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.categoryId,
    this.brand,
    this.motorType,
    this.stockQty = 0,
    this.stockMin = 5,
    this.costPrice = 0.0,
    this.sellPrice = 0.0,
    this.sellPriceWholesale,
    this.unit = 'pcs',
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      sku: data['sku'],
      barcode: data['barcode'],
      categoryId: data['categoryId'],
      brand: data['brand'],
      motorType: data['motorType'],
      stockQty: data['stockQty'] ?? 0,
      stockMin: data['stockMin'] ?? 5,
      costPrice: (data['costPrice'] as num?)?.toDouble() ?? 0.0,
      sellPrice: (data['sellPrice'] as num?)?.toDouble() ?? 0.0,
      sellPriceWholesale: (data['sellPriceWholesale'] as num?)?.toDouble(),
      unit: data['unit'] ?? 'pcs',
      imageUrl: data['imageUrl'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'categoryId': categoryId,
      'brand': brand,
      'motorType': motorType,
      'stockQty': stockQty,
      'stockMin': stockMin,
      'costPrice': costPrice,
      'sellPrice': sellPrice,
      'sellPriceWholesale': sellPriceWholesale,
      'unit': unit,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? sku,
    String? barcode,
    String? categoryId,
    String? brand,
    String? motorType,
    int? stockQty,
    int? stockMin,
    double? costPrice,
    double? sellPrice,
    double? sellPriceWholesale,
    String? unit,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      brand: brand ?? this.brand,
      motorType: motorType ?? this.motorType,
      stockQty: stockQty ?? this.stockQty,
      stockMin: stockMin ?? this.stockMin,
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      sellPriceWholesale: sellPriceWholesale ?? this.sellPriceWholesale,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
