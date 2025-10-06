import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pastor_report/models/borang_b_model.dart';
import 'package:pastor_report/services/borang_b_firestore_service.dart';

class BorangBBackupService {
  static BorangBBackupService? _instance;
  static BorangBBackupService get instance {
    _instance ??= BorangBBackupService._();
    return _instance!;
  }

  BorangBBackupService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BorangBFirestoreService _firestoreService =
      BorangBFirestoreService.instance;

  /// Backup all reports to Firestore
  Future<bool> backupToCloud(String userId) async {
    try {
      debugPrint('☁️ Starting backup to Firestore...');

      // Get all Firestore reports for this user
      final reports = await _firestoreService.getReportsByUser(userId);

      if (reports.isEmpty) {
        debugPrint('⚠️ No reports to backup');
        return false;
      }

      // Create a batch write
      final batch = _firestore.batch();

      for (final report in reports) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('borang_b_reports')
            .doc(report.id);

        batch.set(docRef, report.toJson(), SetOptions(merge: true));
      }

      await batch.commit();

      debugPrint('✅ Successfully backed up ${reports.length} reports');
      return true;
    } catch (e) {
      debugPrint('❌ Error backing up to cloud: $e');
      return false;
    }
  }

  /// Restore reports from Firestore (this is now a backup operation since we use Firestore as primary)
  Future<bool> restoreFromCloud(String userId) async {
    try {
      debugPrint('☁️ All data is now stored in Firestore directly');
      return true; // No-op since all data is already in Firestore
    } catch (e) {
      debugPrint('❌ Error restoring from cloud: $e');
      return false;
    }
  }

  /// Sync function is no longer needed as we're using Firestore as primary storage
  Future<bool> syncWithCloud(String userId) async {
    try {
      debugPrint('☁️ All data is now stored in Firestore directly');
      return true; // No-op since all data is already in Firestore
    } catch (e) {
      debugPrint('❌ Error syncing with cloud: $e');
      return false;
    }
  }

  /// Delete cloud backup for a specific report
  Future<bool> deleteCloudReport(String userId, String reportId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('borang_b_reports')
          .doc(reportId)
          .delete();

      debugPrint('🗑️ Deleted report $reportId from cloud');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting cloud report: $e');
      return false;
    }
  }

  /// Get cloud backup status
  Future<Map<String, dynamic>> getBackupStatus(String userId) async {
    try {
      final reports = await _firestoreService.getReportsByUser(userId);

      DateTime? lastUpdate;
      if (reports.isNotEmpty) {
        lastUpdate = reports
            .map((r) => r.updatedAt ?? r.createdAt)
            .whereType<DateTime>()
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      return {
        'cloudCount': reports.length,
        'localCount': 0, // No more local storage
        'hasCloudBackup': reports.isNotEmpty,
        'lastBackup': lastUpdate,
      };
    } catch (e) {
      debugPrint('❌ Error getting backup status: $e');
      return {
        'cloudCount': 0,
        'localCount': 0,
        'hasCloudBackup': false,
        'lastBackup': null,
      };
    }
  }

  /// Export reports to a file
  Future<File?> exportToFile(String userId) async {
    try {
      debugPrint('📤 Exporting reports to file...');

      // Get all reports for the user from Firestore
      final userReports = await _firestoreService.getReportsByUser(userId);

      if (userReports.isEmpty) {
        debugPrint('ℹ️ No reports to export');
        return null;
      }

      // Convert to JSON
      final jsonData = jsonEncode(userReports.map((r) => r.toJson()).toList());

      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/borang_b_backup_$timestamp.json';
      final file = File(path);

      // Write to file
      await file.writeAsString(jsonData);

      // Share file
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Borang B Reports Backup',
      );

      debugPrint('✅ Exported ${userReports.length} reports to file');
      return file;
    } catch (e) {
      debugPrint('❌ Error exporting to file: $e');
      return null;
    }
  }

  /// Import reports from a file
  Future<bool> importFromFile() async {
    try {
      debugPrint('📥 Importing reports from file...');

      // Open file picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('ℹ️ No file selected');
        return false;
      }

      final path = result.files.single.path;
      if (path == null) {
        debugPrint('❌ Path is null');
        return false;
      }

      final file = File(path);
      final contents = await file.readAsString();

      // Parse JSON
      final List<dynamic> jsonList = json.decode(contents);
      final reports = jsonList
          .map((json) => BorangBData.fromJson(json as Map<String, dynamic>))
          .toList();

      // Add all reports to Firestore
      int added = 0;
      for (final report in reports) {
        // Save to Firestore directly
        await _firestoreService.saveReport(report);
        added++;
      }

      debugPrint('✅ Imported $added reports to Firestore');
      return true;
    } catch (e) {
      debugPrint('❌ Error importing from file: $e');
      return false;
    }
  }
}
