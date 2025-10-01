// lib/services/activity_storage_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pastor_report/models/activity_model.dart';

/// Local storage service for managing activities
class ActivityStorageService {
  static ActivityStorageService? _instance;
  static ActivityStorageService get instance {
    _instance ??= ActivityStorageService._();
    return _instance!;
  }

  ActivityStorageService._();

  static const String _activitiesKey = 'user_activities';
  SharedPreferences? _prefs;

  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get all activities
  Future<List<Activity>> getActivities() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();

      final String? activitiesJson = _prefs!.getString(_activitiesKey);
      if (activitiesJson == null || activitiesJson.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(activitiesJson);
      return decoded.map((json) => Activity.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading activities: $e');
      return [];
    }
  }

  /// Get activities within a date range
  Future<List<Activity>> getActivitiesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final activities = await getActivities();
    return activities.where((activity) {
      return activity.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
          activity.date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  /// Get activities for a specific month
  Future<List<Activity>> getActivitiesByMonth(int year, int month) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);
    return getActivitiesByDateRange(startDate, endDate);
  }

  /// Add a new activity
  Future<bool> addActivity(Activity activity) async {
    try {
      final activities = await getActivities();
      activities.add(activity);

      // Sort by date (newest first)
      activities.sort((a, b) => b.date.compareTo(a.date));

      await _saveActivities(activities);
      debugPrint('✅ Activity added: ${activity.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding activity: $e');
      return false;
    }
  }

  /// Update an existing activity
  Future<bool> updateActivity(Activity updatedActivity) async {
    try {
      final activities = await getActivities();
      final index = activities.indexWhere((a) => a.id == updatedActivity.id);

      if (index == -1) {
        debugPrint('❌ Activity not found: ${updatedActivity.id}');
        return false;
      }

      activities[index] = updatedActivity.copyWith(
        updatedAt: DateTime.now(),
      );

      // Sort by date (newest first)
      activities.sort((a, b) => b.date.compareTo(a.date));

      await _saveActivities(activities);
      debugPrint('✅ Activity updated: ${updatedActivity.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating activity: $e');
      return false;
    }
  }

  /// Delete an activity
  Future<bool> deleteActivity(String activityId) async {
    try {
      final activities = await getActivities();
      activities.removeWhere((a) => a.id == activityId);

      await _saveActivities(activities);
      debugPrint('✅ Activity deleted: $activityId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting activity: $e');
      return false;
    }
  }

  /// Get total mileage for a date range
  Future<double> getTotalMileage(DateTime startDate, DateTime endDate) async {
    final activities = await getActivitiesByDateRange(startDate, endDate);
    return activities.fold<double>(0.0, (sum, activity) => sum + activity.mileage);
  }

  /// Get activity count for a date range
  Future<int> getActivityCount(DateTime startDate, DateTime endDate) async {
    final activities = await getActivitiesByDateRange(startDate, endDate);
    return activities.length;
  }

  /// Clear all activities (for testing or reset)
  Future<void> clearAllActivities() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(_activitiesKey);
      debugPrint('✅ All activities cleared');
    } catch (e) {
      debugPrint('❌ Error clearing activities: $e');
    }
  }

  /// Save activities to local storage
  Future<void> _saveActivities(List<Activity> activities) async {
    _prefs ??= await SharedPreferences.getInstance();

    final activitiesJson = jsonEncode(
      activities.map((a) => a.toJson()).toList(),
    );

    await _prefs!.setString(_activitiesKey, activitiesJson);
  }

  /// Export activities as JSON (for backup)
  Future<String> exportAsJson() async {
    final activities = await getActivities();
    return jsonEncode(activities.map((a) => a.toJson()).toList());
  }

  /// Import activities from JSON (for restore)
  Future<bool> importFromJson(String json) async {
    try {
      final List<dynamic> decoded = jsonDecode(json);
      final activities = decoded.map((json) => Activity.fromJson(json)).toList();

      await _saveActivities(activities);
      debugPrint('✅ Imported ${activities.length} activities');
      return true;
    } catch (e) {
      debugPrint('❌ Error importing activities: $e');
      return false;
    }
  }
}
