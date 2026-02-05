const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require(path.join(__dirname, '../../firebase-service-account.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: `https://health-vault-14507.firebaseio.com`
});

const db = admin.firestore();
const auth = admin.auth();

module.exports = { admin, db, auth };
