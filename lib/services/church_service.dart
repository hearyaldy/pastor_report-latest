import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/church_model.dart';

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
          churches.where((c) => c.status == ChurchStatus.church).length;
      final companyCount =
          churches.where((c) => c.status == ChurchStatus.company).length;
      final branchCount =
          churches.where((c) => c.status == ChurchStatus.branch).length;
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
          churches.where((c) => c.status == ChurchStatus.church).length;
      final companyCount =
          churches.where((c) => c.status == ChurchStatus.company).length;
      final branchCount =
          churches.where((c) => c.status == ChurchStatus.branch).length;
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
}
