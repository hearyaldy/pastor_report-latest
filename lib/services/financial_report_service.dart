import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pastor_report/models/financial_report_model.dart';

class FinancialReportService {
  static final FinancialReportService instance =
      FinancialReportService._internal();
  factory FinancialReportService() => instance;
  FinancialReportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'financial_reports';

  /// Create a new financial report
  Future<void> createReport(FinancialReport report) async {
    try {
      // Make sure report has a valid ID
      final reportId = report.id.isNotEmpty
          ? report.id
          : '${report.churchId}_${report.month.year}_${report.month.month}';

      final reportWithId =
          report.id.isEmpty ? report.copyWith(id: reportId) : report;

      final dataToSave = reportWithId.toMap();

      debugPrint('➕ FinancialReportService.createReport:');
      debugPrint('   Report ID: $reportId');
      debugPrint('   Status: ${dataToSave['status']}');
      debugPrint('   ChurchId: ${dataToSave['churchId']}');
      debugPrint('   MissionId: ${dataToSave['missionId']}');
      debugPrint('   DistrictId: ${dataToSave['districtId']}');
      debugPrint('   Tithe: ${dataToSave['tithe']}');
      debugPrint('   Offerings: ${dataToSave['offerings']}');

      await _firestore
          .collection(_collectionName)
          .doc(reportId)
          .set(dataToSave);

      debugPrint('✅ Report created successfully: $reportId');
    } catch (e) {
      debugPrint('❌ Failed to create financial report: $e');
      throw Exception('Failed to create financial report: $e');
    }
  }

  /// Get a financial report by ID
  Future<FinancialReport?> getReportById(String reportId) async {
    try {
      final doc =
          await _firestore.collection(_collectionName).doc(reportId).get();

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
          .where('month',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
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
  Future<List<FinancialReport>> getReportsByChurch(String churchId,
      {String? districtId}) async {
    try {
      debugPrint('🔍 FinancialReportService.getReportsByChurch:');
      debugPrint('   ChurchId: $churchId');
      debugPrint('   DistrictId filter: $districtId');

      var query = _firestore
          .collection(_collectionName)
          .where('churchId', isEqualTo: churchId);

      if (districtId != null) {
        query = query.where('districtId', isEqualTo: districtId);
      }

      final querySnapshot =
          await query.orderBy('month', descending: true).get();

      debugPrint('   Found ${querySnapshot.docs.length} reports');

      if (querySnapshot.docs.isNotEmpty) {
        debugPrint('   📋 Sample reports (first 3):');
        for (var doc in querySnapshot.docs.take(3)) {
          final data = doc.data();
          debugPrint('      - ID: ${doc.id}, Status: ${data['status']}, '
              'MissionId: ${data['missionId']}, '
              'Tithe: ${data['tithe']}, Offerings: ${data['offerings']}');
        }
      }

      final reports = querySnapshot.docs
          .map((doc) => FinancialReport.fromSnapshot(doc))
          .toList();

      debugPrint('   ✅ Loaded ${reports.length} reports successfully');

      return reports;
    } catch (e) {
      debugPrint('❌ Failed to get church reports: $e');
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
      final dataToUpdate = updatedReport.toMap();

      debugPrint('🔄 FinancialReportService.updateReport:');
      debugPrint('   Report ID: ${report.id}');
      debugPrint('   Status being saved: ${dataToUpdate['status']}');
      debugPrint('   Tithe: ${dataToUpdate['tithe']}');
      debugPrint('   Offerings: ${dataToUpdate['offerings']}');
      debugPrint('   MissionId: ${dataToUpdate['missionId']}');
      debugPrint('   DistrictId: ${dataToUpdate['districtId']}');
      debugPrint('   SubmittedAt: ${dataToUpdate['submittedAt']}');

      await _firestore
          .collection(_collectionName)
          .doc(report.id)
          .update(dataToUpdate);

      debugPrint('✅ Update successful for report ${report.id}');

      // Verify the update by reading it back
      final docSnapshot = await _firestore
          .collection(_collectionName)
          .doc(report.id)
          .get();
      if (docSnapshot.exists) {
        final savedData = docSnapshot.data();
        debugPrint('✅ Verification read - Status in Firestore: ${savedData?['status']}');
      }
    } catch (e) {
      debugPrint('❌ Failed to update financial report: $e');
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
          .where('month',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('month', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          // Removed status filter to include all reports (draft, submitted, etc.)
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

      debugPrint('🔎 FinancialReportService.getMissionAggregateByMonth:');
      debugPrint('   MissionId: "$missionId"');
      debugPrint('   Month: ${month.year}-${month.month}');
      debugPrint('   Date range: $startOfMonth to $endOfMonth');

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('missionId', isEqualTo: missionId)
          .where('month',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('month', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          // Removed status filter to include all reports (draft, submitted, etc.)
          .get();

      debugPrint('   Found ${querySnapshot.docs.length} reports (all statuses)');

      if (querySnapshot.docs.isEmpty) {
        debugPrint('   ⚠️ No reports found! Checking for common issues:');

        // Debug: Check if any reports exist without missionId filter
        final allReportsSnapshot = await _firestore
            .collection(_collectionName)
            .where('month',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .where('month', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
            .limit(5)
            .get();

        debugPrint('   Found ${allReportsSnapshot.docs.length} reports total (without missionId filter)');
        if (allReportsSnapshot.docs.isNotEmpty) {
          debugPrint('   Sample reports in this month:');
          for (var doc in allReportsSnapshot.docs) {
            final data = doc.data();
            debugPrint('      - ID: ${doc.id}, MissionId: "${data['missionId']}", '
                'ChurchId: ${data['churchId']}, Status: ${data['status']}');
          }
        }
      } else {
        debugPrint('   📋 Sample reports found (first 3):');
        for (var doc in querySnapshot.docs.take(3)) {
          final data = doc.data();
          debugPrint('      - ID: ${doc.id}, MissionId: "${data['missionId']}", '
              'ChurchId: ${data['churchId']}, Status: ${data['status']}, '
              'Tithe: ${data['tithe']}, Offerings: ${data['offerings']}');
        }
      }

      double totalTithe = 0.0;
      double totalOfferings = 0.0;
      double totalSpecialOfferings = 0.0;

      for (var doc in querySnapshot.docs) {
        final report = FinancialReport.fromSnapshot(doc);
        totalTithe += report.tithe;
        totalOfferings += report.offerings;
        totalSpecialOfferings += report.specialOfferings;
      }

      debugPrint('   💰 Calculated totals:');
      debugPrint('      Tithe: RM ${totalTithe.toStringAsFixed(2)}');
      debugPrint('      Offerings: RM ${totalOfferings.toStringAsFixed(2)}');
      debugPrint('      Special: RM ${totalSpecialOfferings.toStringAsFixed(2)}');
      debugPrint('      Total: RM ${(totalTithe + totalOfferings + totalSpecialOfferings).toStringAsFixed(2)}');

      return {
        'tithe': totalTithe,
        'offerings': totalOfferings,
        'specialOfferings': totalSpecialOfferings,
        'total': totalTithe + totalOfferings + totalSpecialOfferings,
      };
    } catch (e) {
      debugPrint('❌ Failed to aggregate mission data: $e');
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
  Future<int> countChurchesWithReports(
      String districtId, DateTime month) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('districtId', isEqualTo: districtId)
          .where('month',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('month', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          // Removed status filter to include all reports (draft, submitted, etc.)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      throw Exception('Failed to count churches with reports: $e');
    }
  }

  /// Get ALL financial reports (for admin view)
  Future<List<FinancialReport>> getAllReports({
    String? missionId,
    String? regionId,
    String? districtId,
    int? limit,
  }) async {
    try {
      var query = _firestore.collection(_collectionName).orderBy('submittedAt', descending: true);

      if (missionId != null && missionId.isNotEmpty) {
        query = query.where('missionId', isEqualTo: missionId);
      }
      if (regionId != null && regionId.isNotEmpty) {
        query = query.where('regionId', isEqualTo: regionId);
      }
      if (districtId != null && districtId.isNotEmpty) {
        query = query.where('districtId', isEqualTo: districtId);
      }
      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => FinancialReport.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all reports: $e');
    }
  }

  /// Get all reports for a specific month (optimized for loading reports by month)
  Future<List<FinancialReport>> getReportsByMonth(
    DateTime month, {
    String? missionId,
    String? regionId,
    String? districtId,
  }) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      var query = _firestore
          .collection(_collectionName)
          .where('month', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('month', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth));

      if (missionId != null && missionId.isNotEmpty) {
        query = query.where('missionId', isEqualTo: missionId);
      }
      if (districtId != null && districtId.isNotEmpty) {
        query = query.where('districtId', isEqualTo: districtId);
      }
      // Note: Can't filter by regionId here due to Firestore's limitation on range queries
      // We'll filter in memory if needed

      final querySnapshot = await query.get();

      var reports = querySnapshot.docs
          .map((doc) => FinancialReport.fromSnapshot(doc))
          .toList();

      // Filter by region in memory if needed
      if (regionId != null && regionId.isNotEmpty) {
        reports = reports.where((r) => r.regionId == regionId).toList();
      }

      return reports;
    } catch (e) {
      throw Exception('Failed to get reports by month: $e');
    }
  }
}
