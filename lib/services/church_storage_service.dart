import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pastor_report/models/church_model.dart';

class ChurchStorageService {
  static ChurchStorageService? _instance;
  static ChurchStorageService get instance {
    _instance ??= ChurchStorageService._();
    return _instance!;
  }

  ChurchStorageService._();

  static const String _storageKey = 'churches';
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('✅ ChurchStorageService initialized');
  }

  /// Get all churches
  Future<List<Church>> getAllChurches() async {
    try {
      final String? jsonString = _prefs?.getString(_storageKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      final churches = jsonList
          .map((json) => Church.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort by created date (newest first)
      churches.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return churches;
    } catch (e) {
      debugPrint('❌ Error loading churches: $e');
      return [];
    }
  }

  /// Get churches for specific user
  Future<List<Church>> getUserChurches(String userId) async {
    final allChurches = await getAllChurches();
    return allChurches.where((church) => church.userId == userId).toList();
  }

  /// Save a church
  Future<bool> saveChurch(Church church) async {
    try {
      final churches = await getAllChurches();

      // Check if church exists (update) or new (add)
      final index = churches.indexWhere((c) => c.id == church.id);
      if (index != -1) {
        churches[index] = church.copyWith(updatedAt: DateTime.now());
      } else {
        churches.add(church);
      }

      final jsonString = jsonEncode(churches.map((c) => c.toJson()).toList());
      await _prefs?.setString(_storageKey, jsonString);

      debugPrint('✅ Church saved: ${church.churchName}');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving church: $e');
      return false;
    }
  }

  /// Delete a church
  Future<bool> deleteChurch(String churchId) async {
    try {
      final churches = await getAllChurches();
      churches.removeWhere((c) => c.id == churchId);

      final jsonString = jsonEncode(churches.map((c) => c.toJson()).toList());
      await _prefs?.setString(_storageKey, jsonString);

      debugPrint('🗑️ Church deleted: $churchId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting church: $e');
      return false;
    }
  }

  /// Get church by ID
  Future<Church?> getChurchById(String churchId) async {
    final churches = await getAllChurches();
    try {
      return churches.firstWhere((c) => c.id == churchId);
    } catch (e) {
      return null;
    }
  }

  /// Get statistics
  Future<Map<String, dynamic>> getStatistics(String userId) async {
    final churches = await getUserChurches(userId);

    final churchCount = churches.where((c) => c.status == ChurchStatus.organizedChurch).length;
    final companyCount = churches.where((c) => c.status == ChurchStatus.company).length;
    final branchCount = churches.where((c) => c.status == ChurchStatus.group).length;
    final totalMembers = churches.fold<int>(0, (sum, c) => sum + (c.memberCount ?? 0));

    return {
      'totalChurches': churches.length,
      'churchCount': churchCount,
      'companyCount': companyCount,
      'branchCount': branchCount,
      'totalMembers': totalMembers,
    };
  }
}
