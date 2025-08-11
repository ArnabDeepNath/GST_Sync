import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceItem {
  final String id;
  final String name;
  final double quantity;
  final double unitPrice;
  final double taxRate;
  final double totalPrice;
  final String? hsn;
  final String invoiceId; // Reference to the invoice
  final DateTime createdAt;

  InvoiceItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.taxRate,
    required this.totalPrice,
    this.hsn,
    required this.invoiceId,
    required this.createdAt,
  });

  // Calculate tax amount based on unit price, quantity, and tax rate
  double get taxAmount => (unitPrice * quantity) * (taxRate / 100);

  // Factory constructor to create an InvoiceItem from a DocumentSnapshot
  factory InvoiceItem.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return InvoiceItem(
      id: snapshot.id,
      name: data['name'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      taxRate: (data['taxRate'] ?? 0).toDouble(),
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
      hsn: data['hsn'],
      invoiceId: data['invoiceId'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Convert InvoiceItem to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'taxRate': taxRate,
      'totalPrice': totalPrice,
      'hsn': hsn,
      'invoiceId': invoiceId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // // Calculate tax amount
  // double get taxAmount => totalPrice * taxRate / 100;

  // Calculate price before tax
  double get priceBeforeTax => totalPrice - taxAmount;
}
