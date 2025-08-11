import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gspappv2/features/party/domain/models/party.dart';

class PartyRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all parties for a store with optional filter by type
  Stream<List<Party>> getParties(String storeId, {PartyType? type}) {
    Query query = _firestore
        .collection('stores')
        .doc(storeId)
        .collection('parties')
        .orderBy('name');

    if (type != null) {
      query = query.where('type', isEqualTo: type.toString().split('.').last);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Party.fromSnapshot(doc)).toList();
    });
  }

  /// Get a party by ID
  Future<Party> getPartyById(String storeId, String partyId) async {
    final doc = await _firestore
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

  /// Add a new party
  Future<String> addParty(String storeId, Party party) async {
    final docRef = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('parties')
        .add(party.toMap());

    return docRef.id;
  }

  /// Update an existing party
  Future<void> updateParty(String storeId, Party party) async {
    await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('parties')
        .doc(party.id)
        .update(party.toMap());
  }

  /// Delete a party
  Future<void> deleteParty(String storeId, String partyId) async {
    await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('parties')
        .doc(partyId)
        .delete();
  }
}
