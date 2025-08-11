import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gspappv2/features/reports/domain/models/report_type.dart';

class FiledReport {
  final String id;
  final ReportType type;
  final DateTime filedDate;
  final String period;
  final String status;
  final String? acknowledgmentNo;
  final String storeId; // Reference to the store
  final DateTime createdAt;
  final String? errorMessage; // Store any error messages
  final String? directionType; // 'inward', 'outward', or null

  FiledReport({
    required this.id,
    required this.type,
    required this.filedDate,
    required this.period,
    required this.status,
    this.acknowledgmentNo,
    required this.storeId,
    required this.createdAt,
    this.errorMessage,
    this.directionType,
  });

  // Factory constructor to create a FiledReport from a DocumentSnapshot
  factory FiledReport.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return FiledReport(
      id: snapshot.id,
      type: _getReportType(data['type'] ?? ''),
      filedDate: data['filedDate'] != null
          ? (data['filedDate'] as Timestamp).toDate()
          : DateTime.now(),
      period: data['period'] ?? '',
      status: data['status'] ?? '',
      acknowledgmentNo: data['acknowledgmentNo'],
      storeId: data['storeId'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      errorMessage: data['errorMessage'],
      directionType: data['directionType'],
    );
  }

  // Convert FiledReport to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'filedDate': Timestamp.fromDate(filedDate),
      'period': period,
      'status': status,
      'acknowledgmentNo': acknowledgmentNo,
      'storeId': storeId,
      'createdAt': FieldValue.serverTimestamp(),
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (directionType != null) 'directionType': directionType,
    };
  }

  // Helper method to convert string to ReportType
  static ReportType _getReportType(String type) {
    switch (type.toLowerCase()) {
      case 'gstr1':
        return ReportType.gstr1;
      case 'gstr3b':
        return ReportType.gstr3b;
      case 'gstr9':
        return ReportType.gstr9;
      default:
        return ReportType.gstr1;
    }
  }
}
