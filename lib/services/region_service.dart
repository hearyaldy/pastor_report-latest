import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/region_model.dart';

class RegionService {
  static final RegionService instance = RegionService._internal();
  factory RegionService() => instance;
  RegionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'regions';

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
    return _firestore
        .collection(_collectionName)
        .where('missionId', isEqualTo: missionId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Region.fromSnapshot(doc)).toList());
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
}
