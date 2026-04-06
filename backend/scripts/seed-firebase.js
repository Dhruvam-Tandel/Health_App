const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ============================================================================
// TEST STAFF ACCOUNT - CHANGE THIS TO YOUR EMAIL
// ============================================================================

// 👇 CHANGE THIS TO YOUR EMAIL ADDRESS
const YOUR_EMAIL = 'dhruvamtandel0412@gmail.com'; // Your email for admin staff account


const TEST_STAFF = {
    email: YOUR_EMAIL,
    organizationId: 'ORG001',
    employeeId: 'EMP001',
    organizationName: 'City Hospital',
    department: 'Administration',
    fullName: 'Admin Staff',
    phone: '+1234567890',
};

// ============================================================================
// VERIFIED ORGANIZATIONS
// ============================================================================

const VERIFIED_ORGANIZATIONS = [
    {
        id: 'ORG001',
        name: 'City Hospital',
        address: '123 Main Street, New York, NY 10001',
        phone: '+1-555-0101',
        email: 'contact@cityhospital.com',
        type: 'Hospital',
        verified: true,
        emailDomains: ['cityhospital.com', 'gmail.com'], // Added gmail.com for testing
        createdAt: new Date().toISOString(),
    },
    {
        id: 'ORG002',
        name: 'Metro Medical Center',
        address: '456 Park Avenue, Los Angeles, CA 90001',
        phone: '+1-555-0102',
        email: 'info@metromedical.com',
        type: 'Medical Center',
        verified: true,
        emailDomains: ['metromedical.com', 'gmail.com'], // Added gmail.com for testing
        createdAt: new Date().toISOString(),
    },
    {
        id: 'ORG003',
        name: 'Downtown Clinic',
        address: '789 Oak Street, Chicago, IL 60601',
        phone: '+1-555-0103',
        email: 'contact@downtownclinic.com',
        type: 'Clinic',
        verified: true,
        emailDomains: ['downtownclinic.com', 'gmail.com'], // Added gmail.com for testing
        createdAt: new Date().toISOString(),
    },
];


// ============================================================================
// VERIFIED DOCTORS
// ============================================================================

const VERIFIED_DOCTORS = [
    {
        licenseNumber: 'MH12345',
        fullName: 'Dr. John Smith',
        specialization: 'Cardiology',
        medicalCouncil: 'Maharashtra Medical Council',
        qualification: 'MBBS, MD (Cardiology)',
        verified: true,
        createdAt: new Date().toISOString(),
    },
    {
        licenseNumber: 'DL67890',
        fullName: 'Dr. Sarah Johnson',
        specialization: 'Pediatrics',
        medicalCouncil: 'Delhi Medical Council',
        qualification: 'MBBS, MD (Pediatrics)',
        verified: true,
        createdAt: new Date().toISOString(),
    },
    {
        licenseNumber: 'KA11223',
        fullName: 'Dr. Michael Brown',
        specialization: 'Orthopedics',
        medicalCouncil: 'Karnataka Medical Council',
        qualification: 'MBBS, MS (Orthopedics)',
        verified: true,
        createdAt: new Date().toISOString(),
    },
    {
        licenseNumber: 'TN44556',
        fullName: 'Dr. Emily Davis',
        specialization: 'Dermatology',
        medicalCouncil: 'Tamil Nadu Medical Council',
        qualification: 'MBBS, MD (Dermatology)',
        verified: true,
        createdAt: new Date().toISOString(),
    },
    {
        licenseNumber: 'GJ77889',
        fullName: 'Dr. Robert Wilson',
        specialization: 'Neurology',
        medicalCouncil: 'Gujarat Medical Council',
        qualification: 'MBBS, DM (Neurology)',
        verified: true,
        createdAt: new Date().toISOString(),
    },
];

// ============================================================================
// VERIFIED STAFF MEMBERS
// ============================================================================

const VERIFIED_STAFF = [
    {
        organizationId: 'ORG001',
        employeeId: 'EMP001',
        email: YOUR_EMAIL, // Uses your custom email
        fullName: 'Admin Staff',
        department: 'Administration',
        position: 'Admin',
        verified: true,
        createdAt: new Date().toISOString(),
    },
    {
        organizationId: 'ORG001',
        employeeId: 'EMP002',
        email: 'nurse.jane@cityhospital.com',
        fullName: 'Jane Nurse',
        department: 'Nursing',
        position: 'Senior Nurse',
        verified: true,
        createdAt: new Date().toISOString(),
    },
    {
        organizationId: 'ORG002',
        employeeId: 'EMP003',
        email: 'admin.metro@metromedical.com',
        fullName: 'Metro Admin',
        department: 'Administration',
        position: 'Admin Officer',
        verified: true,
        createdAt: new Date().toISOString(),
    },
];

// ============================================================================
// SEED FUNCTIONS
// ============================================================================

async function seedVerifiedOrganizations() {
    console.log('\n📋 Seeding verified organizations...');

    for (const org of VERIFIED_ORGANIZATIONS) {
        try {
            await db.collection('verified_organizations').doc(org.id).set(org);
            console.log(`✅ Added organization: ${org.name} (${org.id})`);
        } catch (error) {
            console.error(`❌ Error adding organization ${org.id}:`, error.message);
        }
    }
}

async function seedVerifiedDoctors() {
    console.log('\n👨‍⚕️ Seeding verified doctors...');

    for (const doctor of VERIFIED_DOCTORS) {
        try {
            await db.collection('verified_doctors').doc(doctor.licenseNumber).set(doctor);
            console.log(`✅ Added doctor: ${doctor.fullName} (${doctor.licenseNumber})`);
        } catch (error) {
            console.error(`❌ Error adding doctor ${doctor.licenseNumber}:`, error.message);
        }
    }
}

async function seedVerifiedStaff() {
    console.log('\n👔 Seeding verified staff members...');

    for (const staff of VERIFIED_STAFF) {
        try {
            const docId = `${staff.organizationId}_${staff.employeeId}`;
            await db.collection('verified_staff').doc(docId).set(staff);
            console.log(`✅ Added staff: ${staff.fullName} (${staff.organizationId}/${staff.employeeId})`);
        } catch (error) {
            console.error(`❌ Error adding staff ${staff.employeeId}:`, error.message);
        }
    }
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================

async function seedAll() {
    console.log('🌱 Starting Firebase seeding process...\n');
    console.log('='.repeat(60));

    try {
        await seedVerifiedOrganizations();
        await seedVerifiedDoctors();
        await seedVerifiedStaff();

        console.log('\n' + '='.repeat(60));
        console.log('\n✅ Seeding completed successfully!');
        console.log('\n📊 Summary:');
        console.log(`   - Organizations: ${VERIFIED_ORGANIZATIONS.length}`);
        console.log(`   - Doctors: ${VERIFIED_DOCTORS.length}`);
        console.log(`   - Staff Members: ${VERIFIED_STAFF.length}`);

        console.log('\n🧪 Test Credentials:');
        console.log('\n   📧 Test Staff Account:');
        console.log(`      Email: ${TEST_STAFF.email}`);
        console.log(`      Organization ID: ${TEST_STAFF.organizationId}`);
        console.log(`      Employee ID: ${TEST_STAFF.employeeId}`);
        console.log(`      Password: (Set during signup)`);

        console.log('\n   👨‍⚕️ Test Doctor Licenses:');
        VERIFIED_DOCTORS.forEach(doc => {
            console.log(`      - ${doc.licenseNumber} (${doc.fullName})`);
        });

        console.log('\n   🏥 Test Organizations:');
        VERIFIED_ORGANIZATIONS.forEach(org => {
            console.log(`      - ${org.id} (${org.name})`);
        });

        console.log('\n' + '='.repeat(60));

    } catch (error) {
        console.error('\n❌ Seeding failed:', error);
        process.exit(1);
    }

    process.exit(0);
}

// Run seeding
seedAll();
