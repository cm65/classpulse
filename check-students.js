const admin = require('firebase-admin');

if (!admin.apps.length) {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'tutornotification'
  });
}

const db = admin.firestore();

async function checkStudents() {
  const instituteId = 'test-institute-1769767330952';
  
  // List batches
  const batches = await db.collection('institutes').doc(instituteId).collection('batches').get();
  console.log('Batches:');
  batches.forEach(doc => {
    console.log(`  ${doc.id}: ${doc.data().name}`);
  });
  
  // List students
  const students = await db.collection('institutes').doc(instituteId).collection('students').get();
  console.log('\nStudents:');
  students.forEach(doc => {
    const data = doc.data();
    console.log(`  ${doc.id}: ${data.name} (batchId: ${data.batchId})`);
  });
}

checkStudents().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
