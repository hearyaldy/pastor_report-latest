import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Diagnostic script to check current state of regions
///
/// This will help us understand:
/// 1. How many regions exist for NSM
/// 2. How many regions exist for Sabah Mission
/// 3. Which regions belong to which mission
/// 4. Whether Region 5-12 still exist (and where they are)

Future<void> main() async {
  print('=== Region State Diagnostic ===\n');

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    print('✓ Firebase initialized\n');
  } catch (e) {
    print('Error initializing Firebase: $e');
    return;
  }

  final firestore = FirebaseFirestore.instance;

  // Mission IDs
  const northSabahMissionId = 'M89PoDdB5sNCoDl8qTNS'; // NSM
  const sabahMissionId = '4LFC9isp22H7Og1FHBm6';      // Sabah Mission

  try {
    print('=== North Sabah Mission Regions ===');
    final nsmRegions = await firestore
        .collection('regions')
        .where('missionId', isEqualTo: northSabahMissionId)
        .get();

    print('Found ${nsmRegions.docs.length} regions for NSM:\n');
    for (var doc in nsmRegions.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      print('  • ${data['name']} (ID: ${doc.id})');
      print('    Code: ${data['code'] ?? "N/A"}');
      print('    Created: ${createdAt ?? "Unknown"}');
      print('    Mission: ${data['missionId']}');

      // Count districts and churches
      final districts = await firestore
          .collection('districts')
          .where('regionId', isEqualTo: doc.id)
          .get();
      final churches = await firestore
          .collection('churches')
          .where('regionId', isEqualTo: doc.id)
          .get();
      print('    Districts: ${districts.docs.length}, Churches: ${churches.docs.length}');
      print('');
    }

    print('\n=== Sabah Mission Regions ===');
    final sabahRegions = await firestore
        .collection('regions')
        .where('missionId', isEqualTo: sabahMissionId)
        .get();

    print('Found ${sabahRegions.docs.length} regions for Sabah Mission:\n');
    for (var doc in sabahRegions.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      print('  • ${data['name']} (ID: ${doc.id})');
      print('    Code: ${data['code'] ?? "N/A"}');
      print('    Created: ${createdAt ?? "Unknown"}');
      print('    Mission: ${data['missionId']}');

      // Count districts and churches
      final districts = await firestore
          .collection('districts')
          .where('regionId', isEqualTo: doc.id)
          .get();
      final churches = await firestore
          .collection('churches')
          .where('regionId', isEqualTo: doc.id)
          .get();
      print('    Districts: ${districts.docs.length}, Churches: ${churches.docs.length}');
      print('');
    }

    print('\n=== Summary ===');
    print('NSM regions: ${nsmRegions.docs.length} (Expected: 4 - Region 1-4)');
    print('Sabah Mission regions: ${sabahRegions.docs.length} (Expected: 10 - Region 1-10)');

    // Check if Region 5-12 exist anywhere
    print('\n=== Searching for Region 5-12 ===');
    for (int i = 5; i <= 12; i++) {
      final regionName = 'Region $i';
      final found = await firestore
          .collection('regions')
          .where('name', isEqualTo: regionName)
          .get();

      if (found.docs.isEmpty) {
        print('  ✗ $regionName: NOT FOUND');
      } else {
        for (var doc in found.docs) {
          final data = doc.data();
          final missionName = data['missionId'] == northSabahMissionId ? 'NSM' :
                              data['missionId'] == sabahMissionId ? 'Sabah Mission' :
                              'Unknown';
          print('  ✓ $regionName: Found (ID: ${doc.id}, Mission: $missionName)');
        }
      }
    }

    print('\n=== Recommendation ===');
    if (nsmRegions.docs.length > 4) {
      print('⚠️  NSM has ${nsmRegions.docs.length} regions (should be 4)');
      print('→ Run STEP 1: Reassign excess regions to Sabah Mission');
    } else {
      print('✓ NSM has correct number of regions (4)');
    }

    if (sabahRegions.docs.length < 10) {
      print('⚠️  Sabah Mission has ${sabahRegions.docs.length} regions (should be 10)');
      print('→ Run STEP 2: Restore from churches_SAB.json');
    } else {
      print('✓ Sabah Mission has all 10 regions');
    }

  } catch (e) {
    print('Error during diagnostic: $e');
  }
}
