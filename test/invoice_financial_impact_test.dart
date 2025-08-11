import 'package:flutter_test/flutter_test.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:gspappv2/features/invoice/domain/models/document_type.dart';

void main() {
  group('Invoice Financial Impact Tests', () {
    // Test data
    final testDate = DateTime.now();
    const String testStoreId = 'store1';
    const String testPartyId = 'party1';
    const double testAmount = 1000.0;
    const double testTaxAmount = 180.0;

    group('Sales Invoices', () {
      test('Regular sales invoice should have positive financial impact', () {
        final invoice = Invoice(
          id: 'test1',
          invoiceNumber: 'INV-001',
          invoiceDate: testDate,
          partyId: testPartyId,
          totalAmount: testAmount,
          taxAmount: testTaxAmount,
          storeId: testStoreId,
          createdAt: testDate,
          updatedAt: testDate,
          invoiceDirection: InvoiceDirection.sales,
          documentType: DocumentType.invoice,
        );

        expect(invoice.financialImpact, equals(testAmount));
        expect(invoice.isIncome, isTrue);
        expect(invoice.isExpense, isFalse);
      });

      test('Sales credit note should have negative financial impact', () {
        final invoice = Invoice(
          id: 'test2',
          invoiceNumber: 'CRN-001',
          invoiceDate: testDate,
          partyId: testPartyId,
          totalAmount:
              -testAmount, // Credit notes are stored with negative amounts
          taxAmount: -testTaxAmount,
          storeId: testStoreId,
          createdAt: testDate,
          updatedAt: testDate,
          invoiceDirection: InvoiceDirection.sales,
          documentType: DocumentType.creditNote,
        );

        expect(invoice.financialImpact, equals(-testAmount));
        expect(invoice.isIncome, isFalse);
        expect(invoice.isExpense, isTrue);
      });

      test('Sales debit note should have positive financial impact', () {
        final invoice = Invoice(
          id: 'test3',
          invoiceNumber: 'DBN-001',
          invoiceDate: testDate,
          partyId: testPartyId,
          totalAmount:
              testAmount, // Debit notes are stored with positive amounts
          taxAmount: testTaxAmount,
          storeId: testStoreId,
          createdAt: testDate,
          updatedAt: testDate,
          invoiceDirection: InvoiceDirection.sales,
          documentType: DocumentType.debitNote,
        );

        expect(invoice.financialImpact, equals(testAmount));
        expect(invoice.isIncome, isTrue);
        expect(invoice.isExpense, isFalse);
      });

      test('Sales return invoice should have negative financial impact', () {
        final invoice = Invoice(
          id: 'test4',
          invoiceNumber: 'RTN-001',
          invoiceDate: testDate,
          partyId: testPartyId,
          totalAmount:
              testAmount, // Return invoices are stored with positive amounts
          taxAmount: testTaxAmount,
          storeId: testStoreId,
          createdAt: testDate,
          updatedAt: testDate,
          invoiceDirection: InvoiceDirection.sales,
          documentType: DocumentType.returnInvoice,
        );

        expect(invoice.financialImpact,
            equals(-testAmount)); // Should be negative due to return logic
        expect(invoice.isIncome, isFalse);
        expect(invoice.isExpense, isTrue);
      });
    });

    group('Purchase Invoices', () {
      test('Regular purchase invoice should have negative financial impact',
          () {
        final invoice = Invoice(
          id: 'test5',
          invoiceNumber: 'PINV-001',
          invoiceDate: testDate,
          partyId: testPartyId,
          totalAmount: testAmount,
          taxAmount: testTaxAmount,
          storeId: testStoreId,
          createdAt: testDate,
          updatedAt: testDate,
          invoiceDirection: InvoiceDirection.purchase,
          documentType: DocumentType.invoice,
        );

        expect(invoice.financialImpact, equals(-testAmount));
        expect(invoice.isIncome, isFalse);
        expect(invoice.isExpense, isTrue);
      });

      test('Purchase credit note should have positive financial impact', () {
        final invoice = Invoice(
          id: 'test6',
          invoiceNumber: 'PCRN-001',
          invoiceDate: testDate,
          partyId: testPartyId,
          totalAmount:
              -testAmount, // Credit notes are stored with negative amounts
          taxAmount: -testTaxAmount,
          storeId: testStoreId,
          createdAt: testDate,
          updatedAt: testDate,
          invoiceDirection: InvoiceDirection.purchase,
          documentType: DocumentType.creditNote,
        );

        expect(invoice.financialImpact,
            equals(testAmount)); // Double negative = positive
        expect(invoice.isIncome, isTrue);
        expect(invoice.isExpense, isFalse);
      });

      test('Purchase debit note should have negative financial impact', () {
        final invoice = Invoice(
          id: 'test7',
          invoiceNumber: 'PDBN-001',
          invoiceDate: testDate,
          partyId: testPartyId,
          totalAmount:
              testAmount, // Debit notes are stored with positive amounts
          taxAmount: testTaxAmount,
          storeId: testStoreId,
          createdAt: testDate,
          updatedAt: testDate,
          invoiceDirection: InvoiceDirection.purchase,
          documentType: DocumentType.debitNote,
        );

        expect(invoice.financialImpact, equals(-testAmount));
        expect(invoice.isIncome, isFalse);
        expect(invoice.isExpense, isTrue);
      });

      test('Purchase return invoice should have positive financial impact', () {
        final invoice = Invoice(
          id: 'test8',
          invoiceNumber: 'PRTN-001',
          invoiceDate: testDate,
          partyId: testPartyId,
          totalAmount:
              testAmount, // Return invoices are stored with positive amounts
          taxAmount: testTaxAmount,
          storeId: testStoreId,
          createdAt: testDate,
          updatedAt: testDate,
          invoiceDirection: InvoiceDirection.purchase,
          documentType: DocumentType.returnInvoice,
        );

        expect(invoice.financialImpact,
            equals(testAmount)); // Purchase return = money back
        expect(invoice.isIncome, isTrue);
        expect(invoice.isExpense, isFalse);
      });
    });

    group('Document Creation Methods', () {
      test('createCreditNote should create note with negative amounts', () {
        final originalInvoice = Invoice(
          id: 'original',
          invoiceNumber: 'INV-001',
          invoiceDate: testDate,
          partyId: testPartyId,
          totalAmount: testAmount,
          taxAmount: testTaxAmount,
          storeId: testStoreId,
          createdAt: testDate,
          updatedAt: testDate,
          invoiceDirection: InvoiceDirection.sales,
          documentType: DocumentType.invoice,
        );

        final creditNote = originalInvoice.createCreditNote(
          newId: 'credit1',
          newInvoiceNumber: 'CRN-001',
        );

        expect(creditNote.totalAmount, equals(-testAmount));
        expect(creditNote.taxAmount, equals(-testTaxAmount));
        expect(creditNote.documentType, equals(DocumentType.creditNote));
        expect(creditNote.invoiceDirection, equals(InvoiceDirection.sales));
        expect(creditNote.financialImpact, equals(-testAmount));
      });

      test('createDebitNote should create note with positive amounts', () {
        final originalInvoice = Invoice(
          id: 'original',
          invoiceNumber: 'INV-001',
          invoiceDate: testDate,
          partyId: testPartyId,
          totalAmount: testAmount,
          taxAmount: testTaxAmount,
          storeId: testStoreId,
          createdAt: testDate,
          updatedAt: testDate,
          invoiceDirection: InvoiceDirection.sales,
          documentType: DocumentType.invoice,
        );

        const double additionalAmount = 200.0;
        const double additionalTax = 36.0;

        final debitNote = originalInvoice.createDebitNote(
          newId: 'debit1',
          newInvoiceNumber: 'DBN-001',
          newTotalAmount: additionalAmount,
          newTaxAmount: additionalTax,
        );

        expect(debitNote.totalAmount, equals(additionalAmount));
        expect(debitNote.taxAmount, equals(additionalTax));
        expect(debitNote.documentType, equals(DocumentType.debitNote));
        expect(debitNote.invoiceDirection, equals(InvoiceDirection.sales));
        expect(debitNote.financialImpact, equals(additionalAmount));
      });
    });

    group('Edge Cases', () {
      test('Zero amount invoice should have zero financial impact', () {
        final invoice = Invoice(
          id: 'test9',
          invoiceNumber: 'ZERO-001',
          invoiceDate: testDate,
          partyId: testPartyId,
          totalAmount: 0.0,
          taxAmount: 0.0,
          storeId: testStoreId,
          createdAt: testDate,
          updatedAt: testDate,
          invoiceDirection: InvoiceDirection.sales,
          documentType: DocumentType.invoice,
        );

        expect(invoice.financialImpact, equals(0.0));
        expect(invoice.isIncome, isFalse);
        expect(invoice.isExpense, isFalse);
      });

      test('Quotation should have same logic as regular invoice', () {
        final salesQuotation = Invoice(
          id: 'test10',
          invoiceNumber: 'QOT-001',
          invoiceDate: testDate,
          partyId: testPartyId,
          totalAmount: testAmount,
          taxAmount: testTaxAmount,
          storeId: testStoreId,
          createdAt: testDate,
          updatedAt: testDate,
          invoiceDirection: InvoiceDirection.sales,
          documentType: DocumentType.quotation,
        );

        expect(salesQuotation.financialImpact, equals(testAmount));

        final purchaseQuotation = Invoice(
          id: 'test11',
          invoiceNumber: 'PQOT-001',
          invoiceDate: testDate,
          partyId: testPartyId,
          totalAmount: testAmount,
          taxAmount: testTaxAmount,
          storeId: testStoreId,
          createdAt: testDate,
          updatedAt: testDate,
          invoiceDirection: InvoiceDirection.purchase,
          documentType: DocumentType.quotation,
        );

        expect(purchaseQuotation.financialImpact, equals(-testAmount));
      });
    });
  });
}
