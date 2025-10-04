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

  // Get all regions for a mission
  Future<List<Region>> getRegionsByMission(String missionId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('missionId', isEqualTo: missionId)
          .orderBy('name')
          .get();

      return querySnapshot.docs.map((doc) => Region.fromSnapshot(doc)).toList();
    } catch (e) {
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
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .orderBy('name')
          .get();

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
        return snapshot.docs
            .any((doc) => doc.id != excludeRegionId);
      }

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check region code: $e');
    }
  }
}
