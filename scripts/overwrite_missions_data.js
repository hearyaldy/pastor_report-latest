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
const SABAH_MISSION_ID = '4LFC9isp22H7Og1FHBm6'; // Sabah Mission Firestore ID
const NSM_MISSION_ID = 'M89PoDdB5sNCoDl8qTNS'; // North Sabah Mission Firestore ID
const NSM_MISSION_NAME = 'North Sabah Mission';

// Load JSON files
const sabahChurchesPath = path.join(__dirname, '../assets/churches_SAB.json');
const nsmStaffPath = path.join(__dirname, '../assets/NSM STAFF.json');
const nsmChurchesPath = path.join(__dirname, '../assets/NSM_Churches_Updated.json');

const sabahData = JSON.parse(fs.readFileSync(sabahChurchesPath, 'utf8'));
const nsmStaffData = JSON.parse(fs.readFileSync(nsmStaffPath, 'utf8'));
const nsmChurchesData = JSON.parse(fs.readFileSync(nsmChurchesPath, 'utf8'));

// Helper function to generate unique IDs
function generateId() {
  return db.collection('_').doc().id;
}

// Helper function to get church status enum
function getChurchStatus(type) {
  switch (type) {
    case 'organized_church':
      return 'organizedChurch';
    case 'company':
      return 'company';
    case 'group':
      return 'group';
    default:
      return 'organizedChurch';
  }
}

// Helper function to delete collection by mission ID
async function deleteByMissionId(collectionName, missionId) {
  console.log(`   Deleting ${collectionName} for mission ${missionId}...`);
  const snapshot = await db.collection(collectionName).where('missionId', '==', missionId).get();

  const batch = db.batch();
  let count = 0;

  snapshot.forEach((doc) => {
    batch.delete(doc.ref);
    count++;
  });

  if (count > 0) {
    await batch.commit();
  }

  console.log(`   ✓ Deleted ${count} ${collectionName}`);
  return count;
}

// Helper function to delete staff by mission name
async function deleteStaffByMission(missionName) {
  console.log(`   Deleting staff for mission ${missionName}...`);
  const snapshot = await db.collection('staff').where('mission', '==', missionName).get();

  const batch = db.batch();
  let count = 0;

  snapshot.forEach((doc) => {
    batch.delete(doc.ref);
    count++;
  });

  if (count > 0) {
    await batch.commit();
  }

  console.log(`   ✓ Deleted ${count} staff members`);
  return count;
}

// Step 1: Delete all existing data
async function deleteExistingData() {
  console.log('\n🗑️  STEP 1: Deleting existing data...\n');

  console.log('Deleting Sabah Mission data:');
  await deleteByMissionId('churches', SABAH_MISSION_ID);
  await deleteByMissionId('districts', SABAH_MISSION_ID);
  await deleteByMissionId('regions', SABAH_MISSION_ID);

  console.log('\nDeleting North Sabah Mission data:');
  await deleteByMissionId('churches', NSM_MISSION_ID);
  await deleteByMissionId('districts', NSM_MISSION_ID);
  await deleteByMissionId('regions', NSM_MISSION_ID);
  await deleteStaffByMission(NSM_MISSION_NAME);

  console.log('\n✅ All existing data deleted successfully!\n');
}

// Step 2: Import Sabah Mission data
async function importSabahMission() {
  console.log('🏢 STEP 2: Importing Sabah Mission data...\n');

  let stats = {
    regions: 0,
    districts: 0,
    churches: 0,
    companies: 0,
    groups: 0
  };

  if (!sabahData.regions) {
    console.log('⚠️  No regions found in Sabah data');
    return stats;
  }

  for (const [regionKey, regionData] of Object.entries(sabahData.regions)) {
    const regionId = generateId();
    const regionName = regionData.name;

    // Create region
    await db.collection('regions').doc(regionId).set({
      id: regionId,
      name: regionName,
      missionId: SABAH_MISSION_ID,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✓ Region: ${regionName}`);
    stats.regions++;

    // Process pastoral districts
    if (regionData.pastoral_districts) {
      for (const [districtName, districtData] of Object.entries(regionData.pastoral_districts)) {
        const districtId = generateId();

        // Handle multiple pastors case
        let pastorName = '';
        let pastorPhone = '';

        if (districtData.pastors && Array.isArray(districtData.pastors)) {
          // Multiple pastors - join their names
          pastorName = districtData.pastors.map(p => p.name).join(', ');
          pastorPhone = districtData.pastors[0].phone || '';
        } else if (districtData.pastor) {
          pastorName = districtData.pastor;
          pastorPhone = districtData.phone || '';
        }

        // Create district
        await db.collection('districts').doc(districtId).set({
          id: districtId,
          name: districtName,
          regionId: regionId,
          missionId: SABAH_MISSION_ID,
          pastorName: pastorName,
          pastorPhone: pastorPhone,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`  ✓ District: ${districtName}`);
        stats.districts++;

        // Process organized churches
        if (districtData.organized_churches && districtData.organized_churches.length > 0) {
          for (const church of districtData.organized_churches) {
            const churchId = generateId();
            const churchName = typeof church === 'string' ? church : church.name;

            await db.collection('churches').doc(churchId).set({
              id: churchId,
              userId: '',
              churchName: churchName,
              elderName: pastorName || 'Unknown',
              status: getChurchStatus('organized_church'),
              elderEmail: '',
              elderPhone: pastorPhone || '',
              address: `${districtName}, ${regionName}, Sabah`,
              memberCount: null,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              districtId: districtId,
              regionId: regionId,
              missionId: SABAH_MISSION_ID,
            });

            stats.churches++;
          }
        }

        // Process companies
        if (districtData.companies && districtData.companies.length > 0) {
          for (const company of districtData.companies) {
            const companyId = generateId();
            const companyName = typeof company === 'string' ? company : company.name;

            await db.collection('churches').doc(companyId).set({
              id: companyId,
              userId: '',
              churchName: companyName,
              elderName: pastorName || 'Unknown',
              status: getChurchStatus('company'),
              elderEmail: '',
              elderPhone: pastorPhone || '',
              address: `${districtName}, ${regionName}, Sabah`,
              memberCount: null,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              districtId: districtId,
              regionId: regionId,
              missionId: SABAH_MISSION_ID,
            });

            stats.companies++;
          }
        }

        // Process groups
        if (districtData.groups && districtData.groups.length > 0) {
          for (const group of districtData.groups) {
            const groupId = generateId();
            const groupName = typeof group === 'string' ? group : group.name;

            await db.collection('churches').doc(groupId).set({
              id: groupId,
              userId: '',
              churchName: groupName,
              elderName: pastorName || 'Unknown',
              status: getChurchStatus('group'),
              elderEmail: '',
              elderPhone: pastorPhone || '',
              address: `${districtName}, ${regionName}, Sabah`,
              memberCount: null,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              districtId: districtId,
              regionId: regionId,
              missionId: SABAH_MISSION_ID,
            });

            stats.groups++;
          }
        }

        const total = (districtData.organized_churches?.length || 0) +
                      (districtData.companies?.length || 0) +
                      (districtData.groups?.length || 0);
        console.log(`    Created ${total} congregations`);
      }
    }
  }

  console.log(`\n✅ Sabah Mission imported: ${stats.regions} regions, ${stats.districts} districts, ${stats.churches + stats.companies + stats.groups} total congregations\n`);
  return stats;
}

// Step 3: Create NSM Regions (from NSM STAFF.json)
async function createNSMRegions() {
  console.log('🏢 STEP 3: Creating North Sabah Mission regions...\n');

  const regionMap = new Map();

  // Extract unique regions from field_pastors
  if (nsmStaffData.field_pastors) {
    for (const regionName of Object.keys(nsmStaffData.field_pastors)) {
      const regionId = generateId();

      await db.collection('regions').doc(regionId).set({
        id: regionId,
        name: regionName,
        missionId: NSM_MISSION_ID,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      regionMap.set(regionName, regionId);
      console.log(`✓ Created region: ${regionName}`);
    }
  }

  console.log(`\n✅ Created ${regionMap.size} NSM regions\n`);
  return regionMap;
}

// Step 4: Import NSM Churches
async function importNSMChurches(regionMap) {
  console.log('🏢 STEP 4: Importing North Sabah Mission churches...\n');

  let stats = {
    districts: 0,
    churches: 0,
    companies: 0,
    groups: 0
  };

  if (!nsmChurchesData.regions) {
    console.log('⚠️  No regions found in NSM churches data');
    return stats;
  }

  for (const [regionNum, regionData] of Object.entries(nsmChurchesData.regions)) {
    const regionName = regionData.name.toUpperCase().replace('REGION ', 'REGION ');
    const regionId = regionMap.get(regionName) || regionMap.get(`REGION ${regionNum}`);

    if (!regionId) {
      console.log(`⚠️  Warning: Could not find region ID for ${regionName}`);
      continue;
    }

    console.log(`Processing ${regionName}:`);

    // Process pastoral districts
    if (regionData.pastoral_districts) {
      for (const [districtName, districtData] of Object.entries(regionData.pastoral_districts)) {
        const districtId = generateId();

        // Handle multiple pastors case
        let pastorName = '';
        let pastorPhone = '';

        if (districtData.pastors && Array.isArray(districtData.pastors)) {
          pastorName = districtData.pastors.map(p => p.name).join(', ');
          pastorPhone = districtData.pastors[0].phone || '';
        } else if (districtData.pastor) {
          pastorName = districtData.pastor;
          pastorPhone = districtData.phone || '';
        }

        // Create district
        await db.collection('districts').doc(districtId).set({
          id: districtId,
          name: districtName,
          regionId: regionId,
          missionId: NSM_MISSION_ID,
          pastorName: pastorName,
          pastorPhone: pastorPhone,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        stats.districts++;

        // Process organized churches
        if (districtData.organized_churches && districtData.organized_churches.length > 0) {
          for (const church of districtData.organized_churches) {
            const churchId = generateId();
            const churchName = typeof church === 'string' ? church : church.name;

            await db.collection('churches').doc(churchId).set({
              id: churchId,
              userId: '',
              churchName: churchName,
              elderName: pastorName || 'Unknown',
              status: getChurchStatus('organized_church'),
              elderEmail: '',
              elderPhone: pastorPhone || '',
              address: `${districtName}, ${regionName}, Sabah`,
              memberCount: null,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              districtId: districtId,
              regionId: regionId,
              missionId: NSM_MISSION_ID,
            });

            stats.churches++;
          }
        }

        // Process companies
        if (districtData.companies && districtData.companies.length > 0) {
          for (const company of districtData.companies) {
            const companyId = generateId();
            const companyName = typeof company === 'string' ? company : company.name;

            await db.collection('churches').doc(companyId).set({
              id: companyId,
              userId: '',
              churchName: companyName,
              elderName: pastorName || 'Unknown',
              status: getChurchStatus('company'),
              elderEmail: '',
              elderPhone: pastorPhone || '',
              address: `${districtName}, ${regionName}, Sabah`,
              memberCount: null,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              districtId: districtId,
              regionId: regionId,
              missionId: NSM_MISSION_ID,
            });

            stats.companies++;
          }
        }

        // Process groups
        if (districtData.groups && districtData.groups.length > 0) {
          for (const group of districtData.groups) {
            const groupId = generateId();
            const groupName = typeof group === 'string' ? group : group.name;

            await db.collection('churches').doc(groupId).set({
              id: groupId,
              userId: '',
              churchName: groupName,
              elderName: pastorName || 'Unknown',
              status: getChurchStatus('group'),
              elderEmail: '',
              elderPhone: pastorPhone || '',
              address: `${districtName}, ${regionName}, Sabah`,
              memberCount: null,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              districtId: districtId,
              regionId: regionId,
              missionId: NSM_MISSION_ID,
            });

            stats.groups++;
          }
        }

        const total = (districtData.organized_churches?.length || 0) +
                      (districtData.companies?.length || 0) +
                      (districtData.groups?.length || 0);
        console.log(`  ✓ ${districtName}: ${total} congregations`);
      }
    }
  }

  console.log(`\n✅ NSM churches imported: ${stats.districts} districts, ${stats.churches + stats.companies + stats.groups} total congregations\n`);
  return stats;
}

// Step 5: Import NSM Staff
async function importNSMStaff(regionMap) {
  console.log('👥 STEP 5: Importing North Sabah Mission staff...\n');

  let stats = {
    officers: 0,
    directors: 0,
    assistants: 0,
    finance: 0,
    pastors: 0
  };

  // Import officers
  if (nsmStaffData.officers) {
    for (const officer of nsmStaffData.officers) {
      const staffId = generateId();

      await db.collection('staff').doc(staffId).set({
        id: staffId,
        name: officer.name,
        role: officer.position,
        email: officer.email,
        phone: officer.phone,
        mission: NSM_MISSION_NAME,
        department: 'Executive',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'system_import',
      });

      stats.officers++;
    }
    console.log(`✓ Imported ${stats.officers} officers`);
  }

  // Import department directors
  if (nsmStaffData.department_directors) {
    for (const director of nsmStaffData.department_directors) {
      const staffId = generateId();

      await db.collection('staff').doc(staffId).set({
        id: staffId,
        name: director.name,
        role: director.position,
        email: director.email,
        phone: director.phone,
        mission: NSM_MISSION_NAME,
        department: 'Department Directors',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'system_import',
      });

      stats.directors++;
    }
    console.log(`✓ Imported ${stats.directors} department directors`);
  }

  // Import administrative assistants
  if (nsmStaffData.administrative_assistants) {
    for (const assistant of nsmStaffData.administrative_assistants) {
      const staffId = generateId();

      await db.collection('staff').doc(staffId).set({
        id: staffId,
        name: assistant.name,
        role: assistant.position,
        email: assistant.email,
        phone: assistant.phone,
        mission: NSM_MISSION_NAME,
        department: 'Administrative',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'system_import',
      });

      stats.assistants++;
    }
    console.log(`✓ Imported ${stats.assistants} administrative assistants`);
  }

  // Import finance office staff
  if (nsmStaffData.finance_office) {
    for (const staffMember of nsmStaffData.finance_office) {
      const staffId = generateId();

      await db.collection('staff').doc(staffId).set({
        id: staffId,
        name: staffMember.name,
        role: staffMember.position,
        email: staffMember.email,
        phone: staffMember.phone,
        mission: NSM_MISSION_NAME,
        department: 'Finance',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'system_import',
      });

      stats.finance++;
    }
    console.log(`✓ Imported ${stats.finance} finance staff`);
  }

  // Import field pastors by region
  if (nsmStaffData.field_pastors) {
    for (const [regionName, pastors] of Object.entries(nsmStaffData.field_pastors)) {
      for (const pastor of pastors) {
        const staffId = generateId();

        await db.collection('staff').doc(staffId).set({
          id: staffId,
          name: pastor.name,
          role: 'Field Pastor',
          email: pastor.email,
          phone: pastor.phone,
          mission: NSM_MISSION_NAME,
          department: 'Field Ministry',
          region: regionName,
          district: pastor.assignment,
          notes: `Region: ${regionName}, Assignment: ${pastor.assignment}`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: 'system_import',
        });

        stats.pastors++;
      }
    }
    console.log(`✓ Imported ${stats.pastors} field pastors`);
  }

  console.log(`\n✅ NSM staff imported: ${stats.officers + stats.directors + stats.assistants + stats.finance + stats.pastors} total staff\n`);
  return stats;
}

// Main execution
async function main() {
  console.log('\n' + '='.repeat(70));
  console.log('🚀 MISSION DATA OVERWRITE SCRIPT');
  console.log('='.repeat(70));
  console.log('This script will:');
  console.log('1. Delete all existing Sabah Mission and North Sabah Mission data');
  console.log('2. Import Sabah Mission data from churches_SAB.json');
  console.log('3. Create NSM regions from NSM STAFF.json');
  console.log('4. Import NSM churches from NSM_Churches_Updated.json');
  console.log('5. Import NSM staff from NSM STAFF.json');
  console.log('='.repeat(70) + '\n');

  try {
    // Step 1: Delete existing data
    await deleteExistingData();

    // Step 2: Import Sabah Mission
    const sabahStats = await importSabahMission();

    // Step 3: Create NSM Regions
    const nsmRegionMap = await createNSMRegions();

    // Step 4: Import NSM Churches
    const nsmChurchStats = await importNSMChurches(nsmRegionMap);

    // Step 5: Import NSM Staff
    const nsmStaffStats = await importNSMStaff(nsmRegionMap);

    // Final summary
    console.log('\n' + '='.repeat(70));
    console.log('📊 FINAL SUMMARY');
    console.log('='.repeat(70));
    console.log('\n🏢 SABAH MISSION:');
    console.log(`   • Regions: ${sabahStats.regions}`);
    console.log(`   • Districts: ${sabahStats.districts}`);
    console.log(`   • Organized Churches: ${sabahStats.churches}`);
    console.log(`   • Companies: ${sabahStats.companies}`);
    console.log(`   • Groups: ${sabahStats.groups}`);
    console.log(`   • Total Congregations: ${sabahStats.churches + sabahStats.companies + sabahStats.groups}`);

    console.log('\n🏢 NORTH SABAH MISSION:');
    console.log(`   • Regions: ${nsmRegionMap.size}`);
    console.log(`   • Districts: ${nsmChurchStats.districts}`);
    console.log(`   • Organized Churches: ${nsmChurchStats.churches}`);
    console.log(`   • Companies: ${nsmChurchStats.companies}`);
    console.log(`   • Groups: ${nsmChurchStats.groups}`);
    console.log(`   • Total Congregations: ${nsmChurchStats.churches + nsmChurchStats.companies + nsmChurchStats.groups}`);
    console.log(`   • Staff Members: ${nsmStaffStats.officers + nsmStaffStats.directors + nsmStaffStats.assistants + nsmStaffStats.finance + nsmStaffStats.pastors}`);

    console.log('\n' + '='.repeat(70));
    console.log('🎉 ALL DATA SUCCESSFULLY IMPORTED!');
    console.log('='.repeat(70) + '\n');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

main();
