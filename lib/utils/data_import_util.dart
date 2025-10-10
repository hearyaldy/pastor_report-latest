// lib/utils/data_import_util.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';

class DataImportUtil {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final ChurchService _churchService = ChurchService.instance;
  static final Uuid _uuid = Uuid();

  /// Import North Sabah Mission churches from the updated JSON file
  static Future<Map<String, dynamic>> importNSMChurches(
      BuildContext context) async {
    try {
      print('DataImportUtil: Starting NSM Churches import...');
      
      // Load the JSON file
      print('DataImportUtil: Loading NSM_Churches_Updated.json');
      final jsonString =
          await rootBundle.loadString('assets/NSM_Churches_Updated.json');
      print('DataImportUtil: JSON file loaded successfully. Length: ${jsonString.length}');
      
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      print('DataImportUtil: JSON parsed successfully');

      // Summary data for tracking
      final summary = {
        'total': 0,
        'created': 0,
        'updated': 0,
        'errors': 0,
        'details': <String>[],
      };

      // Get the mission ID for North Sabah Mission
      const missionId =
          "North Sabah Mission"; // Update this if your ID is different

      // Access the regions in the JSON
      print('DataImportUtil: Accessing regions from JSON data');
      final regions = jsonData['regions'] as Map<String, dynamic>;
      print('DataImportUtil: Found ${regions.length} regions to process');

      // Process each region
      for (final regionEntry in regions.entries) {
        final regionId = regionEntry.key;
        final regionData = regionEntry.value as Map<String, dynamic>;
        final regionName = regionData['name'] as String;
        print('DataImportUtil: Processing region $regionId: $regionName');

        // Process each district in the region
        print('DataImportUtil: Getting pastoral_districts for region $regionId');
        final districts =
            regionData['pastoral_districts'] as Map<String, dynamic>;
        print('DataImportUtil: Found ${districts.length} districts in region $regionId');
        
        for (final districtEntry in districts.entries) {
          final districtId = districtEntry.key;
          final districtData = districtEntry.value as Map<String, dynamic>;
          print('DataImportUtil: Processing district $districtId in region $regionId');

          // Process organized churches
          await _processChurches(
            districtData['organized_churches'] as List<dynamic>? ?? [],
            ChurchStatus.organizedChurch,
            regionId,
            regionName,
            districtId,
            missionId,
            summary,
          );

          // Process companies
          await _processChurches(
            districtData['companies'] as List<dynamic>? ?? [],
            ChurchStatus.company,
            regionId,
            regionName,
            districtId,
            missionId,
            summary,
          );

          // Process groups
          await _processChurches(
            districtData['groups'] as List<dynamic>? ?? [],
            ChurchStatus.group,
            regionId,
            regionName,
            districtId,
            missionId,
            summary,
          );
        }
      }

      return summary;
    } catch (e, stackTrace) {
      print('ERROR importing NSM churches: $e');
      print('Stack trace: $stackTrace');
      return {
        'total': 0,
        'created': 0,
        'updated': 0,
        'errors': 1,
        'details': ['Error: $e', 'StackTrace: $stackTrace'],
      };
    }
  }

  /// Process a list of churches for a specific status
  static Future<void> _processChurches(
    List<dynamic> churches,
    ChurchStatus status,
    String regionId,
    String
        regionName, // This parameter is used for logging but not in Church constructor
    String districtId,
    String missionId,
    Map<String, dynamic> summary,
  ) async {
    print('DataImportUtil: Processing ${churches.length} churches with status ${status.name} in district $districtId, region $regionId');
    
    for (final churchData in churches) {
      final churchName = churchData['name'] as String;
      summary['total'] = summary['total'] + 1;
      print('DataImportUtil: Processing church: $churchName');

      try {
        // Check if the church already exists
        print('DataImportUtil: Checking if church "$churchName" already exists in district "$districtId"');
        final existingChurches = await _firestore
            .collection('churches')
            .where('churchName', isEqualTo: churchName)
            .where('districtId', isEqualTo: districtId)
            .get();
        print('DataImportUtil: Found ${existingChurches.docs.length} existing churches matching "$churchName" in district "$districtId"');

        if (existingChurches.docs.isNotEmpty) {
          // Update existing church
          final existingChurch = existingChurches.docs.first;
          final churchId = existingChurch.id;

          await _firestore.collection('churches').doc(churchId).update({
            'churchName': churchName,
            'regionId': regionId,
            // Remove regionName as it's not a field in the Church model
            'districtId': districtId,
            'missionId': missionId,
            'status': status.toString().split('.').last,
            'updatedAt': DateTime.now().toIso8601String(),
          });

          summary['updated'] = summary['updated'] + 1;
          summary['details'].add('Updated: $churchName');
        } else {
          // Create new church
          final churchId = _uuid.v4();
          final church = Church(
            id: churchId,
            churchName: churchName,
            // Required fields with default values for new church
            userId: 'system_import', // Using a placeholder user ID
            elderName: 'To be assigned',
            elderEmail: 'placeholder@example.com',
            elderPhone: '000-000-0000',
            regionId: regionId,
            districtId: districtId,
            missionId: missionId,
            status: status,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _churchService.createChurch(church);

          summary['created'] = summary['created'] + 1;
          summary['details'].add('Created: $churchName');
        }
      } catch (e, stackTrace) {
        print('ERROR processing church $churchName: $e');
        print('Stack trace: $stackTrace');
        summary['errors'] = summary['errors'] + 1;
        summary['details'].add('Error with $churchName: $e');
      }
    }
  }
}
