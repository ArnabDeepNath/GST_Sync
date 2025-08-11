import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class User extends Equatable {
  final String id;
  final String name;
  final String gstin;
  final String email;
  final String? phone;
  final String? address;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    required this.gstin,
    required this.email,
    this.phone,
    this.address,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, name, gstin, email, phone, address, createdAt];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gstin': gstin,
      'email': email,
      'phone': phone,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      gstin: json['gstin'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      address: json['address'],
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String? gstin;
  final String? photoURL;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    this.gstin,
    this.photoURL,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor to create a UserModel from a DocumentSnapshot
  factory UserModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return UserModel(
      id: snapshot.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      gstin: data['gstin'],
      photoURL: data['photoURL'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Convert UserModel to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'gstin': gstin,
      'photoURL': photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Create a copy of the UserModel with updated fields
  UserModel copyWith({
    String? name,
    String? phoneNumber,
    String? gstin,
    String? photoURL,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gstin: gstin ?? this.gstin,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
