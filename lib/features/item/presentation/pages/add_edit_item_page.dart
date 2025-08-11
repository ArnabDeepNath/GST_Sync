import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gspappv2/features/item/domain/models/item.dart';
import 'package:gspappv2/features/item/presentation/bloc/item_bloc.dart';

class AddEditItemPage extends StatefulWidget {
  final Item? item;
  final String storeId;

  const AddEditItemPage({
    super.key,
    this.item,
    required this.storeId,
  });

  @override
  State<AddEditItemPage> createState() => _AddEditItemPageState();
}

class _AddEditItemPageState extends State<AddEditItemPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _unitPriceController;
  late TextEditingController _hsnController;
  late TextEditingController _taxRateController;
  String _selectedUQC = UQCCodes.PCS; // Default to PCS (pieces)

  bool get isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _unitPriceController = TextEditingController(
        text: widget.item?.unitPrice.toString() ?? '0.00');
    _hsnController = TextEditingController(text: widget.item?.hsn ?? '');
    _taxRateController =
        TextEditingController(text: widget.item?.taxRate.toString() ?? '0.00');
    _selectedUQC = widget.item?.uqc ?? UQCCodes.PCS;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitPriceController.dispose();
    _hsnController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  void _saveItem() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final unitPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
      final hsn = _hsnController.text.isNotEmpty ? _hsnController.text : null;
      final taxRate = double.tryParse(_taxRateController.text) ?? 0.0;

      if (isEditing) {
        final updatedItem = widget.item!.copyWith(
          name: name,
          unitPrice: unitPrice,
          hsn: hsn,
          taxRate: taxRate,
          uqc: _selectedUQC,
        );
        context.read<ItemBloc>().add(UpdateItemEvent(updatedItem));
      } else {
        context.read<ItemBloc>().add(
              AddItemEvent(
                storeId: widget.storeId,
                name: name,
                unitPrice: unitPrice,
                hsn: hsn,
                taxRate: taxRate,
                uqc: _selectedUQC,
              ),
            );
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Item' : 'Add New Item'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveItem,
          ),
        ],
      ),
      body: BlocListener<ItemBloc, ItemState>(
        listener: (context, state) {
          if (state is ItemError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    hintText: 'Enter the name of the item',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter item name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _unitPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Unit Price *',
                    hintText: 'Enter the price per unit',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter unit price';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price < 0) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hsnController,
                  decoration: const InputDecoration(
                    labelText: 'HSN/SAC Code',
                    hintText: 'Enter HSN/SAC code (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _taxRateController,
                  decoration: const InputDecoration(
                    labelText: 'Tax Rate (%) *',
                    hintText: 'Enter the tax rate percentage',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.percent),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter tax rate';
                    }
                    final rate = double.tryParse(value);
                    if (rate == null || rate < 0 || rate > 100) {
                      return 'Please enter a valid tax rate (0-100)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Unit of Measurement (UQC) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  value: _selectedUQC,
                  items: UQCCodes.getAllUQCs()
                      .map(
                        (uqc) => DropdownMenuItem<String>(
                          value: uqc['code'],
                          child: Text('${uqc['name']} (${uqc['code']})'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedUQC = value;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a UQC';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saveItem,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    isEditing ? 'Update Item' : 'Save Item',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
