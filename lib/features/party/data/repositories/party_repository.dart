import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gspappv2/features/party/domain/models/party.dart';
import 'package:csv/csv.dart';

class PartyRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Add a new party
  Future<Party> addParty({
    required String storeId,
    required String name,
    required PartyType type,
    String? gstin,
    String? address,
    String? phone,
    String? email,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final partyData = {
      'name': name,
      'type': type == PartyType.buyer ? 'buyer' : 'seller',
      'gstin': gstin,
      'address': address,
      'phone': phone,
      'email': email,
      'storeId': storeId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('parties')
        .add(partyData);

    // Get the document with server timestamp
    final snapshot = await docRef.get();
    return Party.fromSnapshot(snapshot);
  }

  // Update party
  Future<void> updateParty(Party party) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(party.storeId)
        .collection('parties')
        .doc(party.id)
        .update(party.toMap());
  }

  // Get parties for a store
  Stream<List<Party>> getParties(String storeId, {PartyType? type}) {
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
      query = query.where('type',
          isEqualTo: type == PartyType.buyer ? 'buyer' : 'seller');
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Party.fromSnapshot(doc)).toList());
  }

  // Get party by ID
  Future<Party> getPartyById(String storeId, String partyId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final doc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('parties')
        .doc(partyId)
        .get();

    if (!doc.exists) {
      throw Exception('Party not found');
    }

    return Party.fromSnapshot(doc);
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

  // Import parties from CSV
  Future<ImportResult> importPartiesFromCsv(
      String storeId, String csvContent) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final List<List<dynamic>> rowsAsListOfValues =
        const CsvToListConverter().convert(csvContent);

    // Skip header row and validate format
    if (rowsAsListOfValues.isEmpty || rowsAsListOfValues[0].length < 4) {
      throw Exception('Invalid CSV format. Please use the correct template.');
    }

    final List<String> successfulImports = [];
    final List<String> failedImports = [];
    int totalProcessed = 0;

    // Start from index 1 to skip header row
    for (var i = 1; i < rowsAsListOfValues.length; i++) {
      try {
        final row = rowsAsListOfValues[i];
        if (row.length < 4) continue; // Skip invalid rows

        final partyData = {
          'name': row[0]?.toString().trim() ?? '',
          'type': row[1]?.toString().trim().toLowerCase() == 'supplier'
              ? 'seller'
              : 'buyer',
          'gstin': row[2]?.toString().trim(),
          'phone': row[3]?.toString().trim(),
          'address': row[4]?.toString().trim(),
          'email': row[5]?.toString().trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'userId': currentUserId,
          'storeId': storeId,
        };

        // Basic validation
        if (((partyData['name'] as String?)?.isEmpty ?? true)) {
          throw Exception('Name is required');
        }

        // GSTIN validation if provided
        if ((partyData['gstin'] as String?)?.isNotEmpty == true &&
            (partyData['gstin'] as String).length != 15) {
          throw Exception('Invalid GSTIN format');
        }

        // Add to Firestore
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('stores')
            .doc(storeId)
            .collection('parties')
            .add(partyData);

        successfulImports.add(partyData['name'] as String);
        totalProcessed++;
      } catch (e) {
        failedImports.add('Row ${i + 1}: ${e.toString()}');
      }
    }

    return ImportResult(
      successful: successfulImports,
      failed: failedImports,
      totalProcessed: totalProcessed,
    );
  }
}

class ImportResult {
  final List<String> successful;
  final List<String> failed;
  final int totalProcessed;

  ImportResult({
    required this.successful,
    required this.failed,
    required this.totalProcessed,
  });
}
