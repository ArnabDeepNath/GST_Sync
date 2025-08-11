import 'package:cloud_firestore/cloud_firestore.dart';

class Store {
  final String id;
  final String name;
  final String address;
  final String? gstin;
  final String? description;
  final String? phone;
  final DateTime createdAt;
  final DateTime updatedAt;

  Store({
    required this.id,
    required this.name,
    required this.address,
    this.gstin,
    this.description,
    this.phone,
    required this.createdAt,
    required this.updatedAt,
  });
  // Factory constructor to create a Store from a DocumentSnapshot
  factory Store.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Store(
      id: snapshot.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      gstin: data['gstin'],
      description: data['description'],
      phone: data['phone'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Convert Store to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'gstin': gstin,
      'description': description,
      'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Create a copy of the Store with updated fields
  Store copyWith({
    String? name,
    String? address,
    String? gstin,
    String? description,
    String? phone,
  }) {
    return Store(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
