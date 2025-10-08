import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:uuid/uuid.dart';

class TestRegionsHelper {
  static const uuid = Uuid();
  static final RegionService _regionService = RegionService.instance;
  static final MissionService _missionService = MissionService();

  /// Check if any regions exist in the database
  static Future<void> checkRegions() async {
    try {
      print('=== CHECKING REGIONS IN DATABASE ===');

      // Get all regions directly from Firestore
      final snapshot =
          await FirebaseFirestore.instance.collection('regions').get();

      print('Total regions in database: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print('No regions found in database');
        await _createSampleRegions();
      } else {
        print('Found regions:');
        for (var doc in snapshot.docs) {
          final data = doc.data();
          print('  - ID: ${doc.id}');
          print('    Name: ${data['name']}');
          print('    Code: ${data['code']}');
          print('    MissionId: ${data['missionId'] ?? data['mission']}');
          print('    Created: ${data['createdAt']}');
          print('    ---');
        }
      }
    } catch (e) {
      print('ERROR checking regions: $e');
    }
  }

  /// Create sample regions for testing
  static Future<void> _createSampleRegions() async {
    try {
      print('=== CREATING SAMPLE REGIONS ===');

      // Get available missions first
      final missions = await _missionService.getAllMissions();
      if (missions.isEmpty) {
        print('No missions found! Cannot create regions without missions.');
        return;
      }

      final firstMission = missions.first;
      print('Using mission: ${firstMission.name} (ID: ${firstMission.id})');

      // Sample regions data
      final sampleRegions = [
        {'name': 'Region 1', 'code': 'R001'},
        {'name': 'Region 2', 'code': 'R002'},
        {'name': 'Region 3', 'code': 'R003'},
        {'name': 'Region 4', 'code': 'R004'},
        {'name': 'Region 5', 'code': 'R005'},
      ];

      print('Creating ${sampleRegions.length} sample regions...');

      for (var regionData in sampleRegions) {
        final region = Region(
          id: uuid.v4(),
          name: regionData['name']!,
          code: regionData['code']!,
          missionId: firstMission.id,
          createdAt: DateTime.now(),
          createdBy: 'system-test',
        );

        await _regionService.createRegion(region);
        print('Created region: ${region.name} (${region.code})');
      }

      print('Sample regions created successfully!');
    } catch (e) {
      print('ERROR creating sample regions: $e');
    }
  }

  /// Check what missions exist
  static Future<void> checkMissions() async {
    try {
      print('=== CHECKING MISSIONS IN DATABASE ===');

      final missions = await _missionService.getAllMissions();
      print('Total missions: ${missions.length}');

      if (missions.isEmpty) {
        print('No missions found in database');
      } else {
        print('Found missions:');
        for (var mission in missions) {
          print('  - ID: ${mission.id}');
          print('    Name: ${mission.name}');
          print('    Code: ${mission.code}');
          print('    ---');
        }
      }
    } catch (e) {
      print('ERROR checking missions: $e');
    }
  }

  /// Complete debug check
  static Future<void> debugCheck() async {
    print('\n🔍 === REGION MANAGEMENT DEBUG CHECK ===');
    await checkMissions();
    print('');
    await checkRegions();
    print('🔍 === DEBUG CHECK COMPLETE ===\n');
  }
}
