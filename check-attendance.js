const admin = require('firebase-admin');

if (!admin.apps.length) {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'tutornotification'
  });
}

const db = admin.firestore();

async function checkAttendance() {
  const instituteId = 'test-institute-1769767330952';
  
  // Get all attendance records
  const attendanceSnap = await db
    .collection('institutes')
    .doc(instituteId)
    .collection('attendance')
    .orderBy('createdAt', 'desc')
    .limit(5)
    .get();
    
  console.log(`Found ${attendanceSnap.size} attendance record(s):\n`);
  
  for (const doc of attendanceSnap.docs) {
    const data = doc.data();
    console.log(`Attendance ID: ${doc.id}`);
    console.log(`  Batch: ${data.batchName}`);
    console.log(`  Date: ${data.date}`);
    console.log(`  Present: ${data.presentCount}, Absent: ${data.absentCount}, Late: ${data.lateCount}`);
    console.log(`  Status: ${data.status}`);
    console.log(`  Created: ${data.createdAt?.toDate()}`);
    
    // Check records subcollection
    const recordsSnap = await doc.ref.collection('records').get();
    console.log(`  Records (${recordsSnap.size}):`);
    recordsSnap.forEach(rec => {
      const r = rec.data();
      console.log(`    - ${r.studentName}: ${r.status} (notified: ${r.notified || false})`);
    });
    console.log('');
  }
}

checkAttendance()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
