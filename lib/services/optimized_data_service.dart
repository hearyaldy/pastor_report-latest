// lib/services/optimized_data_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/models/mission_model.dart';
import 'package:pastor_report/services/cache_service.dart';

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
        return cached.map((data) {
          final id = data['id'] as String? ?? '';
          return Mission.fromMap(data, id);
        }).toList();
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
          return cached.map((data) {
            final id = data['id'] as String? ?? '';
            return Mission.fromMap(data, id);
          }).toList();
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

    // Cache the results
    await _cache.setCacheList(
      cacheKey,
      missions.map((m) => m.toMap()).toList(),
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
        icon: Department.getIconFromString(data['icon'] as String? ?? 'business'),
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
    String missionName, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cache.getMissionDepartmentsByNameKey(missionName);

    // Try cache first
    if (!forceRefresh) {
      final cached = await _cache.getCachedList(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return cached.map((data) => Department.fromMap(data)).toList();
      }
    }

    // Find mission by name
    final missionsSnapshot = await _firestore
        .collection('missions')
        .where('name', isEqualTo: missionName)
        .limit(1)
        .get(const GetOptions(source: Source.serverAndCache));

    if (missionsSnapshot.docs.isEmpty) {
      return [];
    }

    final missionId = missionsSnapshot.docs.first.id;

    // Get departments for this mission
    return getDepartmentsByMissionId(missionId, forceRefresh: forceRefresh);
  }

  /// Stream departments with smart caching
  Stream<List<Department>> streamDepartmentsByMissionName(String missionName) async* {
    debugPrint('🎧 StreamDepartments: Creating stream for $missionName');

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
        debugPrint('📦 StreamDepartments: Emitted ${departments.length} cached departments');
      }
    }

    // Find mission first
    final missionsSnapshot = await _firestore
        .collection('missions')
        .where('name', isEqualTo: missionName)
        .limit(1)
        .get();

    if (missionsSnapshot.docs.isEmpty) {
      yield [];
      return;
    }

    final missionId = missionsSnapshot.docs.first.id;

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
          icon: Department.getIconFromString(data['icon'] as String? ?? 'business'),
          formUrl: data['formUrl'] as String? ?? '',
          isActive: data['isActive'] as bool? ?? true,
          mission: data['mission'] as String? ?? '',
        );
      }).toList();

      debugPrint('📊 OptimizedDataService: Loaded ${departments.length} departments for $missionName (active: ${departments.where((d) => d.isActive).length}, inactive: ${departments.where((d) => !d.isActive).length})');

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
          final id = data['id'] as String? ?? '';
          missions.add(Mission.fromMap(data, id));
        } catch (e) {
          debugPrint('Error parsing cached mission: $e');
        }
      }
      if (missions.isNotEmpty) {
        yield missions;
        debugPrint('📦 StreamMissions: Emitted ${missions.length} cached missions');
      }
    }

    // Listen to Firestore changes and yield them
    await for (final snapshot in _firestore
        .collection('missions')
        .orderBy('name')
        .snapshots()) {
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

      // Update cache
      _cache.setCacheList(
        _cache.getMissionsListKey(),
        missions.map((m) => m.toMap()).toList(),
        'missions',
      );

      yield missions;
    }
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
