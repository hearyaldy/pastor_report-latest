import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/services/mission_service.dart';

class ChurchService {
  static final ChurchService instance = ChurchService._internal();
  factory ChurchService() => instance;
  ChurchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'churches';

  // Create a new church
  Future<void> createChurch(Church church) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(church.id)
          .set(church.toJson());
    } catch (e) {
      throw Exception('Failed to create church: $e');
    }
  }

  // Get a church by ID
  Future<Church?> getChurchById(String churchId) async {
    try {
      final doc =
          await _firestore.collection(_collectionName).doc(churchId).get();

      if (doc.exists) {
        return Church.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get church: $e');
    }
  }

  // Get all churches for multiple districts at once - more efficient than individual calls
  Future<List<Church>> getChurchesByDistricts(List<String> districtIds) async {
    try {
      if (districtIds.isEmpty) {
        return [];
      }

      // Firestore has a limit of 10 items in whereIn clause
      if (districtIds.length > 10) {
        // Split into batches of 10
        final churches = <Church>[];
        for (int i = 0; i < districtIds.length; i += 10) {
          final batch = districtIds.skip(i).take(10).toList();
          final batchChurches = await _getChurchesByDistrictsBatch(batch);
          churches.addAll(batchChurches);
        }
        return churches;
      } else {
        return await _getChurchesByDistrictsBatch(districtIds);
      }
    } catch (e) {
      print('ChurchService: Error getting churches by districts: $e');
      throw Exception('Failed to get churches by districts: $e');
    }
  }

  // Helper method to get churches for up to 10 districts
  Future<List<Church>> _getChurchesByDistrictsBatch(List<String> districtIds) async {
    final querySnapshot = await _firestore
        .collection(_collectionName)
        .where('districtId', whereIn: districtIds)
        .orderBy('churchName')
        .get();

    return querySnapshot.docs
        .map((doc) => Church.fromJson(doc.data()))
        .toList();
  }

  // Get count of churches for multiple districts - more efficient than individual calls
  Future<int> getChurchCountByDistricts(List<String> districtIds) async {
    try {
      if (districtIds.isEmpty) {
        return 0;
      }

      // Firestore has a limit of 10 items in whereIn clause
      if (districtIds.length > 10) {
        // Split into batches of 10
        int totalCount = 0;
        for (int i = 0; i < districtIds.length; i += 10) {
          final batch = districtIds.skip(i).take(10).toList();
          final batchCount = await _getChurchCountByDistrictsBatch(batch);
          totalCount += batchCount;
        }
        return totalCount;
      } else {
        return await _getChurchCountByDistrictsBatch(districtIds);
      }
    } catch (e) {
      print('ChurchService: Error counting churches by districts: $e');
      throw Exception('Failed to count churches by districts: $e');
    }
  }

  // Helper method to get count of churches for up to 10 districts
  Future<int> _getChurchCountByDistrictsBatch(List<String> districtIds) async {
    final querySnapshot = await _firestore
        .collection(_collectionName)
        .where('districtId', whereIn: districtIds)
        .count()
        .get();

    return querySnapshot.count ?? 0;
  }

  // Get all churches for a district
  Future<List<Church>> getChurchesByDistrict(String districtId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('districtId', isEqualTo: districtId)
          .orderBy('churchName')
          .get();

      return querySnapshot.docs
          .map((doc) => Church.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get churches: $e');
    }
  }

  // Get all churches for a region (includes all churches in all districts in the region)
  Future<List<Church>> getChurchesByRegion(String regionId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('regionId', isEqualTo: regionId)
          .orderBy('churchName')
          .get();

      return querySnapshot.docs
          .map((doc) => Church.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get churches by region: $e');
    }
  }

  // Get all churches for a user (pastor)
  Future<List<Church>> getUserChurches(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Church.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user churches: $e');
    }
  }

  // Stream all churches for a district (real-time updates)
  Stream<List<Church>> streamChurchesByDistrict(String districtId) {
    return _firestore
        .collection(_collectionName)
        .where('districtId', isEqualTo: districtId)
        .orderBy('churchName')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Church.fromJson(doc.data())).toList());
  }

  // Stream user churches (real-time updates)
  Stream<List<Church>> streamUserChurches(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Church.fromJson(doc.data())).toList());
  }

  // Update a church
  Future<void> updateChurch(Church church) async {
    try {
      final updatedChurch = church.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(_collectionName)
          .doc(church.id)
          .update(updatedChurch.toJson());
    } catch (e) {
      throw Exception('Failed to update church: $e');
    }
  }

  // Assign treasurer to church
  Future<void> assignTreasurerToChurch(
      String churchId, String treasurerId) async {
    try {
      await _firestore.collection(_collectionName).doc(churchId).update({
        'treasurerId': treasurerId,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to assign treasurer to church: $e');
    }
  }

  // Remove treasurer from church
  Future<void> removeTreasurerFromChurch(String churchId) async {
    try {
      await _firestore.collection(_collectionName).doc(churchId).update({
        'treasurerId': null,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to remove treasurer from church: $e');
    }
  }

  // Assign church to district
  Future<void> assignChurchToDistrict(String churchId, String districtId,
      String regionId, String missionId) async {
    try {
      await _firestore.collection(_collectionName).doc(churchId).update({
        'districtId': districtId,
        'regionId': regionId,
        'missionId': missionId,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to assign church to district: $e');
    }
  }

  // Delete a church
  Future<void> deleteChurch(String churchId) async {
    try {
      // TODO: Check if there are any financial reports for this church
      // before allowing deletion
      await _firestore.collection(_collectionName).doc(churchId).delete();
    } catch (e) {
      throw Exception('Failed to delete church: $e');
    }
  }

  // Get all churches (for super admin)
  Future<List<Church>> getAllChurches() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .orderBy('churchName')
          .get();

      return querySnapshot.docs
          .map((doc) => Church.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all churches: $e');
    }
  }

  // Stream all churches (for super admin)
  Stream<List<Church>> streamAllChurches() {
    return _firestore
        .collection(_collectionName)
        .orderBy('churchName')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Church.fromJson(doc.data())).toList());
  }

  // Get statistics for a user
  Future<Map<String, dynamic>> getStatistics(String userId) async {
    try {
      final churches = await getUserChurches(userId);

      final churchCount =
          churches.where((c) => c.status == ChurchStatus.organizedChurch).length;
      final companyCount =
          churches.where((c) => c.status == ChurchStatus.company).length;
      final branchCount =
          churches.where((c) => c.status == ChurchStatus.group).length;
      final totalMembers =
          churches.fold<int>(0, (sum, c) => sum + (c.memberCount ?? 0));

      return {
        'totalChurches': churches.length,
        'churchCount': churchCount,
        'companyCount': companyCount,
        'branchCount': branchCount,
        'totalMembers': totalMembers,
      };
    } catch (e) {
      throw Exception('Failed to get statistics: $e');
    }
  }

  // Get statistics for a district
  Future<Map<String, dynamic>> getDistrictStatistics(String districtId) async {
    try {
      final churches = await getChurchesByDistrict(districtId);

      final churchCount =
          churches.where((c) => c.status == ChurchStatus.organizedChurch).length;
      final companyCount =
          churches.where((c) => c.status == ChurchStatus.company).length;
      final branchCount =
          churches.where((c) => c.status == ChurchStatus.group).length;
      final totalMembers =
          churches.fold<int>(0, (sum, c) => sum + (c.memberCount ?? 0));

      return {
        'totalChurches': churches.length,
        'churchCount': churchCount,
        'companyCount': companyCount,
        'branchCount': branchCount,
        'totalMembers': totalMembers,
      };
    } catch (e) {
      throw Exception('Failed to get district statistics: $e');
    }
  }

  // Get church by treasurer ID
  Future<Church?> getChurchByTreasurer(String treasurerId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('treasurerId', isEqualTo: treasurerId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Church.fromJson(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get church by treasurer: $e');
    }
  }

  // Get all churches for a mission
  Future<List<Church>> getChurchesByMission(String missionIdentifier) async {
    try {
      print('ChurchService: Getting churches for mission: $missionIdentifier');

      // Try to resolve the mission name/ID
      final resolvedName =
          await MissionService.instance.getMissionNameFromId(missionIdentifier);
      final missionIds = <String>[missionIdentifier];

      // Add the resolved name if it's different
      if (resolvedName != null && resolvedName != missionIdentifier) {
        missionIds.add(resolvedName);
        print(
            'ChurchService: Resolved mission ID to name: $missionIdentifier -> $resolvedName');
      }

      // Use whereIn to search for churches with either the ID or name
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('missionId', whereIn: missionIds)
          .orderBy('churchName')
          .get();

      final results =
          querySnapshot.docs.map((doc) => Church.fromJson(doc.data())).toList();

      print(
          'ChurchService: Found ${results.length} churches for mission: $missionIdentifier');
      return results;
    } catch (e) {
      print('ChurchService: Error getting churches by mission: $e');
      throw Exception('Failed to get churches by mission: $e');
    }
  }

  // Get count of churches for a mission - more efficient than loading all data
  Future<int> getChurchCountByMission(String missionIdentifier) async {
    try {
      // Special case for getting count of all churches
      if (missionIdentifier == 'all') {
        final querySnapshot = await _firestore
            .collection(_collectionName)
            .count()
            .get();
        
        final count = querySnapshot.count ?? 0;
        print('ChurchService: Counted $count churches (all missions)');
        return count;
      }

      print('ChurchService: Counting churches for mission: $missionIdentifier');

      // Try to resolve the mission name/ID
      final resolvedName =
          await MissionService.instance.getMissionNameFromId(missionIdentifier);
      final missionIds = <String>[missionIdentifier];

      // Add the resolved name if it's different
      if (resolvedName != null && resolvedName != missionIdentifier) {
        missionIds.add(resolvedName);
      }

      // Use whereIn to search for churches with either the ID or name
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('missionId', whereIn: missionIds)
          .count()
          .get();

      final count = querySnapshot.count ?? 0;
      print('ChurchService: Counted $count churches for mission: $missionIdentifier');
      return count;
    } catch (e) {
      print('ChurchService: Error counting churches by mission: $e');
      throw Exception('Failed to count churches by mission: $e');
    }
  }
}
