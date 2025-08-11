import 'package:equatable/equatable.dart';

enum PartyType {
  unregistered,
  registeredRegular,
  registeredComposite,
}

class Party extends Equatable {
  final String id;
  final String name;
  final String? gstin;
  final PartyType type;
  final double totalTaxableValue;
  final int totalInvoices;
  final int totalCDNs;
  final DateTime lastUpdated;
  final double monthlyAverage;
  final double previousMonthValue;
  final String address;
  final String? phone;
  final String? email;
  final double balance;

  const Party({
    required this.id,
    required this.name,
    this.gstin,
    required this.type,
    this.totalTaxableValue = 0.0,
    this.totalInvoices = 0,
    this.totalCDNs = 0,
    required this.lastUpdated,
    this.monthlyAverage = 0.0,
    this.previousMonthValue = 0.0,
    required this.address,
    this.phone,
    this.email,
    this.balance = 0.0,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        gstin,
        totalTaxableValue,
        totalInvoices,
        totalCDNs,
        lastUpdated,
        monthlyAverage,
        previousMonthValue,
        address,
        phone,
        email,
        balance,
      ];

  Party copyWith({
    String? id,
    String? name,
    String? gstin,
    PartyType? type,
    double? totalTaxableValue,
    int? totalInvoices,
    int? totalCDNs,
    DateTime? lastUpdated,
    double? monthlyAverage,
    double? previousMonthValue,
    String? address,
    String? phone,
    String? email,
    double? balance,
  }) {
    return Party(
      id: id ?? this.id,
      name: name ?? this.name,
      gstin: gstin ?? this.gstin,
      type: type ?? this.type,
      totalTaxableValue: totalTaxableValue ?? this.totalTaxableValue,
      totalInvoices: totalInvoices ?? this.totalInvoices,
      totalCDNs: totalCDNs ?? this.totalCDNs,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      monthlyAverage: monthlyAverage ?? this.monthlyAverage,
      previousMonthValue: previousMonthValue ?? this.previousMonthValue,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      balance: balance ?? this.balance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'gstin': gstin,
      'totalTaxableValue': totalTaxableValue,
      'totalInvoices': totalInvoices,
      'totalCDNs': totalCDNs,
      'lastUpdated': lastUpdated.toIso8601String(),
      'monthlyAverage': monthlyAverage,
      'previousMonthValue': previousMonthValue,
      'address': address,
      'phone': phone,
      'email': email,
      'balance': balance,
    };
  }

  factory Party.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert to double
    double safeDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value.isFinite ? value : 0.0;
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed?.isFinite == true ? parsed! : 0.0;
      }
      return 0.0;
    }

    // Helper function to safely convert to int
    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.isFinite ? value.toInt() : 0;
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? 0;
      }
      return 0;
    }

    return Party(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      gstin: json['gstin']?.toString(),
      type: PartyType.values.firstWhere(
        (e) => e.toString() == (json['type'] ?? 'PartyType.unregistered'),
        orElse: () => PartyType.unregistered,
      ),
      totalTaxableValue: safeDouble(json['totalTaxableValue']),
      totalInvoices: safeInt(json['totalInvoices']),
      totalCDNs: safeInt(json['totalCDNs']),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString()) ?? DateTime.now()
          : DateTime.now(),
      monthlyAverage: safeDouble(json['monthlyAverage']),
      previousMonthValue: safeDouble(json['previousMonthValue']),
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      balance: safeDouble(json['balance']),
    );
  }
}
