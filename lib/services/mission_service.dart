// lib/services/mission_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/mission_model.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/utils/constants.dart';

class MissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _missionsCollection = 'missions';
  final String _departmentsCollection =
      'departments'; // Subcollection in each mission

  // Stream of all missions
  Stream<List<Mission>> getMissionsStream() {
    return _firestore
        .collection(_missionsCollection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Mission.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Get a specific mission with its departments
  Stream<Mission?> getMissionWithDepartmentsStream(String missionId) {
    return _firestore
        .collection(_missionsCollection)
        .doc(missionId)
        .snapshots()
        .asyncMap((missionDoc) async {
      if (!missionDoc.exists) {
        return null;
      }

      final mission = Mission.fromMap(missionDoc.data()!, missionDoc.id);

      // Get departments from the subcollection
      final departmentsSnapshot = await _firestore
          .collection(_missionsCollection)
          .doc(missionId)
          .collection(_departmentsCollection)
          .orderBy('name')
          .get();

      final departments = departmentsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add id to the map
        return Department.fromMap(data);
      }).toList();

      // Return mission with departments
      return Mission(
        id: mission.id,
        name: mission.name,
        code: mission.code,
        description: mission.description,
        logoUrl: mission.logoUrl,
        departments: departments,
        createdAt: mission.createdAt,
        updatedAt: mission.updatedAt,
      );
    });
  }

  // Get departments for a mission by mission name
  Stream<List<Department>> getDepartmentsStreamByMissionName(
      String missionName) {
    return _firestore
        .collection(_missionsCollection)
        .where('name', isEqualTo: missionName)
        .limit(1)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) {
        return [];
      }

      final missionId = snapshot.docs.first.id;
      final departmentsSnapshot = await _firestore
          .collection(_missionsCollection)
          .doc(missionId)
          .collection(_departmentsCollection)
          .orderBy('name')
          .get();

      return departmentsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add id to the map
        // Add mission name to department data for compatibility with existing code
        data['mission'] = missionName;
        return Department.fromMap(data);
      }).toList();
    });
  }

  // Get all missions with one-time fetch
  Future<List<Mission>> getAllMissions() async {
    try {
      final snapshot = await _firestore
          .collection(_missionsCollection)
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        return Mission.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw 'Failed to fetch missions: $e';
    }
  }

  // Get a mission by its name
  Future<Mission?> getMissionByName(String name) async {
    try {
      final snapshot = await _firestore
          .collection(_missionsCollection)
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      return Mission.fromMap(doc.data(), doc.id);
    } catch (e) {
      throw 'Failed to fetch mission: $e';
    }
  }

  // Add a new mission
  Future<String> addMission(Mission mission) async {
    try {
      final docRef =
          await _firestore.collection(_missionsCollection).add(mission.toMap());

      return docRef.id;
    } catch (e) {
      throw 'Failed to add mission: $e';
    }
  }

  // Update a mission
  Future<void> updateMission(Mission mission) async {
    try {
      await _firestore.collection(_missionsCollection).doc(mission.id).update({
        'name': mission.name,
        'code': mission.code,
        'description': mission.description,
        'logoUrl': mission.logoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update mission: $e';
    }
  }

  // Delete a mission
  Future<void> deleteMission(String missionId) async {
    try {
      // First, delete all departments in the subcollection
      final departmentsSnapshot = await _firestore
          .collection(_missionsCollection)
          .doc(missionId)
          .collection(_departmentsCollection)
          .get();

      final batch = _firestore.batch();
      for (var doc in departmentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Then delete the mission document
      batch.delete(_firestore.collection(_missionsCollection).doc(missionId));

      await batch.commit();
    } catch (e) {
      throw 'Failed to delete mission: $e';
    }
  }

  // Add a department to a mission
  Future<String> addDepartmentToMission(
      String missionId, Department department) async {
    try {
      final docRef = await _firestore
          .collection(_missionsCollection)
          .doc(missionId)
          .collection(_departmentsCollection)
          .add({
        'name': department.name,
        'icon': Department.getIconString(department.icon),
        'formUrl': department.formUrl,
        'isActive': department.isActive,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      throw 'Failed to add department to mission: $e';
    }
  }

  // Update a department in a mission
  Future<void> updateDepartmentInMission(
      String missionId, Department department) async {
    try {
      await _firestore
          .collection(_missionsCollection)
          .doc(missionId)
          .collection(_departmentsCollection)
          .doc(department.id)
          .update({
        'name': department.name,
        'icon': Department.getIconString(department.icon),
        'formUrl': department.formUrl,
        'isActive': department.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update department: $e';
    }
  }

  // Delete a department from a mission
  Future<void> deleteDepartmentFromMission(
      String missionId, String departmentId) async {
    try {
      await _firestore
          .collection(_missionsCollection)
          .doc(missionId)
          .collection(_departmentsCollection)
          .doc(departmentId)
          .delete();
    } catch (e) {
      throw 'Failed to delete department: $e';
    }
  }

  // Check if a department exists in a mission by name
  Future<bool> departmentExistsInMission(
      String missionId, String departmentName) async {
    try {
      final snapshot = await _firestore
          .collection(_missionsCollection)
          .doc(missionId)
          .collection(_departmentsCollection)
          .where('name', isEqualTo: departmentName)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw 'Failed to check if department exists: $e';
    }
  }

  // Seed missions and their departments - this creates the initial data structure
  Future<void> seedMissionsWithDepartments() async {
    try {
      // Check if missions already exist
      final missionsSnapshot =
          await _firestore.collection(_missionsCollection).limit(1).get();

      if (missionsSnapshot.docs.isNotEmpty) {
        return; // Already seeded
      }

      // Get list of missions from constants
      final List<String> missionNames = AppConstants.missions;

      // Base departments that will be assigned to each mission
      final baseDepartments = [
        {
          'name': 'Ministerial',
          'icon': 'person',
          'formUrl': 'https://forms.gle/MinisterialReportForm',
          'isActive': true,
        },
        {
          'name': 'Stewardship',
          'icon': 'account_balance',
          'formUrl': 'https://forms.gle/Fwud8srq8aXikzY48',
          'isActive': true,
        },
        {
          'name': 'Youth',
          'icon': 'group',
          'formUrl': 'https://tinyurl.com/laporan-jpba',
          'isActive': true,
        },
        {
          'name': 'Communication',
          'icon': 'message',
          'formUrl': 'https://forms.gle/wMaDk2VUwhd8MwXk9',
          'isActive': true,
        },
        {
          'name': 'Health Ministry',
          'icon': 'local_hospital',
          'formUrl': 'https://forms.gle/aR4mRU8HopXGQ6cq5',
          'isActive': true,
        },
        {
          'name': 'Education',
          'icon': 'school',
          'formUrl': 'https://forms.gle/EducationReportForm',
          'isActive': true,
        },
        {
          'name': 'Family Life',
          'icon': 'family_restroom',
          'formUrl': 'https://forms.gle/iak14RPeULZ18BCD6',
          'isActive': true,
        },
        {
          'name': 'Women\'s Ministry',
          'icon': 'woman',
          'formUrl': 'https://forms.gle/ybAS4jRESNPQp71J7',
          'isActive': true,
        },
        {
          'name': 'Children',
          'icon': 'child_care',
          'formUrl': 'http://tiny.cc/HANTARFILELAPORAN',
          'isActive': true,
        },
        {
          'name': 'Publishing',
          'icon': 'book',
          'formUrl': 'https://forms.gle/PublishingReportForm',
          'isActive': true,
        },
        {
          'name': 'Personal Ministry',
          'icon': 'person_pin',
          'formUrl': 'https://forms.gle/PersonalMinistryReportForm',
          'isActive': true,
        },
        {
          'name': 'Sabbath School',
          'icon': 'access_time',
          'formUrl':
              'https://docs.google.com/forms/d/1JTupBS6yVIePQmgTHih8ptlG9zxUSVv2aJzJc3c3V10/edit',
          'isActive': true,
        },
        {
          'name': 'Adventist Community Services',
          'icon': 'volunteer_activism',
          'formUrl': 'https://forms.gle/CommunityServicesReportForm',
          'isActive': true,
        },
      ];

      // Create a batch for creating missions
      final batch = _firestore.batch();

      // Create missions
      for (var missionName in missionNames) {
        final missionDocRef = _firestore.collection(_missionsCollection).doc();
        batch.set(missionDocRef, {
          'name': missionName,
          'code': missionName.substring(0, 3).toUpperCase(),
          'description': 'Mission for $missionName',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Commit the batch operation to create missions
      await batch.commit();

      // Now fetch the created missions
      final createdMissionsSnapshot =
          await _firestore.collection(_missionsCollection).get();

      // Add departments to each mission
      for (var missionDoc in createdMissionsSnapshot.docs) {
        final missionRef =
            _firestore.collection(_missionsCollection).doc(missionDoc.id);

        // Create a batch for adding departments to this mission
        final departmentsBatch = _firestore.batch();

        // Add departments to this mission
        for (var dept in baseDepartments) {
          final deptDocRef =
              missionRef.collection(_departmentsCollection).doc();
          departmentsBatch.set(deptDocRef, {
            ...dept,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // Commit the batch to create departments for this mission
        await departmentsBatch.commit();
      }
    } catch (e) {
      throw 'Failed to seed missions with departments: $e';
    }
  }

  // Utility method to reseed missions and departments
  Future<void> reseedAllMissionsWithDepartments() async {
    try {
      // Get all existing missions
      final missionsSnapshot =
          await _firestore.collection(_missionsCollection).get();

      // Delete all missions and their subcollections
      for (var missionDoc in missionsSnapshot.docs) {
        // First, delete all departments in the subcollection
        final departmentsSnapshot = await _firestore
            .collection(_missionsCollection)
            .doc(missionDoc.id)
            .collection(_departmentsCollection)
            .get();

        final batch = _firestore.batch();
        for (var deptDoc in departmentsSnapshot.docs) {
          batch.delete(deptDoc.reference);
        }

        // Then delete the mission
        batch.delete(missionDoc.reference);

        await batch.commit();
      }

      // Now seed fresh missions with departments
      await seedMissionsWithDepartments();
    } catch (e) {
      throw 'Failed to reseed missions with departments: $e';
    }
  }
}
