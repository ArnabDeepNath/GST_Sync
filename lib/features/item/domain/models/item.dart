import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  final String id;
  final String name;
  final double unitPrice;
  final String? hsn;
  final double taxRate;
  final String uqc; // Unique Quantity Code
  final String storeId; // Reference to the store
  final DateTime createdAt;
  final DateTime updatedAt;

  Item({
    required this.id,
    required this.name,
    required this.unitPrice,
    this.hsn,
    required this.taxRate,
    required this.uqc,
    required this.storeId,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor to create an Item from a DocumentSnapshot
  factory Item.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Item(
      id: snapshot.id,
      name: data['name'] ?? '',
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      hsn: data['hsn'],
      taxRate: (data['taxRate'] ?? 0).toDouble(),
      uqc: data['uqc'] ?? 'OTH', // Default to Other if not specified
      storeId: data['storeId'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Convert Item to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unitPrice': unitPrice,
      'hsn': hsn,
      'taxRate': taxRate,
      'uqc': uqc,
      'storeId': storeId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Create a copy of the Item with updated fields
  Item copyWith({
    String? name,
    double? unitPrice,
    String? hsn,
    double? taxRate,
    String? uqc,
    String? storeId,
  }) {
    return Item(
      id: id,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      hsn: hsn ?? this.hsn,
      taxRate: taxRate ?? this.taxRate,
      uqc: uqc ?? this.uqc,
      storeId: storeId ?? this.storeId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

// List of common UQCs (Unique Quantity Codes) as per GST standards
class UQCCodes {
  static const String BAG = 'BAG'; // BAGS
  static const String BAL = 'BAL'; // BALE
  static const String BDL = 'BDL'; // BUNDLES
  static const String BGS = 'BGS'; // BAGS
  static const String BOT = 'BOT'; // BOTTLES
  static const String BOX = 'BOX'; // BOX
  static const String BTL = 'BTL'; // BOTTLES
  static const String BUN = 'BUN'; // BUNDLES
  static const String CBM = 'CBM'; // CUBIC METERS
  static const String CCM = 'CCM'; // CUBIC CENTIMETERS
  static const String CMS = 'CMS'; // CENTIMETERS
  static const String CRT = 'CRT'; // CRATES
  static const String DOZ = 'DOZ'; // DOZEN
  static const String DRM = 'DRM'; // DRUMS
  static const String GMS = 'GMS'; // GRAMS
  static const String GRS = 'GRS'; // GROSS
  static const String GYD = 'GYD'; // GROSS YARDS
  static const String KGS = 'KGS'; // KILOGRAMS
  static const String KLR = 'KLR'; // KILOLITER
  static const String KME = 'KME'; // KILOMETER
  static const String LTR = 'LTR'; // LITERS
  static const String MTR = 'MTR'; // METERS
  static const String NOS = 'NOS'; // NUMBERS
  static const String PAC = 'PAC'; // PACKS
  static const String PCS = 'PCS'; // PIECES
  static const String PRS = 'PRS'; // PAIRS
  static const String QTL = 'QTL'; // QUINTAL
  static const String ROL = 'ROL'; // ROLLS
  static const String SET = 'SET'; // SETS
  static const String SQF = 'SQF'; // SQUARE FEET
  static const String SQM = 'SQM'; // SQUARE METERS
  static const String SQY = 'SQY'; // SQUARE YARDS
  static const String TBS = 'TBS'; // TABLETS
  static const String TGM = 'TGM'; // TEN GROSS
  static const String THD = 'THD'; // THOUSANDS
  static const String TON = 'TON'; // TONNES
  static const String TUB = 'TUB'; // TUBES
  static const String UGS = 'UGS'; // US GALLONS
  static const String UNT = 'UNT'; // UNITS
  static const String YDS = 'YDS'; // YARDS
  static const String OTH = 'OTH'; // OTHERS

  // Get a list of all UQC codes for dropdown
  static List<Map<String, String>> getAllUQCs() {
    return [
      {'code': BAG, 'name': 'BAGS'},
      {'code': BAL, 'name': 'BALE'},
      {'code': BDL, 'name': 'BUNDLES'},
      {'code': BGS, 'name': 'BAGS'},
      {'code': BOT, 'name': 'BOTTLES'},
      {'code': BOX, 'name': 'BOX'},
      {'code': BTL, 'name': 'BOTTLES'},
      {'code': BUN, 'name': 'BUNDLES'},
      {'code': CBM, 'name': 'CUBIC METERS'},
      {'code': CCM, 'name': 'CUBIC CENTIMETERS'},
      {'code': CMS, 'name': 'CENTIMETERS'},
      {'code': CRT, 'name': 'CRATES'},
      {'code': DOZ, 'name': 'DOZEN'},
      {'code': DRM, 'name': 'DRUMS'},
      {'code': GMS, 'name': 'GRAMS'},
      {'code': GRS, 'name': 'GROSS'},
      {'code': GYD, 'name': 'GROSS YARDS'},
      {'code': KGS, 'name': 'KILOGRAMS'},
      {'code': KLR, 'name': 'KILOLITER'},
      {'code': KME, 'name': 'KILOMETER'},
      {'code': LTR, 'name': 'LITERS'},
      {'code': MTR, 'name': 'METERS'},
      {'code': NOS, 'name': 'NUMBERS'},
      {'code': PAC, 'name': 'PACKS'},
      {'code': PCS, 'name': 'PIECES'},
      {'code': PRS, 'name': 'PAIRS'},
      {'code': QTL, 'name': 'QUINTAL'},
      {'code': ROL, 'name': 'ROLLS'},
      {'code': SET, 'name': 'SETS'},
      {'code': SQF, 'name': 'SQUARE FEET'},
      {'code': SQM, 'name': 'SQUARE METERS'},
      {'code': SQY, 'name': 'SQUARE YARDS'},
      {'code': TBS, 'name': 'TABLETS'},
      {'code': TGM, 'name': 'TEN GROSS'},
      {'code': THD, 'name': 'THOUSANDS'},
      {'code': TON, 'name': 'TONNES'},
      {'code': TUB, 'name': 'TUBES'},
      {'code': UGS, 'name': 'US GALLONS'},
      {'code': UNT, 'name': 'UNITS'},
      {'code': YDS, 'name': 'YARDS'},
      {'code': OTH, 'name': 'OTHERS'},
    ];
  }

  // Get UQC name from code
  static String getUQCName(String code) {
    final uqcMap = getAllUQCs().firstWhere(
      (uqc) => uqc['code'] == code,
      orElse: () => {'code': OTH, 'name': 'OTHERS'},
    );
    return uqcMap['name'] ?? 'OTHERS';
  }
}
