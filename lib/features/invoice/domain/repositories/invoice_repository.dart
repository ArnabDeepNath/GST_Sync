import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_item.dart';

class InvoiceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all invoices for a store
  Stream<List<Invoice>> getInvoices(String storeId) {
    return _firestore
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .orderBy('invoiceDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Invoice.fromSnapshot(doc)).toList();
    });
  }

  /// Get an invoice by ID
  Future<Invoice> getInvoiceById(String storeId, String invoiceId) async {
    final doc = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .doc(invoiceId)
        .get();

    if (!doc.exists) {
      throw Exception('Invoice not found');
    }

    return Invoice.fromSnapshot(doc);
  }

  /// Get items for an invoice
  Stream<List<InvoiceItem>> getInvoiceItems(String storeId, String invoiceId) {
    return _firestore
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .doc(invoiceId)
        .collection('items')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => InvoiceItem.fromSnapshot(doc)).toList();
    });
  }

  /// Add a new invoice
  Future<String> addInvoice(String storeId, Invoice invoice) async {
    // Create a document reference with a new ID
    final docRef = _firestore
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .doc();

    // Create the invoice with the generated ID
    final invoiceWithId = Invoice(
      id: docRef.id,
      invoiceNumber: invoice.invoiceNumber,
      invoiceDate: invoice.invoiceDate,
      partyId: invoice.partyId,
      totalAmount: invoice.totalAmount,
      taxAmount: invoice.taxAmount,
      notes: invoice.notes,
      storeId: storeId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Set the document
    await docRef.set(invoiceWithId.toMap());

    return docRef.id;
  }

  /// Add items to an invoice
  Future<void> addInvoiceItems(
      String storeId, String invoiceId, List<InvoiceItem> items) async {
    final batch = _firestore.batch();

    for (var item in items) {
      final docRef = _firestore
          .collection('stores')
          .doc(storeId)
          .collection('invoices')
          .doc(invoiceId)
          .collection('items')
          .doc();

      // Create the item with the generated ID
      final itemWithId = InvoiceItem(
        id: docRef.id,
        name: item.name,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        taxRate: item.taxRate,
        totalPrice: item.totalPrice,
        hsn: item.hsn,
        invoiceId: invoiceId,
        createdAt: DateTime.now(),
      );

      batch.set(docRef, itemWithId.toMap());
    }

    await batch.commit();
  }

  /// Update an invoice
  Future<void> updateInvoice(String storeId, Invoice invoice) async {
    await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .doc(invoice.id)
        .update(invoice.toMap());
  }

  /// Delete an invoice and its items
  Future<void> deleteInvoice(String storeId, String invoiceId) async {
    final batch = _firestore.batch();

    // Delete the invoice document
    final invoiceRef = _firestore
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .doc(invoiceId);

    batch.delete(invoiceRef);

    // Get all items for this invoice
    final itemsSnapshot = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .doc(invoiceId)
        .collection('items')
        .get();

    // Delete each item
    for (var doc in itemsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
