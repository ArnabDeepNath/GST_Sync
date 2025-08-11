import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gspappv2/features/invoice/domain/models/document_type.dart';
import 'package:intl/intl.dart';

// Define an enum for invoice direction
enum InvoiceDirection {
  sales, // Outgoing invoice (you selling to someone)
  purchase // Incoming invoice (you buying from someone)
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String partyId; // Reference to the party
  final double totalAmount;
  final double taxAmount;
  final String? notes;
  final String storeId; // Reference to the store
  final DateTime createdAt;
  final DateTime updatedAt;
  // New fields for enhanced document support
  final DocumentType
      documentType; // Type of document (invoice, return, credit note, etc.)
  final String?
      originalDocumentId; // Reference to original document if this is a return
  final String?
      originalDocumentNumber; // Original document number for reference
  final String? reason; // Reason for credit/debit note or return

  // New field to indicate if this is a sales or purchase invoice
  final InvoiceDirection invoiceDirection;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.partyId,
    required this.totalAmount,
    required this.taxAmount,
    this.notes,
    required this.storeId,
    required this.createdAt,
    required this.updatedAt,
    this.documentType = DocumentType.invoice,
    this.originalDocumentId,
    this.originalDocumentNumber,
    this.reason,
    this.invoiceDirection = InvoiceDirection.sales, // Default to sales invoice
  });

  // Factory constructor to create an Invoice from a DocumentSnapshot
  factory Invoice.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;

    // Convert string to enum for document type
    DocumentType docType = DocumentType.invoice; // Default
    if (data['documentType'] != null) {
      try {
        docType = DocumentType.values.firstWhere(
          (e) => e.toString() == 'DocumentType.${data['documentType']}',
          orElse: () => DocumentType.invoice,
        );
      } catch (_) {
        // If parsing fails, default to invoice
        docType = DocumentType.invoice;
      }
    }

    // Convert string to enum for invoice direction
    InvoiceDirection direction = InvoiceDirection.sales; // Default
    if (data['invoiceDirection'] != null) {
      try {
        direction = InvoiceDirection.values.firstWhere(
          (e) => e.toString() == 'InvoiceDirection.${data['invoiceDirection']}',
          orElse: () => InvoiceDirection.sales,
        );
      } catch (_) {
        // If parsing fails, default to sales
        direction = InvoiceDirection.sales;
      }
    }

    return Invoice(
      id: snapshot.id,
      invoiceNumber: data['invoiceNumber'] ?? '',
      invoiceDate: data['invoiceDate'] != null
          ? (data['invoiceDate'] as Timestamp).toDate()
          : DateTime.now(),
      partyId: data['partyId'] ?? '',
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      taxAmount: (data['taxAmount'] ?? 0).toDouble(),
      notes: data['notes'],
      storeId: data['storeId'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      documentType: docType,
      originalDocumentId: data['originalDocumentId'],
      originalDocumentNumber: data['originalDocumentNumber'],
      reason: data['reason'],
      invoiceDirection: direction,
    );
  }

  // Convert Invoice to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'invoiceNumber': invoiceNumber,
      'invoiceDate': Timestamp.fromDate(invoiceDate),
      'partyId': partyId,
      'totalAmount': totalAmount,
      'taxAmount': taxAmount,
      'notes': notes,
      'storeId': storeId,
      'documentType':
          documentType.toString().split('.').last, // Store enum as string
      'originalDocumentId': originalDocumentId,
      'originalDocumentNumber': originalDocumentNumber,
      'reason': reason,
      'invoiceDirection':
          invoiceDirection.toString().split('.').last, // Store enum as string
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Create a copy of the Invoice with updated fields
  Invoice copyWith({
    String? invoiceNumber,
    DateTime? invoiceDate,
    String? partyId,
    double? totalAmount,
    double? taxAmount,
    String? notes,
    DocumentType? documentType,
    String? originalDocumentId,
    String? originalDocumentNumber,
    String? reason,
    InvoiceDirection? invoiceDirection,
  }) {
    return Invoice(
      id: id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      partyId: partyId ?? this.partyId,
      totalAmount: totalAmount ?? this.totalAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      notes: notes ?? this.notes,
      storeId: storeId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      documentType: documentType ?? this.documentType,
      originalDocumentId: originalDocumentId ?? this.originalDocumentId,
      originalDocumentNumber:
          originalDocumentNumber ?? this.originalDocumentNumber,
      reason: reason ?? this.reason,
      invoiceDirection: invoiceDirection ?? this.invoiceDirection,
    );
  }

  // Create a return invoice based on this invoice
  Invoice createReturnInvoice({
    required String newId,
    required String newInvoiceNumber,
    double? newTotalAmount,
    double? newTaxAmount,
    String? newReason,
  }) {
    return Invoice(
      id: newId,
      invoiceNumber: newInvoiceNumber,
      invoiceDate: DateTime.now(),
      partyId: partyId,
      totalAmount: newTotalAmount ?? totalAmount,
      taxAmount: newTaxAmount ?? taxAmount,
      notes: notes,
      storeId: storeId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      documentType: DocumentType.returnInvoice,
      originalDocumentId: id,
      originalDocumentNumber: invoiceNumber,
      reason: newReason ?? 'Return against invoice $invoiceNumber',
      invoiceDirection: invoiceDirection, // Keep the same direction
    );
  }

  // Create a credit note based on this invoice
  Invoice createCreditNote({
    required String newId,
    required String newInvoiceNumber,
    double? newTotalAmount,
    double? newTaxAmount,
    String? newReason,
  }) {
    return Invoice(
      id: newId,
      invoiceNumber: newInvoiceNumber,
      invoiceDate: DateTime.now(),
      partyId: partyId,
      // Credit notes have negative values compared to the original invoice
      totalAmount: -(newTotalAmount ?? totalAmount),
      taxAmount: -(newTaxAmount ?? taxAmount),
      notes: notes,
      storeId: storeId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      documentType: DocumentType.creditNote,
      originalDocumentId: id,
      originalDocumentNumber: invoiceNumber,
      reason: newReason ?? 'Credit note for invoice $invoiceNumber',
      invoiceDirection: invoiceDirection, // Keep the same direction
    );
  }

  // Create a debit note based on this invoice
  Invoice createDebitNote({
    required String newId,
    required String newInvoiceNumber,
    required double newTotalAmount,
    required double newTaxAmount,
    String? newReason,
  }) {
    return Invoice(
      id: newId,
      invoiceNumber: newInvoiceNumber,
      invoiceDate: DateTime.now(),
      partyId: partyId,
      totalAmount: newTotalAmount,
      taxAmount: newTaxAmount,
      notes: notes,
      storeId: storeId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      documentType: DocumentType.debitNote,
      originalDocumentId: id,
      originalDocumentNumber: invoiceNumber,
      reason: newReason ?? 'Debit note for invoice $invoiceNumber',
      invoiceDirection: invoiceDirection, // Keep the same direction
    );
  }

  // Convert this invoice to a quotation
  Invoice createQuotationFromInvoice({
    required String newId,
    required String newQuotationNumber,
  }) {
    return Invoice(
      id: newId,
      invoiceNumber: newQuotationNumber,
      invoiceDate: DateTime.now(),
      partyId: partyId,
      totalAmount: totalAmount,
      taxAmount: taxAmount,
      notes: notes,
      storeId: storeId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      documentType: DocumentType.quotation,
      invoiceDirection: invoiceDirection, // Keep the same direction
    );
  }

  // Convert a quotation to an invoice
  Invoice createInvoiceFromQuotation({
    required String newId,
    required String newInvoiceNumber,
  }) {
    return Invoice(
      id: newId,
      invoiceNumber: newInvoiceNumber,
      invoiceDate: DateTime.now(),
      partyId: partyId,
      totalAmount: totalAmount,
      taxAmount: taxAmount,
      notes: notes,
      storeId: storeId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      documentType: DocumentType.invoice,
      originalDocumentId: documentType == DocumentType.quotation ? id : null,
      originalDocumentNumber:
          documentType == DocumentType.quotation ? invoiceNumber : null,
      invoiceDirection: invoiceDirection, // Keep the same direction
    );
  }

  // Create an amended invoice based on this invoice
  Invoice createAmendedInvoice({
    required String newId,
    required String newInvoiceNumber,
    String? newReason,
  }) {
    // For amendments, we simply reverse the original amount:
    // - If original was positive, amendment is negative
    // - If original was negative, amendment is positive
    // This effectively cancels out the original transaction
    double amendedTotalAmount = -totalAmount;
    double amendedTaxAmount = -taxAmount;

    return Invoice(
      id: newId,
      invoiceNumber: newInvoiceNumber,
      invoiceDate: DateTime.now(),
      partyId: partyId,
      totalAmount: amendedTotalAmount,
      taxAmount: amendedTaxAmount,
      notes: notes,
      storeId: storeId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      documentType: DocumentType.invoice, // Amended invoices are still invoices
      originalDocumentId: id,
      originalDocumentNumber: invoiceNumber,
      reason: newReason ?? 'Amended version of invoice $invoiceNumber',
      invoiceDirection: invoiceDirection, // Keep the same direction
    );
  }

  // Get a display title based on document type
  String get displayTitle {
    return '${documentType.displayName} #$invoiceNumber';
  }

  // Get formatted properties
  String get formattedDate {
    final formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(invoiceDate);
  }

  // Get the document status for display
  String get status {
    if (documentType == DocumentType.returnInvoice) {
      return 'Returned';
    } else if (documentType == DocumentType.creditNote) {
      return 'Credited';
    } else if (documentType == DocumentType.debitNote) {
      return 'Debited';
    } else if (documentType == DocumentType.quotation) {
      return 'Quotation';
    } else {
      return 'Regular';
    }
  }

  // New methods for financial calculations  // Calculate the financial impact of this document
  // Positive means money coming in, negative means money going out
  double get financialImpact {
    double amount = totalAmount;

    // For purchase invoices: negative is outgoing money, positive is incoming (refund)
    // For sales invoices: positive is incoming money, negative is outgoing
    if (invoiceDirection == InvoiceDirection.purchase) {
      amount = -amount;
    }

    // Return invoices should reverse the direction (stored as positive but should reduce sales/increase purchase refunds)
    if (documentType == DocumentType.returnInvoice) {
      amount = -amount;
    }

    // Credit notes are already stored with negative amounts in the database, so no additional processing needed
    // Debit notes are stored with positive amounts and should add to the transaction, so no additional processing needed

    return amount;
  }

  // Check if this document represents income (money coming in)
  bool get isIncome {
    return financialImpact > 0;
  }

  // Check if this document represents expense (money going out)
  bool get isExpense {
    return financialImpact < 0;
  }

  // Get display text for invoice direction
  String get directionText {
    return invoiceDirection == InvoiceDirection.sales ? 'Sales' : 'Purchase';
  }

  // For display purposes - combines document type and direction
  String get fullDocumentTypeDisplay {
    return '${documentType.displayName} (${directionText})';
  }
}
