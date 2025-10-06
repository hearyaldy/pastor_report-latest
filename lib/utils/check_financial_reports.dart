import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility to check financial reports status
class FinancialReportsChecker {
  static Future<Map<String, dynamic>> checkReportsStatus() async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Get all financial reports
      final allReports = await firestore.collection('financial_reports').get();

      // Count reports with and without missionId
      int totalReports = allReports.docs.length;
      int reportsWithMissionId = 0;
      int reportsWithoutMissionId = 0;
      int submittedReports = 0;

      final Set<String> uniqueMissions = {};
      final Set<String> uniqueChurches = {};

      final Map<String, int> missionIdCounts = {};

      for (var doc in allReports.docs) {
        final data = doc.data();
        final missionId = data['missionId'] as String?;
        final churchId = data['churchId'] as String?;
        final status = data['status'] as String?;

        if (missionId != null && missionId.isNotEmpty) {
          reportsWithMissionId++;
          uniqueMissions.add(missionId);
          missionIdCounts[missionId] = (missionIdCounts[missionId] ?? 0) + 1;
        } else {
          reportsWithoutMissionId++;
        }

        if (status == 'submitted') {
          submittedReports++;
        }

        if (churchId != null) {
          uniqueChurches.add(churchId);
        }
      }

      debugPrint('📋 MissionID Distribution:');
      missionIdCounts.forEach((missionId, count) {
        debugPrint('   "$missionId": $count reports');
      });

      final result = {
        'totalReports': totalReports,
        'reportsWithMissionId': reportsWithMissionId,
        'reportsWithoutMissionId': reportsWithoutMissionId,
        'submittedReports': submittedReports,
        'uniqueMissions': uniqueMissions.length,
        'uniqueChurches': uniqueChurches.length,
        'needsFix': reportsWithoutMissionId > 0,
        'missionIdCounts': missionIdCounts,
        'missionIds': uniqueMissions.toList(),
      };

      debugPrint('📊 Financial Reports Status:');
      debugPrint('   Total reports: $totalReports');
      debugPrint('   With missionId: $reportsWithMissionId');
      debugPrint('   Without missionId: $reportsWithoutMissionId');
      debugPrint('   Submitted: $submittedReports');
      debugPrint('   Unique missions: ${uniqueMissions.length}');
      debugPrint('   Unique churches: ${uniqueChurches.length}');
      debugPrint('   Needs fix: ${reportsWithoutMissionId > 0 ? "YES" : "NO"}');

      return result;
    } catch (e) {
      debugPrint('❌ Error checking reports: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  /// Check if a specific mission has reports
  static Future<Map<String, dynamic>> checkMissionReports(String missionId) async {
    final firestore = FirebaseFirestore.instance;

    try {
      final snapshot = await firestore
          .collection('financial_reports')
          .where('missionId', isEqualTo: missionId)
          .get();

      final result = {
        'missionId': missionId,
        'totalReports': snapshot.docs.length,
        'months': <String>[],
      };

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final month = (data['month'] as Timestamp?)?.toDate();
        if (month != null) {
          (result['months'] as List).add('${month.year}-${month.month}');
        }
      }

      debugPrint('📊 Mission Reports ($missionId):');
      debugPrint('   Total: ${snapshot.docs.length}');
      debugPrint('   Months: ${result['months']}');

      return result;
    } catch (e) {
      debugPrint('❌ Error checking mission reports: $e');
      return {
        'error': e.toString(),
      };
    }
  }
}
