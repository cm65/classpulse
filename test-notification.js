// Test script to create attendance with records simultaneously
const admin = require('firebase-admin');

// Initialize with service account key
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'tutornotification'
});

const db = admin.firestore();

async function createAttendanceWithRecords() {
  const instituteId = 'test-institute';
  const attendanceId = 'attendance-sms-test-' + Date.now();

  console.log('Creating attendance document and records...');

  // Use a batch to create both the attendance doc and records almost simultaneously
  const batch = db.batch();

  // Reference to the attendance document
  const attendanceRef = db
    .collection('institutes')
    .doc(instituteId)
    .collection('attendance')
    .doc(attendanceId);

  // Reference to the student record
  const recordRef = attendanceRef.collection('records').doc('student1');

  // Set the attendance document
  batch.set(attendanceRef, {
    batchId: 'test-batch',
    date: admin.firestore.Timestamp.now(),
    submittedBy: 'test-script',
    submittedAt: admin.firestore.Timestamp.now()
  });

  // Set the student record
  batch.set(recordRef, {
    studentId: 'student1',
    studentName: 'Test Student',
    parentPhone: '8368423820',
    status: 'absent',
    notificationStatus: 'pending',
    notificationChannel: ''
  });

  // Commit the batch
  await batch.commit();

  console.log('Created attendance14 with records!');
  console.log('The Cloud Function should trigger and find 1 notification to send.');
  console.log('Check your WhatsApp for a message!');
}

createAttendanceWithRecords()
  .then(() => {
    console.log('Done!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Error:', error);
    process.exit(1);
  });
