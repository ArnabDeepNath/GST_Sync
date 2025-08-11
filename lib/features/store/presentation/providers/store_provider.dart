import 'package:flutter/material.dart';
import 'package:gspappv2/features/store/domain/models/store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gspappv2/features/party/domain/models/party.dart';

class StoreProvider extends ChangeNotifier {
  Store? _selectedStore;
  List<Store> _stores = [];
  bool _isLoading = false;
  String? _error;
  PartyType _selectedPartyType = PartyType.buyer; // Default to customer view

  Store? get selectedStore => _selectedStore;
  List<Store> get stores => _stores;
  bool get isLoading => _isLoading;
  String? get error => _error;
  PartyType get selectedPartyType =>
      _selectedPartyType; // Initialize provider and load stores
  Future<void> initialize() async {
    await loadStores();

    // Try to restore the last selected store
    final prefs = await SharedPreferences.getInstance();
    final lastSelectedStoreId = prefs.getString('selected_store_id');
    final savedPartyType = prefs.getString('selected_party_type');

    if (savedPartyType != null) {
      _selectedPartyType = PartyType.values.firstWhere(
        (type) => type.toString() == savedPartyType,
        orElse: () => PartyType.buyer,
      );
    }

    if (lastSelectedStoreId != null && _stores.isNotEmpty) {
      final store = _stores.firstWhere(
        (store) => store.id == lastSelectedStoreId,
        orElse: () => _stores.first,
      );
      selectStore(store);
    } else if (_stores.isNotEmpty) {
      selectStore(_stores.first);
    }
  }

  // Load all stores for the current user
  Future<void> loadStores() async {
    print('StoreProvider: loadStores() called');
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _error = 'User not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('stores')
          .orderBy('createdAt', descending: true)
          .get();

      _stores = snapshot.docs.map((doc) => Store.fromSnapshot(doc)).toList();
      _isLoading = false;

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Select a store and save to preferences
  Future<void> selectStore(Store store) async {
    _selectedStore = store;
    notifyListeners();

    // Save the selected store ID to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_store_id', store.id);
  }

  // Toggle between customer and supplier view
  Future<void> togglePartyType(PartyType type) async {
    _selectedPartyType = type;
    notifyListeners();

    // Save the selected party type to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_party_type', type.toString());
  }

  // Add a new store
  Future<void> addStore({
    required String name,
    required String address,
    String? gstin,
    String? phone,
    String? description,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _error = 'User not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final storeData = {
        'name': name,
        'address': address,
        'gstin': gstin,
        'phone': phone,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('stores')
          .add(storeData);

      // Reload stores
      await loadStores();

      // Find and select the newly added store
      final addedStore = _stores.firstWhere((store) => store.id == docRef.id);
      selectStore(addedStore);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete a store
  Future<void> deleteStore(String storeId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _error = 'User not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      // Get reference to the store document
      final storeRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('stores')
          .doc(storeId);

      // Delete all subcollections before deleting the store
      // Note: In Firestore, deleting a document doesn't automatically delete its subcollections
      // We need to delete them manually for proper cleanup

      // Delete all parties
      final partiesSnapshot = await storeRef.collection('parties').get();
      for (var doc in partiesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all items
      final itemsSnapshot = await storeRef.collection('items').get();
      for (var doc in itemsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all invoices and their items
      final invoicesSnapshot = await storeRef.collection('invoices').get();
      for (var invoiceDoc in invoicesSnapshot.docs) {
        // Delete invoice items
        final itemsSnapshot =
            await invoiceDoc.reference.collection('items').get();
        for (var itemDoc in itemsSnapshot.docs) {
          batch.delete(itemDoc.reference);
        }
        // Delete the invoice
        batch.delete(invoiceDoc.reference);
      }

      // Delete all reports
      final reportsSnapshot = await storeRef.collection('reports').get();
      for (var doc in reportsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Finally, delete the store document itself
      batch.delete(storeRef);

      // Commit all deletions
      await batch.commit();

      // If the deleted store was selected, clear selection or select another store
      if (_selectedStore?.id == storeId) {
        _selectedStore = null;

        // Clear saved selected store from preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('selected_store_id');
      }

      // Reload stores
      await loadStores();

      // If no store is selected and there are stores available, select the first one
      if (_selectedStore == null && _stores.isNotEmpty) {
        selectStore(_stores.first);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
