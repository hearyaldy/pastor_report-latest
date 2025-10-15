import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/church_model.dart';

class RestorationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Restore Sabah Mission regions, districts, and churches from JSON
  Future<Map<String, dynamic>> restoreSabahMissionFromJson({
    required String sabahMissionId,
    required String userId,
  }) async {
    try {
      print('RestorationService: Starting Sabah Mission restoration...');

      // Load JSON file
      final jsonString = await rootBundle.loadString('assets/churches_SAB.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final regionsData = jsonData['regions'] as Map<String, dynamic>;

      print('  Found ${regionsData.length} regions in JSON');

      int regionsCreated = 0;
      int regionsUpdated = 0;
      int districtsCreated = 0;
      int churchesCreated = 0;

      // Process each region
      for (var entry in regionsData.entries) {
        final regionNumber = entry.key;
        final regionInfo = entry.value as Map<String, dynamic>;
        final regionName = regionInfo['name'] as String;

        print('\n  Processing $regionName...');

        // Try to find existing region by name and mission
        final existingRegions = await _firestore
            .collection('regions')
            .where('name', isEqualTo: regionName)
            .where('missionId', isEqualTo: sabahMissionId)
            .limit(1)
            .get();

        String regionId;
        bool regionExists = false;

        if (existingRegions.docs.isNotEmpty) {
          // Use existing region ID
          regionId = existingRegions.docs.first.id;
          regionExists = true;
          print('    ✓ Found existing region: $regionName (ID: $regionId)');
        } else {
          // Create new region ID
          regionId = 'sabah_region_$regionNumber';
          print('    ✓ Creating new region: $regionName (ID: $regionId)');
        }

        final region = Region(
          id: regionId,
          name: regionName,
          code: 'R$regionNumber',
          missionId: sabahMissionId,
          createdBy: userId,
          createdAt: regionExists
              ? (existingRegions.docs.first.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
              : DateTime.now(),
        );

        if (regionExists) {
          await _firestore.collection('regions').doc(regionId).update(region.toMap());
          regionsUpdated++;
        } else {
          await _firestore.collection('regions').doc(regionId).set(region.toMap());
          regionsCreated++;
        }

        // Process districts
        final pastoralDistricts = regionInfo['pastoral_districts'] as Map<String, dynamic>?;
        if (pastoralDistricts != null) {
          for (var districtEntry in pastoralDistricts.entries) {
            final districtKey = districtEntry.key;
            final districtData = districtEntry.value as Map<String, dynamic>;

            // Create district name from key (e.g., GAUR -> Gaur)
            final districtName = _formatDistrictName(districtKey);

            // Try to find existing district by name and region
            final existingDistricts = await _firestore
                .collection('districts')
                .where('name', isEqualTo: districtName)
                .where('regionId', isEqualTo: regionId)
                .limit(1)
                .get();

            String districtId;
            bool districtExists = false;

            if (existingDistricts.docs.isNotEmpty) {
              // Use existing district ID
              districtId = existingDistricts.docs.first.id;
              districtExists = true;
              print('      ✓ Found existing district: $districtName (ID: $districtId)');
            } else {
              // Create new district ID
              districtId = '${regionId}_${districtKey.toLowerCase()}';
              districtExists = false;
              print('      ✓ Creating new district: $districtName (ID: $districtId)');
            }

            final district = District(
              id: districtId,
              name: districtName,
              code: districtKey,
              regionId: regionId,
              missionId: sabahMissionId,
              createdBy: userId,
              createdAt: districtExists
                  ? (existingDistricts.docs.first.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
                  : DateTime.now(),
            );

            if (districtExists) {
              await _firestore.collection('districts').doc(districtId).update(district.toMap());
            } else {
              await _firestore.collection('districts').doc(districtId).set(district.toMap());
              districtsCreated++;
            }

            // Process churches (organized_churches, companies, groups)
            int districtChurchCount = 0;

            // Organized churches
            final organizedChurches = districtData['organized_churches'] as List?;
            if (organizedChurches != null) {
              for (var churchData in organizedChurches) {
                final churchInfo = churchData as Map<String, dynamic>;
                await _createChurch(
                  churchName: churchInfo['name'] as String,
                  districtId: districtId,
                  regionId: regionId,
                  missionId: sabahMissionId,
                  userId: userId,
                  status: ChurchStatus.organizedChurch,
                );
                districtChurchCount++;
              }
            }

            // Companies
            final companies = districtData['companies'] as List?;
            if (companies != null) {
              for (var churchData in companies) {
                final churchInfo = churchData as Map<String, dynamic>;
                await _createChurch(
                  churchName: churchInfo['name'] as String,
                  districtId: districtId,
                  regionId: regionId,
                  missionId: sabahMissionId,
                  userId: userId,
                  status: ChurchStatus.company,
                );
                districtChurchCount++;
              }
            }

            // Groups
            final groups = districtData['groups'] as List?;
            if (groups != null) {
              for (var churchData in groups) {
                final churchInfo = churchData as Map<String, dynamic>;
                await _createChurch(
                  churchName: churchInfo['name'] as String,
                  districtId: districtId,
                  regionId: regionId,
                  missionId: sabahMissionId,
                  userId: userId,
                  status: ChurchStatus.group,
                );
                districtChurchCount++;
              }
            }

            churchesCreated += districtChurchCount;
            if (districtChurchCount > 0) {
              print('        ✓ Created $districtChurchCount churches in $districtName');
            }
          }
        }
      }

      print('\n  Restoration complete!');
      print('  Regions created: $regionsCreated, updated: $regionsUpdated');
      print('  Districts created: $districtsCreated');
      print('  Churches created: $churchesCreated');

      return {
        'success': true,
        'message': 'Restoration completed successfully',
        'regionsCreated': regionsCreated,
        'regionsUpdated': regionsUpdated,
        'districtsCreated': districtsCreated,
        'churchesCreated': churchesCreated,
      };
    } catch (e) {
      print('RestorationService ERROR: $e');
      return {
        'success': false,
        'message': 'Error during restoration: $e',
      };
    }
  }

  Future<void> _createChurch({
    required String churchName,
    required String districtId,
    required String regionId,
    required String missionId,
    required String userId,
    required ChurchStatus status,
  }) async {
    // Try to find existing church by name in this mission
    final existingChurches = await _firestore
        .collection('churches')
        .where('churchName', isEqualTo: churchName)
        .where('missionId', isEqualTo: missionId)
        .limit(1)
        .get();

    DocumentSnapshot? existingChurch;
    String churchId;

    if (existingChurches.docs.isNotEmpty) {
      // Found existing church - use its ID
      existingChurch = existingChurches.docs.first;
      churchId = existingChurch.id;

      print('    → Updating existing church: $churchName (ID: $churchId)');

      // Update the existing church with correct district/region
      await _firestore.collection('churches').doc(churchId).update({
        'districtId': districtId,
        'regionId': regionId,
        'missionId': missionId,
        'status': status.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } else {
      // Church doesn't exist - create new one
      churchId = '${districtId}_${_sanitizeId(churchName)}';

      print('    → Creating new church: $churchName (ID: $churchId)');

      await _firestore.collection('churches').doc(churchId).set({
        'id': churchId,
        'userId': userId,
        'churchName': churchName,
        'elderName': 'TBD',
        'elderEmail': '',
        'elderPhone': '',
        'status': status.name,
        'districtId': districtId,
        'regionId': regionId,
        'missionId': missionId,
        'address': null,
        'memberCount': null,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': null,
        'treasurerId': null,
      });
    }
  }

  String _formatDistrictName(String key) {
    // Convert GAUR to Gaur, KOTA_KINABALU_CITY to Kota Kinabalu City
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  String _sanitizeId(String name) {
    // Create a safe ID from name (remove special chars, spaces, etc.)
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
