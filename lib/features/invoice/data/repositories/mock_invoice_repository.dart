import 'package:gspappv2/core/repositories/base_repository.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_model.dart';

class MockInvoiceRepository implements BaseRepository<Invoice> {
  final List<Invoice> _invoices = [];

  @override
  Future<List<Invoice>> getAll() async {
    return _invoices;
  }

  @override
  Future<Invoice> add(Invoice invoice) async {
    _invoices.add(invoice);
    return invoice;
  }

  @override
  Future<void> update(Invoice invoice) async {
    final index = _invoices.indexWhere((i) => i.id == invoice.id);
    if (index != -1) {
      _invoices[index] = invoice;
    }
  }

  @override
  Future<void> delete(String id) async {
    _invoices.removeWhere((invoice) => invoice.id == id);
  }
}
