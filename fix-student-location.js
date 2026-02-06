const admin = require('firebase-admin');

if (!admin.apps.length) {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'tutornotification'
  });
}

const db = admin.firestore();

async function fixStudentLocation() {
  const instituteId = 'test-institute-1769767330952';
  const batchId = '87XBA5OBFE0z11kP3v8e';
  const now = admin.firestore.Timestamp.now();
  
  // Create student in the correct location (under batch)
  console.log('Creating student in correct location...');
  const studentRef = db
    .collection('institutes')
    .doc(instituteId)
    .collection('batches')
    .doc(batchId)
    .collection('students')
    .doc();
    
  await studentRef.set({
    name: 'Rahul Kumar',
    parentName: 'Suresh Kumar',
    parentPhone: '+919876543210',
    parentEmail: 'suresh@example.com',
    isActive: true,
    createdAt: now,
    updatedAt: now
  });
  
  console.log(`✅ Student created at: institutes/${instituteId}/batches/${batchId}/students/${studentRef.id}`);
  
  // Add another student for testing
  const student2Ref = db
    .collection('institutes')
    .doc(instituteId)
    .collection('batches')
    .doc(batchId)
    .collection('students')
    .doc();
    
  await student2Ref.set({
    name: 'Priya Sharma',
    parentName: 'Vikram Sharma',
    parentPhone: '+919812345678',
    parentEmail: 'vikram@example.com',
    isActive: true,
    createdAt: now,
    updatedAt: now
  });
  
  console.log(`✅ Second student created: ${student2Ref.id}`);
}

fixStudentLocation()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
