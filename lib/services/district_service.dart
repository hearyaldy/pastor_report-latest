import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/district_model.dart';

class DistrictService {
  static final DistrictService instance = DistrictService._internal();
  factory DistrictService() => instance;
  DistrictService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'districts';

  // Cache for district names by ID
  final Map<String, String> _districtNameCache = {};
  // Cache for districts by mission
  final Map<String, List<District>> _missionDistrictsCache = {};

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

  // Stream a single district by ID (real-time updates)
  Stream<List<District>> streamDistrictById(String districtId) {
    return _firestore
        .collection(_collectionName)
        .doc(districtId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return <District>[];
      }
      return [District.fromSnapshot(snapshot)];
    });
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

  // Get a district by name (case sensitive)
  Future<District?> getDistrictByName(String districtName) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('name', isEqualTo: districtName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return District.fromSnapshot(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get district by name: $e');
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
  Future<void> assignPastorToDistrict(
      String districtId, String pastorId) async {
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
      final querySnapshot =
          await _firestore.collection(_collectionName).orderBy('name').get();

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

  // Convert district ID to name
  Future<String> getDistrictNameById(String? districtId) async {
    if (districtId == null || districtId.isEmpty) {
      return "Unknown District";
    }

    try {
      // First try direct lookup
      final district = await getDistrictById(districtId);
      if (district != null) {
        return district.name;
      }

      // Try to find in all districts
      final districts = await getAllDistricts();
      for (final d in districts) {
        if (d.id == districtId) {
          return d.name;
        }
      }

      // If still not found, return the ID as a last resort
      print(
          'DistrictService: Could not find district name for ID $districtId, returning ID');
      return districtId;
    } catch (e) {
      print(
          'DistrictService: Error getting district name for ID $districtId: $e');
      return "Unknown District";
    }
  }

  // Get a district name safely, trying multiple approaches
  Future<String> resolveDistrictName(String? districtId,
      {String? missionId}) async {
    if (districtId == null || districtId.isEmpty) {
      return "";
    }

    // Check cache first
    if (_districtNameCache.containsKey(districtId)) {
      print(
          'DistrictService: Using cached district name: ${_districtNameCache[districtId]} for ID: $districtId');
      return _districtNameCache[districtId]!;
    }

    try {
      // Step 1: Try direct lookup by ID
      final district = await getDistrictById(districtId);
      if (district != null) {
        print(
            'DistrictService: Found district by direct lookup: ${district.name}');
        _districtNameCache[districtId] = district.name; // Cache result
        return district.name;
      }

      // Step 2: Search in all districts
      final allDistricts = await getAllDistricts();
      for (final d in allDistricts) {
        if (d.id == districtId) {
          print('DistrictService: Found district in all districts: ${d.name}');
          _districtNameCache[districtId] = d.name; // Cache result
          return d.name;
        }
      }

      // Step 3: If missionId is provided, try to find districts for this mission
      if (missionId != null && missionId.isNotEmpty) {
        print(
            'DistrictService: Trying to find district by mission: $missionId');

        List<District> missionDistricts;
        if (_missionDistrictsCache.containsKey(missionId)) {
          missionDistricts = _missionDistrictsCache[missionId]!;
          print(
              'DistrictService: Using cached mission districts (${missionDistricts.length}) for mission: $missionId');
        } else {
          missionDistricts = await getDistrictsByMission(missionId);
          _missionDistrictsCache[missionId] = missionDistricts; // Cache result
        }

        if (missionDistricts.isNotEmpty) {
          // If mission has only one district, use that as a fallback
          if (missionDistricts.length == 1) {
            print(
                'DistrictService: Using mission\'s sole district: ${missionDistricts[0].name}');
            _districtNameCache[districtId] =
                missionDistricts[0].name; // Cache result
            return missionDistricts[0].name;
          }

          // Try to find a district with a similar ID or name
          for (final d in missionDistricts) {
            if (d.id == districtId ||
                d.id.contains(districtId) ||
                districtId.contains(d.id) ||
                d.name.toLowerCase().contains(districtId.toLowerCase())) {
              print('DistrictService: Found similar district: ${d.name}');
              _districtNameCache[districtId] = d.name; // Cache result
              return d.name;
            }
          }
        }
      }

      // Step 4: If all else fails, use the ID
      _districtNameCache[districtId] = districtId; // Cache the fallback
      return districtId;
    } catch (e) {
      print('DistrictService: Error resolving district name: $e');
      return districtId;
    }
  }

  // Clear all caches
  void clearCaches() {
    _districtNameCache.clear();
    _missionDistrictsCache.clear();
  }
}
