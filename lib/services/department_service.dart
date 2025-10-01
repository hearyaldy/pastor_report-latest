// lib/services/department_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/services/mission_service.dart';

class DepartmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'departments'; // Legacy collection
  final MissionService _missionService = MissionService();

  // This boolean helps with the transition to the new data structure
  bool _useNewMissionStructure = true;

  // Set whether to use the new mission structure
  void setUseMissionStructure(bool use) {
    _useNewMissionStructure = use;
  }

  // Check if we're using the new mission structure
  bool isUsingMissionStructure() {
    return _useNewMissionStructure;
  }

  // Check if a department exists in the new structure
  Future<bool> departmentExistsInMission(
      String missionId, String departmentName) async {
    if (!_useNewMissionStructure) {
      return false;
    }

    return await _missionService.departmentExistsInMission(
        missionId, departmentName);
  }

  // Get departments strictly filtered by mission
  Stream<List<Department>> getDepartmentsStream({String? mission}) {
    if (_useNewMissionStructure && mission != null && mission.isNotEmpty) {
      // Use the new mission-based structure
      return _missionService.getDepartmentsStreamByMissionName(mission);
    } else {
      // Fallback to legacy structure for backward compatibility
      Query query = _firestore.collection(_collection);

      // Filter by mission if provided
      if (mission != null && mission.isNotEmpty) {
        query = query.where('mission', isEqualTo: mission);
      }

      // Return departments ordered by name
      return query.orderBy('name').snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Add id to the map
          return Department.fromMap(data);
        }).toList();
      });
    }
  }

  // Get all departments (one-time fetch, optionally filtered by mission)
  Future<List<Department>> getDepartments({String? mission}) async {
    try {
      if (_useNewMissionStructure && mission != null && mission.isNotEmpty) {
        // Use the new mission-based structure to fetch departments
        final departmentsSnapshot = await _missionService
            .getDepartmentsStreamByMissionName(mission)
            .first;
        return departmentsSnapshot;
      } else {
        // Fallback to legacy structure
        Query query = _firestore.collection(_collection);

        // Filter by mission if provided
        if (mission != null && mission.isNotEmpty) {
          query = query.where('mission', isEqualTo: mission);
        }

        final snapshot = await query.orderBy('name').get();

        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Add id to the map
          return Department.fromMap(data);
        }).toList();
      }
    } catch (e) {
      throw 'Failed to fetch departments: $e';
    }
  }

  // Add new department
  Future<void> addDepartment(Department department) async {
    try {
      if (_useNewMissionStructure &&
          department.mission != null &&
          department.mission!.isNotEmpty) {
        // Find mission ID by name
        final mission =
            await _missionService.getMissionByName(department.mission!);
        if (mission != null) {
          await _missionService.addDepartmentToMission(mission.id, department);
          return;
        }
      }

      // Fallback to legacy structure
      await _firestore.collection(_collection).add({
        'name': department.name,
        'icon': Department.getIconString(department.icon),
        'formUrl': department.formUrl,
        'mission': department.mission,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to add department: $e';
    }
  }

  // Update department
  Future<void> updateDepartment(Department department) async {
    try {
      if (_useNewMissionStructure &&
          department.mission != null &&
          department.mission!.isNotEmpty) {
        // Find mission ID by name
        final mission =
            await _missionService.getMissionByName(department.mission!);
        if (mission != null) {
          await _missionService.updateDepartmentInMission(
              mission.id, department);
          return;
        }
      }

      // Fallback to legacy structure
      await _firestore.collection(_collection).doc(department.id).update({
        'name': department.name,
        'icon': Department.getIconString(department.icon),
        'formUrl': department.formUrl,
        'mission': department.mission,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update department: $e';
    }
  }

  // Delete department
  Future<void> deleteDepartment(String departmentId,
      {String? missionName}) async {
    try {
      if (_useNewMissionStructure &&
          missionName != null &&
          missionName.isNotEmpty) {
        // Find mission ID by name
        final mission = await _missionService.getMissionByName(missionName);
        if (mission != null) {
          await _missionService.deleteDepartmentFromMission(
              mission.id, departmentId);
          return;
        }
      }

      // Fallback to legacy structure
      await _firestore.collection(_collection).doc(departmentId).delete();
    } catch (e) {
      throw 'Failed to delete department: $e';
    }
  }

  // Seed initial departments (call once to populate database)
  Future<void> seedDepartments() async {
    try {
      if (_useNewMissionStructure) {
        // Use the mission service to seed missions and departments
        await _missionService.seedMissionsWithDepartments();
      } else {
        // Legacy seeding approach for backward compatibility
        // Check if departments already exist
        final snapshot =
            await _firestore.collection(_collection).limit(1).get();
        if (snapshot.docs.isNotEmpty) {
          return; // Already seeded
        }

        // Get list of missions from constants
        final List<String> missions = [
          'Sabah Mission',
          'North Sabah Mission',
          'Sarawak Mission',
          'Peninsular Mission',
        ];

        // Base departments that will be assigned to each mission
        final baseDepartments = [
          {
            'name': 'Ministerial',
            'icon': 'person',
            'formUrl': 'https://forms.gle/MinisterialReportForm'
          },
          {
            'name': 'Stewardship',
            'icon': 'account_balance',
            'formUrl': 'https://forms.gle/Fwud8srq8aXikzY48'
          },
          {
            'name': 'Youth',
            'icon': 'group',
            'formUrl': 'https://tinyurl.com/laporan-jpba'
          },
          {
            'name': 'Communication',
            'icon': 'message',
            'formUrl': 'https://forms.gle/wMaDk2VUwhd8MwXk9'
          },
          {
            'name': 'Health Ministry',
            'icon': 'local_hospital',
            'formUrl': 'https://forms.gle/aR4mRU8HopXGQ6cq5'
          },
          {
            'name': 'Education',
            'icon': 'school',
            'formUrl': 'https://forms.gle/EducationReportForm'
          },
          {
            'name': 'Family Life',
            'icon': 'family_restroom',
            'formUrl': 'https://forms.gle/iak14RPeULZ18BCD6'
          },
          {
            'name': 'Women\'s Ministry',
            'icon': 'woman',
            'formUrl': 'https://forms.gle/ybAS4jRESNPQp71J7'
          },
          {
            'name': 'Children',
            'icon': 'child_care',
            'formUrl': 'http://tiny.cc/HANTARFILELAPORAN'
          },
          {
            'name': 'Publishing',
            'icon': 'book',
            'formUrl': 'https://forms.gle/PublishingReportForm'
          },
          {
            'name': 'Personal Ministry',
            'icon': 'person_pin',
            'formUrl': 'https://forms.gle/PersonalMinistryReportForm'
          },
          {
            'name': 'Sabbath School',
            'icon': 'access_time',
            'formUrl':
                'https://docs.google.com/forms/d/1JTupBS6yVIePQmgTHih8ptlG9zxUSVv2aJzJc3c3V10/edit'
          },
          {
            'name': 'Adventist Community Services',
            'icon': 'volunteer_activism',
            'formUrl': 'https://forms.gle/CommunityServicesReportForm'
          },
        ];

        // Create a batch to add all departments for all missions
        final batch = _firestore.batch();

        // For each mission, add all departments with that mission field
        for (var mission in missions) {
          for (var dept in baseDepartments) {
            final docRef = _firestore.collection(_collection).doc();
            batch.set(docRef, {
              ...dept,
              'mission': mission, // Add mission field to each department
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }

        await batch.commit();
      }
    } catch (e) {
      throw 'Failed to seed departments: $e';
    }
  }

  // Utility method to reseed departments by clearing existing ones and recreating them with mission data
  // Use this only for development/admin purposes
  Future<void> reseedAllDepartments() async {
    try {
      print('Department service: Starting reseedAllDepartments. Using mission structure: $_useNewMissionStructure');
      
      if (_useNewMissionStructure) {
        // Use the mission service to reseed missions and departments
        print('Department service: Delegating to mission service for reseeding');
        await _missionService.reseedAllMissionsWithDepartments();
        print('Department service: Mission service reseed completed');
      } else {
        print('Department service: Using legacy reseeding approach');
        // Legacy reseeding approach
        // Delete all existing departments
        final snapshot = await _firestore.collection(_collection).get();
        print('Department service: Found ${snapshot.docs.length} departments to delete');

        // Process deletions in smaller batches to avoid timeouts
        int batchCounter = 0;
        int batchSize = 400; // Below Firestore's 500 limit
        WriteBatch currentBatch = _firestore.batch();
        
        for (var doc in snapshot.docs) {
          currentBatch.delete(doc.reference);
          batchCounter++;
          
          if (batchCounter >= batchSize) {
            // Commit current batch and start a new one
            await currentBatch.commit();
            currentBatch = _firestore.batch();
            batchCounter = 0;
            print('Department service: Committed batch of $batchSize deletions');
          }
        }
        
        // Commit any remaining operations
        if (batchCounter > 0) {
          await currentBatch.commit();
          print('Department service: Committed final batch of $batchCounter deletions');
        }

        // Now seed with new departments including missions
        print('Department service: Starting seed operation for new departments');
        await seedDepartments();
        print('Department service: Seed operation completed');
      }

      return;
    } catch (e) {
      print('Department service: Error during reseed: $e');
      throw 'Failed to reseed departments: $e';
    }
  }

  // Method to migrate from legacy structure to new mission-based structure
  Future<void> migrateToMissionStructure() async {
    try {
      // Step 1: Create missions if they don't exist
      await _missionService.seedMissionsWithDepartments();

      // Step 2: Get all existing departments from legacy structure
      final legacyDepartments = await _firestore.collection(_collection).get();

      // If no legacy departments, we're done
      if (legacyDepartments.docs.isEmpty) {
        return;
      }

      // Step 3: For each department, add it to the appropriate mission
      for (var deptDoc in legacyDepartments.docs) {
        final data = deptDoc.data();
        final missionName = data['mission'] as String?;

        // Skip if no mission is assigned
        if (missionName == null || missionName.isEmpty) {
          continue;
        }

        // Find the mission
        final mission = await _missionService.getMissionByName(missionName);
        if (mission != null) {
          // Create the department in the mission
          final department = Department(
            id: deptDoc.id,
            name: data['name'] ?? '',
            icon: Department.getIconFromString(data['icon'] ?? 'person'),
            formUrl: data['formUrl'] ?? '',
            isActive: data['isActive'] ?? true,
            mission: missionName,
          );

          // Add to mission
          await _missionService.addDepartmentToMission(mission.id, department);
        }
      }

      // Step 4: Optionally, delete the legacy departments
      // Uncomment this when ready to fully migrate
      /*
      final deleteBatch = _firestore.batch();
      for (var doc in legacyDepartments.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
      */
    } catch (e) {
      throw 'Failed to migrate to mission structure: $e';
    }
  }
}
