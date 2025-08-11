import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // USER OPERATIONS
  // Create or update user profile
  Future<void> createOrUpdateUser({
    required String name,
    required String email,
    required String phoneNumber,
    String? gstin,
    String? photoURL,
  }) async {
    if (currentUserId == null) return;

    // Create a map directly instead of using any PigeonUserDetails
    final userData = {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'gstin': gstin,
      'photoURL': photoURL,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('users').doc(currentUserId).set(
          userData,
          SetOptions(merge: true),
        );
  }

  // Get user details
  Future<DocumentSnapshot> getUserDetails() async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    return await _firestore.collection('users').doc(currentUserId).get();
  }

  // STORE OPERATIONS
  // Add a new store
  Future<DocumentReference> addStore({
    required String name,
    required String address,
    String? gstin,
    String? description,
    String? phone,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .add({
      'name': name,
      'address': address,
      'gstin': gstin,
      'description': description,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update store
  Future<void> updateStore({
    required String storeId,
    required String name,
    required String address,
    String? gstin,
    String? description,
    String? phone,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .update({
      'name': name,
      'address': address,
      'gstin': gstin,
      'description': description,
      'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get stores
  Stream<QuerySnapshot> getStores() {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .orderBy('createdAt', descending: true)
        .snapshots();
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

  // PARTY OPERATIONS
  // Add a new party (buyer or seller)
  Future<DocumentReference> addParty({
    required String storeId,
    required String name,
    required String type, // 'buyer' or 'seller'
    String? gstin,
    String? address,
    String? phone,
    String? email,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('parties')
        .add({
      'name': name,
      'type': type,
      'gstin': gstin,
      'address': address,
      'phone': phone,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update party
  Future<void> updateParty({
    required String storeId,
    required String partyId,
    required String name,
    required String type,
    String? gstin,
    String? address,
    String? phone,
    String? email,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('parties')
        .doc(partyId)
        .update({
      'name': name,
      'type': type,
      'gstin': gstin,
      'address': address,
      'phone': phone,
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get parties for a store
  Stream<QuerySnapshot> getParties(String storeId, {String? type}) {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    var query = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('parties')
        .orderBy('name');

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    return query.snapshots();
  }

  // Delete party
  Future<void> deleteParty(String storeId, String partyId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('parties')
        .doc(partyId)
        .delete();
  }

  // INVOICE OPERATIONS
  // Add a new invoice
  Future<DocumentReference> addInvoice({
    required String storeId,
    required String partyId,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required double totalAmount,
    required double taxAmount,
    String? notes,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .add({
      'partyId': partyId,
      'invoiceNumber': invoiceNumber,
      'invoiceDate': Timestamp.fromDate(invoiceDate),
      'totalAmount': totalAmount,
      'taxAmount': taxAmount,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update invoice
  Future<void> updateInvoice({
    required String storeId,
    required String invoiceId,
    required String partyId,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required double totalAmount,
    required double taxAmount,
    String? notes,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .doc(invoiceId)
        .update({
      'partyId': partyId,
      'invoiceNumber': invoiceNumber,
      'invoiceDate': Timestamp.fromDate(invoiceDate),
      'totalAmount': totalAmount,
      'taxAmount': taxAmount,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get invoices for a store
  Stream<QuerySnapshot> getInvoices(String storeId, {String? partyId}) {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    var query = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .orderBy('invoiceDate', descending: true);

    if (partyId != null) {
      query = query.where('partyId', isEqualTo: partyId);
    }

    return query.snapshots();
  }

  // Delete invoice
  Future<void> deleteInvoice(String storeId, String invoiceId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .doc(invoiceId)
        .delete();
  }

  // ITEM OPERATIONS
  // Add items to an invoice
  Future<void> addItemsToInvoice({
    required String storeId,
    required String invoiceId,
    required List<Map<String, dynamic>> items,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Create a batch to add all items at once
    final batch = _firestore.batch();

    for (var item in items) {
      final itemRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('stores')
          .doc(storeId)
          .collection('invoices')
          .doc(invoiceId)
          .collection('items')
          .doc();

      batch.set(itemRef, {
        'name': item['name'],
        'quantity': item['quantity'],
        'unitPrice': item['unitPrice'],
        'taxRate': item['taxRate'],
        'totalPrice': item['totalPrice'],
        'hsn': item['hsn'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Get items for an invoice
  Stream<QuerySnapshot> getInvoiceItems(String storeId, String invoiceId) {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('invoices')
        .doc(invoiceId)
        .collection('items')
        .snapshots();
  }

  // REPORT OPERATIONS
  // Add a filed report
  Future<DocumentReference> addFiledReport({
    required String storeId,
    required String type,
    required String period,
    required String status,
    String? acknowledgmentNo,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('reports')
        .add({
      'type': type,
      'period': period,
      'filedDate': FieldValue.serverTimestamp(),
      'status': status,
      'acknowledgmentNo': acknowledgmentNo,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get reports for a store
  Stream<QuerySnapshot> getReports(String storeId) {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('reports')
        .orderBy('filedDate', descending: true)
        .snapshots();
  }

  // Delete a report
  Future<void> deleteReport(String storeId, String reportId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('reports')
        .doc(reportId)
        .delete();
  }

  // Update a report
  Future<void> updateReport(
      String storeId, String reportId, Map<String, dynamic> updates) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('reports')
        .doc(reportId)
        .update(updates);
  }
}
