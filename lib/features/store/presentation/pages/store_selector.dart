import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gspappv2/features/store/domain/models/store.dart';

class StoreSelector extends StatefulWidget {
  final void Function(Store) onStoreSelected;

  const StoreSelector({
    Key? key,
    required this.onStoreSelected,
  }) : super(key: key);

  @override
  State<StoreSelector> createState() => _StoreSelectorState();
}

class _StoreSelectorState extends State<StoreSelector> {
  Store? _selectedStore;
  bool _isLoading = true;
  String? _error;
  List<Store> _stores = [];

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _error = 'User not authenticated';
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('stores')
          .orderBy('createdAt', descending: true)
          .get();

      final stores =
          snapshot.docs.map((doc) => Store.fromSnapshot(doc)).toList();

      setState(() {
        _stores = stores;
        _isLoading = false;
        if (stores.isNotEmpty) {
          _selectedStore = stores[0];
          widget.onStoreSelected(_selectedStore!);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $_error', style: TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadStores,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_stores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No stores found. Create your first store.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Navigate to add store page
                },
                child: const Text('Add Store'),
              ),
            ],
          ),
        ),
      );
    }

    return DropdownButton<Store>(
      value: _selectedStore,
      isExpanded: true,
      hint: const Text('Select a store'),
      onChanged: (Store? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedStore = newValue;
          });
          widget.onStoreSelected(newValue);
        }
      },
      items: _stores.map<DropdownMenuItem<Store>>((Store store) {
        return DropdownMenuItem<Store>(
          value: store,
          child: Text(store.name),
        );
      }).toList(),
    );
  }
}
