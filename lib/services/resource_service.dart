import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/resource_model.dart';
import 'package:flutter/foundation.dart';

class ResourceService {
  static final ResourceService instance = ResourceService._internal();
  factory ResourceService() => instance;
  ResourceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'resources';

  /// Create a new resource
  Future<void> createResource(Resource resource) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(resource.id)
          .set(resource.toMap());
      debugPrint('✅ Resource created: ${resource.name}');
    } catch (e) {
      debugPrint('❌ Error creating resource: $e');
      throw Exception('Failed to create resource: $e');
    }
  }

  /// Get a resource by ID
  Future<Resource?> getResourceById(String resourceId) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(resourceId)
          .get();

      if (doc.exists) {
        return Resource.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting resource: $e');
      throw Exception('Failed to get resource: $e');
    }
  }

  /// Get all resources for a mission
  Future<List<Resource>> getResourcesByMission(String missionId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('missionId', isEqualTo: missionId)
          .orderBy('uploadedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Resource.fromSnapshot(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting resources by mission: $e');
      throw Exception('Failed to get resources by mission: $e');
    }
  }

  /// Get resources by category
  Future<List<Resource>> getResourcesByCategory(
    String missionId,
    ResourceCategory category,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('missionId', isEqualTo: missionId)
          .where('category', isEqualTo: category.name)
          .orderBy('uploadedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Resource.fromSnapshot(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting resources by category: $e');
      throw Exception('Failed to get resources by category: $e');
    }
  }

  /// Search resources by name or tags
  Future<List<Resource>> searchResources(
    String missionId,
    String query,
  ) async {
    try {
      // First get all resources for the mission
      final allResources = await getResourcesByMission(missionId);

      // Filter by search query (case-insensitive)
      final lowerQuery = query.toLowerCase();
      return allResources.where((resource) {
        final nameMatch = resource.name.toLowerCase().contains(lowerQuery);
        final descMatch = resource.description.toLowerCase().contains(lowerQuery);
        final tagMatch = resource.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
        return nameMatch || descMatch || tagMatch;
      }).toList();
    } catch (e) {
      debugPrint('❌ Error searching resources: $e');
      throw Exception('Failed to search resources: $e');
    }
  }

  /// Update a resource
  Future<void> updateResource(Resource resource) async {
    try {
      final updatedResource = resource.copyWith(
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_collectionName)
          .doc(resource.id)
          .update(updatedResource.toMap());
      debugPrint('✅ Resource updated: ${resource.name}');
    } catch (e) {
      debugPrint('❌ Error updating resource: $e');
      throw Exception('Failed to update resource: $e');
    }
  }

  /// Delete a resource
  Future<void> deleteResource(String resourceId) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(resourceId)
          .delete();
      debugPrint('✅ Resource deleted: $resourceId');
    } catch (e) {
      debugPrint('❌ Error deleting resource: $e');
      throw Exception('Failed to delete resource: $e');
    }
  }

  /// Get all resources (for superadmin)
  Future<List<Resource>> getAllResources({int? limit}) async {
    try {
      var query = _firestore
          .collection(_collectionName)
          .orderBy('uploadedAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => Resource.fromSnapshot(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting all resources: $e');
      throw Exception('Failed to get all resources: $e');
    }
  }

  /// Get resource count by mission
  Future<int> getResourceCount(String missionId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('missionId', isEqualTo: missionId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error getting resource count: $e');
      return 0;
    }
  }

  /// Stream resources for a mission (real-time updates)
  Stream<List<Resource>> streamResourcesByMission(String missionId) {
    return _firestore
        .collection(_collectionName)
        .where('missionId', isEqualTo: missionId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Resource.fromSnapshot(doc))
            .toList());
  }
}
