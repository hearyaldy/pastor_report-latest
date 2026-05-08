// lib/utils/update_staff_regions_districts_util.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pastor_report/services/staff_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/district_service.dart';

class StaffRegionDistrictUtil {
  static final StaffService _staffService = StaffService.instance;
  static final RegionService _regionService = RegionService.instance;
  static final DistrictService _districtService = DistrictService.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mission IDs
  static const String SABAH_MISSION_ID = '4LFC9isp22H7Og1FHBm6';
  static const String NSM_MISSION_ID = 'M89PoDdB5sNCoDl8qTNS';

  /// Update staff regions and districts for both Sabah Mission and North Sabah Mission
  /// based on the corrected information in JSON files
  static Future<Map<String, dynamic>> updateStaffFromCorrectedData(
      BuildContext context) async {
    try {
      print(
          'StaffRegionDistrictUtil: Starting staff region and district update...');

      final results = <String, dynamic>{
        'sabah': <String, int>{'updated': 0, 'notFound': 0, 'errors': 0},
        'nsm': <String, int>{'updated': 0, 'notFound': 0, 'errors': 0},
        'details': <String>[]
      };

      // Update Sabah Mission staff
      print('StaffRegionDistrictUtil: Updating Sabah Mission staff...');
      results['sabah'] =
          await _updateSabahMissionStaff(results['details'] as List<String>);
      (results['details'] as List<String>).add(
          'Sabah Mission: ${results['sabah']['updated']} updated, ${results['sabah']['notFound']} not found, ${results['sabah']['errors']} errors');

      // Update North Sabah Mission staff
      print('StaffRegionDistrictUtil: Updating North Sabah Mission staff...');
      results['nsm'] =
          await _updateNSMMissionStaff(results['details'] as List<String>);
      (results['details'] as List<String>).add(
          'North Sabah Mission: ${results['nsm']['updated']} updated, ${results['nsm']['notFound']} not found, ${results['nsm']['errors']} errors');

      final totalUpdated =
          results['sabah']['updated'] + results['nsm']['updated'];
      final totalNotFound =
          results['sabah']['notFound'] + results['nsm']['notFound'];
      final totalErrors = results['sabah']['errors'] + results['nsm']['errors'];

      (results['details'] as List<String>).add(
          'Total: $totalUpdated updated, $totalNotFound not found, $totalErrors errors');

      return {
        'success': true,
        'results': results,
        'message':
            'Staff region and district update completed. Updated: $totalUpdated, Not Found: $totalNotFound, Errors: $totalErrors'
      };
    } catch (e, stackTrace) {
      print('ERROR updating staff regions and districts: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
        'message': 'Error updating staff: $e'
      };
    }
  }

  /// Update Sabah Mission staff based on churches_SAB.json data
  static Future<Map<String, int>> _updateSabahMissionStaff(
      List<String> details) async {
    int updated = 0;
    int notFound = 0;
    int errors = 0;

    try {
      // Load churches_SAB.json data
      final String jsonString =
          await rootBundle.loadString('assets/churches_SAB.json');
      final Map<String, dynamic> sabahData = json.decode(jsonString);

      // Get all Sabah Mission staff
      final QuerySnapshot staffSnapshot = await _firestore
          .collection('staff')
          .where('mission', isEqualTo: SABAH_MISSION_ID)
          .get();

      print(
          'StaffRegionDistrictUtil: Found ${staffSnapshot.docs.length} Sabah Mission staff');

      // Build a map of pastor names to their region and district from JSON
      final Map<String, Map<String, String>> pastorMap =
          <String, Map<String, String>>{};

      if (sabahData['regions'] != null) {
        final regions = sabahData['regions'] as Map<String, dynamic>;
        for (final regionEntry in regions.entries) {
          final regionData = regionEntry.value as Map<String, dynamic>;
          final regionName = regionData['name'] as String;

          if (regionData['pastoral_districts'] != null) {
            final districts =
                regionData['pastoral_districts'] as Map<String, dynamic>;

            for (final districtEntry in districts.entries) {
              final districtName = districtEntry.key;
              final districtData = districtEntry.value as Map<String, dynamic>;

              // Handle both single pastor and multiple pastors
              if (districtData['pastors'] != null &&
                  districtData['pastors'] is List) {
                final pastors = districtData['pastors'] as List<dynamic>;
                for (final pastor in pastors) {
                  if (pastor is Map<String, dynamic> &&
                      pastor['name'] != null) {
                    final name = _normalizeName(pastor['name'] as String);
                    if (name.isNotEmpty) {
                      pastorMap[name] = {
                        'regionName': regionName,
                        'districtName': districtName,
                      };
                    }
                  }
                }
              } else if (districtData['pastor'] != null) {
                final pastorName = districtData['pastor'] as String;
                if (pastorName.isNotEmpty) {
                  final name = _normalizeName(pastorName);
                  if (name.isNotEmpty) {
                    pastorMap[name] = {
                      'regionName': regionName,
                      'districtName': districtName,
                    };
                  }
                }
              }
            }
          }
        }
      }

      print(
          'StaffRegionDistrictUtil: Built Sabah pastor map with ${pastorMap.length} entries');

      // Update each Sabah Mission staff member who is a Field Pastor
      for (final staffDoc in staffSnapshot.docs) {
        final staffData = staffDoc.data() as Map<String, dynamic>;
        final staffName = staffData['name'] as String?;

        if (staffName != null &&
            (staffData['role'] as String?) == 'Field Pastor') {
          final normalizedStaffName = _normalizeName(staffName);

          // Try to find matching pastor in map
          final pastorInfo = pastorMap[normalizedStaffName];

          if (pastorInfo != null) {
            try {
              // Find region in database
              final QuerySnapshot regionSnapshot = await _firestore
                  .collection('regions')
                  .where('missionId', isEqualTo: SABAH_MISSION_ID)
                  .where('name', isEqualTo: pastorInfo['regionName'])
                  .limit(1)
                  .get();

              if (regionSnapshot.docs.isNotEmpty) {
                final regionId = regionSnapshot.docs.first.id;

                // Find district in database
                final QuerySnapshot districtSnapshot = await _firestore
                    .collection('districts')
                    .where('regionId', isEqualTo: regionId)
                    .where('name', isEqualTo: pastorInfo['districtName'])
                    .limit(1)
                    .get();

                if (districtSnapshot.docs.isNotEmpty) {
                  final districtId = districtSnapshot.docs.first.id;

                  // First get the existing staff record to preserve current notes
                  final existingStaffDoc = await _firestore
                      .collection('staff')
                      .doc(staffDoc.id)
                      .get();
                  final existingData = existingStaffDoc.data();
                  String? existingNotes = existingData?['notes'] as String?;

                  // Create updated notes by appending to existing notes
                  String updatedNotes = existingNotes != null &&
                          existingNotes.isNotEmpty
                      ? '$existingNotes\nUpdated from churches_SAB.json: ${pastorInfo['regionName']} - ${pastorInfo['districtName']}'
                      : 'Updated from churches_SAB.json: ${pastorInfo['regionName']} - ${pastorInfo['districtName']}';

                  // Update staff record
                  await _firestore.collection('staff').doc(staffDoc.id).update({
                    'region': regionId,
                    'district': districtId,
                    'notes': updatedNotes,
                  });

                  print(
                      '✅ $staffName -> ${pastorInfo['regionName']} / ${pastorInfo['districtName']}');
                  updated++;
                  details.add(
                      'Updated Sabah Mission staff: $staffName -> ${pastorInfo['regionName']} / ${pastorInfo['districtName']}');
                } else {
                  print(
                      '⚠️ $staffName - District not found: ${pastorInfo['districtName']}');
                  notFound++;
                  details.add(
                      'District not found for Sabah Mission staff: $staffName - ${pastorInfo['districtName']}');
                }
              } else {
                print(
                    '⚠️ $staffName - Region not found: ${pastorInfo['regionName']}');
                notFound++;
                details.add(
                    'Region not found for Sabah Mission staff: $staffName - ${pastorInfo['regionName']}');
              }
            } catch (e) {
              print('❌ Error updating $staffName: $e');
              errors++;
              details
                  .add('Error updating Sabah Mission staff: $staffName - $e');
            }
          } else {
            print(
                '⚠️ $staffName (Field Pastor) - Not found in churches_SAB.json');
            notFound++;
            details.add('Not found in JSON Sabah Mission staff: $staffName');
          }
        }
      }
    } catch (e) {
      print('❌ Error updating Sabah Mission staff: $e');
      errors++;
      details.add('Error processing Sabah Mission: $e');
    }

    return {'updated': updated, 'notFound': notFound, 'errors': errors};
  }

  /// Update North Sabah Mission staff based on NSM STAFF.json data
  static Future<Map<String, int>> _updateNSMMissionStaff(
      List<String> details) async {
    int updated = 0;
    int notFound = 0;
    int errors = 0;

    try {
      // Load NSM STAFF.json data (has the field pastor assignments with corrected regions/districts)
      final String jsonString =
          await rootBundle.loadString('assets/NSM STAFF.json');
      final Map<String, dynamic> nsmStaffData = json.decode(jsonString);

      // Get all North Sabah Mission staff
      final QuerySnapshot staffSnapshot = await _firestore
          .collection('staff')
          .where('mission', isEqualTo: NSM_MISSION_ID)
          .get();

      print(
          'StaffRegionDistrictUtil: Found ${staffSnapshot.docs.length} North Sabah Mission staff');

      // Build a map of field pastors from NSM STAFF.json with their region and assignment
      final Map<String, Map<String, String>> fieldPastorMap =
          <String, Map<String, String>>{};

      if (nsmStaffData['field_pastors'] != null) {
        final fieldPastors =
            nsmStaffData['field_pastors'] as Map<String, dynamic>;

        for (final regionEntry in fieldPastors.entries) {
          final regionName = regionEntry.key; // e.g., "REGION 1", "REGION 2"
          final pastors = regionEntry.value as List<dynamic>;

          for (final pastor in pastors) {
            final pastorName = pastor['name'] as String;
            final assignment = pastor['assignment'] as String;

            final normalized = _normalizeName(pastorName);
            if (normalized.isNotEmpty) {
              fieldPastorMap[normalized] = {
                'regionName':
                    regionName, // Note: This is "REGION 1" format, not "Region 1"
                'assignment': assignment, // This is the district name
              };
            }
          }
        }
      }

      print(
          'StaffRegionDistrictUtil: Built NSM field pastor map with ${fieldPastorMap.length} entries');

      // Update each NSM staff member who is a Field Pastor
      for (final staffDoc in staffSnapshot.docs) {
        final staffData = staffDoc.data() as Map<String, dynamic>;
        final staffName = staffData['name'] as String?;
        final staffRole = staffData['role'] as String?;

        if (staffName != null && staffRole == 'Field Pastor') {
          final normalizedStaffName = _normalizeName(staffName);

          // Try to find matching field pastor in map
          final pastorInfo = fieldPastorMap[normalizedStaffName];

          if (pastorInfo != null) {
            try {
              // The region name in NSM STAFF.json is in format "REGION 1", "REGION 2", etc.
              // But in the database it might be different, so try multiple possible formats
              String regionName = pastorInfo['regionName'] as String;
              List<String> possibleRegionNames = [
                regionName, // Original format: "REGION 1"
                regionName.replaceFirst('REGION', 'Region'), // "Region 1"
                regionName.replaceFirst('REGION', 'region'), // "region 1"
                regionName.replaceFirst(
                    RegExp(r'^REGION\s*'), 'Region '), // "Region 1"
              ];

              DocumentSnapshot? foundRegionDoc;

              // Try each possible region name format
              for (String possibleName in possibleRegionNames) {
                possibleName = possibleName.trim();
                final regionSnapshot = await _firestore
                    .collection('regions')
                    .where('missionId', isEqualTo: NSM_MISSION_ID)
                    .where('name', isEqualTo: possibleName)
                    .limit(1)
                    .get();

                if (regionSnapshot.docs.isNotEmpty) {
                  foundRegionDoc = regionSnapshot.docs.first;
                  break; // Found the region
                }
              }

              // If still not found, try a more flexible approach with just the number
              if (foundRegionDoc == null) {
                // Extract the number from the region name (e.g., "REGION 1" -> "1")
                final regionNumber =
                    RegExp(r'(\d+)').firstMatch(regionName)?.group(1);
                if (regionNumber != null) {
                  // Search for regions that contain the number
                  final allRegions = await _firestore
                      .collection('regions')
                      .where('missionId', isEqualTo: NSM_MISSION_ID)
                      .get();

                  // Find a region that has this number in its name
                  for (var regionDoc in allRegions.docs) {
                    final regionData = regionDoc.data();
                    final dbName = regionData['name'] as String?;
                    if (dbName != null && dbName.contains(regionNumber)) {
                      foundRegionDoc = regionDoc;
                      break;
                    }
                  }
                }
              }

              if (foundRegionDoc != null) {
                final regionId = foundRegionDoc.id;
                final actualRegionName = (foundRegionDoc.data()
                    as Map<String, dynamic>)['name'] as String;

                // Find district in database - this will be the assignment
                // The assignment from NSM STAFF.json has "District" suffix (e.g., "Morion District")
                // But the database might have different formats
                final assignment = pastorInfo['assignment'] as String;
                DocumentSnapshot? foundDistrictDoc;

                // Normalize the assignment name to find the base name
                String baseDistrictName = assignment;
                if (assignment.endsWith(' District')) {
                  baseDistrictName =
                      assignment.replaceAll(' District', '').trim();
                }

                // Try exact match with "District" suffix first
                var districtSnapshot = await _firestore
                    .collection('districts')
                    .where('regionId', isEqualTo: regionId)
                    .where('name', isEqualTo: assignment)
                    .limit(1)
                    .get();

                if (districtSnapshot.docs.isNotEmpty) {
                  foundDistrictDoc = districtSnapshot.docs.first;
                } else {
                  // Try exact match without "District" suffix
                  districtSnapshot = await _firestore
                      .collection('districts')
                      .where('regionId', isEqualTo: regionId)
                      .where('name', isEqualTo: baseDistrictName)
                      .limit(1)
                      .get();

                  if (districtSnapshot.docs.isNotEmpty) {
                    foundDistrictDoc = districtSnapshot.docs.first;
                  } else {
                    // If still not found, try to search for districts that might contain the base name
                    // This is a more flexible approach where we get all districts in the region
                    // and do a partial match
                    final allDistrictsInRegion = await _firestore
                        .collection('districts')
                        .where('regionId', isEqualTo: regionId)
                        .get();

                    // Case-insensitive partial matching
                    for (var districtDoc in allDistrictsInRegion.docs) {
                      final districtData = districtDoc.data();
                      final dbName = districtData['name'] as String?;
                      if (dbName != null) {
                        // Normalize the database district name too
                        String normalizedDbName = dbName.toLowerCase();
                        String normalizedSearchName =
                            baseDistrictName.toLowerCase();

                        // Check for exact match or if one contains the other
                        if (normalizedDbName == normalizedSearchName ||
                            normalizedSearchName == normalizedDbName ||
                            normalizedDbName.contains(normalizedSearchName) ||
                            normalizedSearchName.contains(normalizedDbName)) {
                          // Additional check: compare words after removing common prefixes/suffixes
                          String cleanDbName = normalizedDbName
                              .replaceAll(
                                  RegExp(r'\b(chaplain|chinese|bahasa)\b'), '')
                              .replaceAll(RegExp(r'\s+'), ' ')
                              .trim();
                          String cleanSearchName = normalizedSearchName
                              .replaceAll(
                                  RegExp(r'\b(chaplain|chinese|bahasa)\b'), '')
                              .replaceAll(RegExp(r'\s+'), ' ')
                              .trim();

                          if (cleanDbName == cleanSearchName ||
                              cleanDbName.contains(cleanSearchName) ||
                              cleanSearchName.contains(cleanDbName)) {
                            foundDistrictDoc = districtDoc;
                            break;
                          }
                        }
                      }
                    }
                  }
                }

                if (foundDistrictDoc != null) {
                  final districtId = foundDistrictDoc.id;
                  final actualDistrictName = (foundDistrictDoc.data()
                      as Map<String, dynamic>)['name'] as String;

                  // First get the existing staff record to preserve current notes
                  final existingStaffDoc = await _firestore
                      .collection('staff')
                      .doc(staffDoc.id)
                      .get();
                  final existingData = existingStaffDoc.data();
                  String? existingNotes = existingData?['notes'] as String?;

                  // Create updated notes by appending to existing notes
                  String updatedNotes = existingNotes != null &&
                          existingNotes.isNotEmpty
                      ? '$existingNotes\nUpdated from NSM STAFF.json: $actualRegionName - $actualDistrictName'
                      : 'Updated from NSM STAFF.json: $actualRegionName - $actualDistrictName';

                  // Update staff record
                  await _firestore.collection('staff').doc(staffDoc.id).update({
                    'region': regionId,
                    'district': districtId,
                    'notes': updatedNotes,
                  });

                  print(
                      '✅ $staffName -> $actualRegionName / $actualDistrictName');
                  updated++;
                  details.add(
                      'Updated NSM staff: $staffName -> $actualRegionName / $actualDistrictName');
                } else {
                  print('⚠️ $staffName - District not found: $assignment');
                  notFound++;
                  details.add(
                      'District not found for NSM staff: $staffName - $assignment');
                }
              } else {
                print(
                    '⚠️ $staffName - Region not found: $regionName (tried: ${possibleRegionNames.join(", ")})');
                notFound++;
                details.add(
                    'Region not found for NSM staff: $staffName - $regionName');
              }
            } catch (e) {
              print('❌ Error updating $staffName: $e');
              errors++;
              details.add('Error updating NSM staff: $staffName - $e');
            }
          } else {
            print('⚠️ $staffName (Field Pastor) - Not found in NSM STAFF.json');
            notFound++;
            details.add('Not found in JSON NSM staff: $staffName');
          }
        }
      }
    } catch (e) {
      print('❌ Error updating NSM staff: $e');
      errors++;
      details.add('Error processing NSM: $e');
    }

    return {'updated': updated, 'notFound': notFound, 'errors': errors};
  }

  static String _normalizeName(String? name) {
    if (name == null) return '';
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim();
  }
}
