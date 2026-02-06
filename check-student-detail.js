const admin = require('firebase-admin');

if (!admin.apps.length) {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'tutornotification'
  });
}

const db = admin.firestore();

async function check() {
  const instituteId = 'test-institute-1769767330952';
  const studentDoc = await db.collection('institutes').doc(instituteId).collection('students').doc('uaKEUsXHCsYxkgE9oDGV').get();
  console.log('Student document:');
  console.log(JSON.stringify(studentDoc.data(), null, 2));
}

check().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
