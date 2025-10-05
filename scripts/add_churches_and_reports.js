const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function addChurchesAndReports() {
  console.log('🚀 Fetching existing data from Firestore...\n');

  // Fetch existing regions
  const regionsSnapshot = await db.collection('regions').get();
  const regions = [];
  regionsSnapshot.forEach(doc => {
    const data = doc.data();
    regions.push({ id: doc.id, ...data });
    console.log(`✅ Found region: ${data.name} (ID: ${doc.id})`);
  });

  // Fetch existing districts
  const districtsSnapshot = await db.collection('districts').get();
  const districts = [];
  districtsSnapshot.forEach(doc => {
    const data = doc.data();
    districts.push({ id: doc.id, ...data });
    console.log(`✅ Found district: ${data.name} (ID: ${doc.id})`);
  });

  // Fetch existing staff
  const staffSnapshot = await db.collection('staff').get();
  console.log(`\n✅ Found ${staffSnapshot.size} existing staff members`);

  if (districts.length === 0) {
    console.log('\n❌ No districts found! Please create regions and districts first.');
    process.exit(1);
  }

  console.log(`\n📊 Summary of existing data:`);
  console.log(`  - ${regions.length} regions`);
  console.log(`  - ${districts.length} districts`);
  console.log(`  - ${staffSnapshot.size} staff members\n`);

  // Get the first district's missionId for consistency
  const missionId = districts[0].missionId || 'mission_sabah';
  console.log(`📍 Using missionId: ${missionId}\n`);

  // Create churches for each district
  const churchesPerDistrict = {
    // Distribute 3-5 churches per district
    default: 3
  };

  const churchNames = [
    'Central Church', 'Grace Church', 'Hope Church', 'Faith Church',
    'Victory Church', 'Bethel Church', 'Emmanuel Church', 'Calvary Church',
    'New Life Church', 'Trinity Church', 'Cornerstone Church', 'Lighthouse Church',
    'Riverside Church', 'Mountain View Church', 'Valley Church', 'Hillside Church',
    'Parkway Church', 'Community Church', 'Fellowship Church', 'United Church'
  ];

  let totalChurches = 0;
  let totalMembers = 0;
  let churchIndex = 0;

  console.log('⛪ Creating churches for each district...\n');

  for (const district of districts) {
    const numChurches = Math.min(3 + Math.floor(Math.random() * 3), churchNames.length - churchIndex);

    for (let i = 0; i < numChurches; i++) {
      const churchId = `ch_${district.code.toLowerCase()}_${i + 1}`;
      const churchName = `${district.name} - ${churchNames[churchIndex++]}`;
      const memberCount = 50 + Math.floor(Math.random() * 200); // Random 50-250 members

      await db.collection('churches').doc(churchId).set({
        id: churchId,
        churchName: churchName,
        districtId: district.id,
        regionId: district.regionId,
        missionId: missionId,
        userId: 'system',
        elderName: `Elder ${churchName.split('-')[1].trim().split(' ')[0]}`,
        elderEmail: `elder@${churchId}.com`,
        elderPhone: '+60123456789',
        status: 'church',
        memberCount: memberCount,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      totalChurches++;
      totalMembers += memberCount;
      console.log(`  ✓ ${churchName} (${memberCount} members)`);
    }
  }

  console.log(`\n✅ Created ${totalChurches} churches with ${totalMembers} total members\n`);

  // Create financial reports for current month
  console.log('💰 Creating financial reports for current month...\n');

  const now = new Date();
  const currentMonth = new Date(now.getFullYear(), now.getMonth(), 1);

  const churchesSnapshot = await db.collection('churches').get();
  let reportCount = 0;

  for (const churchDoc of churchesSnapshot.docs) {
    const church = churchDoc.data();
    reportCount++;

    // Calculate realistic financial amounts based on member count
    const avgTithePerMember = 100 + Math.random() * 100; // RM 100-200 per member
    const avgOfferingPerMember = 50 + Math.random() * 50; // RM 50-100 per member

    const tithe = Math.floor(church.memberCount * avgTithePerMember);
    const offerings = Math.floor(church.memberCount * avgOfferingPerMember);
    const specialOfferings = Math.floor(Math.random() * 500) + 100; // RM 100-600

    const reportId = `report_${church.id}_${now.getMonth() + 1}`;

    await db.collection('financial_reports').doc(reportId).set({
      id: reportId,
      churchId: church.id,
      districtId: church.districtId,
      regionId: church.regionId,
      missionId: church.missionId,
      month: admin.firestore.Timestamp.fromDate(currentMonth),
      year: now.getFullYear(),
      tithe: tithe,
      offerings: offerings,
      specialOfferings: specialOfferings,
      submittedBy: 'system',
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'submitted',
    });

    console.log(`  ✓ ${church.churchName}: RM ${(tithe + offerings + specialOfferings).toLocaleString()}`);
  }

  const grandTotalTithe = reportCount * 15000; // Approximate
  const grandTotalOfferings = reportCount * 7500;

  console.log(`\n✅ Created ${reportCount} financial reports`);
  console.log(`\n📊 FINAL SUMMARY:`);
  console.log(`  - ${regions.length} Regions`);
  console.log(`  - ${districts.length} Districts`);
  console.log(`  - ${totalChurches} Churches`);
  console.log(`  - ${totalMembers.toLocaleString()} Total Members`);
  console.log(`  - ${staffSnapshot.size} Staff Members`);
  console.log(`  - ${reportCount} Financial Reports`);
  console.log(`  - Estimated Total Tithe: RM ${grandTotalTithe.toLocaleString()}`);
  console.log(`  - Estimated Total Offerings: RM ${grandTotalOfferings.toLocaleString()}`);
  console.log('\n🎉 Done! Refresh your app to see the updated data.');

  process.exit(0);
}

addChurchesAndReports().catch(error => {
  console.error('❌ Error:', error);
  process.exit(1);
});
