const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const serviceAccount = require('../pastor-report-e4c52-firebase-adminsdk-fbsvc-a7f1335a9b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'pastor-report-e4c52'
});

const db = admin.firestore();

// Read the NSM Churches data
const nsmChurchesPath = path.join(__dirname, '../assets/NSM_Churches_Updated.json');
const nsmData = JSON.parse(fs.readFileSync(nsmChurchesPath, 'utf8'));

const MISSION_ID = 'north_sabah_mission';
const MISSION_NAME = 'North Sabah Mission';

async function uploadNSMChurches() {
  console.log('🚀 Uploading North Sabah Mission Churches...\n');

  try {
    // Step 1: Ensure mission exists
    console.log('📋 Step 1: Checking/Creating Mission...');
    const missionRef = db.collection('missions').doc(MISSION_ID);
    const missionDoc = await missionRef.get();

    if (!missionDoc.exists) {
      await missionRef.set({
        id: MISSION_ID,
        name: MISSION_NAME,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`  ✓ Created mission: ${MISSION_NAME}`);
    } else {
      console.log(`  ✓ Mission exists: ${MISSION_NAME}`);
    }

    let totalRegions = 0;
    let totalDistricts = 0;
    let totalChurches = 0;
    let totalCompanies = 0;
    let totalGroups = 0;

    // Step 2: Process each region
    console.log('\n📋 Step 2: Processing Regions and Districts...\n');

    for (const [regionNum, regionData] of Object.entries(nsmData.regions)) {
      const regionId = `nsm_region_${regionNum}`;
      const regionName = regionData.name;

      // Create/Update region
      const regionRef = db.collection('regions').doc(regionId);
      await regionRef.set({
        id: regionId,
        name: regionName,
        missionId: MISSION_ID,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      console.log(`✓ Region: ${regionName}`);
      totalRegions++;

      // Process pastoral districts
      for (const [districtName, districtData] of Object.entries(regionData.pastoral_districts)) {
        const districtId = `nsm_district_${regionNum}_${districtName.toLowerCase().replace(/[^a-z0-9]+/g, '_')}`;

        // Create/Update district
        const districtRef = db.collection('districts').doc(districtId);
        await districtRef.set({
          id: districtId,
          name: districtName,
          regionId: regionId,
          missionId: MISSION_ID,
          pastor: districtData.pastor || '',
          phone: districtData.phone || '',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        console.log(`  ✓ District: ${districtName} (Pastor: ${districtData.pastor || 'TBD'})`);
        totalDistricts++;

        // Process organized churches
        if (districtData.organized_churches && districtData.organized_churches.length > 0) {
          for (const church of districtData.organized_churches) {
            const churchId = `nsm_church_${districtId}_${church.name.toLowerCase().replace(/[^a-z0-9]+/g, '_')}`;

            await db.collection('churches').doc(churchId).set({
              id: churchId,
              churchName: church.name,
              districtId: districtId,
              regionId: regionId,
              missionId: MISSION_ID,
              status: 'church',
              userId: 'system',
              elderName: '',
              elderEmail: '',
              elderPhone: '',
              memberCount: 0,
              dateOrganized: church.doc || null,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });

            console.log(`    ⛪ Church: ${church.name}`);
            totalChurches++;
          }
        }

        // Process companies
        if (districtData.companies && districtData.companies.length > 0) {
          for (const company of districtData.companies) {
            const companyId = `nsm_company_${districtId}_${company.name.toLowerCase().replace(/[^a-z0-9]+/g, '_')}`;

            await db.collection('churches').doc(companyId).set({
              id: companyId,
              churchName: company.name,
              districtId: districtId,
              regionId: regionId,
              missionId: MISSION_ID,
              status: 'company',
              userId: 'system',
              elderName: '',
              elderEmail: '',
              elderPhone: '',
              memberCount: 0,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });

            console.log(`    🏢 Company: ${company.name}`);
            totalCompanies++;
          }
        }

        // Process groups
        if (districtData.groups && districtData.groups.length > 0) {
          for (const group of districtData.groups) {
            const groupId = `nsm_group_${districtId}_${group.name.toLowerCase().replace(/[^a-z0-9]+/g, '_')}`;

            await db.collection('churches').doc(groupId).set({
              id: groupId,
              churchName: group.name,
              districtId: districtId,
              regionId: regionId,
              missionId: MISSION_ID,
              status: 'group',
              userId: 'system',
              elderName: '',
              elderEmail: '',
              elderPhone: '',
              memberCount: 0,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });

            console.log(`    👥 Group: ${group.name}`);
            totalGroups++;
          }
        }
      }

      console.log('');
    }

    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 UPLOAD SUMMARY');
    console.log('='.repeat(60));
    console.log(`✅ Mission: ${MISSION_NAME}`);
    console.log(`✅ Regions: ${totalRegions}`);
    console.log(`✅ Districts: ${totalDistricts}`);
    console.log(`⛪ Organized Churches: ${totalChurches}`);
    console.log(`🏢 Companies: ${totalCompanies}`);
    console.log(`👥 Groups: ${totalGroups}`);
    console.log(`📈 Total Congregations: ${totalChurches + totalCompanies + totalGroups}`);
    console.log('='.repeat(60));

    console.log('\n🎉 Upload complete! Check your Firebase console to verify the data.');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  }
}

uploadNSMChurches();
