// seed.js
// Run this AFTER the emulator is up, any time you need testuser1 recreated.
// Usage:  node seed.js

process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'shealert-222cc' }); // <-- replace with your actual project ID if different

const db = admin.firestore();

async function seed() {
  await db.collection('users').doc('testuser1').set({
    lastKnownLocation: new admin.firestore.GeoPoint(13.0827, 80.2707), // Chennai coords, change as needed
  });

  console.log('✅ testuser1 seeded with lastKnownLocation geopoint.');
  process.exit(0);
}

seed().catch((err) => {
  console.error('❌ Seed failed:', err);
  process.exit(1);
});