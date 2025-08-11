import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gspappv2/features/store/domain/models/store.dart';

class StoreRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Add a new store
  Future<Store> addStore({
    required String name,
    required String address,
    String? gstin,
    String? description,
    String? phone,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final storeData = {
      'name': name,
      'address': address,
      'gstin': gstin,
      'description': description,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .add(storeData);

    // Get the document with server timestamp
    final snapshot = await docRef.get();
    return Store.fromSnapshot(snapshot);
  }

  // Update store
  Future<void> updateStore(Store store) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(store.id)
        .update(store.toMap());
  }

  // Get stores
  Stream<List<Store>> getStores() {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Store.fromSnapshot(doc)).toList());
  }

  // Get store by ID
  Future<Store> getStoreById(String storeId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final doc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .get();

    if (!doc.exists) {
      throw Exception('Store not found');
    }

    return Store.fromSnapshot(doc);
  }

  // Delete store
  Future<void> deleteStore(String storeId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .delete();
  }
}
