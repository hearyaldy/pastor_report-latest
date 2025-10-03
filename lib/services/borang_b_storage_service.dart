// lib/services/borang_b_storage_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pastor_report/models/borang_b_model.dart';

class BorangBStorageService {
  static BorangBStorageService? _instance;
  static BorangBStorageService get instance {
    _instance ??= BorangBStorageService._();
    return _instance!;
  }

  BorangBStorageService._();

  static const String _storageKey = 'borang_b_data';
  SharedPreferences? _prefs;

  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('✅ BorangBStorageService initialized');
  }

  /// Get all Borang B reports
  Future<List<BorangBData>> getAllReports() async {
    try {
      final String? jsonString = _prefs?.getString(_storageKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString);
      final reports = jsonList
          .map((json) => BorangBData.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort by month (newest first)
      reports.sort((a, b) => b.month.compareTo(a.month));

      debugPrint('📊 Loaded ${reports.length} Borang B reports');
      return reports;
    } catch (e) {
      debugPrint('❌ Error loading Borang B reports: $e');
      return [];
    }
  }

  /// Get report for specific month
  Future<BorangBData?> getReportByMonth(int year, int month) async {
    try {
      final reports = await getAllReports();

      return reports.firstWhere(
        (report) => report.month.year == year && report.month.month == month,
        orElse: () => throw Exception('Not found'),
      );
    } catch (e) {
      return null; // No report for this month
    }
  }

  /// Get reports by user ID
  Future<List<BorangBData>> getReportsByUserId(String userId) async {
    try {
      final reports = await getAllReports();
      return reports.where((report) => report.userId == userId).toList();
    } catch (e) {
      debugPrint('❌ Error getting reports by user: $e');
      return [];
    }
  }

  /// Save or update a report
  Future<bool> saveReport(BorangBData report) async {
    try {
      final reports = await getAllReports();

      // Check if report for this month already exists
      final existingIndex = reports.indexWhere(
        (r) => r.month.year == report.month.year &&
               r.month.month == report.month.month &&
               r.userId == report.userId,
      );

      if (existingIndex != -1) {
        // Update existing report
        reports[existingIndex] = report.copyWith(updatedAt: DateTime.now());
        debugPrint('📝 Updated Borang B for ${report.month.year}-${report.month.month}');
      } else {
        // Add new report
        reports.add(report);
        debugPrint('➕ Added new Borang B for ${report.month.year}-${report.month.month}');
      }

      // Save to storage
      final jsonList = reports.map((r) => r.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _prefs?.setString(_storageKey, jsonString);

      return true;
    } catch (e) {
      debugPrint('❌ Error saving Borang B report: $e');
      return false;
    }
  }

  /// Delete a report
  Future<bool> deleteReport(String id) async {
    try {
      final reports = await getAllReports();
      final initialLength = reports.length;

      reports.removeWhere((report) => report.id == id);

      if (reports.length < initialLength) {
        final jsonList = reports.map((r) => r.toJson()).toList();
        final jsonString = json.encode(jsonList);
        await _prefs?.setString(_storageKey, jsonString);

        debugPrint('🗑️ Deleted Borang B report: $id');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error deleting Borang B report: $e');
      return false;
    }
  }

  /// Delete report by month
  Future<bool> deleteReportByMonth(int year, int month, String userId) async {
    try {
      final report = await getReportByMonth(year, month);
      if (report != null && report.userId == userId) {
        return await deleteReport(report.id);
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting report by month: $e');
      return false;
    }
  }

  /// Check if report exists for a specific month
  Future<bool> hasReportForMonth(int year, int month, String userId) async {
    final report = await getReportByMonth(year, month);
    return report != null && report.userId == userId;
  }

  /// Get reports for a specific year
  Future<List<BorangBData>> getReportsByYear(int year, String userId) async {
    try {
      final reports = await getAllReports();
      return reports
          .where((r) => r.month.year == year && r.userId == userId)
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting reports by year: $e');
      return [];
    }
  }

  /// Clear all reports (use with caution!)
  Future<bool> clearAllReports() async {
    try {
      await _prefs?.remove(_storageKey);
      debugPrint('🗑️ Cleared all Borang B reports');
      return true;
    } catch (e) {
      debugPrint('❌ Error clearing reports: $e');
      return false;
    }
  }

  /// Export all reports as JSON string (for backup)
  Future<String?> exportAsJson() async {
    try {
      final reports = await getAllReports();
      final jsonList = reports.map((r) => r.toJson()).toList();
      return json.encode(jsonList);
    } catch (e) {
      debugPrint('❌ Error exporting reports: $e');
      return null;
    }
  }

  /// Import reports from JSON string (for restore)
  Future<bool> importFromJson(String jsonString) async {
    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      final reports = jsonList
          .map((json) => BorangBData.fromJson(json as Map<String, dynamic>))
          .toList();

      final existingReports = await getAllReports();

      // Merge with existing reports (avoid duplicates)
      for (final newReport in reports) {
        final exists = existingReports.any(
          (r) => r.month.year == newReport.month.year &&
                 r.month.month == newReport.month.month &&
                 r.userId == newReport.userId,
        );

        if (!exists) {
          existingReports.add(newReport);
        }
      }

      // Save merged reports
      final mergedJsonList = existingReports.map((r) => r.toJson()).toList();
      final mergedJsonString = json.encode(mergedJsonList);
      await _prefs?.setString(_storageKey, mergedJsonString);

      debugPrint('📥 Imported ${reports.length} Borang B reports');
      return true;
    } catch (e) {
      debugPrint('❌ Error importing reports: $e');
      return false;
    }
  }
}
