// lib/services/cache_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for caching Firestore data to reduce read/write costs
class CacheService {
  static CacheService? _instance;
  static CacheService get instance {
    _instance ??= CacheService._();
    return _instance!;
  }

  CacheService._();

  SharedPreferences? _prefs;

  /// Initialize cache service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Cache duration configurations
  static const Duration missionsCacheDuration = Duration(hours: 24);
  static const Duration departmentsCacheDuration = Duration(hours: 12);
  static const Duration usersCacheDuration = Duration(minutes: 30);

  /// Get cached data with expiry check
  Future<Map<String, dynamic>?> getCached(String key) async {
    if (_prefs == null) await initialize();

    final cachedData = _prefs!.getString(key);
    if (cachedData == null) return null;

    try {
      final data = jsonDecode(cachedData) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int?;
      final cacheType = data['type'] as String?;

      if (timestamp == null) return null;

      // Check if cache is still valid
      final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      Duration maxAge;
      switch (cacheType) {
        case 'missions':
          maxAge = missionsCacheDuration;
          break;
        case 'departments':
          maxAge = departmentsCacheDuration;
          break;
        case 'users':
          maxAge = usersCacheDuration;
          break;
        default:
          maxAge = const Duration(hours: 1);
      }

      if (now.difference(cachedTime) > maxAge) {
        // Cache expired
        await _prefs!.remove(key);
        return null;
      }

      return data['data'] as Map<String, dynamic>?;
    } catch (e) {
      // Invalid cache data, remove it
      await _prefs!.remove(key);
      return null;
    }
  }

  /// Set cached data with timestamp
  Future<void> setCache(String key, Map<String, dynamic> data, String type) async {
    if (_prefs == null) await initialize();

    final cacheData = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': type,
      'data': data,
    };

    await _prefs!.setString(key, jsonEncode(cacheData));
  }

  /// Set cached list data
  Future<void> setCacheList(String key, List<Map<String, dynamic>> data, String type) async {
    if (_prefs == null) await initialize();

    final cacheData = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': type,
      'data': data,
    };

    await _prefs!.setString(key, jsonEncode(cacheData));
  }

  /// Get cached list data
  Future<List<Map<String, dynamic>>?> getCachedList(String key) async {
    if (_prefs == null) await initialize();

    final cachedData = _prefs!.getString(key);
    if (cachedData == null) return null;

    try {
      final data = jsonDecode(cachedData) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int?;
      final cacheType = data['type'] as String?;

      if (timestamp == null) return null;

      // Check if cache is still valid
      final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      Duration maxAge;
      switch (cacheType) {
        case 'missions':
          maxAge = missionsCacheDuration;
          break;
        case 'departments':
          maxAge = departmentsCacheDuration;
          break;
        case 'users':
          maxAge = usersCacheDuration;
          break;
        default:
          maxAge = const Duration(hours: 1);
      }

      if (now.difference(cachedTime) > maxAge) {
        // Cache expired
        await _prefs!.remove(key);
        return null;
      }

      final list = data['data'] as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      // Invalid cache data, remove it
      await _prefs!.remove(key);
      return null;
    }
  }

  /// Clear specific cache key
  Future<void> clearCache(String key) async {
    if (_prefs == null) await initialize();
    await _prefs!.remove(key);
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    if (_prefs == null) await initialize();

    // Get all keys
    final keys = _prefs!.getKeys();

    // Remove all cache keys
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }

  /// Clear cache by type
  Future<void> clearCacheByType(String type) async {
    if (_prefs == null) await initialize();

    final keys = _prefs!.getKeys();

    for (final key in keys) {
      final cachedData = _prefs!.getString(key);
      if (cachedData != null) {
        try {
          final data = jsonDecode(cachedData) as Map<String, dynamic>;
          if (data['type'] == type) {
            await _prefs!.remove(key);
          }
        } catch (e) {
          // Skip invalid data
        }
      }
    }
  }

  /// Generate cache key for missions list
  String getMissionsListKey() => 'cache_missions_list';

  /// Generate cache key for specific mission
  String getMissionKey(String missionId) => 'cache_mission_$missionId';

  /// Generate cache key for mission departments
  String getMissionDepartmentsKey(String missionId) => 'cache_departments_mission_$missionId';

  /// Generate cache key for mission departments by name
  String getMissionDepartmentsByNameKey(String missionName) => 'cache_departments_name_$missionName';

  /// Generate cache key for users list
  String getUsersListKey() => 'cache_users_list';

  /// Generate cache key for specific user
  String getUserKey(String userId) => 'cache_user_$userId';
}

/// Extension to enable Firestore caching globally
extension FirestoreCacheExtension on FirebaseFirestore {
  /// Enable persistence and caching
  static Future<void> enableCaching() async {
    try {
      final settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      FirebaseFirestore.instance.settings = settings;
    } catch (e) {
      print('Failed to enable Firestore caching: $e');
    }
  }
}
