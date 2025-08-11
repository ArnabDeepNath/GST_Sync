import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gspappv2/features/invoice/domain/models/invoice_item_model.dart';
import 'package:gspappv2/features/item/domain/models/item.dart';
import 'package:gspappv2/features/item/presentation/bloc/item_bloc.dart';
import 'package:gspappv2/features/store/presentation/providers/store_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class AddItemDialog extends StatefulWidget {
  final String storeId;

  const AddItemDialog({
    super.key,
    required this.storeId,
  });

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hsnController = TextEditingController();
  final _quantityController = TextEditingController();
  final _rateController = TextEditingController();
  final _taxRateController = TextEditingController(text: '18.0');

  Item? selectedItem;
  bool _isManualEntry = true;

  @override
  void initState() {
    super.initState();
    // Load items when dialog opens
    context.read<ItemBloc>().add(LoadItems(widget.storeId));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hsnController.dispose();
    _quantityController.dispose();
    _rateController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  void _handleItemSelection(Item item) {
    setState(() {
      selectedItem = item;
      _nameController.text = item.name;
      _hsnController.text = item.hsn ?? '';
      _rateController.text = item.unitPrice.toString();
      _taxRateController.text = item.taxRate.toString();
      _isManualEntry = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Item'),
      content: BlocBuilder<ItemBloc, ItemState>(
        builder: (context, state) {
          return SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Selection Section
                  if (state is ItemsLoaded && state.items.isNotEmpty) ...[
                    const Text(
                      'Select from saved items:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 150,
                      width: double.maxFinite,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: state.items.length,
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          return ListTile(
                            title: Text(item.name),
                            subtitle: Text(
                              '₹${item.unitPrice.toStringAsFixed(2)} | Tax: ${item.taxRate}%',
                            ),
                            selected: selectedItem?.id == item.id,
                            onTap: () => _handleItemSelection(item),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('OR'),
                        ),
                        Expanded(
                          child: Divider(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Manual Entry Section
                  Row(
                    children: [
                      const Text(
                        'Manual Entry:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (selectedItem != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedItem = null;
                              _isManualEntry = true;
                            });
                          },
                          child: const Text('Clear Selection'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    enabled: _isManualEntry,
                    decoration: const InputDecoration(labelText: 'Item Name *'),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter item name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _hsnController,
                    enabled: _isManualEntry,
                    decoration:
                        const InputDecoration(labelText: 'HSN/SAC (Optional)'),
                  ),
                  TextFormField(
                    controller: _rateController,
                    enabled: _isManualEntry,
                    decoration:
                        const InputDecoration(labelText: 'Unit Price *'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter unit price';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _taxRateController,
                    enabled: _isManualEntry,
                    decoration:
                        const InputDecoration(labelText: 'Tax Rate (%) *'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter tax rate';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Quantity is always editable regardless of item selection
                  TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity *'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter quantity';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final quantity = double.parse(_quantityController.text);
              final rate = double.parse(_rateController.text);
              final taxRate =
                  double.parse(_taxRateController.text); // Used for item save
              final item = InvoiceItem(
                id: const Uuid().v4(),
                name: _nameController.text,
                hsn: _hsnController.text.isEmpty ? 'N/A' : _hsnController.text,
                quantity: quantity.toInt(),
                rate: rate,
                amount: quantity * rate,
              );

              // Optionally save as a reusable item if not selected from existing ones
              if (selectedItem == null && _isManualEntry) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Save Item'),
                    content: const Text(
                        'Do you want to save this as a reusable item?'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context, item);
                        },
                        child: const Text('No'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Save the item using the taxRate variable
                          context.read<ItemBloc>().add(
                                AddItemEvent(
                                  storeId: widget.storeId,
                                  name: _nameController.text,
                                  unitPrice: rate,
                                  hsn: _hsnController.text.isEmpty
                                      ? null
                                      : _hsnController.text,
                                  taxRate: taxRate, // Using taxRate
                                  uqc: UQCCodes.PCS, // Default to PCS
                                ),
                              );
                          Navigator.pop(context);
                          Navigator.pop(context, item);
                        },
                        child: const Text('Yes, Save Item'),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.pop(context, item);
              }
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
