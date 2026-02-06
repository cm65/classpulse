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

async function checkUsers() {
  console.log('Listing all anonymous users:');
  const result = await auth.listUsers(100);
  const anonUsers = result.users.filter(u => u.providerData.length === 0);
  
  for (const user of anonUsers) {
    console.log(`\nUser: ${user.uid}`);
    console.log(`  Created: ${user.metadata.creationTime}`);
    console.log(`  Last sign in: ${user.metadata.lastSignInTime}`);
    
    // Check if teacher doc exists
    const teacherDoc = await db.collection('teachers').doc(user.uid).get();
    if (teacherDoc.exists) {
      console.log(`  Teacher doc: EXISTS`);
      console.log(`  Institute ID: ${teacherDoc.data().instituteId}`);
    } else {
      console.log(`  Teacher doc: MISSING`);
    }
  }
}

checkUsers()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
