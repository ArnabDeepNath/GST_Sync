import 'package:equatable/equatable.dart';
import 'package:gspappv2/features/party/domain/models/party_model.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_item_model.dart';

enum InvoiceType {
  b2b,
  b2c,
  sezWithPayment,
  sezWithoutPayment,
  deemedExport,
  exempt
}

class Invoice extends Equatable {
  final String id;
  final String invoiceNumber;
  final DateTime date;
  final String partyId;
  final InvoiceType type;
  final List<InvoiceItem> items;
  final double totalAmount;
  final double totalTaxAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final String? notes;
  final double received;
  final Party party;

  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    required this.partyId,
    required this.type,
    required this.items,
    required this.totalAmount,
    required this.totalTaxAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    this.notes,
    required this.received,
    required this.party,
  });

  @override
  List<Object?> get props => [
        id,
        invoiceNumber,
        date,
        partyId,
        type,
        items,
        totalAmount,
        totalTaxAmount,
        cgst,
        sgst,
        igst,
        notes,
        received,
        party,
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'date': date.toIso8601String(),
        'partyId': partyId,
        'type': type.toString(),
        'items': items.map((item) => item.toJson()).toList(),
        'totalAmount': totalAmount,
        'totalTaxAmount': totalTaxAmount,
        'cgst': cgst,
        'sgst': sgst,
        'igst': igst,
        'notes': notes,
        'received': received,
        'party': party.toJson(),
      };

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'],
        invoiceNumber: json['invoiceNumber'],
        date: DateTime.parse(json['date']),
        partyId: json['partyId'],
        type: InvoiceType.values.firstWhere(
          (e) => e.toString() == json['type'],
        ),
        items: (json['items'] as List)
            .map((item) => InvoiceItem.fromJson(item))
            .toList(),
        totalAmount: json['totalAmount'].toDouble(),
        totalTaxAmount: json['totalTaxAmount'].toDouble(),
        cgst: json['cgst'].toDouble(),
        sgst: json['sgst'].toDouble(),
        igst: json['igst'].toDouble(),
        notes: json['notes'],
        received: json['received'].toDouble(),
        party: Party.fromJson(json['party']),
      );

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    DateTime? date,
    String? partyId,
    InvoiceType? type,
    List<InvoiceItem>? items,
    double? totalAmount,
    double? totalTaxAmount,
    double? cgst,
    double? sgst,
    double? igst,
    String? notes,
    double? received,
    Party? party,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      date: date ?? this.date,
      partyId: partyId ?? this.partyId,
      type: type ?? this.type,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      totalTaxAmount: totalTaxAmount ?? this.totalTaxAmount,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
      igst: igst ?? this.igst,
      notes: notes ?? this.notes,
      received: received ?? this.received,
      party: party ?? this.party,
    );
  }
}
