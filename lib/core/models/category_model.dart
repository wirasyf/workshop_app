import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  final String slug;
  final String? parentId;

  CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      slug: data['slug'] ?? '',
      parentId: data['parentId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'parentId': parentId,
    };
  }
}

class ServiceCategoryModel {
  final String id;
  final String name;
  final String slug;

  ServiceCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory ServiceCategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceCategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      slug: data['slug'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
    };
  }
}
