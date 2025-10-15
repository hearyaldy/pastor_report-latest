import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pastor_report/services/staff_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/models/staff_model.dart';

class StaffRegionDistrictUpdater {
  final StaffService _staffService = StaffService.instance;
  final RegionService _regionService = RegionService.instance;
  final DistrictService _districtService = DistrictService.instance;

  // Mission IDs
  static const String SABAH_MISSION_ID = '4LFC9isp22H7Og1FHBm6';
  static const String NSM_MISSION_ID = 'M89PoDdB5sNCoDl8qTNS';

  Future<Map<String, dynamic>> updateStaffBasedOnUpdatedData() async {
    print('🔧 Starting staff region and district update based on corrected data...');

    Map<String, dynamic> results = {
      'sabahMission': {'updated': 0, 'notFound': 0, 'errors': 0},
      'nsmMission': {'updated': 0, 'notFound': 0, 'errors': 0},
    };

    // Update Sabah Mission staff based on churches_SAB.json
    print('\n🏢 UPDATING SABAH MISSION STAFF...');
    results['sabahMission'] = await _updateSabahMissionStaffFromChurches();

    // Update North Sabah Mission staff based on NSM_Churches_Updated.json
    print('\n🏢 UPDATING NORTH SABAH MISSION STAFF...');
    results['nsmMission'] = await _updateNSMMissionStaffFromUpdatedChurches();

    // Print summary
    _printSummary(results);

    return results;
  }

  Future<Map<String, int>> _updateSabahMissionStaffFromChurches() async {
    int updated = 0;
    int notFound = 0;
    int errors = 0;

    try {
      // Load churches_SAB.json data
      final String jsonString = await rootBundle.loadString('assets/churches_SAB.json');
      final Map<String, dynamic> sabahData = json.decode(jsonString);

      // Get all Sabah Mission staff
      final sabahStaff = await _staffService.getStaffByMission(SABAH_MISSION_ID);

      print('Found ${sabahStaff.length} Sabah Mission staff members');

      // Build a map of pastor names to their region and district from JSON
      final Map<String, Map<String, String>> pastorMap = <String, Map<String, String>>{};

      if (sabahData['regions'] != null) {
        for (final regionEntry in sabahData['regions'].entries) {
          final regionData = regionEntry.value as Map<String, dynamic>;
          final regionNumber = regionEntry.key; // e.g., "1", "2"
          final regionName = regionData['name'] as String;

          if (regionData['pastoral_districts'] != null) {
            final districts = regionData['pastoral_districts'] as Map<String, dynamic>;
            
            for (final districtEntry in districts.entries) {
              final districtName = districtEntry.key;
              final districtData = districtEntry.value as Map<String, dynamic>;

              // Handle both single pastor and multiple pastors
              if (districtData['pastors'] != null && districtData['pastors'] is List) {
                final pastors = districtData['pastors'] as List<dynamic>;
                for (final pastor in pastors) {
                  if (pastor is Map<String, dynamic> && pastor['name'] != null) {
                    final name = _normalizeName(pastor['name'] as String);
                    pastorMap[name] = {
                      'regionName': regionName,
                      'districtName': districtName,
                    };
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

      print('Built Sabah pastor map with ${pastorMap.length} entries');

      // Update each Sabah Mission staff member who is a Field Pastor
      for (final staff in sabahStaff) {
        if (staff.role == 'Field Pastor') {
          final normalizedStaffName = _normalizeName(staff.name);

          // Try to find matching pastor in map
          final pastorInfo = pastorMap[normalizedStaffName];

          if (pastorInfo != null) {
            try {
              // Find region in database
              final regions = await _regionService.getRegionsByMission(SABAH_MISSION_ID);
              final region = regions.firstWhere(
                (r) => r.name == pastorInfo['regionName'],
                orElse: () => throw Exception('Region not found: ${pastorInfo['regionName']}'),
              );

              // Find district in database
              final districts = await _districtService.getDistrictsByRegion(region.id);
              final district = districts.firstWhere(
                (d) => d.name == pastorInfo['districtName'],
                orElse: () => throw Exception('District not found: ${pastorInfo['districtName']}'),
              );

              // Update staff record
              final updatedStaff = staff.copyWith(
                region: region.id,
                district: district.id,
                notes: staff.notes != null 
                  ? '${staff.notes}\nUpdated from churches_SAB.json: ${pastorInfo['regionName']} - ${pastorInfo['districtName']}'
                  : 'Updated from churches_SAB.json: ${pastorInfo['regionName']} - ${pastorInfo['districtName']}',
              );

              final success = await _staffService.updateStaff(updatedStaff);
              if (success) {
                print('✅ ${staff.name} -> ${pastorInfo['regionName']} / ${pastorInfo['districtName']}');
                updated++;
              } else {
                print('❌ Failed to update ${staff.name}');
                errors++;
              }
            } catch (e) {
              print('⚠️ ${staff.name} - Region/District not found in DB: $e');
              notFound++;
            }
          } else {
            print('⚠️ ${staff.name} (Field Pastor) - Not found in churches_SAB.json');
            notFound++;
          }
        }
      }
    } catch (e) {
      print('❌ Error updating Sabah Mission staff: $e');
      errors++;
    }

    return {'updated': updated, 'notFound': notFound, 'errors': errors};
  }

  Future<Map<String, int>> _updateNSMMissionStaffFromUpdatedChurches() async {
    int updated = 0;
    int notFound = 0;
    int errors = 0;

    try {
      // Load NSM_Churches_Updated.json data (has the corrected assignments)
      final String jsonString = await rootBundle.loadString('assets/NSM_Churches_Updated.json');
      final Map<String, dynamic> nsmData = json.decode(jsonString);

      // Get all North Sabah Mission staff
      final nsmStaff = await _staffService.getStaffByMission(NSM_MISSION_ID);

      print('Found ${nsmStaff.length} North Sabah Mission staff members');

      // Build a map of pastor names to their region and district from updated JSON
      final Map<String, Map<String, String>> pastorMap = <String, Map<String, String>>{};

      if (nsmData['regions'] != null) {
        for (final regionEntry in nsmData['regions'].entries) {
          final regionData = regionEntry.value as Map<String, dynamic>;
          final regionNumber = regionEntry.key; // e.g., "1", "2"
          final regionName = regionData['name'] as String;

          if (regionData['pastoral_districts'] != null) {
            final districts = regionData['pastoral_districts'] as Map<String, dynamic>;
            
            for (final districtEntry in districts.entries) {
              final districtName = districtEntry.key;
              final districtData = districtEntry.value as Map<String, dynamic>;

              // Handle both single pastor and multiple pastors
              if (districtData['pastors'] != null && districtData['pastors'] is List) {
                final pastors = districtData['pastors'] as List<dynamic>;
                for (final pastor in pastors) {
                  if (pastor is Map<String, dynamic> && pastor['name'] != null) {
                    final name = _normalizeName(pastor['name'] as String);
                    if (name.isNotEmpty) {
                      pastorMap[name] = {
                        'regionName': regionName,
                        'districtName': districtName,
                      };
                    }
                  }
                }
              } else if (districtData['pastor'] != null && districtData['pastor'] != '') {
                final pastorName = districtData['pastor'] as String;
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

      print('Built NSM updated pastor map with ${pastorMap.length} entries');

      // Update each NSM staff member who is a Field Pastor
      for (final staff in nsmStaff) {
        if (staff.role == 'Field Pastor') {
          final normalizedStaffName = _normalizeName(staff.name);

          // Try to find matching pastor in map
          final pastorInfo = pastorMap[normalizedStaffName];

          if (pastorInfo != null) {
            try {
              // Find region in database
              final regions = await _regionService.getRegionsByMission(NSM_MISSION_ID);
              final region = regions.firstWhere(
                (r) => r.name == pastorInfo['regionName'],
                orElse: () => throw Exception('Region not found: ${pastorInfo['regionName']}'),
              );

              // Find district in database
              final districts = await _districtService.getDistrictsByRegion(region.id);
              final district = districts.firstWhere(
                (d) => d.name == pastorInfo['districtName'],
                orElse: () => throw Exception('District not found: ${pastorInfo['districtName']}'),
              );

              // Update staff record
              final updatedStaff = staff.copyWith(
                region: region.id,
                district: district.id,
                notes: staff.notes != null 
                  ? '${staff.notes}\nUpdated from NSM_Churches_Updated.json: ${pastorInfo['regionName']} - ${pastorInfo['districtName']}'
                  : 'Updated from NSM_Churches_Updated.json: ${pastorInfo['regionName']} - ${pastorInfo['districtName']}',
              );

              final success = await _staffService.updateStaff(updatedStaff);
              if (success) {
                print('✅ ${staff.name} -> ${pastorInfo['regionName']} / ${pastorInfo['districtName']}');
                updated++;
              } else {
                print('❌ Failed to update ${staff.name}');
                errors++;
              }
            } catch (e) {
              print('⚠️ ${staff.name} - Region/District not found in DB: $e');
              notFound++;
            }
          } else {
            print('⚠️ ${staff.name} (Field Pastor) - Not found in NSM_Churches_Updated.json');
            notFound++;
          }
        }
      }
    } catch (e) {
      print('❌ Error updating NSM staff: $e');
      errors++;
    }

    return {'updated': updated, 'notFound': notFound, 'errors': errors};
  }

  Future<Map<String, int>> _updateNSMMissionStaffFromNSMStaffJSON() async {
    int updated = 0;
    int notFound = 0;
    int errors = 0;

    try {
      // Load NSM STAFF.json data (with corrected assignments)
      final String jsonString = await rootBundle.loadString('assets/NSM STAFF.json');
      final Map<String, dynamic> nsmStaffData = json.decode(jsonString);
      
      // Get all North Sabah Mission staff
      final nsmStaff = await _staffService.getStaffByMission(NSM_MISSION_ID);

      print('Processing NSM assignments from NSM STAFF.json for ${nsmStaff.length} staff members');

      // Build a map of assignments to region from the NSM STAFF.json
      final Map<String, String> regionForAssignment = <String, String>{};

      if (nsmStaffData['field_pastors'] != null) {
        for (final regionEntry in nsmStaffData['field_pastors'].entries) {
          final regionName = regionEntry.key; // e.g., "REGION 1"
          final pastors = regionEntry.value as List<dynamic>;

          for (final pastor in pastors) {
            final assignment = pastor['assignment'] as String;
            if (assignment != null) {
              regionForAssignment[assignment] = regionName;
            }
          }
        }
      }

      print('Built NSM staff assignment map with ${regionForAssignment.length} entries');

      // Update each NSM staff member based on the corrected assignments
      for (final staff in nsmStaff) {
        if (staff.role == 'Field Pastor' && staff.district != null) {
          final assignment = staff.district;

          if (regionForAssignment.containsKey(assignment)) {
            try {
              // Find region in database based on corrected region name
              final regions = await _regionService.getRegionsByMission(NSM_MISSION_ID);
              final region = regions.firstWhere(
                (r) => r.name == regionForAssignment[assignment],
                orElse: () => throw Exception('Region not found: ${regionForAssignment[assignment]}'),
              );

              // Find district in database
              final districts = await _districtService.getDistrictsByRegion(region.id);
              final district = districts.firstWhere(
                (d) => d.name == assignment,
                orElse: () => throw Exception('District not found: $assignment'),
              );

              // Update staff record
              final updatedStaff = staff.copyWith(
                region: region.id,
                district: district.id,
                notes: staff.notes != null 
                  ? '${staff.notes}\nUpdated from NSM STAFF.json: ${regionForAssignment[assignment]} - $assignment'
                  : 'Updated from NSM STAFF.json: ${regionForAssignment[assignment]} - $assignment',
              );

              final success = await _staffService.updateStaff(updatedStaff);
              if (success) {
                print('✅ ${staff.name} -> ${regionForAssignment[assignment]} / $assignment');
                updated++;
              } else {
                print('❌ Failed to update ${staff.name}');
                errors++;
              }
            } catch (e) {
              print('⚠️ ${staff.name} - Region/District not found in DB for assignment $assignment: $e');
              notFound++;
            }
          } else {
            print('⚠️ Assignment $assignment not found in NSM STAFF.json for ${staff.name}');
            notFound++;
          }
        }
      }
    } catch (e) {
      print('❌ Error updating NSM staff from NSM STAFF.json: $e');
      errors++;
    }

    return {'updated': updated, 'notFound': notFound, 'errors': errors};
  }

  String _normalizeName(String? name) {
    if (name == null) return '';
    return name.toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .trim();
  }

  void _printSummary(Map<String, dynamic> results) {
    print('\n' + '=' * 70);
    print('📊 FINAL SUMMARY');
    print('=' * 70);
    
    print('\n🏢 SABAH MISSION:');
    print('   ✅ Updated: ${results['sabahMission']['updated']}');
    print('   ⚠️  Not Found: ${results['sabahMission']['notFound']}');
    print('   ❌ Errors: ${results['sabahMission']['errors']}');

    print('\n🏢 NORTH SABAH MISSION:');
    print('   ✅ Updated: ${results['nsmMission']['updated']}');
    print('   ⚠️  Not Found: ${results['nsmMission']['notFound']}');
    print('   ❌ Errors: ${results['nsmMission']['errors']}');

    print('\n📈 TOTAL:');
    print('   ✅ Total Updated: ${results['sabahMission']['updated'] + results['nsmMission']['updated']}');
    print('   ⚠️  Total Not Found: ${results['sabahMission']['notFound'] + results['nsmMission']['notFound']}');
    print('   ❌ Total Errors: ${results['sabahMission']['errors'] + results['nsmMission']['errors']}');

    print('\n' + '=' * 70);
    print('🎉 UPDATE COMPLETE!');
    print('='.repeat(70));
  }
}