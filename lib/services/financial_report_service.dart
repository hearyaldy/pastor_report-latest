import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/financial_report_model.dart';

class FinancialReportService {
  static final FinancialReportService instance = FinancialReportService._internal();
  factory FinancialReportService() => instance;
  FinancialReportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'financial_reports';

  /// Create a new financial report
  Future<void> createReport(FinancialReport report) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(report.id)
          .set(report.toMap());
    } catch (e) {
      throw Exception('Failed to create financial report: $e');
    }
  }

  /// Get a financial report by ID
  Future<FinancialReport?> getReportById(String reportId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(reportId).get();

      if (doc.exists) {
        return FinancialReport.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get financial report: $e');
    }
  }

  /// Get reports for a specific church and month
  Future<FinancialReport?> getReportByChurchAndMonth(
    String churchId,
    DateTime month,
  ) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('churchId', isEqualTo: churchId)
          .where('month', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('month', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return FinancialReport.fromSnapshot(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get report by church and month: $e');
    }
  }

  /// Get all reports for a church
  Future<List<FinancialReport>> getReportsByChurch(String churchId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('churchId', isEqualTo: churchId)
          .orderBy('month', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => FinancialReport.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get church reports: $e');
    }
  }

  /// Get all reports for a district
  Future<List<FinancialReport>> getReportsByDistrict(String districtId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('districtId', isEqualTo: districtId)
          .orderBy('month', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => FinancialReport.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get district reports: $e');
    }
  }

  /// Get all reports for a mission
  Future<List<FinancialReport>> getReportsByMission(String missionId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('missionId', isEqualTo: missionId)
          .orderBy('month', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => FinancialReport.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get mission reports: $e');
    }
  }

  /// Stream reports for a district (real-time)
  Stream<List<FinancialReport>> streamReportsByDistrict(String districtId) {
    return _firestore
        .collection(_collectionName)
        .where('districtId', isEqualTo: districtId)
        .orderBy('month', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinancialReport.fromSnapshot(doc))
            .toList());
  }

  /// Stream reports for a mission (real-time)
  Stream<List<FinancialReport>> streamReportsByMission(String missionId) {
    return _firestore
        .collection(_collectionName)
        .where('missionId', isEqualTo: missionId)
        .orderBy('month', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinancialReport.fromSnapshot(doc))
            .toList());
  }

  /// Update a financial report
  Future<void> updateReport(FinancialReport report) async {
    try {
      final updatedReport = report.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(_collectionName)
          .doc(report.id)
          .update(updatedReport.toMap());
    } catch (e) {
      throw Exception('Failed to update financial report: $e');
    }
  }

  /// Delete a financial report
  Future<void> deleteReport(String reportId) async {
    try {
      await _firestore.collection(_collectionName).doc(reportId).delete();
    } catch (e) {
      throw Exception('Failed to delete financial report: $e');
    }
  }

  /// Get aggregated financial data for a district by month
  Future<Map<String, double>> getDistrictAggregateByMonth(
    String districtId,
    DateTime month,
  ) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('districtId', isEqualTo: districtId)
          .where('month', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('month', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .where('status', isEqualTo: 'submitted')
          .get();

      double totalTithe = 0.0;
      double totalOfferings = 0.0;
      double totalSpecialOfferings = 0.0;

      for (var doc in querySnapshot.docs) {
        final report = FinancialReport.fromSnapshot(doc);
        totalTithe += report.tithe;
        totalOfferings += report.offerings;
        totalSpecialOfferings += report.specialOfferings;
      }

      return {
        'tithe': totalTithe,
        'offerings': totalOfferings,
        'specialOfferings': totalSpecialOfferings,
        'total': totalTithe + totalOfferings + totalSpecialOfferings,
      };
    } catch (e) {
      throw Exception('Failed to aggregate district data: $e');
    }
  }

  /// Get aggregated financial data for a mission by month
  Future<Map<String, double>> getMissionAggregateByMonth(
    String missionId,
    DateTime month,
  ) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('missionId', isEqualTo: missionId)
          .where('month', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('month', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .where('status', isEqualTo: 'submitted')
          .get();

      double totalTithe = 0.0;
      double totalOfferings = 0.0;
      double totalSpecialOfferings = 0.0;

      for (var doc in querySnapshot.docs) {
        final report = FinancialReport.fromSnapshot(doc);
        totalTithe += report.tithe;
        totalOfferings += report.offerings;
        totalSpecialOfferings += report.specialOfferings;
      }

      return {
        'tithe': totalTithe,
        'offerings': totalOfferings,
        'specialOfferings': totalSpecialOfferings,
        'total': totalTithe + totalOfferings + totalSpecialOfferings,
      };
    } catch (e) {
      throw Exception('Failed to aggregate mission data: $e');
    }
  }

  /// Get financial reports for the last N months for a mission
  Future<List<Map<String, dynamic>>> getMissionMonthlyTrends(
    String missionId,
    int monthsCount,
  ) async {
    try {
      final now = DateTime.now();
      final trends = <Map<String, dynamic>>[];

      for (int i = 0; i < monthsCount; i++) {
        final month = DateTime(now.year, now.month - i, 1);
        final aggregate = await getMissionAggregateByMonth(missionId, month);

        trends.add({
          'month': month,
          'tithe': aggregate['tithe'],
          'offerings': aggregate['offerings'],
          'total': aggregate['total'],
        });
      }

      return trends.reversed.toList(); // Return oldest to newest
    } catch (e) {
      throw Exception('Failed to get monthly trends: $e');
    }
  }

  /// Count churches with submitted reports in a district for a given month
  Future<int> countChurchesWithReports(String districtId, DateTime month) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('districtId', isEqualTo: districtId)
          .where('month', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('month', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .where('status', isEqualTo: 'submitted')
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      throw Exception('Failed to count churches with reports: $e');
    }
  }
}
