import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

const String missionId = 'north_sabah_mission';
const String missionName = 'North Sabah Mission';

Future<void> main() async {
  print('🚀 Uploading North Sabah Mission Churches...\n');

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    final db = FirebaseFirestore.instance;

    // Read the NSM Churches data
    final file = File('assets/NSM_Churches_Updated.json');
    final jsonString = await file.readAsString();
    final nsmData = json.decode(jsonString) as Map<String, dynamic>;

    // Step 1: Ensure mission exists
    print('📋 Step 1: Checking/Creating Mission...');
    final missionRef = db.collection('missions').doc(missionId);
    final missionDoc = await missionRef.get();

    if (!missionDoc.exists) {
      await missionRef.set({
        'id': missionId,
        'name': missionName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('  ✓ Created mission: $missionName');
    } else {
      print('  ✓ Mission exists: $missionName');
    }

    int totalRegions = 0;
    int totalDistricts = 0;
    int totalChurches = 0;
    int totalCompanies = 0;
    int totalGroups = 0;

    // Step 2: Process each region
    print('\n📋 Step 2: Processing Regions and Districts...\n');

    final regions = nsmData['regions'] as Map<String, dynamic>;

    for (var regionEntry in regions.entries) {
      final regionNum = regionEntry.key;
      final regionData = regionEntry.value as Map<String, dynamic>;
      final regionId = 'nsm_region_$regionNum';
      final regionName = regionData['name'] as String;

      // Create/Update region
      await db.collection('regions').doc(regionId).set({
        'id': regionId,
        'name': regionName,
        'missionId': missionId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✓ Region: $regionName');
      totalRegions++;

      // Process pastoral districts
      final pastoralDistricts =
          regionData['pastoral_districts'] as Map<String, dynamic>;

      for (var districtEntry in pastoralDistricts.entries) {
        final districtName = districtEntry.key;
        final districtData = districtEntry.value as Map<String, dynamic>;
        final districtId =
            'nsm_district_${regionNum}_${districtName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';

        // Create/Update district
        await db.collection('districts').doc(districtId).set({
          'id': districtId,
          'name': districtName,
          'regionId': regionId,
          'missionId': missionId,
          'pastor': districtData['pastor'] ?? '',
          'phone': districtData['phone'] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print(
            '  ✓ District: $districtName (Pastor: ${districtData['pastor'] ?? 'TBD'})');
        totalDistricts++;

        // Process organized churches
        final organizedChurches =
            districtData['organized_churches'] as List<dynamic>? ?? [];
        for (var church in organizedChurches) {
          final churchMap = church as Map<String, dynamic>;
          final churchName = churchMap['name'] as String;
          final churchId =
              'nsm_church_${districtId}_${churchName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';

          await db.collection('churches').doc(churchId).set({
            'id': churchId,
            'churchName': churchName,
            'districtId': districtId,
            'regionId': regionId,
            'missionId': missionId,
            'status': 'church',
            'userId': 'system',
            'elderName': '',
            'elderEmail': '',
            'elderPhone': '',
            'memberCount': 0,
            'dateOrganized': churchMap['doc'],
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          print('    ⛪ Church: $churchName');
          totalChurches++;
        }

        // Process companies
        final companies = districtData['companies'] as List<dynamic>? ?? [];
        for (var company in companies) {
          final companyMap = company as Map<String, dynamic>;
          final companyName = companyMap['name'] as String;
          final companyId =
              'nsm_company_${districtId}_${companyName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';

          await db.collection('churches').doc(companyId).set({
            'id': companyId,
            'churchName': companyName,
            'districtId': districtId,
            'regionId': regionId,
            'missionId': missionId,
            'status': 'company',
            'userId': 'system',
            'elderName': '',
            'elderEmail': '',
            'elderPhone': '',
            'memberCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          print('    🏢 Company: $companyName');
          totalCompanies++;
        }

        // Process groups
        final groups = districtData['groups'] as List<dynamic>? ?? [];
        for (var group in groups) {
          final groupMap = group as Map<String, dynamic>;
          final groupName = groupMap['name'] as String;
          final groupId =
              'nsm_group_${districtId}_${groupName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';

          await db.collection('churches').doc(groupId).set({
            'id': groupId,
            'churchName': groupName,
            'districtId': districtId,
            'regionId': regionId,
            'missionId': missionId,
            'status': 'group',
            'userId': 'system',
            'elderName': '',
            'elderEmail': '',
            'elderPhone': '',
            'memberCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          print('    👥 Group: $groupName');
          totalGroups++;
        }
      }

      print('');
    }

    // Summary
    print('\n${'=' * 60}');
    print('📊 UPLOAD SUMMARY');
    print('=' * 60);
    print('✅ Mission: $missionName');
    print('✅ Regions: $totalRegions');
    print('✅ Districts: $totalDistricts');
    print('⛪ Organized Churches: $totalChurches');
    print('🏢 Companies: $totalCompanies');
    print('👥 Groups: $totalGroups');
    print('📈 Total Congregations: ${totalChurches + totalCompanies + totalGroups}');
    print('=' * 60);

    print(
        '\n🎉 Upload complete! Check your Firebase console to verify the data.');
  } catch (error) {
    print('\n❌ Error: $error');
    exit(1);
  }

  exit(0);
}
