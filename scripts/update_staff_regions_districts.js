const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const serviceAccount = require('../pastor-report-e4c52-firebase-adminsdk-fbsvc-a7f1335a9b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'pastor-report-e4c52'
});

const db = admin.firestore();

// Mission IDs
const SABAH_MISSION_ID = '4LFC9isp22H7Og1FHBm6';
const NSM_MISSION_ID = 'M89PoDdB5sNCoDl8qTNS';

// Load JSON files
const sabahChurchesPath = path.join(__dirname, '../assets/churches_SAB.json');
const nsmStaffPath = path.join(__dirname, '../assets/NSM STAFF.json');

const sabahData = JSON.parse(fs.readFileSync(sabahChurchesPath, 'utf8'));
const nsmStaffData = JSON.parse(fs.readFileSync(nsmStaffPath, 'utf8'));

// Helper function to normalize names for comparison
function normalizeName(name) {
  return name.toLowerCase()
    .replace(/\s+/g, ' ')
    .replace(/[^a-z0-9 ]/g, '')
    .trim();
}

// Helper function to find region and district UIDs from database
async function findRegionAndDistrictUIDs(missionId, regionName, districtName) {
  try {
    // Find region by name and missionId
    const regionsSnapshot = await db.collection('regions')
      .where('missionId', '==', missionId)
      .where('name', '==', regionName)
      .get();

    if (regionsSnapshot.empty) {
      console.log(`⚠️  Region not found: ${regionName}`);
      return { regionId: null, districtId: null };
    }

    const regionId = regionsSnapshot.docs[0].id;

    // Find district by name and regionId
    const districtsSnapshot = await db.collection('districts')
      .where('regionId', '==', regionId)
      .where('name', '==', districtName)
      .get();

    if (districtsSnapshot.empty) {
      console.log(`⚠️  District not found: ${districtName} in ${regionName}`);
      return { regionId, districtId: null };
    }

    const districtId = districtsSnapshot.docs[0].id;

    return { regionId, districtId };
  } catch (e) {
    console.error(`Error finding region/district: ${e}`);
    return { regionId: null, districtId: null };
  }
}

// Update Sabah Mission staff
async function updateSabahMissionStaff() {
  console.log('\n🏢 UPDATING SABAH MISSION STAFF...\n');

  let updated = 0;
  let notFound = 0;
  const updates = [];

  // Get all Sabah Mission staff
  const staffSnapshot = await db.collection('staff')
    .where('mission', '==', SABAH_MISSION_ID)
    .get();

  console.log(`Found ${staffSnapshot.size} Sabah Mission staff members`);

  // Build a map of pastor names to their region and district from JSON
  const pastorMap = new Map();

  for (const [regionKey, regionData] of Object.entries(sabahData.regions)) {
    const regionName = regionData.name;

    if (regionData.pastoral_districts) {
      for (const [districtName, districtData] of Object.entries(regionData.pastoral_districts)) {
        // Handle both single pastor and multiple pastors
        if (districtData.pastors && Array.isArray(districtData.pastors)) {
          for (const pastor of districtData.pastors) {
            const normalizedName = normalizeName(pastor.name);
            pastorMap.set(normalizedName, {
              regionName,
              districtName,
              originalName: pastor.name
            });
          }
        } else if (districtData.pastor) {
          const normalizedName = normalizeName(districtData.pastor);
          pastorMap.set(normalizedName, {
            regionName,
            districtName,
            originalName: districtData.pastor
          });
        }
      }
    }
  }

  console.log(`Built pastor map with ${pastorMap.size} entries\n`);

  // Update each staff member
  for (const staffDoc of staffSnapshot.docs) {
    const staff = staffDoc.data();
    const normalizedStaffName = normalizeName(staff.name);

    // Try to find matching pastor in map
    const pastorInfo = pastorMap.get(normalizedStaffName);

    if (pastorInfo) {
      // Get region and district UIDs
      const { regionId, districtId } = await findRegionAndDistrictUIDs(
        SABAH_MISSION_ID,
        pastorInfo.regionName,
        pastorInfo.districtName
      );

      if (regionId && districtId) {
        await db.collection('staff').doc(staffDoc.id).update({
          region: regionId,
          district: districtId
        });

        console.log(`✓ ${staff.name} -> ${pastorInfo.regionName} / ${pastorInfo.districtName}`);
        updated++;
        updates.push({
          name: staff.name,
          region: pastorInfo.regionName,
          district: pastorInfo.districtName
        });
      } else {
        console.log(`⚠️  ${staff.name} - Region/District not found in DB`);
        notFound++;
      }
    } else {
      console.log(`⚠️  ${staff.name} - Not found in JSON`);
      notFound++;
    }
  }

  return { updated, notFound, details: updates };
}

// Update NSM staff
async function updateNSMStaff() {
  console.log('\n\n🏢 UPDATING NORTH SABAH MISSION STAFF...\n');

  let updated = 0;
  let notFound = 0;
  const updates = [];

  // Get all NSM staff
  const staffSnapshot = await db.collection('staff')
    .where('mission', '==', NSM_MISSION_ID)
    .get();

  console.log(`Found ${staffSnapshot.size} NSM staff members`);

  // Build a map of staff names to their regions from NSM STAFF.json
  const staffRegionMap = new Map();

  if (nsmStaffData.field_pastors) {
    for (const [regionName, pastors] of Object.entries(nsmStaffData.field_pastors)) {
      for (const pastor of pastors) {
        const normalizedName = normalizeName(pastor.name);
        staffRegionMap.set(normalizedName, {
          regionName,
          assignment: pastor.assignment,
          originalName: pastor.name
        });
      }
    }
  }

  console.log(`Built NSM staff map with ${staffRegionMap.size} field pastors\n`);

  // Update each staff member
  for (const staffDoc of staffSnapshot.docs) {
    const staff = staffDoc.data();
    const normalizedStaffName = normalizeName(staff.name);

    // Try to find matching staff in map
    const staffInfo = staffRegionMap.get(normalizedStaffName);

    if (staffInfo) {
      // Get region UID
      const regionsSnapshot = await db.collection('regions')
        .where('missionId', '==', NSM_MISSION_ID)
        .where('name', '==', staffInfo.regionName)
        .get();

      if (!regionsSnapshot.empty) {
        const regionId = regionsSnapshot.docs[0].id;

        await db.collection('staff').doc(staffDoc.id).update({
          region: regionId,
          district: staffInfo.assignment // Store assignment as string for NSM
        });

        console.log(`✓ ${staff.name} -> ${staffInfo.regionName} / ${staffInfo.assignment}`);
        updated++;
        updates.push({
          name: staff.name,
          region: staffInfo.regionName,
          assignment: staffInfo.assignment
        });
      } else {
        console.log(`⚠️  ${staff.name} - Region not found: ${staffInfo.regionName}`);
        notFound++;
      }
    } else {
      // For non-field pastors (officers, directors, etc.), just log but don't count as not found
      if (staff.role === 'Field Pastor') {
        console.log(`⚠️  ${staff.name} (Field Pastor) - Not found in JSON`);
        notFound++;
      }
    }
  }

  return { updated, notFound, details: updates };
}

// Main execution
async function main() {
  console.log('\n' + '='.repeat(70));
  console.log('🔧 STAFF REGION/DISTRICT UPDATE SCRIPT');
  console.log('='.repeat(70));
  console.log('This script will update staff records with correct region/district UIDs');
  console.log('based on the data in the JSON files.');
  console.log('='.repeat(70));

  try {
    // Update Sabah Mission staff
    const sabahResults = await updateSabahMissionStaff();

    // Update NSM staff
    const nsmResults = await updateNSMStaff();

    // Final summary
    console.log('\n' + '='.repeat(70));
    console.log('📊 FINAL SUMMARY');
    console.log('='.repeat(70));
    console.log('\n🏢 SABAH MISSION:');
    console.log(`   ✅ Updated: ${sabahResults.updated}`);
    console.log(`   ⚠️  Not Found: ${sabahResults.notFound}`);

    console.log('\n🏢 NORTH SABAH MISSION:');
    console.log(`   ✅ Updated: ${nsmResults.updated}`);
    console.log(`   ⚠️  Not Found: ${nsmResults.notFound}`);

    console.log('\n📈 TOTAL:');
    console.log(`   ✅ Total Updated: ${sabahResults.updated + nsmResults.updated}`);
    console.log(`   ⚠️  Total Not Found: ${sabahResults.notFound + nsmResults.notFound}`);

    console.log('\n' + '='.repeat(70));
    console.log('🎉 UPDATE COMPLETE!');
    console.log('='.repeat(70) + '\n');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

main();
