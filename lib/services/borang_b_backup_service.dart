import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pastor_report/models/borang_b_model.dart';
import 'package:pastor_report/services/borang_b_storage_service.dart';

class BorangBBackupService {
  static BorangBBackupService? _instance;
  static BorangBBackupService get instance {
    _instance ??= BorangBBackupService._();
    return _instance!;
  }

  BorangBBackupService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BorangBStorageService _storageService = BorangBStorageService.instance;

  /// Backup all reports to Firestore
  Future<bool> backupToCloud(String userId) async {
    try {
      debugPrint('☁️ Starting backup to Firestore...');

      // Get all local reports
      final reports = await _storageService.getAllReports();
      final userReports = reports.where((r) => r.userId == userId).toList();

      if (userReports.isEmpty) {
        debugPrint('⚠️ No reports to backup');
        return false;
      }

      // Create a batch write
      final batch = _firestore.batch();

      for (final report in userReports) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('borang_b_reports')
            .doc(report.id);

        batch.set(docRef, report.toJson(), SetOptions(merge: true));
      }

      await batch.commit();

      debugPrint('✅ Successfully backed up ${userReports.length} reports');
      return true;
    } catch (e) {
      debugPrint('❌ Error backing up to cloud: $e');
      return false;
    }
  }

  /// Restore reports from Firestore
  Future<bool> restoreFromCloud(String userId) async {
    try {
      debugPrint('☁️ Starting restore from Firestore...');

      // Get reports from Firestore
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('borang_b_reports')
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ No reports found in cloud');
        return false;
      }

      // Convert to BorangBData objects
      final cloudReports = snapshot.docs
          .map((doc) => BorangBData.fromJson(doc.data()))
          .toList();

      // Get existing local reports
      final localReports = await _storageService.getAllReports();
      final localReportIds = localReports.map((r) => r.id).toSet();

      // Merge: Add cloud reports that don't exist locally
      final reportsToAdd = cloudReports
          .where((cloudReport) => !localReportIds.contains(cloudReport.id))
          .toList();

      // Save new reports locally
      for (final report in reportsToAdd) {
        await _storageService.saveReport(report);
      }

      debugPrint('✅ Successfully restored ${reportsToAdd.length} new reports');
      return true;
    } catch (e) {
      debugPrint('❌ Error restoring from cloud: $e');
      return false;
    }
  }

  /// Sync: Merge local and cloud data (two-way sync)
  Future<bool> syncWithCloud(String userId) async {
    try {
      debugPrint('🔄 Starting sync with Firestore...');

      // 1. Get cloud reports
      final cloudSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('borang_b_reports')
          .get();

      final cloudReports = cloudSnapshot.docs
          .map((doc) => BorangBData.fromJson(doc.data()))
          .toList();

      // 2. Get local reports
      final localReports = await _storageService.getAllReports();
      final userLocalReports = localReports.where((r) => r.userId == userId).toList();

      // 3. Create maps for easy lookup
      final cloudMap = {for (var r in cloudReports) r.id: r};
      final localMap = {for (var r in userLocalReports) r.id: r};

      // 4. Find reports to upload (exist locally but not in cloud)
      final toUpload = userLocalReports
          .where((local) => !cloudMap.containsKey(local.id))
          .toList();

      // 5. Find reports to download (exist in cloud but not locally)
      final toDownload = cloudReports
          .where((cloud) => !localMap.containsKey(cloud.id))
          .toList();

      // 6. Upload to cloud
      if (toUpload.isNotEmpty) {
        final batch = _firestore.batch();
        for (final report in toUpload) {
          final docRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('borang_b_reports')
              .doc(report.id);
          batch.set(docRef, report.toJson());
        }
        await batch.commit();
        debugPrint('⬆️ Uploaded ${toUpload.length} reports to cloud');
      }

      // 7. Download to local
      if (toDownload.isNotEmpty) {
        for (final report in toDownload) {
          await _storageService.saveReport(report);
        }
        debugPrint('⬇️ Downloaded ${toDownload.length} reports from cloud');
      }

      debugPrint('✅ Sync completed successfully');
      return true;
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
      final cloudSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('borang_b_reports')
          .get();

      final localReports = await _storageService.getAllReports();
      final userLocalReports = localReports.where((r) => r.userId == userId).toList();

      return {
        'cloudCount': cloudSnapshot.docs.length,
        'localCount': userLocalReports.length,
        'hasCloudBackup': cloudSnapshot.docs.isNotEmpty,
        'lastBackup': cloudSnapshot.docs.isNotEmpty
            ? cloudSnapshot.docs
                .map((doc) => (doc.data()['createdAt'] as Timestamp?)?.toDate())
                .whereType<DateTime>()
                .reduce((a, b) => a.isAfter(b) ? a : b)
            : null,
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

  /// Export all reports to JSON file and share
  Future<bool> exportToFile(String userId) async {
    try {
      debugPrint('📤 Starting export to file...');

      // Get all user reports
      final reports = await _storageService.getAllReports();
      final userReports = reports.where((r) => r.userId == userId).toList();

      if (userReports.isEmpty) {
        debugPrint('⚠️ No reports to export');
        return false;
      }

      // Convert to JSON
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'userId': userId,
        'reportCount': userReports.length,
        'reports': userReports.map((r) => r.toJson()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final fileName = 'borang_b_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      // Share the file
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Borang B Reports Backup',
        text: 'Backup contains ${userReports.length} monthly reports',
      );

      debugPrint('✅ Successfully exported ${userReports.length} reports');
      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('❌ Error exporting to file: $e');
      return false;
    }
  }

  /// Import reports from JSON file
  Future<bool> importFromFile() async {
    try {
      debugPrint('📥 Starting import from file...');

      // Pick a file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('⚠️ No file selected');
        return false;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        debugPrint('⚠️ Invalid file path');
        return false;
      }

      // Read file
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final importData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate structure
      if (!importData.containsKey('reports') || importData['reports'] is! List) {
        debugPrint('❌ Invalid backup file format');
        return false;
      }

      // Convert to BorangBData objects
      final importedReports = (importData['reports'] as List)
          .map((json) => BorangBData.fromJson(json as Map<String, dynamic>))
          .toList();

      // Get existing local reports
      final localReports = await _storageService.getAllReports();
      final localReportIds = localReports.map((r) => r.id).toSet();

      // Merge: Add imported reports that don't exist locally
      final reportsToAdd = importedReports
          .where((importedReport) => !localReportIds.contains(importedReport.id))
          .toList();

      // Save new reports locally
      for (final report in reportsToAdd) {
        await _storageService.saveReport(report);
      }

      debugPrint('✅ Successfully imported ${reportsToAdd.length} new reports');
      return true;
    } catch (e) {
      debugPrint('❌ Error importing from file: $e');
      return false;
    }
  }
}
