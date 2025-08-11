import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gspappv2/features/store/presentation/providers/store_provider.dart';
import 'package:gspappv2/features/store/domain/models/store.dart';
import 'package:gspappv2/features/party/domain/models/party.dart';

class DrawerStoreSelector extends StatelessWidget {
  const DrawerStoreSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);
    final selectedStore = storeProvider.selectedStore;
    final stores = storeProvider.stores;
    final isLoading = storeProvider.isLoading;
    final error = storeProvider.error;
    final selectedPartyType = storeProvider.selectedPartyType;

    // Show loading state
    if (isLoading) {
      return const ListTile(
        leading: Icon(Icons.store),
        title: Text('Loading stores...'),
        subtitle: LinearProgressIndicator(),
      );
    }

    // Show error state
    if (error != null) {
      return ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Error loading stores'),
        subtitle: Text(error, style: const TextStyle(color: Colors.red)),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => storeProvider.loadStores(),
        ),
      );
    }

    // No stores found
    if (stores.isEmpty) {
      return ListTile(
        leading: const Icon(Icons.store_outlined),
        title: const Text('No stores found'),
        subtitle: const Text('Add a store to get started'),
        trailing: IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _showAddStoreDialog(context),
        ),
      );
    }

    // Show store dropdown and party type selector
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Store Selector
        ExpansionTile(
          leading: const Icon(Icons.store),
          title: Text(selectedStore?.name ?? 'Select Store'),
          subtitle: selectedStore != null
              ? Text(selectedStore.address)
              : const Text('Select a store to continue'),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => storeProvider.loadStores(),
            tooltip: 'Refresh stores',
          ),
          children: [
            ...stores.map((store) => ListTile(
                  selected: store.id == selectedStore?.id,
                  title: Text(store.name),
                  subtitle: Text(store.address),
                  trailing: stores.length > 1
                      ? PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') {
                              _showDeleteStoreDialog(context, store);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete, color: Colors.red),
                                title: Text('Delete Store',
                                    style: TextStyle(color: Colors.red)),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        )
                      : null, // Don't show delete option if only one store exists
                  onTap: () {
                    storeProvider.selectStore(store);
                    Navigator.pop(context); // Close drawer
                  },
                )),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add New Store'),
              onTap: () => _showAddStoreDialog(context),
            ),
          ],
        ),

        // Party Type Selector
        if (selectedStore != null) ...[
          const Divider(),
          ListTile(
            leading: Icon(
              selectedPartyType == PartyType.buyer
                  ? Icons.people
                  : Icons.business,
              color: selectedPartyType == PartyType.buyer
                  ? Colors.blue
                  : Colors.green,
            ),
            title: const Text('View Mode'),
            subtitle: Text(
              selectedPartyType == PartyType.buyer
                  ? 'Showing Customers'
                  : 'Showing Suppliers',
              style: TextStyle(
                color: selectedPartyType == PartyType.buyer
                    ? Colors.blue
                    : Colors.green,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildTypeButton(
                    context,
                    type: PartyType.buyer,
                    icon: Icons.people,
                    label: 'Customers',
                    isSelected: selectedPartyType == PartyType.buyer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTypeButton(
                    context,
                    type: PartyType.seller,
                    icon: Icons.business,
                    label: 'Suppliers',
                    isSelected: selectedPartyType == PartyType.seller,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildTypeButton(
    BuildContext context, {
    required PartyType type,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    final color = type == PartyType.buyer ? Colors.blue : Colors.green;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final storeProvider =
              Provider.of<StoreProvider>(context, listen: false);
          storeProvider.togglePartyType(type);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.grey.withOpacity(0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show dialog to add a new store
  void _showAddStoreDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final gstinController = TextEditingController();
    final phoneController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Store'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Store Name*'),
                  validator: (value) => value?.isEmpty ?? true
                      ? 'Please enter a store name'
                      : null,
                ),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address*'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter an address' : null,
                ),
                TextFormField(
                  controller: gstinController,
                  decoration:
                      const InputDecoration(labelText: 'GSTIN (Optional)'),
                ),
                TextFormField(
                  controller: phoneController,
                  decoration:
                      const InputDecoration(labelText: 'Phone (Optional)'),
                ),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                      labelText: 'Description (Optional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final storeProvider =
                    Provider.of<StoreProvider>(context, listen: false);
                storeProvider.addStore(
                  name: nameController.text.trim(),
                  address: addressController.text.trim(),
                  gstin: gstinController.text.isEmpty
                      ? null
                      : gstinController.text.trim(),
                  phone: phoneController.text.isEmpty
                      ? null
                      : phoneController.text.trim(),
                  description: descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  } // Show dialog to confirm store deletion

  void _showDeleteStoreDialog(BuildContext context, Store store) {
    final confirmationController = TextEditingController();
    bool isConfirmationValid = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Delete Store'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete "${store.name}"?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'This action will permanently delete:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• All parties (customers and suppliers)'),
                    Text('• All items and inventory'),
                    Text('• All invoices and their items'),
                    Text('• All reports and filing records'),
                    Text('• All other store data'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone!',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'To confirm deletion, please type the store name below:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmationController,
                decoration: InputDecoration(
                  hintText: store.name,
                  border: const OutlineInputBorder(),
                  errorBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    isConfirmationValid = value.trim() == store.name;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isConfirmationValid
                  ? () {
                      // Close the confirmation dialog first
                      Navigator.pop(context);
                      // Call the delete function with better error handling
                      _performStoreDelete(context, store);
                    }
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: isConfirmationValid ? Colors.red : Colors.grey,
              ),
              child: const Text('Delete Store'),
            ),
          ],
        ),
      ),
    );
  }

  // Separate method to perform the actual deletion with better error handling
  void _performStoreDelete(BuildContext context, Store store) async {
    OverlayEntry? loadingOverlay;

    try {
      // Create and show loading overlay
      loadingOverlay = OverlayEntry(
        builder: (context) => Material(
          color: Colors.black54,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting store and all associated data...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Add overlay to show loading
      Overlay.of(context).insert(loadingOverlay);

      // Get store provider and perform deletion
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      await storeProvider.deleteStore(store.id);

      // Remove loading overlay
      loadingOverlay.remove();
      loadingOverlay = null;

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Store "${store.name}" has been deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Remove loading overlay if it exists
      loadingOverlay?.remove();

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting store: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
