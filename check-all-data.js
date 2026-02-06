const admin = require('firebase-admin');

if (!admin.apps.length) {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'tutornotification'
  });
}

const db = admin.firestore();

async function checkAllData() {
  const instituteId = 'test-institute-1769767330952';
  const batchId = '87XBA5OBFE0z11kP3v8e';
  
  // Check institute
  const institute = await db.collection('institutes').doc(instituteId).get();
  console.log('Institute:', institute.exists ? 'EXISTS' : 'NOT FOUND');
  
  // List all subcollections
  const collections = await db.collection('institutes').doc(instituteId).listCollections();
  console.log('\nInstitute subcollections:');
  for (const col of collections) {
    const docs = await col.get();
    console.log(`  - ${col.id}: ${docs.size} documents`);
  }
  
  // Check batch subcollections
  const batchCollections = await db.collection('institutes').doc(instituteId)
    .collection('batches').doc(batchId).listCollections();
  console.log('\nBatch subcollections:');
  for (const col of batchCollections) {
    const docs = await col.get();
    console.log(`  - ${col.id}: ${docs.size} documents`);
    
    // If attendance, show details
    if (col.id === 'attendance') {
      docs.forEach(doc => {
        console.log(`      ${doc.id}:`, JSON.stringify(doc.data(), null, 2).substring(0, 200));
      });
    }
  }
}

checkAllData()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
