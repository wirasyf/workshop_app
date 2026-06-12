import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleModel {
  final String id;
  final String customerName;
  final String? phoneNumber;
  final String plateNumber;
  final String? vehicleBrand;
  final String? vehicleType;
  final int? vehicleYear;
  final String? notes;
  final DateTime createdAt;

  VehicleModel({
    required this.id,
    required this.customerName,
    this.phoneNumber,
    required this.plateNumber,
    this.vehicleBrand,
    this.vehicleType,
    this.vehicleYear,
    this.notes,
    required this.createdAt,
  });

  factory VehicleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VehicleModel(
      id: doc.id,
      customerName: data['customerName'] ?? '',
      phoneNumber: data['phoneNumber'],
      plateNumber: data['plateNumber'] ?? '',
      vehicleBrand: data['vehicleBrand'],
      vehicleType: data['vehicleType'],
      vehicleYear: data['vehicleYear'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerName': customerName,
      'phoneNumber': phoneNumber,
      'plateNumber': plateNumber,
      'vehicleBrand': vehicleBrand,
      'vehicleType': vehicleType,
      'vehicleYear': vehicleYear,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
