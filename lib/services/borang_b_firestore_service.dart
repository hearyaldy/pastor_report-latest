// lib/services/borang_b_firestore_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pastor_report/models/borang_b_model.dart';

class BorangBFirestoreService {
  static BorangBFirestoreService? _instance;
  static BorangBFirestoreService get instance {
    _instance ??= BorangBFirestoreService._();
    return _instance!;
  }

  BorangBFirestoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'borang_b_reports';

  /// Save or update a Borang B report
  Future<bool> saveReport(BorangBData report) async {
    try {
      await _firestore.collection(_collection).doc(report.id).set(
            report.toJson(),
            SetOptions(merge: true),
          );

      debugPrint('✅ Borang B report saved to Firestore: ${report.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving Borang B to Firestore: $e');
      return false;
    }
  }

  /// Get a specific report by ID
  Future<BorangBData?> getReportById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();

      if (doc.exists && doc.data() != null) {
        return BorangBData.fromJson(doc.data()!);
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting Borang B report: $e');
      return null;
    }
  }

  /// Get report for a specific user and month
  Future<BorangBData?> getReportByUserAndMonth(
    String userId,
    int year,
    int month,
  ) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('month', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('month', isLessThan: endDate.toIso8601String())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return BorangBData.fromJson(querySnapshot.docs.first.data());
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting Borang B by user and month: $e');
      return null;
    }
  }

  /// Get all reports by user ID
  Future<List<BorangBData>> getReportsByUser(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('month', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => BorangBData.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting Borang B reports by user: $e');
      return [];
    }
  }

  /// Get all reports
  Future<List<BorangBData>> getAllReports() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('month', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => BorangBData.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting all Borang B reports: $e');
      return [];
    }
  }

  /// Get all reports by mission ID
  Future<List<BorangBData>> getReportsByMission(String missionId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('missionId', isEqualTo: missionId)
          .orderBy('month', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => BorangBData.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting Borang B reports by mission: $e');
      return [];
    }
  }

  /// Get reports by mission and month
  Future<List<BorangBData>> getReportsByMissionAndMonth(
    String missionId,
    int year,
    int month,
  ) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final querySnapshot = await _firestore
          .collection(_collection)
          .where('missionId', isEqualTo: missionId)
          .where('month', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('month', isLessThan: endDate.toIso8601String())
          .orderBy('month', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => BorangBData.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting Borang B reports by mission and month: $e');
      return [];
    }
  }

  /// Stream reports by user
  Stream<List<BorangBData>> streamReportsByUser(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('month', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BorangBData.fromJson(doc.data()))
            .toList());
  }

  /// Stream reports by mission
  Stream<List<BorangBData>> streamReportsByMission(String missionId) {
    return _firestore
        .collection(_collection)
        .where('missionId', isEqualTo: missionId)
        .orderBy('month', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BorangBData.fromJson(doc.data()))
            .toList());
  }

  /// Stream reports by mission and month
  Stream<List<BorangBData>> streamReportsByMissionAndMonth(
    String missionId,
    int year,
    int month,
  ) {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);

    return _firestore
        .collection(_collection)
        .where('missionId', isEqualTo: missionId)
        .where('month', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('month', isLessThan: endDate.toIso8601String())
        .orderBy('month', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BorangBData.fromJson(doc.data()))
            .toList());
  }

  /// Delete a report
  Future<bool> deleteReport(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      debugPrint('🗑️ Borang B report deleted: $id');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting Borang B report: $e');
      return false;
    }
  }

  /// Get aggregate statistics for a mission and month
  Future<Map<String, dynamic>> getMissionStatsByMonth(
    String missionId,
    int year,
    int month,
  ) async {
    try {
      final reports = await getReportsByMissionAndMonth(missionId, year, month);

      if (reports.isEmpty) {
        return {
          'totalReports': 0,
          'totalBaptisms': 0,
          'totalProfessions': 0,
          'totalVisitations': 0,
          'totalLiterature': 0,
          'totalTithe': 0.0,
          'totalOfferings': 0.0,
          'netMembershipChange': 0,
        };
      }

      return {
        'totalReports': reports.length,
        'totalBaptisms': reports.fold<int>(0, (total, r) => total + r.baptisms),
        'totalProfessions': reports.fold<int>(0, (total, r) => total + r.professionOfFaith),
        'totalVisitations': reports.fold<int>(0, (total, r) => total + r.totalVisitations),
        'totalLiterature': reports.fold<int>(0, (total, r) => total + r.totalLiterature),
        'totalTithe': reports.fold<double>(0.0, (total, r) => total + r.tithe),
        'totalOfferings': reports.fold<double>(0.0, (total, r) => total + r.offerings),
        'netMembershipChange': reports.fold<int>(0, (total, r) => total + r.netMembershipChange),
      };
    } catch (e) {
      debugPrint('❌ Error getting mission stats: $e');
      return {};
    }
  }

  /// Export reports to CSV format
  String exportToCSV(List<BorangBData> reports) {
    if (reports.isEmpty) return '';

    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln(
        'Month,Pastor Name,Mission,Baptisms,Professions,Members Beginning,Members End,'
        'Sabbath Services,Prayer Meetings,Bible Studies,Evangelistic Meetings,'
        'Home Visits,Hospital Visits,Prison Visits,Weddings,Funerals,Dedications,'
        'Books,Magazines,Tracts,Tithe,Offerings,Total Financial');

    // CSV Rows
    for (final report in reports) {
      buffer.writeln(
        '${report.month.year}-${report.month.month.toString().padLeft(2, '0')},'
        '"${report.userName}",'
        '"${report.missionId ?? ''}",'
        '${report.baptisms},'
        '${report.professionOfFaith},'
        '${report.membersBeginning},'
        '${report.membersEnd},'
        '${report.sabbathServices},'
        '${report.prayerMeetings},'
        '${report.bibleStudies},'
        '${report.evangelisticMeetings},'
        '${report.homeVisitations},'
        '${report.hospitalVisitations},'
        '${report.prisonVisitations},'
        '${report.weddings},'
        '${report.funerals},'
        '${report.dedications},'
        '${report.booksDistributed},'
        '${report.magazinesDistributed},'
        '${report.tractsDistributed},'
        '${report.tithe.toStringAsFixed(2)},'
        '${report.offerings.toStringAsFixed(2)},'
        '${report.totalFinancial.toStringAsFixed(2)}',
      );
    }

    return buffer.toString();
  }

  /// Export reports to JSON format
  String exportToJSON(List<BorangBData> reports) {
    final jsonList = reports.map((r) => r.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }
}

