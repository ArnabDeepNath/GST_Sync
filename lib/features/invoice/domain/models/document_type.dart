enum DocumentType {
  invoice,
  returnInvoice,
  creditNote,
  debitNote,
  quotation;

  String get displayName {
    switch (this) {
      case DocumentType.invoice:
        return 'Invoice';
      case DocumentType.returnInvoice:
        return 'Return Invoice';
      case DocumentType.creditNote:
        return 'Credit Note';
      case DocumentType.debitNote:
        return 'Debit Note';
      case DocumentType.quotation:
        return 'Quotation';
    }
  }

  String get shortCode {
    switch (this) {
      case DocumentType.invoice:
        return 'INV';
      case DocumentType.returnInvoice:
        return 'RTN';
      case DocumentType.creditNote:
        return 'CRN';
      case DocumentType.debitNote:
        return 'DBN';
      case DocumentType.quotation:
        return 'QOT';
    }
  }

  // For GST filing use
  String get gstFilingType {
    switch (this) {
      case DocumentType.invoice:
        return 'R'; // Regular
      case DocumentType.returnInvoice:
        return 'R'; // Still Regular but returned
      case DocumentType.creditNote:
        return 'C'; // Credit Note
      case DocumentType.debitNote:
        return 'D'; // Debit Note
      case DocumentType.quotation:
        return ''; // Not applicable for GST filing
    }
  }

  // Is this document applicable for GST filing?
  bool get isApplicableForGstFiling {
    return this != DocumentType.quotation;
  }

  // Does this document represent a return?
  bool get isReturn {
    return this == DocumentType.returnInvoice;
  }
}
