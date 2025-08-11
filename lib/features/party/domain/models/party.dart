import 'package:cloud_firestore/cloud_firestore.dart';

enum PartyType { buyer, seller }

class Party {
  final String id;
  final String name;
  final PartyType type;
  final String? gstin;
  final String? address;
  final String? phone;
  final String? email;
  final String storeId; // Reference to the store this party belongs to
  final DateTime createdAt;
  final DateTime updatedAt;

  Party({
    required this.id,
    required this.name,
    required this.type,
    this.gstin,
    this.address,
    this.phone,
    this.email,
    required this.storeId,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor to create a Party from a DocumentSnapshot
  factory Party.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Party(
      id: snapshot.id,
      name: data['name'] ?? '',
      type: data['type'] == 'buyer' ? PartyType.buyer : PartyType.seller,
      gstin: data['gstin'],
      address: data['address'],
      phone: data['phone'],
      email: data['email'],
      storeId: data['storeId'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Convert Party to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type == PartyType.buyer ? 'buyer' : 'seller',
      'gstin': gstin,
      'address': address,
      'phone': phone,
      'email': email,
      'storeId': storeId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Create a copy of the Party with updated fields
  Party copyWith({
    String? name,
    PartyType? type,
    String? gstin,
    String? address,
    String? phone,
    String? email,
  }) {
    return Party(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      gstin: gstin ?? this.gstin,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      storeId: storeId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
