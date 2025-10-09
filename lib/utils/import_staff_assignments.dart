import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Import staff district/region assignments from churches_SAB.json
class StaffAssignmentImporter {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Import staff assignments from churches_SAB.json for Sabah Mission
  static Future<Map<String, dynamic>> importFromChurchesJSON() async {
    debugPrint('📥 IMPORTING STAFF ASSIGNMENTS FROM churches_SAB.json');
    debugPrint('${'=' * 80}');

    final results = {
      'total_pastors_in_json': 0,
      'matched_staff': 0,
      'unmatched_staff': <String>[],
      'updated_staff': 0,
      'errors': <String>[],
    };

    try {
      // Load the JSON file
      final jsonString =
          await rootBundle.loadString('assets/churches_SAB.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;

      // Get Sabah Mission ID
      final missionsSnapshot =
          await _firestore.collection('missions').get();
      String? sabahMissionId;

      for (var doc in missionsSnapshot.docs) {
        final missionData = doc.data();
        final missionName = (missionData['name'] ?? '').toString();
        if (missionName.toLowerCase().contains('sabah') &&
            !missionName.toLowerCase().contains('north')) {
          sabahMissionId = doc.id;
          debugPrint('Found Sabah Mission: $missionName (ID: $sabahMissionId)');
          break;
        }
      }

      if (sabahMissionId == null) {
        throw Exception('Sabah Mission not found in Firestore');
      }

      // Get all regions and districts for Sabah Mission
      final regionsSnapshot = await _firestore
          .collection('regions')
          .where('missionId', isEqualTo: sabahMissionId)
          .get();

      final districtsSnapshot = await _firestore
          .collection('districts')
          .where('missionId', isEqualTo: sabahMissionId)
          .get();

      // Create name-to-ID mappings (case-insensitive)
      final Map<String, String> regionNameToId = {};
      final Map<String, String> districtNameToId = {};

      for (var doc in regionsSnapshot.docs) {
        final name = (doc.data()['name'] ?? '').toString().toUpperCase();
        if (name.isNotEmpty) {
          regionNameToId[name] = doc.id;
          debugPrint('  Region: $name → ${doc.id}');
        }
      }

      for (var doc in districtsSnapshot.docs) {
        final name = (doc.data()['name'] ?? '').toString().toUpperCase();
        if (name.isNotEmpty) {
          districtNameToId[name] = doc.id;
          debugPrint('  District: $name → ${doc.id}');
        }
      }

      debugPrint('\n📊 Mapped ${regionNameToId.length} regions and ${districtNameToId.length} districts');

      // Parse the JSON structure
      final regions = data['regions'] as Map<String, dynamic>?;
      if (regions == null) {
        throw Exception('No regions found in JSON');
      }

      // Extract pastor-to-district mappings
      final Map<String, Map<String, String>> pastorAssignments = {};

      for (var regionEntry in regions.entries) {
        final regionData = regionEntry.value as Map<String, dynamic>;
        final regionName = regionData['name'] as String?;
        final districts =
            regionData['pastoral_districts'] as Map<String, dynamic>?;

        if (districts == null || regionName == null) continue;

        for (var districtEntry in districts.entries) {
          final districtName = districtEntry.key;
          final districtData = districtEntry.value as Map<String, dynamic>;

          // Handle both "pastor": "Name" and "pastors": [{"name": "Name"}]
          final List<String> pastorNames = [];

          // Single pastor format
          final singlePastor = districtData['pastor'] as String?;
          if (singlePastor != null && singlePastor.isNotEmpty) {
            pastorNames.add(singlePastor);
          }

          // Multiple pastors format
          final pastorsList = districtData['pastors'] as List?;
          if (pastorsList != null) {
            for (var pastor in pastorsList) {
              if (pastor is Map<String, dynamic>) {
                final name = pastor['name'] as String?;
                if (name != null && name.isNotEmpty) {
                  pastorNames.add(name);
                }
              }
            }
          }

          // Add all pastors to assignments
          for (var pastorName in pastorNames) {
            results['total_pastors_in_json'] =
                (results['total_pastors_in_json'] as int) + 1;

            pastorAssignments[pastorName.toUpperCase()] = {
              'region': regionName,
              'district': districtName,
            };

            debugPrint('  Pastor: $pastorName → $regionName / $districtName');
          }
        }
      }

      debugPrint('\n✨ Found ${pastorAssignments.length} pastor assignments');

      // Get all staff from Sabah Mission
      final staffSnapshot = await _firestore
          .collection('staff')
          .where('mission', isEqualTo: sabahMissionId)
          .get();

      debugPrint('📋 Processing ${staffSnapshot.docs.length} staff members...\n');

      // Match and update staff
      for (var staffDoc in staffSnapshot.docs) {
        try {
          final staffData = staffDoc.data();
          final staffName = (staffData['name'] ?? '').toString();
          final staffNameUpper = staffName.toUpperCase();

          // Try to find a match in pastor assignments
          Map<String, String>? assignment;

          // Direct match
          if (pastorAssignments.containsKey(staffNameUpper)) {
            assignment = pastorAssignments[staffNameUpper];
          } else {
            // Try partial matching (last name or first name)
            for (var entry in pastorAssignments.entries) {
              final jsonName = entry.key;
              final jsonParts = jsonName.split(' ');
              final staffParts = staffNameUpper.split(' ');

              // Check if last names match
              if (jsonParts.isNotEmpty &&
                  staffParts.isNotEmpty &&
                  jsonParts.last == staffParts.last) {
                assignment = entry.value;
                debugPrint('  Matched by last name: $staffName ≈ ${entry.key}');
                break;
              }
            }
          }

          if (assignment != null) {
            results['matched_staff'] = (results['matched_staff'] as int) + 1;

            final regionName = assignment['region']!;
            final districtName = assignment['district']!;

            // Get the IDs
            final regionId = regionNameToId[regionName.toUpperCase()];
            final districtId = districtNameToId[districtName.toUpperCase()];

            if (regionId == null || districtId == null) {
              debugPrint(
                  '  ⚠️ $staffName: Could not find IDs for $regionName / $districtName');
              (results['errors'] as List).add(
                  '$staffName: Region or district not found in Firestore');
              continue;
            }

            // Update the staff record
            await _firestore.collection('staff').doc(staffDoc.id).update({
              'region': regionId,
              'district': districtId,
            });

            results['updated_staff'] = (results['updated_staff'] as int) + 1;
            debugPrint('  ✅ $staffName: $regionName ($regionId) / $districtName ($districtId)');
          } else {
            (results['unmatched_staff'] as List).add(staffName);
            debugPrint('  ⚠️ No match found for: $staffName');
          }
        } catch (e) {
          (results['errors'] as List).add('Error updating ${staffDoc.id}: $e');
          debugPrint('  ❌ Error updating ${staffDoc.id}: $e');
        }
      }

      debugPrint('\n${'=' * 80}');
      debugPrint('✅ IMPORT COMPLETE:');
      debugPrint('Total Pastors in JSON: ${results['total_pastors_in_json']}');
      debugPrint('Matched Staff: ${results['matched_staff']}');
      debugPrint('Updated Staff: ${results['updated_staff']}');
      debugPrint('Unmatched Staff: ${(results['unmatched_staff'] as List).length}');
      debugPrint('Errors: ${(results['errors'] as List).length}');

      if ((results['unmatched_staff'] as List).isNotEmpty) {
        debugPrint('\n⚠️ UNMATCHED STAFF:');
        for (var name in (results['unmatched_staff'] as List)) {
          debugPrint('  - $name');
        }
      }

      return results;
    } catch (e) {
      debugPrint('❌ Error importing staff assignments: $e');
      rethrow;
    }
  }

  /// Preview what would be imported without updating
  static Future<void> previewImport() async {
    debugPrint('👁️ PREVIEW: Staff assignments from churches_SAB.json\n');

    try {
      final jsonString =
          await rootBundle.loadString('assets/churches_SAB.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;

      final regions = data['regions'] as Map<String, dynamic>?;
      if (regions == null) {
        debugPrint('No regions found in JSON');
        return;
      }

      int totalPastors = 0;

      for (var regionEntry in regions.entries) {
        final regionData = regionEntry.value as Map<String, dynamic>;
        final regionName = regionData['name'] as String?;
        final districts =
            regionData['pastoral_districts'] as Map<String, dynamic>?;

        if (districts == null || regionName == null) continue;

        debugPrint('📍 $regionName:');

        for (var districtEntry in districts.entries) {
          final districtName = districtEntry.key;
          final districtData = districtEntry.value as Map<String, dynamic>;
          final pastorName = districtData['pastor'] as String?;

          if (pastorName != null && pastorName.isNotEmpty) {
            totalPastors++;
            debugPrint('  $districtName: $pastorName');
          }
        }
        debugPrint('');
      }

      debugPrint('📊 Total: $totalPastors pastor assignments found');
    } catch (e) {
      debugPrint('❌ Error previewing: $e');
    }
  }
}
