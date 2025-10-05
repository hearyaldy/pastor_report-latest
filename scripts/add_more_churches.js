const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Function to generate church names
function generateChurchName(districtName, index) {
  const types = [
    'Central Church', 'Grace Church', 'Hope Church', 'Faith Church',
    'Victory Church', 'Bethel Church', 'Emmanuel Church', 'Calvary Church',
    'New Life Church', 'Trinity Church', 'Cornerstone Church', 'Lighthouse Church',
    'Riverside Church', 'Mountain View Church', 'Valley Church', 'Hillside Church',
    'Parkway Church', 'Community Church', 'Fellowship Church', 'United Church',
    'First Church', 'Gospel Church', 'Praise Church', 'Worship Church',
    'Love Church', 'Peace Church', 'Joy Church', 'Spirit Church',
    'Living Water Church', 'Good News Church', 'Salvation Church', 'Mission Church',
    'Believers Church', 'Saints Church', 'Crown Church', 'Glory Church'
  ];

  const typeIndex = index % types.length;
  const suffix = index >= types.length ? ` ${Math.floor(index / types.length) + 1}` : '';

  return `${districtName} - ${types[typeIndex]}${suffix}`;
}

async function addMoreChurches() {
  console.log('🚀 Adding churches to all districts...\n');

  // Fetch existing districts
  const districtsSnapshot = await db.collection('districts').get();
  const districts = [];
  districtsSnapshot.forEach(doc => {
    const data = doc.data();
    districts.push({ id: doc.id, ...data });
  });

  console.log(`✅ Found ${districts.length} districts\n`);

  if (districts.length === 0) {
    console.log('❌ No districts found!');
    process.exit(1);
  }

  const missionId = districts[0].missionId || 'mission_sabah';
  console.log(`📍 Using missionId: ${missionId}\n`);

  // Check existing churches to avoid duplicates
  const existingChurchesSnapshot = await db.collection('churches').get();
  const existingChurchIds = new Set();
  existingChurchesSnapshot.forEach(doc => {
    existingChurchIds.add(doc.id);
  });

  console.log(`📊 Found ${existingChurchIds.size} existing churches\n`);
  console.log('⛪ Creating churches...\n');

  let totalChurches = 0;
  let totalMembers = 0;
  let newChurches = 0;

  for (const district of districts) {
    const churchesPerDistrict = 3; // Create exactly 3 churches per district

    for (let i = 0; i < churchesPerDistrict; i++) {
      const churchId = `ch_${district.id}_${i + 1}`;

      // Skip if church already exists
      if (existingChurchIds.has(churchId)) {
        console.log(`  ⏭️  Skipping ${churchId} (already exists)`);
        totalChurches++;
        continue;
      }

      const churchName = generateChurchName(district.name, i);
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

      newChurches++;
      totalChurches++;
      totalMembers += memberCount;
      console.log(`  ✓ ${churchName} (${memberCount} members)`);
    }
  }

  console.log(`\n✅ Created ${newChurches} NEW churches`);
  console.log(`📊 Total churches in database: ${totalChurches}`);
  console.log(`👥 Total members: ${totalMembers.toLocaleString()}\n`);

  // Create financial reports for NEW churches only
  if (newChurches > 0) {
    console.log('💰 Creating financial reports for new churches...\n');

    const now = new Date();
    const currentMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const allChurchesSnapshot = await db.collection('churches').get();
    let reportCount = 0;

    for (const churchDoc of allChurchesSnapshot.docs) {
      const church = churchDoc.data();
      const reportId = `report_${church.id}_${now.getMonth() + 1}`;

      // Check if report already exists
      const existingReport = await db.collection('financial_reports').doc(reportId).get();
      if (existingReport.exists) {
        continue;
      }

      // Calculate realistic financial amounts
      const avgTithePerMember = 100 + Math.random() * 100;
      const avgOfferingPerMember = 50 + Math.random() * 50;

      const tithe = Math.floor(church.memberCount * avgTithePerMember);
      const offerings = Math.floor(church.memberCount * avgOfferingPerMember);
      const specialOfferings = Math.floor(Math.random() * 500) + 100;

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

      reportCount++;
      console.log(`  ✓ Report for ${church.churchName}: RM ${(tithe + offerings + specialOfferings).toLocaleString()}`);
    }

    console.log(`\n✅ Created ${reportCount} financial reports`);
  }

  console.log('\n🎉 Done! Refresh your My Mission tab to see the updated data.');

  process.exit(0);
}

addMoreChurches().catch(error => {
  console.error('❌ Error:', error);
  process.exit(1);
});
