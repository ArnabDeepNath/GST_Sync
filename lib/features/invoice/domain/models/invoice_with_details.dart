import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_item.dart';
import 'package:gspappv2/features/party/domain/models/party.dart';
import 'package:gspappv2/features/store/domain/models/store.dart';

/// A class that combines an invoice with its related party, store, and items
/// Used for displaying a complete invoice in the preview and PDF generation
class InvoiceWithDetails {
  final Invoice invoice;
  final Party party;
  final List<InvoiceItem> items;
  final Store store;

  InvoiceWithDetails({
    required this.invoice,
    required this.party,
    required this.items,
    required this.store,
  });

  /// Calculate the total tax amount for all items
  double get totalTaxAmount {
    return items.fold(0.0, (sum, item) => sum + item.taxAmount);
  }

  /// Calculate the subtotal (amount before tax)
  double get subtotal {
    return invoice.totalAmount - totalTaxAmount;
  }
}
