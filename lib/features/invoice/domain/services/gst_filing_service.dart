import 'dart:convert';
import 'package:gspappv2/features/invoice/domain/models/document_type.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_with_details.dart';
import 'package:intl/intl.dart';

class GstFilingService {
  /// Convert a list of InvoiceWithDetails to GST filing format
  String convertToGstFilingFormat(
      List<InvoiceWithDetails> invoicesWithDetails) {
    // Separate invoices by direction
    final salesInvoices = invoicesWithDetails
        .where((iwd) => iwd.invoice.invoiceDirection == InvoiceDirection.sales)
        .toList();
    final purchaseInvoices = invoicesWithDetails
        .where(
            (iwd) => iwd.invoice.invoiceDirection == InvoiceDirection.purchase)
        .toList();

    // Create the combined filing data
    final filingData = {
      "saleData": _processSalesInvoices(salesInvoices),
      "purchaseData": _processPurchaseInvoices(purchaseInvoices)
    };

    // Convert to pretty-printed JSON
    return JsonEncoder.withIndent('  ').convert(filingData);
  }

  List<Map<String, dynamic>> _processSalesInvoices(
      List<InvoiceWithDetails> salesInvoices) {
    final List<Map<String, dynamic>> saleData = [];

    for (var invoiceWithDetails in salesInvoices) {
      final invoice = invoiceWithDetails.invoice;
      final party = invoiceWithDetails.party;
      final store = invoiceWithDetails.store;
      final items = invoiceWithDetails.items;

      // Skip if it's not a GST invoice (no GSTIN) or not applicable for GST filing
      if ((party.gstin == null || party.gstin!.isEmpty) ||
          !invoice.documentType.isApplicableForGstFiling) {
        continue;
      }

      // Calculate invoice totals
      final totalInvoiceValue = invoice.totalAmount.abs();
      final totalTaxableValue = items.fold(
          0.0, (sum, item) => sum + (item.totalPrice - item.taxAmount));

      // Extract month and year for GSTR3B period
      final monthYear = DateFormat('MM-yyyy').format(invoice.invoiceDate);

      // Extract place of supply from GSTIN (first 2 digits)
      final placeOfSupply =
          party.gstin!.length >= 2 ? party.gstin!.substring(0, 2) : "";

      // Convert each item to the required format
      final itemList = items.map((item) {
        // Calculate tax amounts
        final taxAmount = item.taxAmount;
        final taxRate = item.taxRate;
        final taxableValue = item.totalPrice - taxAmount;

        // Determine IGST/CGST/SGST split based on place of supply
        final isSameState = store.gstin != null &&
            store.gstin!.length >= 2 &&
            placeOfSupply == store.gstin!.substring(0, 2);

        final igstAmount = isSameState ? 0.0 : taxAmount;
        final cgstAmount = isSameState ? taxAmount / 2 : 0.0;
        final sgstAmount = isSameState ? taxAmount / 2 : 0.0;

        return {
          "igst_amount": igstAmount,
          "cgst_amount": cgstAmount,
          "sgst_amount": sgstAmount,
          "taxable_value": taxableValue.toStringAsFixed(2),
          "hsn_code": item.hsn ?? "0000",
          "product_name": item.name,
          "item_description": item.name,
          "quantity": item.quantity.toStringAsFixed(2),
          "cess_amount": "0.00",
          "gst_rate": taxRate.toStringAsFixed(0),
          "unit_of_product": "OTH" // Default unit
        };
      }).toList(); // Create the sale data entry
      final saleEntry = {
        "document_number": invoice.invoiceNumber,
        "document_date":
            DateFormat('dd/MMM/yy').format(invoice.invoiceDate).toLowerCase(),
        "supply_type": "NOR", // Normal supply
        "invoice_status": (invoice.originalDocumentId != null &&
                invoice.documentType == DocumentType.invoice)
            ? "Amended"
            : "Add",
        "invoice_category": "TXN", // Regular transaction
        "invoice_type": invoice.documentType.gstFilingType,
        "total_invoice_value": totalInvoiceValue,
        "total_taxable_value": totalTaxableValue,
        "txpd_taxtable_value": totalTaxableValue,
        "gstr3b_return_period": monthYear,
        "reverse_charge": "N",
        "isamended": (invoice.originalDocumentId != null &&
                invoice.documentType == DocumentType.invoice)
            ? "Y"
            : "N",
        "place_of_supply": placeOfSupply,
        "supplier_gstin": store.gstin ?? "",
        "buyer_gstin": party.gstin ?? "",
        "customer_name": party.name,
        "itemList": itemList
      };

      // Add reference to original document for amended invoices, credit and debit notes
      if (invoice.originalDocumentId != null &&
          invoice.originalDocumentNumber != null) {
        saleEntry["original_document_number"] =
            invoice.originalDocumentNumber as Object;
        saleEntry["reason"] =
            (invoice.reason ?? "No reason specified") as Object;
      }

      saleData.add(saleEntry);
    }

    return saleData;
  }

  List<Map<String, dynamic>> _processPurchaseInvoices(
      List<InvoiceWithDetails> purchaseInvoices) {
    final List<Map<String, dynamic>> purchaseData = [];

    for (var invoiceWithDetails in purchaseInvoices) {
      final invoice = invoiceWithDetails.invoice;
      final party = invoiceWithDetails.party;
      final store = invoiceWithDetails.store;
      final items = invoiceWithDetails.items;

      // Skip if it's not a GST invoice (no GSTIN) or not applicable for GST filing
      if ((party.gstin == null || party.gstin!.isEmpty) ||
          !invoice.documentType.isApplicableForGstFiling) {
        continue;
      }

      // Calculate invoice totals (use absolute values)
      final totalInvoiceValue = invoice.totalAmount.abs();
      final totalTaxableValue = items.fold(0.0,
          (sum, item) => sum + (item.totalPrice.abs() - item.taxAmount.abs()));

      // Extract month and year for GSTR3B period
      final monthYear = DateFormat('MM-yyyy').format(invoice.invoiceDate);

      // Extract place of supply from GSTIN (first 2 digits)
      final placeOfSupply =
          party.gstin!.length >= 2 ? party.gstin!.substring(0, 2) : "";

      // Convert each item to the required format
      final itemList = items.map((item) {
        // Calculate tax amounts (use absolute values)
        final taxAmount = item.taxAmount.abs();
        final taxRate = item.taxRate;
        final taxableValue = item.totalPrice.abs() - taxAmount;

        // Determine IGST/CGST/SGST split based on place of supply
        final isSameState = store.gstin != null &&
            store.gstin!.length >= 2 &&
            placeOfSupply == store.gstin!.substring(0, 2);

        final igstAmount = isSameState ? 0.0 : taxAmount;
        final cgstAmount = isSameState ? taxAmount / 2 : 0.0;
        final sgstAmount = isSameState ? taxAmount / 2 : 0.0;

        return {
          "igst_amount": igstAmount,
          "cgst_amount": cgstAmount,
          "sgst_amount": sgstAmount,
          "taxable_value": taxableValue.toStringAsFixed(2),
          "hsn_code": item.hsn ?? "0000",
          "product_name": item.name,
          "item_description": item.name,
          "quantity": item.quantity.toStringAsFixed(2),
          "cess_amount": "0.00",
          "gst_rate": taxRate.toStringAsFixed(0),
          "unit_of_product": "OTH" // Default unit
        };
      }).toList(); // For purchase invoices, party is the supplier and store is the buyer
      final purchaseEntry = {
        "document_number": invoice.invoiceNumber,
        "document_date":
            DateFormat('dd/MMM/yy').format(invoice.invoiceDate).toLowerCase(),
        "supply_type": "NOR", // Normal supply
        "invoice_status": (invoice.originalDocumentId != null &&
                invoice.documentType == DocumentType.invoice)
            ? "Amended"
            : "Add",
        "invoice_category": "TXN", // Regular transaction
        "invoice_type": invoice.documentType.gstFilingType,
        "total_invoice_value": totalInvoiceValue,
        "total_taxable_value": totalTaxableValue,
        "txpd_taxtable_value": totalTaxableValue,
        "gstr3b_return_period": monthYear,
        "reverse_charge": "N",
        "isamended": (invoice.originalDocumentId != null &&
                invoice.documentType == DocumentType.invoice)
            ? "Y"
            : "N",
        "place_of_supply": placeOfSupply,
        "supplier_gstin": party.gstin ?? "",
        "buyer_gstin": store.gstin ?? "",
        "customer_name": store.name, // In purchase, the store is the customer
        "itemList": itemList
      };

      // Add reference to original document for amended invoices, credit and debit notes
      if (invoice.originalDocumentId != null &&
          invoice.originalDocumentNumber != null) {
        purchaseEntry["original_document_number"] =
            invoice.originalDocumentNumber as Object;
        purchaseEntry["reason"] =
            (invoice.reason ?? "No reason specified") as Object;
      }

      purchaseData.add(purchaseEntry);
    }

    return purchaseData;
  }
}
