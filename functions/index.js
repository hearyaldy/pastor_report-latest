const {onCall, HttpsError} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

const roleAliases = {
  'Super Admin': 'superAdmin',
  'Admin': 'admin',
  'Mission Admin': 'missionAdmin',
  'Ministerial Secretary': 'ministerialSecretary',
  'Officer': 'officer',
  'Director': 'director',
  'Editor': 'editor',
  'Church Treasurer': 'churchTreasurer',
  'District Pastor': 'districtPastor',
  'User': 'user',
};

const roleHierarchy = {
  superAdmin: 100,
  admin: 90,
  missionAdmin: 80,
  ministerialSecretary: 70,
  officer: 60,
  director: 50,
  editor: 40,
  churchTreasurer: 30,
  districtPastor: 20,
  user: 10,
};

function normalizeRole(userData) {
  const role = userData.userRole || userData.role || 'user';
  return roleAliases[role] || role;
}

function canDeleteUser(callerData, targetData) {
  const callerRole = normalizeRole(callerData);
  const targetRole = normalizeRole(targetData);
  const callerLevel = roleHierarchy[callerRole] || 0;
  const targetLevel = roleHierarchy[targetRole] || 0;

  if (!['superAdmin', 'admin', 'missionAdmin'].includes(callerRole)) {
    return false;
  }

  if (callerLevel <= targetLevel) {
    return false;
  }

  if (callerRole === 'missionAdmin') {
    return Boolean(callerData.mission) &&
      callerData.mission === targetData.mission &&
      !['superAdmin', 'admin', 'missionAdmin'].includes(targetRole);
  }

  return true;
}

async function deleteQueryInBatches(querySnapshot) {
  const firestore = admin.firestore();
  let batch = firestore.batch();
  let operationCount = 0;

  for (const doc of querySnapshot.docs) {
    batch.delete(doc.ref);
    operationCount++;

    if (operationCount === 450) {
      await batch.commit();
      batch = firestore.batch();
      operationCount = 0;
    }
  }

  if (operationCount > 0) {
    await batch.commit();
  }
}

/**
 * Callable Cloud Function to delete a user completely
 * Deletes:
 * 1. All Borang B reports associated with the user
 * 2. The user document from Firestore
 * 3. The Firebase Authentication account
 */
exports.deleteUserCompletely = onCall(async (request) => {
  // Check if the caller is authenticated
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'User must be authenticated to delete users'
    );
  }

  const {uid} = request.data;

  if (!uid) {
    throw new HttpsError('invalid-argument', 'User ID is required');
  }

  if (uid === request.auth.uid) {
    throw new HttpsError(
      'permission-denied',
      'You cannot delete your own account from the admin tool'
    );
  }

  try {
    // Get the caller's user document to check permissions
    const callerDoc = await admin
      .firestore()
      .collection('users')
      .doc(request.auth.uid)
      .get();

    if (!callerDoc.exists) {
      throw new HttpsError(
        'permission-denied',
        'Caller user document not found'
      );
    }

    const callerData = callerDoc.data();

    // Get the target user's role
    const targetDoc = await admin
      .firestore()
      .collection('users')
      .doc(uid)
      .get();

    if (!targetDoc.exists) {
      throw new HttpsError('not-found', 'Target user not found');
    }

    const targetData = targetDoc.data();

    if (!canDeleteUser(callerData, targetData)) {
      throw new HttpsError(
        'permission-denied',
        'You do not have permission to delete this user'
      );
    }

    console.log(`Deleting user ${uid} and all associated data...`);

    // Step 1: Delete all Borang B reports
    const borangBReports = await admin
      .firestore()
      .collection('borang_b_reports')
      .where('userId', '==', uid)
      .get();

    await deleteQueryInBatches(borangBReports);

    console.log(`Deleted ${borangBReports.size} Borang B reports for user ${uid}`);

    // Step 2: Delete user document from Firestore
    await admin.firestore().collection('users').doc(uid).delete();
    console.log(`Deleted Firestore user document for ${uid}`);

    // Step 3: Delete Firebase Auth account
    await admin.auth().deleteUser(uid);
    console.log(`Deleted Firebase Auth account for ${uid}`);

    return {
      success: true,
      message: 'User and all associated data deleted successfully',
      deletedBorangBReports: borangBReports.size,
    };
  } catch (error) {
    console.error('Error deleting user:', error);

    // Re-throw HttpsError as-is
    if (error instanceof HttpsError) {
      throw error;
    }

    // Wrap other errors
    throw new HttpsError('internal', `Failed to delete user: ${error.message}`);
  }
});
