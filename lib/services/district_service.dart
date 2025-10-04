import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/district_model.dart';

class DistrictService {
  static final DistrictService instance = DistrictService._internal();
  factory DistrictService() => instance;
  DistrictService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'districts';

  // Create a new district
  Future<void> createDistrict(District district) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(district.id)
          .set(district.toMap());
    } catch (e) {
      throw Exception('Failed to create district: $e');
    }
  }

  // Get a district by ID
  Future<District?> getDistrictById(String districtId) async {
    try {
      final doc =
          await _firestore.collection(_collectionName).doc(districtId).get();

      if (doc.exists) {
        return District.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get district: $e');
    }
  }

  // Get all districts for a region
  Future<List<District>> getDistrictsByRegion(String regionId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('regionId', isEqualTo: regionId)
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) => District.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get districts: $e');
    }
  }

  // Get all districts for a mission
  Future<List<District>> getDistrictsByMission(String missionId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('missionId', isEqualTo: missionId)
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) => District.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get districts: $e');
    }
  }

  // Stream all districts for a region (real-time updates)
  Stream<List<District>> streamDistrictsByRegion(String regionId) {
    return _firestore
        .collection(_collectionName)
        .where('regionId', isEqualTo: regionId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => District.fromSnapshot(doc)).toList());
  }

  // Stream all districts for a mission (real-time updates)
  Stream<List<District>> streamDistrictsByMission(String missionId) {
    return _firestore
        .collection(_collectionName)
        .where('missionId', isEqualTo: missionId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => District.fromSnapshot(doc)).toList());
  }

  // Get district by pastor ID
  Future<District?> getDistrictByPastor(String pastorId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('pastorId', isEqualTo: pastorId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return District.fromSnapshot(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get district by pastor: $e');
    }
  }

  // Update a district
  Future<void> updateDistrict(District district) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(district.id)
          .update(district.toMap());
    } catch (e) {
      throw Exception('Failed to update district: $e');
    }
  }

  // Assign pastor to district
  Future<void> assignPastorToDistrict(String districtId, String pastorId) async {
    try {
      await _firestore.collection(_collectionName).doc(districtId).update({
        'pastorId': pastorId,
      });
    } catch (e) {
      throw Exception('Failed to assign pastor to district: $e');
    }
  }

  // Remove pastor from district
  Future<void> removePastorFromDistrict(String districtId) async {
    try {
      await _firestore.collection(_collectionName).doc(districtId).update({
        'pastorId': null,
      });
    } catch (e) {
      throw Exception('Failed to remove pastor from district: $e');
    }
  }

  // Delete a district
  Future<void> deleteDistrict(String districtId) async {
    try {
      // Check if there are any churches in this district
      final churchesSnapshot = await _firestore
          .collection('churches')
          .where('districtId', isEqualTo: districtId)
          .limit(1)
          .get();

      if (churchesSnapshot.docs.isNotEmpty) {
        throw Exception(
            'Cannot delete district: There are churches assigned to this district');
      }

      await _firestore.collection(_collectionName).doc(districtId).delete();
    } catch (e) {
      throw Exception('Failed to delete district: $e');
    }
  }

  // Get all districts (for super admin)
  Future<List<District>> getAllDistricts() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) => District.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all districts: $e');
    }
  }

  // Stream all districts (for super admin)
  Stream<List<District>> streamAllDistricts() {
    return _firestore
        .collection(_collectionName)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => District.fromSnapshot(doc)).toList());
  }

  // Check if district code exists in region
  Future<bool> isDistrictCodeExists(String code, String regionId,
      {String? excludeDistrictId}) async {
    try {
      var query = _firestore
          .collection(_collectionName)
          .where('code', isEqualTo: code)
          .where('regionId', isEqualTo: regionId);

      final snapshot = await query.get();

      if (excludeDistrictId != null) {
        return snapshot.docs.any((doc) => doc.id != excludeDistrictId);
      }

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check district code: $e');
    }
  }
}
