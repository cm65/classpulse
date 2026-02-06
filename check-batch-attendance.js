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
  const batchId = '87XBA5OBFE0z11kP3v8e';
  
  // Check attendance under batch
  const batchAttendance = await db
    .collection('institutes').doc(instituteId)
    .collection('batches').doc(batchId)
    .collection('attendance').get();
    
  console.log(`Batch attendance records: ${batchAttendance.size}`);
  batchAttendance.forEach(doc => {
    console.log(`  ${doc.id}:`, JSON.stringify(doc.data()).substring(0, 300));
  });
}

check().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
