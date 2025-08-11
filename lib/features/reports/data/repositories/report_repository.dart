import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gspappv2/features/auth/domain/services/firestore_service.dart';
import 'package:gspappv2/features/reports/domain/models/filed_report.dart';
import 'package:gspappv2/features/reports/domain/models/report_type.dart';

class ReportRepository {
  final FirestoreService _firestoreService;

  ReportRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  // Add a new filed report
  Future<String> addFiledReport({
    required String storeId,
    required ReportType type,
    required String period,
    required String status,
    String? acknowledgmentNo,
    String? errorMessage,
    String? directionType, // 'inward', 'outward', or null
  }) async {
    final docRef = await _firestoreService.addFiledReport(
      storeId: storeId,
      type: type.name,
      period: period,
      status: status,
      acknowledgmentNo: acknowledgmentNo,
    );

    // Update with additional fields if needed
    if (errorMessage != null || directionType != null) {
      await docRef.update({
        if (errorMessage != null) 'errorMessage': errorMessage,
        if (directionType != null) 'directionType': directionType,
      });
    }

    return docRef.id;
  }

  // Stream of filed reports for a store
  Stream<List<FiledReport>> getFiledReports(String storeId) {
    return _firestoreService.getReports(storeId).map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return FiledReport.fromSnapshot(doc);
      }).toList();
    });
  }

  // Delete a filed report
  Future<void> deleteFiledReport(String storeId, String reportId) async {
    await _firestoreService.deleteReport(storeId, reportId);
  }

  // Update an existing filed report
  Future<String?> updateFiledReport(
    String? reportId, {
    required String storeId,
    required ReportType type,
    required String period,
    required String status,
    String? acknowledgmentNo,
    String? errorMessage,
    String? directionType, // 'inward', 'outward', or null
  }) async {
    if (reportId == null) {
      // If no report ID is provided, create a new report instead
      return await addFiledReport(
        storeId: storeId,
        type: type,
        period: period,
        status: status,
        acknowledgmentNo: acknowledgmentNo,
        errorMessage: errorMessage,
        directionType: directionType,
      );
    }

    // Update the existing report
    Map<String, dynamic> updates = {
      'type': type.name,
      'period': period,
      'status': status,
      'filedDate': FieldValue.serverTimestamp(),
    };

    if (acknowledgmentNo != null)
      updates['acknowledgmentNo'] = acknowledgmentNo;
    if (errorMessage != null) updates['errorMessage'] = errorMessage;
    if (directionType != null) updates['directionType'] = directionType;

    await _firestoreService.updateReport(storeId, reportId, updates);
    return reportId;
  }
}
