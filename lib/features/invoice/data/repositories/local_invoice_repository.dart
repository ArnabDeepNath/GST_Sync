import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_model.dart';
import 'package:gspappv2/features/invoice/data/repositories/invoice_repository.dart';

class LocalInvoiceRepository extends InvoiceRepository {
  static const String _key = 'invoices';
  final SharedPreferences _prefs;

  LocalInvoiceRepository(this._prefs);

  @override
  Future<List<Invoice>> getAll() async {
    final String? data = _prefs.getString(_key);
    if (data == null) return [];

    final List<dynamic> jsonList = json.decode(data);
    return jsonList.map((json) => Invoice.fromJson(json)).toList();
  }

  @override
  Future<Invoice> add(Invoice invoice) async {
    final invoices = await getAll();
    invoices.add(invoice);
    await _saveInvoices(invoices);
    return invoice;
  }

  @override
  Future<void> update(Invoice invoice) async {
    final invoices = await getAll();
    final index = invoices.indexWhere((i) => i.id == invoice.id);
    if (index != -1) {
      invoices[index] = invoice;
      await _saveInvoices(invoices);
    }
  }

  @override
  Future<void> delete(String id) async {
    final invoices = await getAll();
    invoices.removeWhere((invoice) => invoice.id == id);
    await _saveInvoices(invoices);
  }

  Future<void> _saveInvoices(List<Invoice> invoices) async {
    final String data = json.encode(invoices.map((i) => i.toJson()).toList());
    await _prefs.setString(_key, data);
  }
}
