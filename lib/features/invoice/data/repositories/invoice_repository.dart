import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_item.dart';
import 'package:csv/csv.dart';

class InvoiceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  // Add a new invoice
  Future<Invoice> addInvoice({
    required String storeId,
    required String partyId,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required double totalAmount,
    required double taxAmount,
    String? notes,
    List<Map<String, dynamic>>? items,
    String? invoiceDirection,
    String? documentType,
    String? originalDocumentId,
    String? originalDocumentNumber,
    String? reason,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    final invoiceData = {
      'partyId': partyId,
      'invoiceNumber': invoiceNumber,
      'invoiceDate': Timestamp.fromDate(invoiceDate),
      'totalAmount': totalAmount,
      'taxAmount': taxAmount,
      'notes': notes,
      'storeId': storeId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'invoiceDirection': invoiceDirection ?? 'sales',
      'documentType': documentType ?? 'invoice',
      'originalDocumentId': originalDocumentId,
      'originalDocumentNumber': originalDocumentNumber,
      'reason': reason,
    };

    // Use a transaction to create the invoice and its items
    final docRef = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .add(invoiceData);

    // If items are provided, add them to the invoice
    if (items != null && items.isNotEmpty) {
      await addItemsToInvoice(storeId, docRef.id, items);
    }

    // Get the document with server timestamp
    final snapshot = await docRef.get();
    return Invoice.fromSnapshot(snapshot);
  }

  // Update invoice
  Future<void> updateInvoice(Invoice invoice) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(invoice.storeId)
        .collection('invoices')
        .doc(invoice.id)
        .update(invoice.toMap());
  }

  // Get invoices for a store
  Stream<List<Invoice>> getInvoices(String storeId, {String? partyId}) {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    var query = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .orderBy('invoiceDate', descending: true);

    if (partyId != null) {
      query = query.where('partyId', isEqualTo: partyId);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Invoice.fromSnapshot(doc)).toList());
  }

  // Get invoice by ID
  Future<Invoice> getInvoiceById(String storeId, String invoiceId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final doc = await _firestore
        .collection('users')
        .doc(currentUserId)
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

  // Delete invoice
  Future<void> deleteInvoice(String storeId, String invoiceId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // First delete all items associated with this invoice
    final itemsSnapshot = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .doc(invoiceId)
        .collection('items')
        .get();

    final batch = _firestore.batch();

    for (var doc in itemsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Then delete the invoice itself
    batch.delete(_firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .doc(invoiceId));

    await batch.commit();
  }

  // Add items to an invoice
  Future<void> addItemsToInvoice(String storeId, String invoiceId,
      List<Map<String, dynamic>> items) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final batch = _firestore.batch();

    for (var item in items) {
      final itemRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('stores')
          .doc(storeId)
          .collection('invoices')
          .doc(invoiceId)
          .collection('items')
          .doc();

      batch.set(itemRef, {
        'name': item['name'],
        'quantity': item['quantity'],
        'unitPrice': item['unitPrice'],
        'taxRate': item['taxRate'],
        'totalPrice': item['totalPrice'],
        'hsn': item['hsn'],
        'invoiceId': invoiceId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Get items for an invoice
  Stream<List<InvoiceItem>> getInvoiceItems(String storeId, String invoiceId) {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .doc(invoiceId)
        .collection('items')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => InvoiceItem.fromSnapshot(doc)).toList());
  }

  // Import invoices from CSV
  Future<ImportResult> importInvoicesFromCsv(
      String storeId, String csvContent) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final List<List<dynamic>> rowsAsListOfValues =
        const CsvToListConverter().convert(csvContent);

    // Skip header row and validate format
    if (rowsAsListOfValues.isEmpty || rowsAsListOfValues[0].length < 6) {
      throw Exception('Invalid CSV format. Please use the correct template.');
    }

    final List<String> successfulImports = [];
    final List<String> failedImports = [];
    int totalProcessed = 0;

    // Start from index 1 to skip header row
    for (var i = 1; i < rowsAsListOfValues.length; i++) {
      try {
        final row = rowsAsListOfValues[i];
        if (row.length < 6) continue; // Skip invalid rows

        final invoiceData = {
          'invoiceNumber': row[0]?.toString().trim() ?? '',
          'invoiceDate': _parseDate(row[1]?.toString().trim()),
          'partyId': row[2]?.toString().trim() ?? '',
          'totalAmount': _parseDouble(row[3]?.toString().trim()),
          'taxAmount': _parseDouble(row[4]?.toString().trim()),
          'notes': row[5]?.toString().trim(),
          'invoiceDirection':
              row[6]?.toString().trim().toLowerCase() == 'purchase'
                  ? 'purchase'
                  : 'sales',
          'documentType': 'invoice',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'storeId': storeId,
        };

        // Basic validation
        if (((invoiceData['invoiceNumber'] as String?)?.isEmpty ?? true)) {
          throw Exception('Invoice number is required');
        }

        if (((invoiceData['partyId'] as String?)?.isEmpty ?? true)) {
          throw Exception('Party ID is required');
        }

        // Add to Firestore
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('stores')
            .doc(storeId)
            .collection('invoices')
            .add(invoiceData);

        successfulImports.add(invoiceData['invoiceNumber'] as String);
        totalProcessed++;
      } catch (e) {
        failedImports.add('Row ${i + 1}: ${e.toString()}');
      }
    }

    return ImportResult(
      successful: successfulImports,
      failed: failedImports,
      totalProcessed: totalProcessed,
    );
  }

  Timestamp _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return Timestamp.fromDate(DateTime.now());
    }
    try {
      // Try parsing common date formats
      DateTime date;
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          date = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        } else {
          date = DateTime.now();
        }
      } else if (dateStr.contains('-')) {
        date = DateTime.parse(dateStr);
      } else {
        date = DateTime.now();
      }
      return Timestamp.fromDate(date);
    } catch (e) {
      return Timestamp.fromDate(DateTime.now());
    }
  }

  double _parseDouble(String? value) {
    if (value == null || value.isEmpty) return 0.0;
    try {
      return double.parse(value.replaceAll(',', ''));
    } catch (e) {
      return 0.0;
    }
  }
}

class ImportResult {
  final List<String> successful;
  final List<String> failed;
  final int totalProcessed;

  ImportResult({
    required this.successful,
    required this.failed,
    required this.totalProcessed,
  });
}
