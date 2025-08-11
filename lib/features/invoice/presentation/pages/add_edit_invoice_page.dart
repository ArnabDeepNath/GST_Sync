import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_item.dart';
import 'package:gspappv2/features/invoice/presentation/bloc/invoice_bloc.dart';
import 'package:gspappv2/features/invoice/presentation/widgets/item_selection_dialog_fixed.dart';
import 'package:gspappv2/features/party/domain/models/party.dart';
import 'package:gspappv2/features/party/presentation/bloc/party_bloc.dart';
import 'package:gspappv2/features/store/presentation/pages/store_selector.dart';
import 'package:gspappv2/features/store/domain/models/store.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
// import 'package:gspappv2/features/invoice/presentation/widgets/item_selection_dialog.dart';

class AddEditInvoicePage extends StatefulWidget {
  final Invoice? invoice;
  final String storeId;

  const AddEditInvoicePage({
    super.key,
    this.invoice,
    required this.storeId,
    required InvoiceDirection invoiceDirection,
  });

  @override
  State<AddEditInvoicePage> createState() => _AddEditInvoicePageState();
}

class _AddEditInvoicePageState extends State<AddEditInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberController = TextEditingController();
  final _dateController = TextEditingController();
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  String? _selectedPartyId;
  Party? _selectedParty;
  final List<InvoiceItem> _items = [];
  Store? _selectedStore;

  @override
  void initState() {
    super.initState();
    _invoiceNumberController.text = widget.invoice?.invoiceNumber ?? '';
    _dateController.text = widget.invoice?.invoiceDate != null
        ? DateFormat('dd/MM/yyyy').format(widget.invoice!.invoiceDate)
        : DateFormat('dd/MM/yyyy').format(DateTime.now());
    _notesController = TextEditingController(text: widget.invoice?.notes ?? '');
    _selectedDate = widget.invoice?.invoiceDate ?? DateTime.now();
    _selectedPartyId = widget.invoice?.partyId;

    if (widget.invoice != null) {
      _loadInvoiceItems(widget.invoice!);
    }

    // Load parties when page opens
    context.read<PartyBloc>().add(LoadParties(widget.storeId));
  }

  Future<void> _loadInvoiceItems(Invoice invoice) async {
    // This would be where you would load the invoice items
    // from the repository using invoice.id
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.invoice == null ? 'Add Invoice' : 'Edit Invoice'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _invoiceNumberController,
              decoration: const InputDecoration(labelText: 'Invoice Number'),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter invoice number' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Date'),
              readOnly: true,
              onTap: () => _selectDate(context),
            ),
            const SizedBox(height: 16),
            BlocBuilder<PartyBloc, PartyState>(
              builder: (context, state) {
                if (state is PartiesLoaded) {
                  return DropdownButtonFormField<String>(
                    value: _selectedPartyId,
                    decoration:
                        const InputDecoration(labelText: 'Select Party'),
                    items: state.parties.map((party) {
                      return DropdownMenuItem(
                        value: party.id,
                        child: Text(party.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPartyId = value;
                        _selectedParty =
                            state.parties.firstWhere((p) => p.id == value);
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select a party' : null,
                  );
                }
                return const CircularProgressIndicator();
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildItemsList(),
            ElevatedButton(
              onPressed: _addItem,
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveInvoice,
        child: const Icon(Icons.save),
      ),
    );
  }

  Widget _buildItemsList() {
    return Column(
      children: [
        const Text('Items', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            return ListTile(
              title: Text(item.name),
              subtitle: Text(
                'Qty: ${item.quantity} × ₹${item.unitPrice} = ₹${item.totalPrice}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _removeItem(index),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _addItem() async {
    final item = await showDialog<InvoiceItem>(
      context: context,
      builder: (context) => ItemSelectionDialog(
        storeId: widget.storeId,
      ),
    );

    if (item != null) {
      setState(() {
        _items.add(item);
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _saveInvoice() {
    if (_formKey.currentState?.validate() ?? false) {
      // Calculate totals
      final totalAmount =
          _items.fold(0.0, (sum, item) => sum + item.totalPrice);
      final taxAmount = _items.fold(0.0, (sum, item) => sum + item.taxAmount);

      if (widget.invoice == null) {
        // Create new invoice
        context.read<InvoiceBloc>().add(AddInvoice(
              storeId: widget.storeId,
              partyId: _selectedPartyId!,
              invoiceNumber: _invoiceNumberController.text,
              invoiceDate: _selectedDate,
              totalAmount: totalAmount,
              taxAmount: taxAmount,
              notes: _notesController.text,
              items: _items
                  .map((item) => {
                        'name': item.name,
                        'quantity': item.quantity,
                        'unitPrice': item.unitPrice,
                        'taxRate': item.taxRate,
                        'totalPrice': item.totalPrice,
                        'hsn': item.hsn,
                      })
                  .toList(),
            ));
      } else {
        // Update existing invoice
        context.read<InvoiceBloc>().add(UpdateInvoice(
              Invoice(
                id: widget.invoice!.id,
                invoiceNumber: _invoiceNumberController.text,
                invoiceDate: _selectedDate,
                partyId: _selectedPartyId!,
                totalAmount: totalAmount,
                taxAmount: taxAmount,
                notes: _notesController.text,
                storeId: widget.storeId,
                createdAt: widget.invoice!.createdAt,
                updatedAt: DateTime.now(),
              ),
            ));
      }

      Navigator.pop(context);
    }
  }
}
