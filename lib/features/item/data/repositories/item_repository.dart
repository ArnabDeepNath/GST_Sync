import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gspappv2/features/item/domain/models/item.dart';
import 'package:csv/csv.dart';

class ItemRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Add a new item
  Future<Item> addItem({
    required String storeId,
    required String name,
    required double unitPrice,
    String? hsn,
    required double taxRate,
    required String uqc,
  }) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final itemData = {
      'name': name,
      'unitPrice': unitPrice,
      'hsn': hsn,
      'taxRate': taxRate,
      'uqc': uqc,
      'storeId': storeId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('items')
        .add(itemData);

    // Get the document with server timestamp
    final snapshot = await docRef.get();
    return Item.fromSnapshot(snapshot);
  }

  // Update item
  Future<void> updateItem(Item item) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(item.storeId)
        .collection('items')
        .doc(item.id)
        .update(item.toMap());
  }

  // Get items for a store
  Stream<List<Item>> getItems(String storeId) {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('items')
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Item.fromSnapshot(doc)).toList());
  }

  // Get item by ID
  Future<Item> getItemById(String storeId, String itemId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final doc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('items')
        .doc(itemId)
        .get();

    if (!doc.exists) {
      throw Exception('Item not found');
    }

    return Item.fromSnapshot(doc);
  }

  // Delete item
  Future<void> deleteItem(String storeId, String itemId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('stores')
        .doc(storeId)
        .collection('items')
        .doc(itemId)
        .delete();
  }

  // Import items from CSV
  Future<ImportResult> importItemsFromCsv(
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
    int totalProcessed = 0; // Start from index 1 to skip header row
    for (var i = 1; i < rowsAsListOfValues.length; i++) {
      try {
        final row = rowsAsListOfValues[i];
        if (row.length < 4) continue; // Skip invalid rows

        final itemData = {
          'name': row[0]?.toString().trim() ?? '',
          'unitPrice': _parseDouble(row[1]?.toString().trim()),
          'hsn': row[2]?.toString().trim(),
          'taxRate': _parseDouble(row[3]?.toString().trim()),
          'uqc':
              (row.length > 4 && row[4]?.toString().trim().isNotEmpty == true)
                  ? row[4]?.toString().trim()
                  : 'PCS',
          'storeId': storeId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Basic validation
        if (((itemData['name'] as String?)?.isEmpty ?? true)) {
          throw Exception('Item name is required');
        }

        if ((itemData['unitPrice'] as double) < 0) {
          throw Exception('Unit price must be non-negative');
        }

        if ((itemData['taxRate'] as double) < 0 ||
            (itemData['taxRate'] as double) > 100) {
          throw Exception('Tax rate must be between 0 and 100');
        }

        // Add to Firestore
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('stores')
            .doc(storeId)
            .collection('items')
            .add(itemData);

        successfulImports.add(itemData['name'] as String);
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

  double _parseDouble(String? value) {
    if (value == null || value.isEmpty) return 0.0;
    try {
      return double.parse(value.replaceAll(',', ''));
    } catch (e) {
      return 0.0;
    }
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
