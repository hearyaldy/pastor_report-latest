import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';

void main() async {
  print('🚀 Starting mock data generation...');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;

  // Mission
  const missionId = 'mission_sabah';
  const missionName = 'Sabah Mission';

  print('📝 Creating mission...');
  await firestore.collection('missions').doc(missionId).set({
    'id': missionId,
    'name': missionName,
    'code': 'SBH',
    'createdAt': FieldValue.serverTimestamp(),
  });

  // Create 3 Regions
  final regions = [
    {'id': 'region_north', 'name': 'North Sabah', 'code': 'NSB'},
    {'id': 'region_west', 'name': 'West Coast', 'code': 'WST'},
    {'id': 'region_east', 'name': 'East Coast', 'code': 'EST'},
  ];

  print('🌍 Creating ${regions.length} regions...');
  for (var region in regions) {
    await firestore.collection('regions').doc(region['id']).set({
      'id': region['id'],
      'name': region['name'],
      'code': region['code'],
      'missionId': missionId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': 'system',
    });
  }

  // Create 2 Districts per Region (6 total)
  final districts = [
    {'id': 'dist_kk1', 'name': 'Kota Kinabalu 1', 'code': 'KK1', 'regionId': 'region_north'},
    {'id': 'dist_kk2', 'name': 'Kota Kinabalu 2', 'code': 'KK2', 'regionId': 'region_north'},
    {'id': 'dist_papar', 'name': 'Papar District', 'code': 'PPR', 'regionId': 'region_west'},
    {'id': 'dist_beaufort', 'name': 'Beaufort District', 'code': 'BFT', 'regionId': 'region_west'},
    {'id': 'dist_sandakan', 'name': 'Sandakan District', 'code': 'SDK', 'regionId': 'region_east'},
    {'id': 'dist_tawau', 'name': 'Tawau District', 'code': 'TWU', 'regionId': 'region_east'},
  ];

  print('🏘️ Creating ${districts.length} districts...');
  for (var district in districts) {
    await firestore.collection('districts').doc(district['id']).set({
      'id': district['id'],
      'name': district['name'],
      'code': district['code'],
      'regionId': district['regionId'],
      'missionId': missionId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': 'system',
    });
  }

  // Create 3-5 Churches per District (25 total)
  final churches = [
    // North Region - KK1
    {'id': 'ch_kk_central', 'name': 'KK Central Church', 'districtId': 'dist_kk1', 'regionId': 'region_north', 'members': 250},
    {'id': 'ch_kk_penampang', 'name': 'Penampang Church', 'districtId': 'dist_kk1', 'regionId': 'region_north', 'members': 180},
    {'id': 'ch_kk_inanam', 'name': 'Inanam Church', 'districtId': 'dist_kk1', 'regionId': 'region_north', 'members': 120},
    // North Region - KK2
    {'id': 'ch_kk_luyang', 'name': 'Luyang Church', 'districtId': 'dist_kk2', 'regionId': 'region_north', 'members': 200},
    {'id': 'ch_kk_putatan', 'name': 'Putatan Church', 'districtId': 'dist_kk2', 'regionId': 'region_north', 'members': 150},
    {'id': 'ch_kk_kota_belud', 'name': 'Kota Belud Church', 'districtId': 'dist_kk2', 'regionId': 'region_north', 'members': 95},
    // West Coast - Papar
    {'id': 'ch_papar_town', 'name': 'Papar Town Church', 'districtId': 'dist_papar', 'regionId': 'region_west', 'members': 130},
    {'id': 'ch_papar_kinarut', 'name': 'Kinarut Church', 'districtId': 'dist_papar', 'regionId': 'region_west', 'members': 85},
    {'id': 'ch_papar_kimanis', 'name': 'Kimanis Church', 'districtId': 'dist_papar', 'regionId': 'region_west', 'members': 70},
    {'id': 'ch_papar_membakut', 'name': 'Membakut Church', 'districtId': 'dist_papar', 'regionId': 'region_west', 'members': 60},
    // West Coast - Beaufort
    {'id': 'ch_beaufort_town', 'name': 'Beaufort Church', 'districtId': 'dist_beaufort', 'regionId': 'region_west', 'members': 110},
    {'id': 'ch_beaufort_sipitang', 'name': 'Sipitang Church', 'districtId': 'dist_beaufort', 'regionId': 'region_west', 'members': 90},
    {'id': 'ch_beaufort_kuala_penyu', 'name': 'Kuala Penyu Church', 'districtId': 'dist_beaufort', 'regionId': 'region_west', 'members': 55},
    // East Coast - Sandakan
    {'id': 'ch_sandakan_central', 'name': 'Sandakan Central Church', 'districtId': 'dist_sandakan', 'regionId': 'region_east', 'members': 220},
    {'id': 'ch_sandakan_batu_sapi', 'name': 'Batu Sapi Church', 'districtId': 'dist_sandakan', 'regionId': 'region_east', 'members': 140},
    {'id': 'ch_sandakan_libaran', 'name': 'Libaran Church', 'districtId': 'dist_sandakan', 'regionId': 'region_east', 'members': 75},
    {'id': 'ch_sandakan_kinabatangan', 'name': 'Kinabatangan Church', 'districtId': 'dist_sandakan', 'regionId': 'region_east', 'members': 65},
    // East Coast - Tawau
    {'id': 'ch_tawau_central', 'name': 'Tawau Central Church', 'districtId': 'dist_tawau', 'regionId': 'region_east', 'members': 190},
    {'id': 'ch_tawau_semporna', 'name': 'Semporna Church', 'districtId': 'dist_tawau', 'regionId': 'region_east', 'members': 160},
    {'id': 'ch_tawau_lahad_datu', 'name': 'Lahad Datu Church', 'districtId': 'dist_tawau', 'regionId': 'region_east', 'members': 145},
    {'id': 'ch_tawau_kunak', 'name': 'Kunak Church', 'districtId': 'dist_tawau', 'regionId': 'region_east', 'members': 80},
  ];

  print('⛪ Creating ${churches.length} churches...');
  for (var church in churches) {
    await firestore.collection('churches').doc(church['id']).set({
      'id': church['id'],
      'churchName': church['name'],
      'districtId': church['districtId'],
      'regionId': church['regionId'],
      'missionId': missionId,
      'userId': 'system',
      'elderName': 'Elder ${church['name']!.split(' ')[0]}',
      'elderEmail': 'elder@${church['id']}.com',
      'elderPhone': '+60123456789',
      'status': 'church',
      'memberCount': church['members'],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Create Staff (20 staff members)
  final staff = [
    {'name': 'Pastor John Lim', 'position': 'Senior Pastor', 'department': 'Administration'},
    {'name': 'Pastor Mary Tan', 'position': 'Associate Pastor', 'department': 'Youth Ministry'},
    {'name': 'Elder David Wong', 'position': 'Elder', 'department': 'Sabbath School'},
    {'name': 'Deacon Peter Lee', 'position': 'Deacon', 'department': 'Community Services'},
    {'name': 'Pastor Sarah Chen', 'position': 'District Pastor', 'department': 'Evangelism'},
    {'name': 'Pastor James Koh', 'position': 'District Pastor', 'department': 'Personal Ministries'},
    {'name': 'Elder Rebecca Ng', 'position': 'Elder', 'department': "Women's Ministries"},
    {'name': 'Pastor Michael Yap', 'position': 'Youth Pastor', 'department': 'Youth Ministry'},
    {'name': 'Deaconess Lisa Tan', 'position': 'Deaconess', 'department': 'Health Ministries'},
    {'name': 'Pastor Daniel Chia', 'position': 'District Pastor', 'department': 'Stewardship'},
    {'name': 'Elder Grace Lim', 'position': 'Elder', 'department': 'Family Ministries'},
    {'name': 'Pastor Timothy Goh', 'position': 'Associate Pastor', 'department': 'Publishing'},
    {'name': 'Deacon Samuel Lee', 'position': 'Deacon', 'department': 'Communication'},
    {'name': 'Pastor Ruth Wong', 'position': 'District Pastor', 'department': "Children's Ministries"},
    {'name': 'Elder Benjamin Tan', 'position': 'Elder', 'department': 'Education'},
  ];

  print('👥 Creating ${staff.length} staff members...');
  int staffIndex = 0;
  for (var person in staff) {
    staffIndex++;
    await firestore.collection('staff').doc('staff_$staffIndex').set({
      'id': 'staff_$staffIndex',
      'name': person['name'],
      'position': person['position'],
      'department': person['department'],
      'mission': missionName,
      'email': '${person['name']!.toLowerCase().replaceAll(' ', '.')}@sabah.mission',
      'phone': '+601${2000000 + staffIndex}',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Create Financial Reports for current month (sample data)
  print('💰 Creating sample financial reports...');
  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month, 1);

  int reportCount = 0;
  for (var church in churches) {
    reportCount++;
    final tithe = (church['members'] as int) * (100 + (reportCount * 5)).toDouble();
    final offerings = (church['members'] as int) * (50 + (reportCount * 3)).toDouble();

    await firestore.collection('financial_reports').doc('report_${church['id']}_${now.month}').set({
      'id': 'report_${church['id']}_${now.month}',
      'churchId': church['id'],
      'districtId': church['districtId'],
      'regionId': church['regionId'],
      'missionId': missionId,
      'month': Timestamp.fromDate(currentMonth),
      'year': now.year,
      'tithe': tithe,
      'offerings': offerings,
      'specialOfferings': (reportCount * 100).toDouble(),
      'submittedBy': 'system',
      'submittedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'submitted',
    });
  }

  print('✅ Mock data created successfully!');
  print('📊 Summary:');
  print('  - 1 Mission: $missionName');
  print('  - ${regions.length} Regions');
  print('  - ${districts.length} Districts');
  print('  - ${churches.length} Churches');
  print('  - ${churches.fold(0, (sum, c) => sum + (c['members'] as int))} Total Members');
  print('  - ${staff.length} Staff Members');
  print('  - $reportCount Financial Reports');
  print('');
  print('🎉 Done! Refresh your app to see the data.');
}
