const admin = require('firebase-admin');

// Initialize if not already
if (!admin.apps.length) {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'tutornotification'
  });
}

const db = admin.firestore();
const auth = admin.auth();

async function fixUserData() {
  // Get all anonymous users
  const result = await auth.listUsers(100);
  const anonUsers = result.users.filter(u => u.providerData.length === 0);
  
  // Use the existing institute ID
  const instituteId = 'test-institute-1769767330952';
  const now = admin.firestore.Timestamp.now();
  
  // Create teacher docs for all anonymous users that don't have one
  for (const user of anonUsers) {
    const teacherDoc = await db.collection('teachers').doc(user.uid).get();
    if (!teacherDoc.exists) {
      console.log(`Creating teacher doc for user: ${user.uid}`);
      await db.collection('teachers').doc(user.uid).set({
        instituteId: instituteId,
        name: 'Test Teacher',
        phone: '+919999999999',
        role: 'admin',
        isActive: true,
        createdAt: now,
        lastLoginAt: now
      });
      console.log(`✅ Teacher created for ${user.uid}`);
    } else {
      console.log(`User ${user.uid} already has teacher doc`);
    }
  }
  
  console.log('\n✅ All users now have teacher documents');
}

fixUserData()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
