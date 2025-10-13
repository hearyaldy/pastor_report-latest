const admin = require('firebase-admin');
const serviceAccount = require('../pastor-report-e4c52-firebase-adminsdk-fbsvc-a7f1335a9b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'pastor-report-e4c52'
});

const db = admin.firestore();

async function checkMissions() {
  console.log('🔍 Checking all missions in database...\n');

  try {
    const missionsSnapshot = await db.collection('missions').get();

    console.log(`Found ${missionsSnapshot.size} mission(s):\n`);

    missionsSnapshot.forEach(doc => {
      const data = doc.data();
      console.log('─'.repeat(60));
      console.log(`📋 Document ID: ${doc.id}`);
      console.log(`   Name: ${data.name}`);
      console.log(`   Created At: ${data.createdAt ? data.createdAt.toDate() : 'N/A'}`);
      console.log(`   Data:`, JSON.stringify(data, null, 2));
    });

    console.log('─'.repeat(60));

    // Check for regions with NSM
    console.log('\n🔍 Checking regions for North Sabah Mission...\n');
    const regionsSnapshot = await db.collection('regions')
      .where('name', '>=', 'Region')
      .where('name', '<=', 'Region\uf8ff')
      .get();

    const nsmRegions = [];
    regionsSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.missionId && data.missionId.toLowerCase().includes('sabah')) {
        nsmRegions.push({ id: doc.id, ...data });
      }
    });

    console.log(`Found ${nsmRegions.length} regions for North Sabah Mission:`);
    nsmRegions.forEach(region => {
      console.log(`  - ${region.id}: ${region.name} (missionId: ${region.missionId})`);
    });

    // Check for districts with NSM
    console.log('\n🔍 Checking districts for North Sabah Mission...\n');
    const districtsSnapshot = await db.collection('districts').get();

    const nsmDistricts = [];
    districtsSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.missionId && data.missionId.toLowerCase().includes('sabah')) {
        nsmDistricts.push({ id: doc.id, ...data });
      }
    });

    console.log(`Found ${nsmDistricts.length} districts for North Sabah Mission`);

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  }
}

checkMissions();
