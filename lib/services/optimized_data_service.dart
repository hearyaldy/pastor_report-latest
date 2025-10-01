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

  // In-memory cache for active streams
  final Map<String, StreamController<List<Department>>> _departmentStreamControllers = {};
  final Map<String, StreamController<List<Mission>>> _missionStreamControllers = {};

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
  Stream<List<Department>> streamDepartmentsByMissionName(String missionName) {
    final streamKey = 'stream_departments_$missionName';

    // Reuse existing stream if available
    if (_departmentStreamControllers.containsKey(streamKey)) {
      return _departmentStreamControllers[streamKey]!.stream;
    }

    // Create new stream controller
    late StreamController<List<Department>> controller;

    controller = StreamController<List<Department>>.broadcast(
      onListen: () async {
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
              // Skip invalid data
            }
          }
          if (departments.isNotEmpty) {
            controller.add(departments);
          }
        }

        // Then set up Firestore listener
        // Find mission first
        final missionsSnapshot = await _firestore
            .collection('missions')
            .where('name', isEqualTo: missionName)
            .limit(1)
            .get();

        if (missionsSnapshot.docs.isEmpty) {
          controller.add([]);
          return;
        }

        final missionId = missionsSnapshot.docs.first.id;

        // Listen to changes (but Firestore will use cache when offline)
        // Show ALL departments (both active and inactive)
        _firestore
            .collection('missions')
            .doc(missionId)
            .collection('departments')
            .orderBy('name')
            .snapshots()
            .listen(
          (snapshot) {
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

            controller.add(departments);
          },
          onError: (error) {
            controller.addError(error);
          },
        );
      },
      onCancel: () {
        _departmentStreamControllers.remove(streamKey);
      },
    );

    _departmentStreamControllers[streamKey] = controller;
    return controller.stream;
  }

  /// Stream missions with smart caching
  Stream<List<Mission>> streamMissions() {
    const streamKey = 'stream_missions';

    // Reuse existing stream
    if (_missionStreamControllers.containsKey(streamKey)) {
      return _missionStreamControllers[streamKey]!.stream;
    }

    late StreamController<List<Mission>> controller;

    controller = StreamController<List<Mission>>.broadcast(
      onListen: () async {
        // Emit cached data first
        final cached = await _cache.getCachedList(_cache.getMissionsListKey());
        if (cached != null && cached.isNotEmpty) {
          final missions = <Mission>[];
          for (final data in cached) {
            try {
              final id = data['id'] as String? ?? '';
              missions.add(Mission.fromMap(data, id));
            } catch (e) {
              // Skip invalid data
            }
          }
          if (missions.isNotEmpty) {
            controller.add(missions);
          }
        }

        // Set up Firestore listener
        _firestore
            .collection('missions')
            .orderBy('name')
            .snapshots()
            .listen(
          (snapshot) {
            final missions = snapshot.docs.map((doc) {
              final data = doc.data();
              return Mission(
                id: doc.id,
                name: data['name'] as String? ?? '',
                code: data['code'] as String? ?? '',
                description: data['description'] as String? ?? '',
              );
            }).toList();

            // Update cache
            _cache.setCacheList(
              _cache.getMissionsListKey(),
              missions.map((m) => m.toMap()).toList(),
              'missions',
            );

            controller.add(missions);
          },
          onError: (error) {
            controller.addError(error);
          },
        );
      },
      onCancel: () {
        _missionStreamControllers.remove(streamKey);
      },
    );

    _missionStreamControllers[streamKey] = controller;
    return controller.stream;
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

  /// Force refresh all department streams (useful after code changes)
  Future<void> refreshAllStreams() async {
    // Close all existing stream controllers
    for (final controller in _departmentStreamControllers.values) {
      await controller.close();
    }
    for (final controller in _missionStreamControllers.values) {
      await controller.close();
    }

    // Clear the maps so new streams will be created
    _departmentStreamControllers.clear();
    _missionStreamControllers.clear();

    // Clear all caches
    await _cache.clearAllCache();
    _lastFetchTimes.clear();
  }

  /// Dispose all stream controllers
  void dispose() {
    for (final controller in _departmentStreamControllers.values) {
      controller.close();
    }
    for (final controller in _missionStreamControllers.values) {
      controller.close();
    }
    _departmentStreamControllers.clear();
    _missionStreamControllers.clear();
  }
}
