// lib/services/optimized_data_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/models/mission_model.dart';
import 'package:pastor_report/services/cache_service.dart';
import 'package:pastor_report/services/mission_service.dart';

/// Optimized data service with caching to reduce Firestore reads
class OptimizedDataService {
  static OptimizedDataService? _instance;
  static OptimizedDataService get instance {
    _instance ??= OptimizedDataService._();
    return _instance!;
  }

  OptimizedDataService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CacheService _cache = CacheService.instance;

  // Track last fetch time to avoid rapid successive reads
  final Map<String, DateTime> _lastFetchTimes = {};
  static const Duration _minFetchInterval = Duration(seconds: 5);

  /// Get missions with caching
  Future<List<Mission>> getMissions({bool forceRefresh = false}) async {
    final cacheKey = _cache.getMissionsListKey();

    // Try cache first (unless force refresh)
    if (!forceRefresh) {
      final cached = await _cache.getCachedList(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return cached.map((data) => Mission.fromCacheMap(data)).toList();
      }
    }

    // Check if we fetched recently
    final lastFetch = _lastFetchTimes['missions'];
    if (lastFetch != null && !forceRefresh) {
      final timeSinceLastFetch = DateTime.now().difference(lastFetch);
      if (timeSinceLastFetch < _minFetchInterval) {
        // Return cached even if expired, to avoid rapid reads
        final cached = await _cache.getCachedList(cacheKey);
        if (cached != null) {
          return cached.map((data) => Mission.fromCacheMap(data)).toList();
        }
      }
    }

    // Fetch from Firestore with cache source
    final snapshot = await _firestore
        .collection('missions')
        .orderBy('name')
        .get(const GetOptions(source: Source.serverAndCache));

    _lastFetchTimes['missions'] = DateTime.now();

    final missions = snapshot.docs.map((doc) {
      final data = doc.data();
      return Mission(
        id: doc.id,
        name: data['name'] as String? ?? '',
        code: data['code'] as String? ?? '',
        description: data['description'] as String? ?? '',
      );
    }).toList();

    // Cache the results (use toCacheMap to avoid FieldValue serialization issues)
    await _cache.setCacheList(
      cacheKey,
      missions.map((m) => m.toCacheMap()).toList(),
      'missions',
    );

    return missions;
  }

  /// Get departments for a mission with caching
  Future<List<Department>> getDepartmentsByMissionId(
    String missionId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cache.getMissionDepartmentsKey(missionId);

    // Try cache first
    if (!forceRefresh) {
      final cached = await _cache.getCachedList(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return cached.map((data) => Department.fromMap(data)).toList();
      }
    }

    // Check rate limiting
    final lastFetch = _lastFetchTimes['departments_$missionId'];
    if (lastFetch != null && !forceRefresh) {
      final timeSinceLastFetch = DateTime.now().difference(lastFetch);
      if (timeSinceLastFetch < _minFetchInterval) {
        final cached = await _cache.getCachedList(cacheKey);
        if (cached != null) {
          return cached.map((data) => Department.fromMap(data)).toList();
        }
      }
    }

    // Fetch from Firestore - Show ALL departments (active and inactive)
    final snapshot = await _firestore
        .collection('missions')
        .doc(missionId)
        .collection('departments')
        .orderBy('name')
        .get(const GetOptions(source: Source.serverAndCache));

    _lastFetchTimes['departments_$missionId'] = DateTime.now();

    final departments = snapshot.docs.map((doc) {
      final data = doc.data();
      return Department(
        id: doc.id,
        name: data['name'] as String? ?? '',
        icon:
            Department.getIconFromString(data['icon'] as String? ?? 'business'),
        formUrl: data['formUrl'] as String? ?? '',
        isActive: data['isActive'] as bool? ?? true,
        mission: data['mission'] as String? ?? '',
      );
    }).toList();

    // Cache results
    await _cache.setCacheList(
      cacheKey,
      departments.map((d) => d.toMap()).toList(),
      'departments',
    );

    return departments;
  }

  /// Get departments by mission name with caching
  Future<List<Department>> getDepartmentsByMissionName(
    String missionIdentifier, {
    bool forceRefresh = false,
  }) async {
    // First, resolve the mission name if an ID was passed
    String missionName = missionIdentifier;
    if (missionIdentifier.contains("-") || missionIdentifier.length > 20) {
      // This looks like an ID rather than a name, resolve it
      final resolvedName =
          await MissionService.instance.getMissionNameFromId(missionIdentifier);
      // If we got a resolved name, use it; otherwise keep the original
      if (resolvedName != null) {
        missionName = resolvedName;
        debugPrint(
            '🔄 Resolved mission ID "$missionIdentifier" to name: "$missionName"');
      }
    }

    final cacheKey = _cache.getMissionDepartmentsByNameKey(missionName);

    // Try cache first
    if (!forceRefresh) {
      final cached = await _cache.getCachedList(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return cached.map((data) => Department.fromMap(data)).toList();
      }
    }

    // Find mission - try two approaches
    String missionId;

    // Check if missionName is actually a document ID from Firestore
    if (missionName.length > 10 && !missionName.contains(" ")) {
      try {
        // Try to directly use it as a document ID
        final directCheck =
            await _firestore.collection('missions').doc(missionName).get();
        if (directCheck.exists) {
          debugPrint('✅ Found mission directly by ID: $missionName');
          missionId = missionName;
        } else {
          // Continue with regular name-based lookup
          final missionsSnapshot = await _firestore
              .collection('missions')
              .where('name', isEqualTo: missionName)
              .limit(1)
              .get(const GetOptions(source: Source.serverAndCache));

          if (missionsSnapshot.docs.isEmpty) {
            debugPrint('❌ No mission found by name: $missionName');
            return [];
          }

          missionId = missionsSnapshot.docs.first.id;
        }
      } catch (e) {
        debugPrint('❌ Error checking mission by ID: $e');
        // Fall back to name-based lookup
        final missionsSnapshot = await _firestore
            .collection('missions')
            .where('name', isEqualTo: missionName)
            .limit(1)
            .get(const GetOptions(source: Source.serverAndCache));

        if (missionsSnapshot.docs.isEmpty) {
          debugPrint('❌ No mission found by name: $missionName');
          return [];
        }

        missionId = missionsSnapshot.docs.first.id;
      }
    } else {
      // Standard name-based lookup
      final missionsSnapshot = await _firestore
          .collection('missions')
          .where('name', isEqualTo: missionName)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));

      if (missionsSnapshot.docs.isEmpty) {
        debugPrint('❌ No mission found by name: $missionName');
        return [];
      }

      missionId = missionsSnapshot.docs.first.id;
    }

    // Get departments for this mission
    return getDepartmentsByMissionId(missionId, forceRefresh: forceRefresh);
  }

  /// Stream departments by mission NAME or ID
  /// This method now accepts either a mission name or ID (document ID or ID from constants)
  Stream<List<Department>> streamDepartmentsByMissionName(
      String missionIdentifier) async* {
    debugPrint(
        '🎧 StreamDepartmentsByMissionName: Creating stream for mission identifier: "$missionIdentifier"');

    // First, resolve the mission name if an ID was passed
    String missionName = missionIdentifier;
    if (missionIdentifier.contains("-") || missionIdentifier.length > 20) {
      // This looks like an ID rather than a name, resolve it
      final resolvedName =
          await MissionService.instance.getMissionNameFromId(missionIdentifier);
      // If we got a resolved name, use it; otherwise keep the original
      if (resolvedName != null) {
        missionName = resolvedName;
        debugPrint(
            '🔄 Resolved mission ID "$missionIdentifier" to name: "$missionName"');
      }
    }

    // First, emit cached data for instant display
    final cached = await _cache.getCachedList(
      _cache.getMissionDepartmentsByNameKey(missionName),
    );
    if (cached != null && cached.isNotEmpty) {
      final departments = <Department>[];
      for (final data in cached) {
        try {
          departments.add(Department.fromMap(data));
        } catch (e) {
          debugPrint('Error parsing cached department: $e');
        }
      }
      if (departments.isNotEmpty) {
        yield departments;
        debugPrint(
            '📦 StreamDepartments: Emitted ${departments.length} cached departments');
      }
    }

    // Find mission first - try two approaches
    String missionId;

    // Check if missionName is actually a document ID from Firestore (e.g., "4LFC9isp22H7Og1FHBm6")
    if (missionName.length > 10 && !missionName.contains(" ")) {
      try {
        // Try to directly use it as a document ID
        final directCheck =
            await _firestore.collection('missions').doc(missionName).get();
        if (directCheck.exists) {
          debugPrint('✅ Found mission directly by ID: $missionName');
          missionId = missionName;
        } else {
          // Continue with regular name-based lookup
          final missionsSnapshot = await _firestore
              .collection('missions')
              .where('name', isEqualTo: missionName)
              .limit(1)
              .get();

          if (missionsSnapshot.docs.isEmpty) {
            debugPrint('❌ No mission found by name: $missionName');
            yield [];
            return;
          }

          missionId = missionsSnapshot.docs.first.id;
        }
      } catch (e) {
        debugPrint('❌ Error checking mission by ID: $e');
        // Fall back to name-based lookup
        final missionsSnapshot = await _firestore
            .collection('missions')
            .where('name', isEqualTo: missionName)
            .limit(1)
            .get();

        if (missionsSnapshot.docs.isEmpty) {
          debugPrint('❌ No mission found by name: $missionName');
          yield [];
          return;
        }

        missionId = missionsSnapshot.docs.first.id;
      }
    } else {
      // Standard name-based lookup
      final missionsSnapshot = await _firestore
          .collection('missions')
          .where('name', isEqualTo: missionName)
          .limit(1)
          .get();

      if (missionsSnapshot.docs.isEmpty) {
        debugPrint('❌ No mission found by name: $missionName');
        yield [];
        return;
      }

      missionId = missionsSnapshot.docs.first.id;
    }

    debugPrint('✅ Using mission ID: $missionId for departments lookup');

    // Listen to Firestore changes and yield them
    // Show ALL departments (both active and inactive)
    await for (final snapshot in _firestore
        .collection('missions')
        .doc(missionId)
        .collection('departments')
        .orderBy('name')
        .snapshots()) {
      final departments = snapshot.docs.map((doc) {
        final data = doc.data();
        return Department(
          id: doc.id,
          name: data['name'] as String? ?? '',
          icon: Department.getIconFromString(
              data['icon'] as String? ?? 'business'),
          formUrl: data['formUrl'] as String? ?? '',
          isActive: data['isActive'] as bool? ?? true,
          mission: data['mission'] as String? ?? '',
        );
      }).toList();

      debugPrint(
          '📊 OptimizedDataService: Loaded ${departments.length} departments for $missionName (active: ${departments.where((d) => d.isActive).length}, inactive: ${departments.where((d) => !d.isActive).length})');

      // Update cache
      _cache.setCacheList(
        _cache.getMissionDepartmentsByNameKey(missionName),
        departments.map((d) => d.toMap()).toList(),
        'departments',
      );

      yield departments;
    }
  }

  /// Stream missions with smart caching
  Stream<List<Mission>> streamMissions() async* {
    debugPrint('🎧 StreamMissions: Creating stream');

    // Emit cached data first
    final cached = await _cache.getCachedList(_cache.getMissionsListKey());
    if (cached != null && cached.isNotEmpty) {
      final missions = <Mission>[];
      for (final data in cached) {
        try {
          missions.add(Mission.fromCacheMap(data));
        } catch (e) {
          debugPrint('Error parsing cached mission: $e');
        }
      }
      if (missions.isNotEmpty) {
        yield missions;
        debugPrint(
            '📦 StreamMissions: Emitted ${missions.length} cached missions');
      }
    }

    // Listen to Firestore changes and yield them
    await for (final snapshot
        in _firestore.collection('missions').orderBy('name').snapshots()) {
      final missions = snapshot.docs.map((doc) {
        final data = doc.data();
        return Mission(
          id: doc.id,
          name: data['name'] as String? ?? '',
          code: data['code'] as String? ?? '',
          description: data['description'] as String? ?? '',
        );
      }).toList();

      debugPrint('📊 OptimizedDataService: Loaded ${missions.length} missions');

      // Update cache (use toCacheMap to avoid FieldValue serialization issues)
      _cache.setCacheList(
        _cache.getMissionsListKey(),
        missions.map((m) => m.toCacheMap()).toList(),
        'missions',
      );

      yield missions;
    }
  }

  /// Stream departments by mission ID - converts ID to name before fetching
  Stream<List<Department>> streamDepartmentsByMissionId(
      String? missionId) async* {
    if (missionId == null || missionId.isEmpty) {
      debugPrint('⚠️ StreamDepartmentsByMissionId: Empty mission ID');
      yield [];
      return;
    }

    // Use the MissionService to convert ID to name
    final missionService = MissionService();
    final missionName = missionService.getMissionNameById(missionId);

    debugPrint(
        '🎧 StreamDepartmentsByMissionId: Converting ID $missionId to name $missionName');

    // Ensure we're always using the mission name, not the ID
    String resolvedMissionName;

    // Special handling for known problematic IDs
    if (missionId == '4LFC9isp22H7Og1FHBm6') {
      resolvedMissionName = 'Sabah Mission';
      debugPrint(
          '🔧 Using hardcoded solution for known mission ID: $missionId -> $resolvedMissionName');
    } else {
      // For other missions, use the resolved name
      resolvedMissionName = missionName;
      // Check if it's still an ID (hasn't been resolved properly)
      if (resolvedMissionName == missionId) {
        debugPrint(
            '⚠️ Warning: Mission name not properly resolved: $missionId. Using anyway.');
      }
    }

    debugPrint(
        '🔍 Fetching departments using mission name: "$resolvedMissionName"');

    // Use the existing stream that works with mission name
    await for (final departments
        in streamDepartmentsByMissionName(resolvedMissionName)) {
      if (departments.isNotEmpty) {
        debugPrint(
            '✅ Successfully loaded ${departments.length} departments for mission: $resolvedMissionName');
        yield departments;
        return; // Exit if we got results
      }
    }

    // If we got this far, we didn't find any departments
    debugPrint('⚠️ No departments found for mission: $missionName');
    yield []; // Return empty list
  }

  /// Clear cache for a specific mission's departments
  Future<void> invalidateMissionDepartmentsCache(String missionId) async {
    await _cache.clearCache(_cache.getMissionDepartmentsKey(missionId));
    _lastFetchTimes.remove('departments_$missionId');
  }

  /// Clear all missions cache
  Future<void> invalidateMissionsCache() async {
    await _cache.clearCacheByType('missions');
    _lastFetchTimes.remove('missions');
  }

  /// Clear all departments cache
  Future<void> invalidateDepartmentsCache() async {
    await _cache.clearCacheByType('departments');
    _lastFetchTimes.removeWhere((key, value) => key.startsWith('departments_'));
  }

  /// Force refresh all caches (useful after code changes)
  Future<void> refreshAllCaches() async {
    // Clear all caches
    await _cache.clearAllCache();
    _lastFetchTimes.clear();
    debugPrint('🔄 OptimizedDataService: All caches cleared');
  }
}
