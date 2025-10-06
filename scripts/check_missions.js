// Script to check all missions in Firestore
const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkMissions() {
  try {
    console.log('📋 Fetching all missions from Firestore...\n');

    const missionsSnapshot = await db.collection('missions').get();

    console.log(`Found ${missionsSnapshot.docs.length} missions:\n`);

    missionsSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`ID: ${doc.id}`);
      console.log(`  Name: ${data.name || 'N/A'}`);
      console.log(`  Code: ${data.code || 'N/A'}`);
      console.log(`  Description: ${data.description || 'N/A'}`);
      console.log('');
    });

    console.log('\n📝 Current hardcoded mappings in mission_service.dart:');
    console.log(`
      // Sabah Mission
      '4LFC9isp22H7Og1FHBm6': {
        'name': 'Sabah Mission',
        'code': 'SAB',
      },
      // Sarawak Mission
      'mpfQa7qEaj0fzuo4xhDN': {
        'name': 'Sarawak Mission',
        'code': 'SAR',
      },
      // North Sabah Mission
      'M89PoDdB5sNCoDl8qTNS': {
        'name': 'North Sabah Mission',
        'code': 'NSM',
      },
      // West Malaysia Mission
      'bwi23rsOpWJLnKcn20WC': {
        'name': 'West Malaysia Mission',
        'code': 'WM',
      },
    `);

    console.log('\n✅ Suggested correct mappings based on Firestore:');
    console.log('const documentIdMappings = {');
    missionsSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`  '${doc.id}': {`);
      console.log(`    'name': '${data.name || 'Unknown'}',`);
      console.log(`    'code': '${data.code || 'N/A'}',`);
      console.log(`  },`);
    });
    console.log('};');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkMissions();
