import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

class Region {
  final String id;
  final String name;
  final String missionId;
  final DateTime createdAt;

  Region({
    required this.id,
    required this.name,
    required this.missionId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'missionId': missionId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class District {
  final String id;
  final String name;
  final String regionId;
  final String missionId;
  final String? pastorName;
  final String? pastorPhone;
  final DateTime createdAt;

  District({
    required this.id,
    required this.name,
    required this.regionId,
    required this.missionId,
    this.pastorName,
    this.pastorPhone,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'regionId': regionId,
      'missionId': missionId,
      'pastorName': pastorName,
      'pastorPhone': pastorPhone,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

enum ChurchStatus {
  organizedChurch,
  company,
  group,
}

class Church {
  final String id;
  final String userId;
  final String churchName;
  final String elderName;
  final ChurchStatus status;
  final String elderEmail;
  final String elderPhone;
  final String? address;
  final int? memberCount;
  final DateTime createdAt;
  final String? districtId;
  final String? regionId;
  final String? missionId;

  Church({
    required this.id,
    required this.userId,
    required this.churchName,
    required this.elderName,
    required this.status,
    required this.elderEmail,
    required this.elderPhone,
    this.address,
    this.memberCount,
    required this.createdAt,
    this.districtId,
    this.regionId,
    this.missionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'churchName': churchName,
      'elderName': elderName,
      'status': status.name,
      'elderEmail': elderEmail,
      'elderPhone': elderPhone,
      'address': address,
      'memberCount': memberCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'districtId': districtId,
      'regionId': regionId,
      'missionId': missionId,
    };
  }
}

Future<void> main() async {
  print('Initializing Firebase...');
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyB1Z7SAsV8g5UcnZMLJmtj4UZfMzA7juRk',
      appId: '1:695678872591:web:0cd71e5809edd908f4c77a',
      messagingSenderId: '695678872591',
      projectId: 'pastor-report-e4c52',
      authDomain: 'pastor-report-e4c52.firebaseapp.com',
      storageBucket: 'pastor-report-e4c52.firebasestorage.app',
      measurementId: 'G-F9KBEM9XGJ',
    ),
  );

  const String missionId = '4LFC9isp22H7Og1FHBm6'; // Sabah Mission Firestore ID

  int regionsCreated = 0;
  int districtsCreated = 0;
  int churchesCreated = 0;
  int churchesDeleted = 0;

  try {
    print('Loading JSON data...');
    final String jsonFilePath = 'assets/churches_SAB.json';
    final File jsonFile = File(jsonFilePath);
    final String jsonString = await jsonFile.readAsString();
    final Map<String, dynamic> jsonData = json.decode(jsonString);

    // STEP 1: Delete all existing churches for this mission
    print('Deleting existing churches for Sabah Mission...');
    final churchQuery = await FirebaseFirestore.instance
        .collection('churches')
        .where('missionId', isEqualTo: missionId)
        .get();

    for (var doc in churchQuery.docs) {
      await doc.reference.delete();
      churchesDeleted++;
    }
    print('Deleted $churchesDeleted existing churches');

    // STEP 2: Delete all existing districts for this mission
    print('Deleting existing districts for Sabah Mission...');
    final districtQuery = await FirebaseFirestore.instance
        .collection('districts')
        .where('missionId', isEqualTo: missionId)
        .get();

    for (var doc in districtQuery.docs) {
      await doc.reference.delete();
    }
    print('Deleted ${districtQuery.docs.length} existing districts');

    // STEP 3: Delete all existing regions for this mission
    print('Deleting existing regions for Sabah Mission...');
    final regionQuery = await FirebaseFirestore.instance
        .collection('regions')
        .where('missionId', isEqualTo: missionId)
        .get();

    for (var doc in regionQuery.docs) {
      await doc.reference.delete();
    }
    print('Deleted ${regionQuery.docs.length} existing regions');

    // STEP 4: Import regions and districts from JSON
    if (jsonData.containsKey('regions')) {
      final regions = jsonData['regions'] as Map<String, dynamic>;

      for (var regionEntry in regions.entries) {
        final regionData = regionEntry.value as Map<String, dynamic>;
        final regionName = regionData['name'] as String;

        // Create region
        final region = Region(
          id: const Uuid().v4(),
          name: regionName,
          missionId: missionId,
          createdAt: DateTime.now(),
        );

        await FirebaseFirestore.instance
            .collection('regions')
            .doc(region.id)
            .set(region.toMap());
        regionsCreated++;
        print('Created region: $regionName');

        // Process districts within this region
        if (regionData.containsKey('pastoral_districts')) {
          final pastoralDistricts =
              regionData['pastoral_districts'] as Map<String, dynamic>;

          for (var districtEntry in pastoralDistricts.entries) {
            final districtName = districtEntry.key;
            final districtData = districtEntry.value as Map<String, dynamic>;

            // Create district
            final district = District(
              id: const Uuid().v4(),
              name: districtName,
              regionId: region.id,
              missionId: missionId,
              pastorName: districtData['pastor'] as String?,
              pastorPhone: districtData['phone'] as String?,
              createdAt: DateTime.now(),
            );

            await FirebaseFirestore.instance
                .collection('districts')
                .doc(district.id)
                .set(district.toMap());
            districtsCreated++;
            print('Created district: $districtName in $regionName');

            // Process churches within this district
            final churches = <Map<String, dynamic>>[];

            // Add organized churches
            if (districtData.containsKey('organized_churches')) {
              final organizedChurches =
                  districtData['organized_churches'] as List<dynamic>;
              for (var church in organizedChurches) {
                if (church is Map<String, dynamic> &&
                    church.containsKey('name')) {
                  churches.add({
                    'name': church['name'] as String,
                    'type': 'organized_church',
                    'doc': church['doc'] as String?,
                  });
                } else if (church is String) {
                  churches.add({
                    'name': church,
                    'type': 'organized_church',
                    'doc': null,
                  });
                }
              }
            }

            // Add companies
            if (districtData.containsKey('companies')) {
              final companyList = districtData['companies'] as List<dynamic>;
              for (var company in companyList) {
                if (company is Map<String, dynamic> &&
                    company.containsKey('name')) {
                  churches.add({
                    'name': company['name'] as String,
                    'type': 'company',
                    'doc': company['doc'] as String?,
                  });
                } else if (company is String) {
                  churches.add({
                    'name': company,
                    'type': 'company',
                    'doc': null,
                  });
                }
              }
            }

            // Add groups
            if (districtData.containsKey('groups')) {
              final groupList = districtData['groups'] as List<dynamic>;
              for (var group in groupList) {
                if (group is Map<String, dynamic> &&
                    group.containsKey('name')) {
                  churches.add({
                    'name': group['name'] as String,
                    'type': 'group',
                    'doc': group['doc'] as String?,
                  });
                } else if (group is String) {
                  churches.add({
                    'name': group,
                    'type': 'group',
                    'doc': null,
                  });
                }
              }
            }

            // Create church records
            for (var churchData in churches) {
              final churchStatus =
                  _getChurchStatusFromType(churchData['type'] as String);

              final church = Church(
                id: const Uuid().v4(),
                userId: '', // Will be assigned later when pastors are linked
                churchName: churchData['name'] as String,
                elderName: district.pastorName ?? 'Unknown',
                status: churchStatus,
                elderEmail: '',
                elderPhone: district.pastorPhone ?? '',
                address: '$districtName, $regionName, Sabah',
                memberCount: null,
                createdAt: DateTime.now(),
                districtId: district.id,
                regionId: region.id,
                missionId: missionId,
              );

              await FirebaseFirestore.instance
                  .collection('churches')
                  .doc(church.id)
                  .set(church.toMap());
              churchesCreated++;
            }

            print(
                'Created ${churches.length} churches/companies/groups in $districtName');
          }
        }
      }
    }

    print('\n🎉 Import completed successfully!');
    print('📊 Summary:');
    print('   • Regions created: $regionsCreated');
    print('   • Districts created: $districtsCreated');
    print('   • Churches created: $churchesCreated');
    print('   • Churches deleted: $churchesDeleted');
    print(
        '   • Total imported: ${regionsCreated + districtsCreated + churchesCreated}');
  } catch (e) {
    print('❌ Error during import: $e');
    exit(1);
  }
}

ChurchStatus _getChurchStatusFromType(String type) {
  switch (type) {
    case 'organized_church':
      return ChurchStatus.organizedChurch;
    case 'company':
      return ChurchStatus.company;
    case 'group':
      return ChurchStatus.group;
    default:
      return ChurchStatus.organizedChurch;
  }
}
