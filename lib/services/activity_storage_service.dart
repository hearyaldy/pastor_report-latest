// lib/services/activity_storage_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pastor_report/models/activity_model.dart';

/// Cloud storage service for managing activities using Firebase Firestore
class ActivityStorageService {
  static ActivityStorageService? _instance;
  static ActivityStorageService get instance {
    _instance ??= ActivityStorageService._();
    return _instance!;
  }

  ActivityStorageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _activitiesCollection = 'activities';

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Initialize the service
  Future<void> initialize() async {
    // Firestore is initialized with Firebase.initializeApp()
    debugPrint('✅ Activity Storage Service initialized with Firestore');
  }

  /// Get all activities
  Future<List<Activity>> getActivities() async {
    try {
      if (_userId == null) {
        debugPrint('⚠️ No user logged in');
        return [];
      }

      final snapshot = await _firestore
          .collection(_activitiesCollection)
          .where('userId', isEqualTo: _userId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Activity.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading activities: $e');
      return [];
    }
  }

  /// Get activities stream for real-time updates
  Stream<List<Activity>> getActivitiesStream() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_activitiesCollection)
        .where('userId', isEqualTo: _userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Activity.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Get activities within a date range
  Future<List<Activity>> getActivitiesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final activities = await getActivities();
    return activities.where((activity) {
      return activity.date
              .isAfter(startDate.subtract(const Duration(days: 1))) &&
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
      if (_userId == null) {
        debugPrint('❌ User not authenticated');
        return false;
      }

      final activityData = activity.toJson();
      activityData['userId'] = _userId;
      activityData['createdAt'] = FieldValue.serverTimestamp();
      activityData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(_activitiesCollection).add(activityData);
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
      if (_userId == null) {
        debugPrint('❌ User not authenticated');
        return false;
      }

      if (updatedActivity.id.isEmpty) {
        debugPrint('❌ Activity ID is required for update');
        return false;
      }

      final activityData = updatedActivity.toJson();
      activityData['userId'] = _userId;
      activityData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_activitiesCollection)
          .doc(updatedActivity.id)
          .update(activityData);
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
      if (_userId == null) {
        debugPrint('❌ User not authenticated');
        return false;
      }

      await _firestore
          .collection(_activitiesCollection)
          .doc(activityId)
          .delete();
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
    return activities.fold<double>(
        0.0, (sum, activity) => sum + activity.mileage);
  }

  /// Get activity count for a date range
  Future<int> getActivityCount(DateTime startDate, DateTime endDate) async {
    final activities = await getActivitiesByDateRange(startDate, endDate);
    return activities.length;
  }

  /// Clear all activities (for testing or reset)
  Future<void> clearAllActivities() async {
    try {
      if (_userId == null) {
        debugPrint('❌ User not authenticated');
        return;
      }

      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection(_activitiesCollection)
          .where('userId', isEqualTo: _userId)
          .get();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('✅ All activities cleared');
    } catch (e) {
      debugPrint('❌ Error clearing activities: $e');
    }
  }

  /// Export activities as JSON (for backup)
  Future<String> exportAsJson() async {
    final activities = await getActivities();
    return jsonEncode(activities.map((a) => a.toJson()).toList());
  }

  /// Import activities from JSON (for restore)
  Future<bool> importFromJson(String json) async {
    try {
      if (_userId == null) {
        debugPrint('❌ User not authenticated');
        return false;
      }

      final List<dynamic> decoded = jsonDecode(json);
      final activities =
          decoded.map((json) => Activity.fromJson(json)).toList();

      final batch = _firestore.batch();
      for (final activity in activities) {
        final activityData = activity.toJson();
        activityData['userId'] = _userId;
        activityData['createdAt'] = FieldValue.serverTimestamp();
        activityData['updatedAt'] = FieldValue.serverTimestamp();

        final docRef = _firestore.collection(_activitiesCollection).doc();
        batch.set(docRef, activityData);
      }

      await batch.commit();
      debugPrint('✅ Imported ${activities.length} activities');
      return true;
    } catch (e) {
      debugPrint('❌ Error importing activities: $e');
      return false;
    }
  }
}
