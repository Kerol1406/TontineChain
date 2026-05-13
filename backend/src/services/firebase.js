const admin = require('firebase-admin');
const { config } = require('./config');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: config.firebaseProjectId,
      clientEmail: config.firebaseClientEmail,
      privateKey: config.firebasePrivateKey
    })
  });
}

const db = admin.firestore();

module.exports = { admin, db };
