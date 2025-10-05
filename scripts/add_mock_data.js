const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const missionId = 'mission_sabah';
const missionName = 'Sabah Mission';

async function addMockData() {
  console.log('🚀 Starting mock data generation...');

  // Add Regions
  const regions = [
    { id: 'region_north', name: 'North Sabah', code: 'NSB' },
    { id: 'region_west', name: 'West Coast', code: 'WST' },
    { id: 'region_east', name: 'East Coast', code: 'EST' },
  ];

  console.log(`🌍 Creating ${regions.length} regions...`);
  for (const region of regions) {
    await db.collection('regions').doc(region.id).set({
      ...region,
      missionId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: 'system',
    });
  }

  // Add Districts
  const districts = [
    { id: 'dist_kk1', name: 'Kota Kinabalu 1', code: 'KK1', regionId: 'region_north' },
    { id: 'dist_kk2', name: 'Kota Kinabalu 2', code: 'KK2', regionId: 'region_north' },
    { id: 'dist_papar', name: 'Papar District', code: 'PPR', regionId: 'region_west' },
    { id: 'dist_beaufort', name: 'Beaufort District', code: 'BFT', regionId: 'region_west' },
    { id: 'dist_sandakan', name: 'Sandakan District', code: 'SDK', regionId: 'region_east' },
    { id: 'dist_tawau', name: 'Tawau District', code: 'TWU', regionId: 'region_east' },
  ];

  console.log(`🏘️ Creating ${districts.length} districts...`);
  for (const district of districts) {
    await db.collection('districts').doc(district.id).set({
      ...district,
      missionId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: 'system',
    });
  }

  // Add Churches
  const churches = [
    { id: 'ch_kk_central', name: 'KK Central Church', districtId: 'dist_kk1', regionId: 'region_north', members: 250 },
    { id: 'ch_kk_penampang', name: 'Penampang Church', districtId: 'dist_kk1', regionId: 'region_north', members: 180 },
    { id: 'ch_kk_inanam', name: 'Inanam Church', districtId: 'dist_kk1', regionId: 'region_north', members: 120 },
    { id: 'ch_kk_luyang', name: 'Luyang Church', districtId: 'dist_kk2', regionId: 'region_north', members: 200 },
    { id: 'ch_kk_putatan', name: 'Putatan Church', districtId: 'dist_kk2', regionId: 'region_north', members: 150 },
    { id: 'ch_kk_kota_belud', name: 'Kota Belud Church', districtId: 'dist_kk2', regionId: 'region_north', members: 95 },
    { id: 'ch_papar_town', name: 'Papar Town Church', districtId: 'dist_papar', regionId: 'region_west', members: 130 },
    { id: 'ch_papar_kinarut', name: 'Kinarut Church', districtId: 'dist_papar', regionId: 'region_west', members: 85 },
    { id: 'ch_papar_kimanis', name: 'Kimanis Church', districtId: 'dist_papar', regionId: 'region_west', members: 70 },
    { id: 'ch_papar_membakut', name: 'Membakut Church', districtId: 'dist_papar', regionId: 'region_west', members: 60 },
    { id: 'ch_beaufort_town', name: 'Beaufort Church', districtId: 'dist_beaufort', regionId: 'region_west', members: 110 },
    { id: 'ch_beaufort_sipitang', name: 'Sipitang Church', districtId: 'dist_beaufort', regionId: 'region_west', members: 90 },
    { id: 'ch_beaufort_kuala_penyu', name: 'Kuala Penyu Church', districtId: 'dist_beaufort', regionId: 'region_west', members: 55 },
    { id: 'ch_sandakan_central', name: 'Sandakan Central Church', districtId: 'dist_sandakan', regionId: 'region_east', members: 220 },
    { id: 'ch_sandakan_batu_sapi', name: 'Batu Sapi Church', districtId: 'dist_sandakan', regionId: 'region_east', members: 140 },
    { id: 'ch_sandakan_libaran', name: 'Libaran Church', districtId: 'dist_sandakan', regionId: 'region_east', members: 75 },
    { id: 'ch_sandakan_kinabatangan', name: 'Kinabatangan Church', districtId: 'dist_sandakan', regionId: 'region_east', members: 65 },
    { id: 'ch_tawau_central', name: 'Tawau Central Church', districtId: 'dist_tawau', regionId: 'region_east', members: 190 },
    { id: 'ch_tawau_semporna', name: 'Semporna Church', districtId: 'dist_tawau', regionId: 'region_east', members: 160 },
    { id: 'ch_tawau_lahad_datu', name: 'Lahad Datu Church', districtId: 'dist_tawau', regionId: 'region_east', members: 145 },
    { id: 'ch_tawau_kunak', name: 'Kunak Church', districtId: 'dist_tawau', regionId: 'region_east', members: 80 },
  ];

  console.log(`⛪ Creating ${churches.length} churches...`);
  for (const church of churches) {
    await db.collection('churches').doc(church.id).set({
      id: church.id,
      churchName: church.name,
      districtId: church.districtId,
      regionId: church.regionId,
      missionId,
      userId: 'system',
      elderName: `Elder ${church.name.split(' ')[0]}`,
      elderEmail: `elder@${church.id}.com`,
      elderPhone: '+60123456789',
      status: 'church',
      memberCount: church.members,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // Add Staff
  const staff = [
    { name: 'Pastor John Lim', position: 'Senior Pastor', department: 'Administration' },
    { name: 'Pastor Mary Tan', position: 'Associate Pastor', department: 'Youth Ministry' },
    { name: 'Elder David Wong', position: 'Elder', department: 'Sabbath School' },
    { name: 'Deacon Peter Lee', position: 'Deacon', department: 'Community Services' },
    { name: 'Pastor Sarah Chen', position: 'District Pastor', department: 'Evangelism' },
    { name: 'Pastor James Koh', position: 'District Pastor', department: 'Personal Ministries' },
    { name: 'Elder Rebecca Ng', position: 'Elder', department: "Women's Ministries" },
    { name: 'Pastor Michael Yap', position: 'Youth Pastor', department: 'Youth Ministry' },
    { name: 'Deaconess Lisa Tan', position: 'Deaconess', department: 'Health Ministries' },
    { name: 'Pastor Daniel Chia', position: 'District Pastor', department: 'Stewardship' },
    { name: 'Elder Grace Lim', position: 'Elder', department: 'Family Ministries' },
    { name: 'Pastor Timothy Goh', position: 'Associate Pastor', department: 'Publishing' },
    { name: 'Deacon Samuel Lee', position: 'Deacon', department: 'Communication' },
    { name: 'Pastor Ruth Wong', position: 'District Pastor', department: "Children's Ministries" },
    { name: 'Elder Benjamin Tan', position: 'Elder', department: 'Education' },
  ];

  console.log(`👥 Creating ${staff.length} staff members...`);
  let staffIndex = 0;
  for (const person of staff) {
    staffIndex++;
    await db.collection('staff').doc(`staff_${staffIndex}`).set({
      id: `staff_${staffIndex}`,
      name: person.name,
      position: person.position,
      department: person.department,
      mission: missionName,
      email: `${person.name.toLowerCase().replace(/ /g, '.')}@sabah.mission`,
      phone: `+601${2000000 + staffIndex}`,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // Add Financial Reports for current month
  console.log('💰 Creating sample financial reports...');
  const now = new Date();
  const currentMonth = new Date(now.getFullYear(), now.getMonth(), 1);

  let reportCount = 0;
  for (const church of churches) {
    reportCount++;
    const tithe = church.members * (100 + reportCount * 5);
    const offerings = church.members * (50 + reportCount * 3);

    await db.collection('financial_reports').doc(`report_${church.id}_${now.getMonth() + 1}`).set({
      id: `report_${church.id}_${now.getMonth() + 1}`,
      churchId: church.id,
      districtId: church.districtId,
      regionId: church.regionId,
      missionId,
      month: admin.firestore.Timestamp.fromDate(currentMonth),
      year: now.getFullYear(),
      tithe,
      offerings,
      specialOfferings: reportCount * 100,
      submittedBy: 'system',
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'submitted',
    });
  }

  const totalMembers = churches.reduce((sum, c) => sum + c.members, 0);

  console.log('✅ Mock data created successfully!');
  console.log('📊 Summary:');
  console.log(`  - 1 Mission: ${missionName}`);
  console.log(`  - ${regions.length} Regions`);
  console.log(`  - ${districts.length} Districts`);
  console.log(`  - ${churches.length} Churches`);
  console.log(`  - ${totalMembers} Total Members`);
  console.log(`  - ${staff.length} Staff Members`);
  console.log(`  - ${reportCount} Financial Reports`);
  console.log('');
  console.log('🎉 Done! Refresh your app to see the data.');

  process.exit(0);
}

addMockData().catch(console.error);
