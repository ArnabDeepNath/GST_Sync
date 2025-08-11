import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gspappv2/features/party/domain/models/party.dart';
import 'package:gspappv2/features/party/presentation/bloc/party_bloc.dart';
import 'package:gspappv2/features/party/presentation/pages/party_details_page.dart';
import 'package:uuid/uuid.dart';

class AddEditPartyPage extends StatefulWidget {
  final Party? party;
  final String storeId;
  final PartyType partyType;

  const AddEditPartyPage({
    super.key, 
    this.party, 
    required this.storeId, 
    required this.partyType
  });

  @override
  State<AddEditPartyPage> createState() => _AddEditPartyPageState();
}

class _AddEditPartyPageState extends State<AddEditPartyPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gstinController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _hasGSTIN = false;

  @override
  void initState() {
    super.initState();
    if (widget.party != null) {
      _nameController.text = widget.party!.name;
      _gstinController.text = widget.party!.gstin ?? '';
      _addressController.text = widget.party!.address ?? '';
      _phoneController.text = widget.party!.phone ?? '';
      _emailController.text = widget.party!.email ?? '';
      _hasGSTIN = widget.party!.gstin != null && widget.party!.gstin!.isNotEmpty;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gstinController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCustomer = widget.partyType == PartyType.buyer;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.party == null
              ? isCustomer ? 'Add New Customer' : 'Add New Supplier'
              : isCustomer ? 'Edit Customer' : 'Edit Supplier',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Business Type Indicator
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: isCustomer ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCustomer ? Icons.person : Icons.business,
                    color: isCustomer ? Colors.blue : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCustomer ? 'Customer Details' : 'Supplier Details',
                    style: TextStyle(
                      color: isCustomer ? Colors.blue : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: isCustomer ? 'Customer Name *' : 'Supplier Business Name *',
                hintText: isCustomer ? 'Enter customer name' : 'Enter business name',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                  isCustomer ? Icons.person_outline : Icons.business_outlined,
                  color: Colors.grey[600],
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return isCustomer 
                      ? 'Please enter customer name'
                      : 'Please enter business name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // GSTIN Switch
            SwitchListTile(
              title: const Text('Has GSTIN Number?'),
              subtitle: Text(
                isCustomer
                    ? 'Turn on if your customer has a GST registration'
                    : 'Turn on if your supplier has a GST registration',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              value: _hasGSTIN,
              onChanged: (bool value) {
                setState(() {
                  _hasGSTIN = value;
                  if (!value) {
                    _gstinController.clear();
                  }
                });
              },
              activeColor: isCustomer ? Colors.blue : Colors.green,
            ),
            const SizedBox(height: 16),

            // GSTIN Field (Conditional)
            if (_hasGSTIN) ...[
              TextFormField(
                controller: _gstinController,
                decoration: InputDecoration(
                  labelText: 'GSTIN Number *',
                  hintText: 'Enter 15-digit GSTIN',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.numbers, color: Colors.grey[600]),
                ),
                validator: (value) {
                  if (_hasGSTIN) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter GSTIN';
                    }
                    if (value.length != 15) {
                      return 'GSTIN must be 15 characters';
                    }
                  }
                  return null;
                },
                maxLength: 15,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
            ],

            // Phone Field
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter mobile number',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey[600]),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),

            // Address Field
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Address',
                hintText: 'Enter complete address',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.location_on_outlined, color: Colors.grey[600]),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Email Field
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter email address',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[600]),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCustomer ? Colors.blue : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.party == null ? 'ADD ${isCustomer ? "CUSTOMER" : "SUPPLIER"}' : 'SAVE CHANGES',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final party = Party(
        id: widget.party?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        type: widget.partyType,
        gstin: _hasGSTIN ? _gstinController.text.trim() : null,
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        storeId: widget.storeId,
        createdAt: widget.party?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.party == null) {
        // Add new party
        context.read<PartyBloc>().add(AddParty(
          storeId: party.storeId,
          name: party.name,
          type: party.type,
          gstin: party.gstin,
          address: party.address,
          phone: party.phone,
          email: party.email,
        ));
      } else {
        // Update existing party
        context.read<PartyBloc>().add(UpdateParty(party));
      }

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.party == null 
              ? '${widget.partyType == PartyType.buyer ? "Customer" : "Supplier"} added successfully'
              : 'Changes saved successfully'
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
