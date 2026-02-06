const admin = require('firebase-admin');

// Initialize with service account key
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'tutornotification'
});

const db = admin.firestore();
const auth = admin.auth();

async function setupTestUser() {
  console.log('Finding anonymous users...');
  
  // List all users and find anonymous ones
  const listUsersResult = await auth.listUsers(100);
  const anonymousUsers = listUsersResult.users.filter(user => 
    user.providerData.length === 0 // Anonymous users have no providers
  );
  
  console.log(`Found ${anonymousUsers.length} anonymous user(s)`);
  
  if (anonymousUsers.length === 0) {
    console.log('No anonymous users found. Please run the app and click "Skip to Register" first.');
    return;
  }
  
  // Use the most recent anonymous user
  const user = anonymousUsers[anonymousUsers.length - 1];
  console.log(`Using anonymous user: ${user.uid}`);
  
  const now = admin.firestore.Timestamp.now();
  const instituteId = 'test-institute-' + Date.now();
  
  // Create Institute document
  console.log('Creating institute...');
  await db.collection('institutes').doc(instituteId).set({
    name: 'Test Coaching Centre',
    adminName: 'Test Teacher',
    phone: '+919999999999',
    email: 'test@example.com',
    address: '123 Test Street, Test City',
    settings: {
      attendanceEditWindowMinutes: 120,
      defaultLanguage: 'en',
      notificationTemplates: {
        presentTemplate: '{student} attended {batch} on {date} at {time}. Thank you!',
        absentTemplate: '{student} was ABSENT from {batch} on {date}. Please contact the institute if this is unexpected.',
        lateTemplate: '{student} was LATE to {batch} on {date}. Arrived at {time}.',
        smsTemplate: '{institute}: {student} was {status} for {batch} on {date}.'
      }
    },
    createdAt: now,
    updatedAt: now
  });
  console.log(`Institute created with ID: ${instituteId}`);
  
  // Create Teacher document for the anonymous user
  console.log('Creating teacher profile...');
  await db.collection('teachers').doc(user.uid).set({
    instituteId: instituteId,
    name: 'Test Teacher',
    phone: '+919999999999',
    role: 'admin',
    isActive: true,
    createdAt: now,
    lastLoginAt: now
  });
  console.log(`Teacher profile created for user: ${user.uid}`);
  
  // Create a test batch
  console.log('Creating test batch...');
  const batchRef = db.collection('institutes').doc(instituteId).collection('batches').doc();
  await batchRef.set({
    name: 'Morning Math Class',
    description: 'Math tuition for Class 10',
    schedule: 'Mon, Wed, Fri - 9:00 AM',
    isActive: true,
    createdAt: now,
    updatedAt: now
  });
  console.log(`Batch created with ID: ${batchRef.id}`);
  
  // Create a test student
  console.log('Creating test student...');
  const studentRef = db.collection('institutes').doc(instituteId).collection('students').doc();
  await studentRef.set({
    name: 'Rahul Kumar',
    parentName: 'Suresh Kumar',
    parentPhone: '+919876543210',
    parentEmail: 'suresh@example.com',
    batchId: batchRef.id,
    batchName: 'Morning Math Class',
    isActive: true,
    createdAt: now,
    updatedAt: now
  });
  console.log(`Student created with ID: ${studentRef.id}`);
  
  console.log('\n✅ Test data setup complete!');
  console.log(`Institute ID: ${instituteId}`);
  console.log(`User ID: ${user.uid}`);
  console.log(`Batch ID: ${batchRef.id}`);
  console.log(`Student ID: ${studentRef.id}`);
  console.log('\nPlease restart the app to see the changes.');
}

setupTestUser()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
