import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String username;
  final String email;
  final String? avatarUrl;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final String? currentSessionId;
  final String? password;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.role = 'owner',
    this.isActive = true,
    required this.createdAt,
    this.currentSessionId,
    this.password,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      avatarUrl: data['avatarUrl'],
      role: data['role'] ?? 'owner',
      isActive: data['isActive'] ?? true,
      createdAt: _parseDate(data['createdAt']),
      currentSessionId: data['currentSessionId'],
      password: data['password'],
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'username': username,
      'email': email,
      'avatarUrl': avatarUrl,
      'role': role,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'currentSessionId': currentSessionId,
    };
    if (password != null) {
      map['password'] = password;
    }
    return map;
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? avatarUrl,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    String? currentSessionId,
    String? password,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      password: password ?? this.password,
    );
  }
}
