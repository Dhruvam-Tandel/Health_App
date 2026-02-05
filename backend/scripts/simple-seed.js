/**
 * Simple Firebase Collection Creator & Data Seeder
 * 
 * This script will:
 * 1. Create 'verified_doctors' collection (if it doesn't exist)
 * 2. Create 'verified_organizations' collection (if it doesn't exist)
 * 3. Add test data to both collections
 * 
 * Usage: node scripts/simple-seed.js
 */

const admin = require('firebase-admin');
const path = require('path');

console.log('\n🚀 Starting Firebase Setup...\n');

// Initialize Firebase
try {
    const serviceAccount = require(path.join(__dirname, '../firebase-service-account.json'));
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
    console.log('✅ Firebase initialized successfully\n');
} catch (error) {
    console.error('❌ Error initializing Firebase:', error.message);
    process.exit(1);
}

const db = admin.firestore();

// ========================================
// STEP 1: CREATE & POPULATE DOCTORS
// ========================================

async function createDoctorsCollection() {
    console.log('📋 STEP 1: Creating verified_doctors collection...');
    console.log('='.repeat(60));

    const doctors = [
        {
            licenseNumber: 'MH12345',
            fullName: 'Dr. John Smith',
            medicalCouncil: 'Medical Council of India',
            specialization: 'Cardiologist',
            status: 'active',
            verifiedAt: new Date()
        },
        {
            licenseNumber: 'DL67890',
            fullName: 'Dr. Sarah Johnson',
            medicalCouncil: 'Medical Council of India',
            specialization: 'Pediatrician',
            status: 'active',
            verifiedAt: new Date()
        },
        {
            licenseNumber: 'MH54321',
            fullName: 'Dr. Rajesh Kumar',
            medicalCouncil: 'Medical Council of India',
            specialization: 'General Physician',
            status: 'active',
            verifiedAt: new Date()
        },
        {
            licenseNumber: 'KA11111',
            fullName: 'Dr. Priya Sharma',
            medicalCouncil: 'Medical Council of India',
            specialization: 'Dermatologist',
            status: 'active',
            verifiedAt: new Date()
        },
        {
            licenseNumber: 'TN22222',
            fullName: 'Dr. Amit Patel',
            medicalCouncil: 'Medical Council of India',
            specialization: 'Orthopedic Surgeon',
            status: 'active',
            verifiedAt: new Date()
        }
    ];

    console.log(`Adding ${doctors.length} doctors to Firestore...\n`);

    for (const doctor of doctors) {
        try {
            // Add doctor to collection (collection is created automatically)
            const docRef = await db.collection('verified_doctors').add(doctor);
            console.log(`✅ Added: ${doctor.fullName} (${doctor.licenseNumber})`);
            console.log(`   Document ID: ${docRef.id}`);
        } catch (error) {
            console.error(`❌ Error adding ${doctor.fullName}:`, error.message);
        }
    }

    console.log('\n✅ verified_doctors collection created and populated!');
    console.log('='.repeat(60));
}

// ========================================
// STEP 2: CREATE & POPULATE ORGANIZATIONS
// ========================================

async function createOrganizationsCollection() {
    console.log('\n🏥 STEP 2: Creating verified_organizations collection...');
    console.log('='.repeat(60));

    const organizations = [
        {
            id: 'ORG001',
            name: 'City Hospital',
            emailDomains: ['cityhospital.com', 'ch.org'],
            status: 'active',
            createdAt: new Date(),
            employees: [
                {
                    employeeId: 'EMP001',
                    email: 'staff@cityhospital.com',
                    name: 'Jane Doe',
                    department: 'Reception',
                    status: 'active'
                },
                {
                    employeeId: 'EMP002',
                    email: 'admin@cityhospital.com',
                    name: 'John Admin',
                    department: 'Administration',
                    status: 'active'
                },
                {
                    employeeId: 'EMP003',
                    email: 'nurse@cityhospital.com',
                    name: 'Mary Wilson',
                    department: 'Nursing',
                    status: 'active'
                }
            ]
        },
        {
            id: 'ORG002',
            name: 'Metro Clinic',
            emailDomains: ['metroclinic.com', 'mc.org'],
            status: 'active',
            createdAt: new Date(),
            employees: [
                {
                    employeeId: 'MC001',
                    email: 'receptionist@metroclinic.com',
                    name: 'Alice Brown',
                    department: 'Reception',
                    status: 'active'
                },
                {
                    employeeId: 'MC002',
                    email: 'manager@metroclinic.com',
                    name: 'Bob Manager',
                    department: 'Management',
                    status: 'active'
                }
            ]
        },
        {
            id: 'ORG003',
            name: 'Apollo Health Center',
            emailDomains: ['apollohealth.com', 'ahc.org'],
            status: 'active',
            createdAt: new Date(),
            employees: [
                {
                    employeeId: 'AHC001',
                    email: 'staff@apollohealth.com',
                    name: 'David Lee',
                    department: 'General Staff',
                    status: 'active'
                },
                {
                    employeeId: 'AHC002',
                    email: 'coordinator@apollohealth.com',
                    name: 'Emma Davis',
                    department: 'Coordination',
                    status: 'active'
                }
            ]
        }
    ];

    console.log(`Adding ${organizations.length} organizations to Firestore...\n`);

    for (const org of organizations) {
        try {
            // Extract employees
            const employees = org.employees;
            const orgData = {
                name: org.name,
                emailDomains: org.emailDomains,
                status: org.status,
                createdAt: org.createdAt
            };

            // Create organization document (collection is created automatically)
            await db.collection('verified_organizations').doc(org.id).set(orgData);
            console.log(`✅ Added Organization: ${org.name} (${org.id})`);

            // Add employees to subcollection
            console.log(`   Adding ${employees.length} employees...`);
            for (const emp of employees) {
                await db
                    .collection('verified_organizations')
                    .doc(org.id)
                    .collection('employees')
                    .doc(emp.employeeId)
                    .set({
                        ...emp,
                        addedAt: new Date()
                    });
                console.log(`   ✅ Employee: ${emp.name} (${emp.employeeId})`);
            }
            console.log('');
        } catch (error) {
            console.error(`❌ Error adding ${org.name}:`, error.message);
        }
    }

    console.log('✅ verified_organizations collection created and populated!');
    console.log('='.repeat(60));
}

// ========================================
// STEP 3: VERIFY COLLECTIONS
// ========================================

async function verifyCollections() {
    console.log('\n🔍 STEP 3: Verifying collections...');
    console.log('='.repeat(60));

    try {
        // Check doctors
        const doctorsSnapshot = await db.collection('verified_doctors').get();
        console.log(`\n👨‍⚕️  verified_doctors collection:`);
        console.log(`   Total documents: ${doctorsSnapshot.size}`);

        if (doctorsSnapshot.size > 0) {
            console.log('   Doctors:');
            doctorsSnapshot.forEach(doc => {
                const data = doc.data();
                console.log(`   - ${data.fullName} (${data.licenseNumber})`);
            });
        }

        // Check organizations
        const orgsSnapshot = await db.collection('verified_organizations').get();
        console.log(`\n🏥 verified_organizations collection:`);
        console.log(`   Total documents: ${orgsSnapshot.size}`);

        if (orgsSnapshot.size > 0) {
            console.log('   Organizations:');
            for (const orgDoc of orgsSnapshot.docs) {
                const orgData = orgDoc.data();
                const employeesSnapshot = await orgDoc.ref.collection('employees').get();
                console.log(`   - ${orgData.name} (${orgDoc.id})`);
                console.log(`     Domains: ${orgData.emailDomains.join(', ')}`);
                console.log(`     Employees: ${employeesSnapshot.size}`);
            }
        }

        console.log('\n' + '='.repeat(60));
    } catch (error) {
        console.error('❌ Error verifying collections:', error.message);
    }
}

// ========================================
// MAIN EXECUTION
// ========================================

async function main() {
    console.log('╔' + '═'.repeat(58) + '╗');
    console.log('║' + ' '.repeat(10) + 'Firebase Collection Creator & Seeder' + ' '.repeat(12) + '║');
    console.log('╚' + '═'.repeat(58) + '╝');
    console.log('\nThis script will:');
    console.log('1. Create verified_doctors collection');
    console.log('2. Create verified_organizations collection');
    console.log('3. Add test data to both collections');
    console.log('');

    try {
        // Create and populate collections
        await createDoctorsCollection();
        await createOrganizationsCollection();

        // Verify everything was created
        await verifyCollections();

        // Show test credentials
        console.log('\n✅ SUCCESS! Collections created and data added!\n');
        console.log('╔' + '═'.repeat(58) + '╗');
        console.log('║' + ' '.repeat(18) + 'TEST CREDENTIALS' + ' '.repeat(24) + '║');
        console.log('╚' + '═'.repeat(58) + '╝');
        console.log('\n📱 Use these credentials to test in your Flutter app:\n');

        console.log('👨‍⚕️  DOCTOR SIGNUP:');
        console.log('   License Number: MH12345');
        console.log('   Full Name: Dr. John Smith');
        console.log('   Medical Council: Medical Council of India');

        console.log('\n👔 STAFF SIGNUP:');
        console.log('   Email: staff@cityhospital.com');
        console.log('   Organization ID: ORG001');
        console.log('   Employee ID: EMP001');

        console.log('\n👤 PATIENT SIGNUP:');
        console.log('   Any email (no verification needed)');

        console.log('\n' + '='.repeat(60));
        console.log('🎉 You can now test authentication in your Flutter app!');
        console.log('='.repeat(60) + '\n');

        process.exit(0);
    } catch (error) {
        console.error('\n❌ FATAL ERROR:', error);
        console.error('\nPlease check:');
        console.error('1. firebase-service-account.json exists in backend folder');
        console.error('2. You have internet connection');
        console.error('3. Firebase project is accessible\n');
        process.exit(1);
    }
}

// Run the script
main();
