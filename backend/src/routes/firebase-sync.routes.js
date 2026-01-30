const express = require('express');
const router = express.Router();
const prisma = require('../config/database');
const { z } = require('zod');

// Initialize Firebase Admin (optional - only if firebase-admin is installed)
let admin = null;
let firebaseAvailable = false;

try {
    admin = require('firebase-admin');

    if (!admin.apps.length) {
        try {
            const serviceAccount = require(process.env.FIREBASE_SERVICE_ACCOUNT_PATH || '../firebase-service-account.json');
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount)
            });
            firebaseAvailable = true;
            console.log('✅ Firebase Admin initialized');
        } catch (error) {
            console.warn('⚠️ Firebase service account not found. Hybrid auth disabled.');
            console.warn('   To enable: Download service account JSON from Firebase Console');
        }
    } else {
        firebaseAvailable = true;
    }
} catch (error) {
    console.log('ℹ️  firebase-admin not installed. Hybrid auth disabled.');
    console.log('   To enable: npm install firebase-admin');
}

// Middleware to verify Firebase token
async function verifyFirebaseToken(req, res, next) {
    // Check if Firebase is available
    if (!firebaseAvailable || !admin) {
        return res.status(503).json({
            error: 'Firebase hybrid auth not configured. Please install firebase-admin and configure service account.'
        });
    }

    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'No token provided' });
        }

        const token = authHeader.split('Bearer ')[1];

        // Verify Firebase ID token
        const decodedToken = await admin.auth().verifyIdToken(token);
        req.firebaseUser = decodedToken;

        next();
    } catch (error) {
        console.error('Token verification error:', error);
        res.status(401).json({ error: 'Invalid token' });
    }
}

// Validation schema
const syncUserSchema = z.object({
    firebaseUid: z.string(),
    email: z.string().email(),
    role: z.enum(['PATIENT', 'DOCTOR', 'STAFF']),
    fullName: z.string().min(2),
    // Doctor fields
    specialization: z.string().optional(),
    licenseNumber: z.string().optional(),
    medicalCouncil: z.string().optional(),
    // Staff fields
    organizationId: z.string().optional(),
    employeeId: z.string().optional(),
    department: z.string().optional(),
});

// POST /api/auth/sync-firebase-user
// Syncs a Firebase user to PostgreSQL database
router.post('/sync-firebase-user', verifyFirebaseToken, async (req, res) => {
    try {
        const data = syncUserSchema.parse(req.body);

        // Verify the Firebase UID matches the token
        if (data.firebaseUid !== req.firebaseUser.uid) {
            return res.status(403).json({ error: 'Firebase UID mismatch' });
        }

        // Check if user already exists
        let user = await prisma.user.findUnique({
            where: { firebaseUid: data.firebaseUid },
            include: {
                patient: true,
                doctor: true,
                staff: true,
            }
        });

        if (user) {
            // User already synced, just return their data
            console.log(`✅ User already synced: ${user.email}`);
            return res.json({
                message: 'User already synced',
                user: {
                    id: user.id,
                    firebaseUid: user.firebaseUid,
                    email: user.email,
                    role: user.role,
                    accountStatus: user.accountStatus,
                    profile: user.patient || user.doctor || user.staff,
                }
            });
        }

        // Create new user in PostgreSQL
        user = await prisma.user.create({
            data: {
                firebaseUid: data.firebaseUid,
                email: data.email,
                role: data.role,
                emailVerified: req.firebaseUser.email_verified || false,
                accountStatus: data.role === 'PATIENT' ? 'ACTIVE' : 'PENDING_VERIFICATION',
                ...(data.role === 'PATIENT' && {
                    patient: {
                        create: {
                            fullName: data.fullName,
                        }
                    }
                }),
                ...(data.role === 'DOCTOR' && {
                    doctor: {
                        create: {
                            fullName: data.fullName,
                            specialization: data.specialization || 'General Medicine',
                            licenseNumber: data.licenseNumber,
                            medicalCouncil: data.medicalCouncil,
                            verificationStatus: 'PENDING',
                        }
                    }
                }),
                ...(data.role === 'STAFF' && {
                    staff: {
                        create: {
                            fullName: data.fullName,
                            organizationId: data.organizationId,
                            employeeId: data.employeeId,
                            department: data.department,
                            verificationStatus: 'PENDING',
                        }
                    }
                }),
            },
            include: {
                patient: true,
                doctor: true,
                staff: true,
            }
        });

        console.log(`✅ Firebase user synced to PostgreSQL: ${user.email}`);

        res.status(201).json({
            message: 'User synced successfully',
            user: {
                id: user.id,
                firebaseUid: user.firebaseUid,
                email: user.email,
                role: user.role,
                accountStatus: user.accountStatus,
                profile: user.patient || user.doctor || user.staff,
            }
        });

    } catch (error) {
        if (error instanceof z.ZodError) {
            return res.status(400).json({ error: error.errors });
        }
        console.error('Sync user error:', error);
        res.status(500).json({ error: 'Failed to sync user' });
    }
});

// GET /api/users/profile
// Get user profile from PostgreSQL using Firebase token
router.get('/profile', verifyFirebaseToken, async (req, res) => {
    try {
        const user = await prisma.user.findUnique({
            where: { firebaseUid: req.firebaseUser.uid },
            include: {
                patient: true,
                doctor: true,
                staff: true,
            }
        });

        if (!user) {
            return res.status(404).json({ error: 'User not found in database' });
        }

        res.json({
            id: user.id,
            firebaseUid: user.firebaseUid,
            email: user.email,
            role: user.role,
            accountStatus: user.accountStatus,
            emailVerified: user.emailVerified,
            profile: user.patient || user.doctor || user.staff,
        });

    } catch (error) {
        console.error('Get profile error:', error);
        res.status(500).json({ error: 'Failed to get profile' });
    }
});

module.exports = { router, verifyFirebaseToken };
