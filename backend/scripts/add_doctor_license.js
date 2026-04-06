const admin = require('firebase-admin');
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function addLicense() {
    const licenseNumber = "MCI-2012-001";
    try {
        const docRef = db.collection('verified_doctors').doc();
        await docRef.set({
            doctorName: "Mayank",
            email: "dhruvamtandel0412@gmail.com",
            licenseNumber: licenseNumber,
            specialization: "General Practice",
            isVerified: true,
            addedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`Successfully added license: ${licenseNumber}`);
        process.exit(0);
    } catch (error) {
        console.error('Error adding license:', error);
        process.exit(1);
    }
}

addLicense();
