import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/region_model.dart';

class RegionService {
  static final RegionService instance = RegionService._internal();
  factory RegionService() => instance;
  RegionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'regions';

  // Cache for region names by ID
  final Map<String, String> _regionNameCache = {};
  // Cache for regions by mission
  final Map<String, List<Region>> _missionRegionsCache = {};

  // Create a new region
  Future<void> createRegion(Region region) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(region.id)
          .set(region.toMap());
    } catch (e) {
      throw Exception('Failed to create region: $e');
    }
  }

  // Get a region by ID
  Future<Region?> getRegionById(String regionId) async {
    try {
      final doc =
          await _firestore.collection(_collectionName).doc(regionId).get();

      if (doc.exists) {
        return Region.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get region: $e');
    }
  }

  // Get all regions for a mission (using either ID or name)
  Future<List<Region>> getRegionsByMission(String missionId) async {
    try {
      print('RegionService: Querying regions with missionId=$missionId');

      // Try querying by missionId field first
      var querySnapshot = await _firestore
          .collection(_collectionName)
          .where('missionId', isEqualTo: missionId)
          .orderBy('name')
          .get();

      print(
          'RegionService: Found ${querySnapshot.docs.length} regions by missionId');

      // If no results, try querying by 'mission' field (backward compatibility)
      if (querySnapshot.docs.isEmpty) {
        print(
            'RegionService: No results by missionId, trying mission field...');
        querySnapshot = await _firestore
            .collection(_collectionName)
            .where('mission', isEqualTo: missionId)
            .orderBy('name')
            .get();
        print(
            'RegionService: Found ${querySnapshot.docs.length} regions by mission field');
      }

      // If we still have no results, try getting all regions and filtering manually
      // This is a workaround for cases where missionId might be stored as the mission name
      if (querySnapshot.docs.isEmpty) {
        print(
            'RegionService: Still no results, trying to get all regions and filter manually');

        final allRegionsSnapshot =
            await _firestore.collection(_collectionName).orderBy('name').get();

        // Get mission by ID to get its name
        final missionsSnapshot = await _firestore
            .collection('missions')
            .where(FieldPath.documentId, isEqualTo: missionId)
            .limit(1)
            .get();

        if (missionsSnapshot.docs.isNotEmpty) {
          final missionName = missionsSnapshot.docs.first.get('name');
          print(
              'RegionService: Found mission name: $missionName for ID: $missionId');

          // Filter manually by mission name
          final filteredDocs = allRegionsSnapshot.docs.where((doc) {
            final data = doc.data();
            final regionMissionId = data['missionId'] ?? data['mission'] ?? '';
            return regionMissionId == missionName ||
                regionMissionId.toString().toLowerCase() ==
                    missionName.toString().toLowerCase();
          }).toList();

          print(
              'RegionService: Found ${filteredDocs.length} regions by mission name');

          // If we found regions, return them
          if (filteredDocs.isNotEmpty) {
            return filteredDocs.map((doc) => Region.fromSnapshot(doc)).toList();
          }
        }
      }

      for (var doc in querySnapshot.docs) {
        print('  Region doc: ${doc.id} - ${doc.data()}');
      }

      return querySnapshot.docs.map((doc) => Region.fromSnapshot(doc)).toList();
    } catch (e) {
      print('RegionService ERROR: $e');
      throw Exception('Failed to get regions: $e');
    }
  }

  // Stream all regions for a mission (real-time updates)
  Stream<List<Region>> streamRegionsByMission(String missionId) {
    print('RegionService: Streaming regions with missionId=$missionId');

    // First try the direct missionId query
    return _firestore
        .collection(_collectionName)
        .where('missionId', isEqualTo: missionId)
        .orderBy('name')
        .snapshots()
        .asyncMap((snapshot) async {
      print(
          'RegionService: Stream found ${snapshot.docs.length} regions by missionId');

      // If no results, try the mission field for backward compatibility
      if (snapshot.docs.isEmpty) {
        print('RegionService: Stream trying mission field...');
        final missionSnapshot = await _firestore
            .collection(_collectionName)
            .where('mission', isEqualTo: missionId)
            .orderBy('name')
            .get();

        print(
            'RegionService: Stream found ${missionSnapshot.docs.length} regions by mission field');

        if (missionSnapshot.docs.isNotEmpty) {
          return missionSnapshot.docs
              .map((doc) => Region.fromSnapshot(doc))
              .toList();
        }

        // If still no results, try getting mission name and filtering
        try {
          final missionsSnapshot = await _firestore
              .collection('missions')
              .where(FieldPath.documentId, isEqualTo: missionId)
              .limit(1)
              .get();

          if (missionsSnapshot.docs.isNotEmpty) {
            final missionName = missionsSnapshot.docs.first.get('name');
            print(
                'RegionService: Stream found mission name: $missionName for ID: $missionId');

            final allRegionsSnapshot = await _firestore
                .collection(_collectionName)
                .orderBy('name')
                .get();

            final filteredRegions = allRegionsSnapshot.docs
                .where((doc) {
                  final data = doc.data();
                  final regionMissionId =
                      data['missionId'] ?? data['mission'] ?? '';
                  return regionMissionId == missionName ||
                      regionMissionId.toString().toLowerCase() ==
                          missionName.toString().toLowerCase();
                })
                .map((doc) => Region.fromSnapshot(doc))
                .toList();

            print(
                'RegionService: Stream found ${filteredRegions.length} regions by mission name');
            return filteredRegions;
          }
        } catch (e) {
          print('RegionService: Stream error during mission name lookup: $e');
        }
      }

      final regions =
          snapshot.docs.map((doc) => Region.fromSnapshot(doc)).toList();
      for (var region in regions) {
        print(
            '  Stream Region: ${region.id} - ${region.name} (mission: ${region.missionId})');
      }
      return regions;
    });
  }

  // Update a region
  Future<void> updateRegion(Region region) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(region.id)
          .update(region.toMap());
    } catch (e) {
      throw Exception('Failed to update region: $e');
    }
  }

  // Delete a region
  Future<void> deleteRegion(String regionId) async {
    try {
      // Check if there are any districts in this region
      final districtsSnapshot = await _firestore
          .collection('districts')
          .where('regionId', isEqualTo: regionId)
          .limit(1)
          .get();

      if (districtsSnapshot.docs.isNotEmpty) {
        throw Exception(
            'Cannot delete region: There are districts assigned to this region');
      }

      await _firestore.collection(_collectionName).doc(regionId).delete();
    } catch (e) {
      throw Exception('Failed to delete region: $e');
    }
  }

  // Get all regions (for super admin)
  Future<List<Region>> getAllRegions() async {
    try {
      final querySnapshot =
          await _firestore.collection(_collectionName).orderBy('name').get();

      return querySnapshot.docs.map((doc) => Region.fromSnapshot(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get all regions: $e');
    }
  }

  // Stream all regions (for super admin)
  Stream<List<Region>> streamAllRegions() {
    return _firestore
        .collection(_collectionName)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Region.fromSnapshot(doc)).toList());
  }

  // Check if region code exists in mission
  Future<bool> isRegionCodeExists(String code, String missionId,
      {String? excludeRegionId}) async {
    try {
      var query = _firestore
          .collection(_collectionName)
          .where('code', isEqualTo: code)
          .where('missionId', isEqualTo: missionId);

      final snapshot = await query.get();

      if (excludeRegionId != null) {
        return snapshot.docs.any((doc) => doc.id != excludeRegionId);
      }

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check region code: $e');
    }
  }

  // Convert region ID to name
  Future<String> getRegionNameById(String? regionId) async {
    if (regionId == null || regionId.isEmpty) {
      return "Unknown Region";
    }

    try {
      // First try direct lookup
      final region = await getRegionById(regionId);
      if (region != null) {
        return region.name;
      }

      // Try to find in all regions
      final regions = await getAllRegions();
      for (final r in regions) {
        if (r.id == regionId) {
          return r.name;
        }
      }

      // If still not found, return the ID as a last resort
      print(
          'RegionService: Could not find region name for ID $regionId, returning ID');
      return regionId;
    } catch (e) {
      print('RegionService: Error getting region name for ID $regionId: $e');
      return "Unknown Region";
    }
  }

  // Get a region name safely, trying multiple approaches
  Future<String> resolveRegionName(String? regionId,
      {String? missionId}) async {
    if (regionId == null || regionId.isEmpty) {
      return "";
    }

    // Check cache first
    if (_regionNameCache.containsKey(regionId)) {
      print(
          'RegionService: Using cached region name: ${_regionNameCache[regionId]} for ID: $regionId');
      return _regionNameCache[regionId]!;
    }

    try {
      // Step 1: Try direct lookup by ID
      final region = await getRegionById(regionId);
      if (region != null) {
        print('RegionService: Found region by direct lookup: ${region.name}');
        _regionNameCache[regionId] = region.name; // Cache result
        return region.name;
      }

      // Step 2: Search in all regions
      final allRegions = await getAllRegions();
      for (final r in allRegions) {
        if (r.id == regionId) {
          print('RegionService: Found region in all regions: ${r.name}');
          _regionNameCache[regionId] = r.name; // Cache result
          return r.name;
        }
      }

      // Step 3: If missionId is provided, try to find regions for this mission
      if (missionId != null && missionId.isNotEmpty) {
        print('RegionService: Trying to find region by mission: $missionId');

        List<Region> missionRegions;
        if (_missionRegionsCache.containsKey(missionId)) {
          missionRegions = _missionRegionsCache[missionId]!;
          print(
              'RegionService: Using cached mission regions (${missionRegions.length}) for mission: $missionId');
        } else {
          missionRegions = await getRegionsByMission(missionId);
          _missionRegionsCache[missionId] = missionRegions; // Cache result
        }

        if (missionRegions.isNotEmpty) {
          // If mission has only one region, use that as a fallback
          if (missionRegions.length == 1) {
            print(
                'RegionService: Using mission\'s sole region: ${missionRegions[0].name}');
            _regionNameCache[regionId] = missionRegions[0].name; // Cache result
            return missionRegions[0].name;
          }

          // Try to find a region with a similar ID or name
          for (final r in missionRegions) {
            if (r.id == regionId ||
                r.id.contains(regionId) ||
                regionId.contains(r.id) ||
                r.name.toLowerCase().contains(regionId.toLowerCase())) {
              print('RegionService: Found similar region: ${r.name}');
              _regionNameCache[regionId] = r.name; // Cache result
              return r.name;
            }
          }
        }
      }

      // Step 4: If all else fails, use the ID
      _regionNameCache[regionId] = regionId; // Cache the fallback
      return regionId;
    } catch (e) {
      print('RegionService: Error resolving region name: $e');
      return regionId;
    }
  }

  // Clear all caches
  void clearCaches() {
    _regionNameCache.clear();
    _missionRegionsCache.clear();
  }

  // Manually remove specific regions by ID
  Future<void> deleteRegionsByIds(List<String> regionIds) async {
    for (var regionId in regionIds) {
      await deleteRegion(regionId);
      print('Deleted region: $regionId');
    }
  }

  // Update mission for multiple regions (to reassign them)
  Future<void> reassignRegionsToMission(
      List<String> regionIds, String newMissionId) async {
    for (var regionId in regionIds) {
      final region = await getRegionById(regionId);
      if (region != null) {
        final updated = region.copyWith(missionId: newMissionId);
        await updateRegion(updated);
        print('Reassigned region ${region.name} to mission $newMissionId');
      }
    }
  }

  // Fix NSM regions: Keep only NSM regions 1-4, REASSIGN regions 5-12 to Sabah Mission
  Future<Map<String, dynamic>> fixNorthSabahMissionRegions({
    required String northSabahMissionId,
    required String sabahMissionId,
  }) async {
    try {
      print('RegionService: Starting NSM region fix...');
      print('  North Sabah Mission ID: $northSabahMissionId');
      print('  Sabah Mission ID: $sabahMissionId');

      // Get all regions currently under North Sabah Mission
      final nsmRegions = await getRegionsByMission(northSabahMissionId);
      print('  Found ${nsmRegions.length} regions under NSM');

      // Regions that should stay with NSM (Region 1-4)
      final regionsToKeep = <String>[
        'nsm_region_1',
        'nsm_region_2',
        'nsm_region_3',
        'nsm_region_4',
      ];

      // Separate regions
      final toKeep = <Region>[];
      final toReassign = <Region>[];

      for (var region in nsmRegions) {
        if (regionsToKeep.contains(region.id)) {
          toKeep.add(region);
          print('  ✓ Keep: ${region.name} (${region.id})');
        } else {
          // This is Region 5-12, should be reassigned to Sabah Mission
          toReassign.add(region);
          print('  → Reassign: ${region.name} (${region.id})');
        }
      }

      // Reassign regions to Sabah Mission (preserving their IDs)
      final reassigned = <String>[];

      for (var region in toReassign) {
        try {
          // Update the region's missionId
          await _firestore.collection(_collectionName).doc(region.id).update({
            'missionId': sabahMissionId,
          });

          // Also update all districts in this region
          final districts = await _firestore
              .collection('districts')
              .where('regionId', isEqualTo: region.id)
              .get();

          for (var districtDoc in districts.docs) {
            await _firestore.collection('districts').doc(districtDoc.id).update({
              'missionId': sabahMissionId,
            });
          }

          // Update all churches in this region
          final churches = await _firestore
              .collection('churches')
              .where('regionId', isEqualTo: region.id)
              .get();

          for (var churchDoc in churches.docs) {
            await _firestore.collection('churches').doc(churchDoc.id).update({
              'missionId': sabahMissionId,
            });
          }

          reassigned.add(region.name);
          print('  ✓ Reassigned ${region.name} to Sabah Mission');
        } catch (e) {
          print('  ✗ Error reassigning ${region.name}: $e');
        }
      }

      clearCaches();

      return {
        'success': true,
        'message': 'Migration completed successfully',
        'kept': toKeep.length,
        'reassigned': reassigned.length,
        'details': {
          'kept': toKeep.map((r) => r.name).toList(),
          'reassigned': reassigned,
        },
      };
    } catch (e) {
      print('RegionService: Error during migration: $e');
      return {
        'success': false,
        'message': 'Error during migration: $e',
      };
    }
  }

  // Emergency: Restore Sabah Mission regions by deleting recently created ones
  Future<Map<String, dynamic>> emergencyCleanupSabahDuplicates(
      String sabahMissionId) async {
    try {
      print('RegionService: Emergency cleanup for Sabah Mission...');

      // Get all regions for Sabah Mission
      final sabahRegions = await getRegionsByMission(sabahMissionId);
      print('  Found ${sabahRegions.length} regions');

      // Group by name to find duplicates
      final regionsByName = <String, List<Region>>{};
      for (var region in sabahRegions) {
        regionsByName.putIfAbsent(region.name, () => []).add(region);
      }

      final deleted = <String>[];

      // For duplicates, keep the OLDER one (original), delete the newer one
      for (var entry in regionsByName.entries) {
        if (entry.value.length > 1) {
          // Sort by creation date (oldest first)
          final regions = entry.value.toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

          // Keep the oldest (first), delete the rest
          final toKeep = regions.first;
          final toDelete = regions.sublist(1);

          print('  ${entry.key}: Keep ${toKeep.id}, Delete ${toDelete.length}');

          for (var region in toDelete) {
            try {
              await _firestore
                  .collection(_collectionName)
                  .doc(region.id)
                  .delete();
              deleted.add('${region.name} (${region.id})');
              print('    ✓ Deleted ${region.id}');
            } catch (e) {
              print('    ✗ Error deleting ${region.id}: $e');
            }
          }
        }
      }

      clearCaches();

      return {
        'success': true,
        'message': 'Emergency cleanup completed',
        'deleted': deleted.length,
        'details': {'deleted': deleted},
      };
    } catch (e) {
      print('RegionService: Error: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Clean up duplicate regions for a mission
  // Keeps the most recent region and removes older duplicates
  Future<Map<String, dynamic>> cleanupDuplicateRegions(String missionId) async {
    try {
      print('RegionService: Starting cleanup for mission $missionId');

      // Get all regions for this mission
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('missionId', isEqualTo: missionId)
          .get();

      print('RegionService: Found ${querySnapshot.docs.length} regions');

      // Group regions by name
      final regionsByName = <String, List<QueryDocumentSnapshot>>{};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String;
        regionsByName.putIfAbsent(name, () => []).add(doc);
      }

      // Find duplicates
      final duplicates = <String, List<QueryDocumentSnapshot>>{};
      regionsByName.forEach((name, docs) {
        if (docs.length > 1) {
          duplicates[name] = docs;
        }
      });

      if (duplicates.isEmpty) {
        print('RegionService: No duplicates found');
        return {
          'success': true,
          'message': 'No duplicates found',
          'duplicatesRemoved': 0,
          'totalRegions': querySnapshot.docs.length,
        };
      }

      print('RegionService: Found ${duplicates.length} region names with duplicates');

      // Identify which regions to remove
      final toRemove = <QueryDocumentSnapshot>[];
      final details = <String, dynamic>{};

      duplicates.forEach((name, docs) {
        print('  Checking "$name" (${docs.length} duplicates)');

        // Sort by creation date (most recent first)
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime); // Descending (newest first)
        });

        // Keep the first (most recent), mark rest for deletion
        final toKeep = docs.first;
        final toDelete = docs.sublist(1);

        details[name] = {
          'kept': toKeep.id,
          'removed': toDelete.map((d) => d.id).toList(),
        };

        toRemove.addAll(toDelete);
      });

      print('RegionService: Will remove ${toRemove.length} duplicate regions');

      // Delete the duplicates
      for (var doc in toRemove) {
        print('  Deleting: ${doc.id}');
        await _firestore.collection(_collectionName).doc(doc.id).delete();
      }

      clearCaches(); // Clear caches after deletion

      return {
        'success': true,
        'message':
            'Successfully removed ${toRemove.length} duplicate region(s)',
        'duplicatesRemoved': toRemove.length,
        'totalRegions': querySnapshot.docs.length - toRemove.length,
        'details': details,
      };
    } catch (e) {
      print('RegionService: Error during cleanup: $e');
      return {
        'success': false,
        'message': 'Error during cleanup: $e',
        'duplicatesRemoved': 0,
      };
    }
  }
}
