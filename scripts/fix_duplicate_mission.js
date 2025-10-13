const admin = require('firebase-admin');
const serviceAccount = require('../pastor-report-e4c52-firebase-adminsdk-fbsvc-a7f1335a9b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'pastor-report-e4c52'
});

const db = admin.firestore();

const ORIGINAL_MISSION_ID = 'M89PoDdB5sNCoDl8qTNS';
const DUPLICATE_MISSION_ID = 'north_sabah_mission';

async function fixDuplicateMission() {
  console.log('🔧 Fixing duplicate North Sabah Mission entries...\n');

  try {
    // Step 1: Update all regions to use the original mission ID
    console.log('📋 Step 1: Updating regions...');
    const regionsSnapshot = await db.collection('regions')
      .where('missionId', '==', DUPLICATE_MISSION_ID)
      .get();

    let regionsUpdated = 0;
    for (const doc of regionsSnapshot.docs) {
      await doc.ref.update({
        missionId: ORIGINAL_MISSION_ID
      });
      regionsUpdated++;
      console.log(`  ✓ Updated region: ${doc.data().name}`);
    }
    console.log(`✅ Updated ${regionsUpdated} regions\n`);

    // Step 2: Update all districts to use the original mission ID
    console.log('📋 Step 2: Updating districts...');
    const districtsSnapshot = await db.collection('districts')
      .where('missionId', '==', DUPLICATE_MISSION_ID)
      .get();

    let districtsUpdated = 0;
    for (const doc of districtsSnapshot.docs) {
      await doc.ref.update({
        missionId: ORIGINAL_MISSION_ID
      });
      districtsUpdated++;
      console.log(`  ✓ Updated district: ${doc.data().name}`);
    }
    console.log(`✅ Updated ${districtsUpdated} districts\n`);

    // Step 3: Update all churches to use the original mission ID
    console.log('📋 Step 3: Updating churches...');
    const churchesSnapshot = await db.collection('churches')
      .where('missionId', '==', DUPLICATE_MISSION_ID)
      .get();

    let churchesUpdated = 0;
    for (const doc of churchesSnapshot.docs) {
      await doc.ref.update({
        missionId: ORIGINAL_MISSION_ID
      });
      churchesUpdated++;
      if (churchesUpdated % 20 === 0) {
        console.log(`  ... Updated ${churchesUpdated} churches so far`);
      }
    }
    console.log(`✅ Updated ${churchesUpdated} churches\n`);

    // Step 4: Delete the duplicate mission
    console.log('📋 Step 4: Deleting duplicate mission...');
    await db.collection('missions').doc(DUPLICATE_MISSION_ID).delete();
    console.log(`✅ Deleted duplicate mission: ${DUPLICATE_MISSION_ID}\n`);

    // Summary
    console.log('═'.repeat(60));
    console.log('✅ FIX COMPLETE');
    console.log('═'.repeat(60));
    console.log(`Regions updated: ${regionsUpdated}`);
    console.log(`Districts updated: ${districtsUpdated}`);
    console.log(`Churches updated: ${churchesUpdated}`);
    console.log(`Duplicate mission deleted: ${DUPLICATE_MISSION_ID}`);
    console.log(`All data now linked to: ${ORIGINAL_MISSION_ID}`);
    console.log('═'.repeat(60));

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  }
}

fixDuplicateMission();
