// lib/services/mission_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/mission_model.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/utils/constants.dart';

class MissionService {
  static final MissionService instance = MissionService._internal();
  factory MissionService() => instance;
  MissionService._internal();

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

  // Get departments for a mission by mission name or ID
  Stream<List<Department>> getDepartmentsStreamByMissionName(
      String missionIdentifier) async* {
    print('🎧 getDepartmentsStreamByMissionName: "$missionIdentifier"');

    String missionId;
    String missionName;

    // Check if this looks like a Firestore ID (long random string without spaces)
    if (missionIdentifier.length > 15 && !missionIdentifier.contains(' ')) {
      // Try to use it as a document ID first
      try {
        final directCheck = await _firestore
            .collection(_missionsCollection)
            .doc(missionIdentifier)
            .get();

        if (directCheck.exists) {
          print('✅ Found mission directly by ID: $missionIdentifier');
          missionId = missionIdentifier;
          missionName = directCheck.data()?['name'] ?? missionIdentifier;
        } else {
          // Fall back to name-based lookup
          print('⚠️ Not a valid document ID, trying as name: $missionIdentifier');
          final snapshot = await _firestore
              .collection(_missionsCollection)
              .where('name', isEqualTo: missionIdentifier)
              .limit(1)
              .get();

          if (snapshot.docs.isEmpty) {
            print('❌ No mission found: $missionIdentifier');
            yield [];
            return;
          }

          missionId = snapshot.docs.first.id;
          missionName = missionIdentifier;
        }
      } catch (e) {
        print('❌ Error checking mission: $e');
        yield [];
        return;
      }
    } else {
      // It's a mission name, look it up
      print('🔍 Looking up mission by name: $missionIdentifier');
      final snapshot = await _firestore
          .collection(_missionsCollection)
          .where('name', isEqualTo: missionIdentifier)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('❌ No mission found with name: $missionIdentifier');
        yield [];
        return;
      }

      missionId = snapshot.docs.first.id;
      missionName = missionIdentifier;
    }

    print('✅ Using mission ID: $missionId, name: $missionName');

    // Now stream the departments from the subcollection
    await for (final departmentsSnapshot in _firestore
        .collection(_missionsCollection)
        .doc(missionId)
        .collection(_departmentsCollection)
        .orderBy('name')
        .snapshots()) {

      final departments = departmentsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['mission'] = missionName;
        return Department.fromMap(data);
      }).toList();

      print('📊 Loaded ${departments.length} departments for $missionName');
      yield departments;
    }
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

  // Convert mission ID to name using a multi-step approach
  String getMissionNameById(String? missionId) {
    if (missionId == null || missionId.isEmpty) {
      return "Unknown Mission";
    }

    // For debug purposes
    print('MissionService: Trying to resolve mission ID: "$missionId"');

    // STEP 1: Try to find the mission by ID in the constants (these are the string IDs like "sabah-mission")
    for (var mission in AppConstants.missions) {
      if (mission['id'] == missionId) {
        print(
            'MissionService: Found in constants by ID match: ${mission['name']}');
        return mission['name'] ?? "Unknown Mission";
      }

      // Also check if this is a Firestore document ID stored in the constants
      if (mission['firestore_id'] == missionId) {
        print(
            'MissionService: Found in constants by Firestore ID match: ${mission['name']}');
        return mission['name'] ?? "Unknown Mission";
      }
    }

    // STEP 2: Check if this is already a mission name
    for (var mission in AppConstants.missions) {
      if (mission['name'] == missionId) {
        print('MissionService: This is already a mission name: $missionId');
        return missionId;
      }
    }

    // STEP 3: For Firestore document IDs (like "4LFC9isp22H7Og1FHBm6")
    // Check our hardcoded mapping for common document IDs
    // This information comes from Firestore documents with fields:
    // - code: "SAB"
    // - name: "Sabah Mission"
    // - description: "Mission for Sabah Mission"
    // - createdAt: timestamp
    final knownDocumentIds = getKnownDocumentIdMappings();

    // Check if the ID is in our known document IDs map
    if (knownDocumentIds.containsKey(missionId)) {
      final missionInfo = knownDocumentIds[missionId]!;
      final name = missionInfo['name'] ?? "Unknown Mission";
      print('MissionService: Found in known document IDs: $missionId -> $name');
      return name;
    }

    // STEP 4: If all else fails, fetch from Firestore asynchronously
    // We can't make this method async because it would change the return type
    getMissionByID(missionId).then((mission) {
      if (mission != null) {
        print('Mission name resolved asynchronously: ${mission.name}');
        // Add this to known document IDs for future use
        print(
            'Consider adding this mapping: \'$missionId\': \'${mission.name}\',');
      }
    }).catchError((e) {
      print('Error resolving mission name: $e');
    });

    print(
        'MissionService: Could not resolve immediately, returning original ID: $missionId');
    return missionId;
  } // Get a mission by ID

  Future<Mission?> getMissionByID(String id) async {
    try {
      final doc =
          await _firestore.collection(_missionsCollection).doc(id).get();
      if (!doc.exists) return null;
      return Mission.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print('Error fetching mission by ID: $e');
      return null;
    }
  }

  // Get a mission by its name
  Future<Mission?> getMissionByName(String name) async {
    try {
      print('MissionService: Looking for mission with name: "$name"');
      final snapshot = await _firestore
          .collection(_missionsCollection)
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      print('MissionService: Found ${snapshot.docs.length} missions');
      if (snapshot.docs.isEmpty) {
        // Debug: List all missions to see what names exist
        final allMissions =
            await _firestore.collection(_missionsCollection).get();
        print('MissionService: Available missions:');
        for (var doc in allMissions.docs) {
          print('  - ID: ${doc.id}, Name: "${doc.data()['name']}"');
        }
        return null;
      }

      final doc = snapshot.docs.first;
      print(
          'MissionService: Found mission - ID: ${doc.id}, Name: "${doc.data()['name']}"');
      return Mission.fromMap(doc.data(), doc.id);
    } catch (e) {
      print('MissionService: Error fetching mission: $e');
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

  // Utility method to find mission ID from mission name
  // This helps with backward compatibility where mission name was used in place of ID
  Future<String?> getMissionIdFromName(String missionName) async {
    try {
      final snapshot = await _firestore
          .collection(_missionsCollection)
          .where('name', isEqualTo: missionName)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('MissionService: No mission found with name "$missionName"');
        return null;
      }

      return snapshot.docs.first.id;
    } catch (e) {
      print('MissionService: Error getting mission ID from name: $e');
      return null;
    }
  }

  // Utility method to find mission name from mission ID
  Future<String?> getMissionNameFromId(String missionId) async {
    try {
      final doc =
          await _firestore.collection(_missionsCollection).doc(missionId).get();

      if (!doc.exists) {
        print('MissionService: No mission found with ID "$missionId"');
        return null;
      }

      return doc.data()?['name'] as String?;
    } catch (e) {
      print('MissionService: Error getting mission name from ID: $e');
      return null;
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
        if (department.color != null) 'color': department.color!.value,
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
        if (department.color != null) 'color': department.color!.value,
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
      final List<Map<String, String>> missions = AppConstants.missions;

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
      for (var mission in missions) {
        final missionDocRef = _firestore.collection(_missionsCollection).doc();
        batch.set(missionDocRef, {
          'name': mission['name'],
          'code': mission['name']!.substring(0, 3).toUpperCase(),
          'description': 'Mission for ${mission['name']}',
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
      print('Starting reseedAllMissionsWithDepartments');

      // First, delete all departments from each mission
      print('Deleting departments from missions');
      await _deleteAllMissionDepartments();

      // Then delete all missions
      print('Deleting all missions');
      await _deleteAllMissions();

      // Now seed with fresh data
      print('Seeding fresh missions and departments');
      await seedMissionsWithDepartments();

      print('Reseed completed successfully');
      return;
    } catch (e) {
      print('Error during mission reseed: $e');
      throw 'Failed to reseed missions with departments: $e';
    }
  }

  // Helper method to delete all departments from all missions
  Future<void> _deleteAllMissionDepartments() async {
    // Get all missions
    final missionsSnapshot =
        await _firestore.collection(_missionsCollection).get();

    int totalDeleted = 0;

    // For each mission, get and delete its departments
    for (var missionDoc in missionsSnapshot.docs) {
      // Get departments for this mission
      final departmentsSnapshot = await _firestore
          .collection(_missionsCollection)
          .doc(missionDoc.id)
          .collection(_departmentsCollection)
          .get();

      int deptCount = departmentsSnapshot.docs.length;
      if (deptCount == 0) continue;

      print('Deleting $deptCount departments from mission ${missionDoc.id}');

      // Process deletions in batches
      int batchCounter = 0;
      int batchSize = 400;
      WriteBatch currentBatch = _firestore.batch();

      for (var deptDoc in departmentsSnapshot.docs) {
        currentBatch.delete(deptDoc.reference);
        batchCounter++;
        totalDeleted++;

        if (batchCounter >= batchSize) {
          // Commit batch and start new one
          await currentBatch.commit();
          currentBatch = _firestore.batch();
          batchCounter = 0;
          print('Committed batch of $batchSize department deletions');
        }
      }

      // Commit remaining operations
      if (batchCounter > 0) {
        await currentBatch.commit();
        print('Committed final batch of $batchCounter department deletions');
      }
    }

    print('Successfully deleted $totalDeleted departments from missions');
  }

  // Helper method to delete all missions
  Future<void> _deleteAllMissions() async {
    // Get all missions
    final missionsSnapshot =
        await _firestore.collection(_missionsCollection).get();

    int missionCount = missionsSnapshot.docs.length;
    if (missionCount == 0) return;

    print('Deleting $missionCount missions');

    // Process deletions in batches
    int batchCounter = 0;
    int batchSize = 400;
    WriteBatch currentBatch = _firestore.batch();

    for (var missionDoc in missionsSnapshot.docs) {
      currentBatch.delete(missionDoc.reference);
      batchCounter++;

      if (batchCounter >= batchSize) {
        // Commit batch and start new one
        await currentBatch.commit();
        currentBatch = _firestore.batch();
        batchCounter = 0;
        print('Committed batch of $batchSize mission deletions');
      }
    }

    // Commit remaining operations
    if (batchCounter > 0) {
      await currentBatch.commit();
      print('Committed final batch of $batchCounter mission deletions');
    }

    print('Successfully deleted all missions');
  }

  // Maps Firestore document IDs to mission information
  // This helps resolve document IDs to mission names without database calls
  Map<String, Map<String, String>> getKnownDocumentIdMappings() {
    // Create a mapping for known Firestore document IDs
    // These mappings match the actual Firestore data
    final Map<String, Map<String, String>> documentIdMappings = {
      // Sabah Mission
      '4LFC9isp22H7Og1FHBm6': {
        'name': 'Sabah Mission',
        'code': 'SAB',
      },
      // North Sabah Mission
      'M89PoDdB5sNCoDl8qTNS': {
        'name': 'North Sabah Mission',
        'code': 'NSM',
      },
      // Peninsular Mission (NOT "West Malaysia Mission")
      'bwi23rsOpWJLnKcn20WC': {
        'name': 'Peninsular Mission',
        'code': 'PEN',
      },
      // Sarawak Mission
      'mpfQa7qEaj0fzuo4xhDN': {
        'name': 'Sarawak Mission',
        'code': 'SAK',
      },
    };

    // Also process any additional mappings from AppConstants.missions
    for (var mission in AppConstants.missions) {
      if (mission.containsKey('firestore_id') && mission.containsKey('name')) {
        final firestoreId = mission['firestore_id']!;
        documentIdMappings[firestoreId] = {
          'name': mission['name']!,
          'code': mission['code'] ?? '',
        };
      }
    }

    return documentIdMappings;
  }
}
