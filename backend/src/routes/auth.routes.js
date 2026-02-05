const express = require('express');
const router = express.Router();
const { db, auth } = require('../config/firebase');
const { verifyToken } = require('../middleware/auth');

/**
 * @route   POST /api/auth/verify-doctor
 * @desc    Verify doctor credentials against Firestore
 * @access  Public
 */
router.post('/verify-doctor', async (req, res) => {
    try {
        const { licenseNumber, fullName, medicalCouncil } = req.body;

        if (!licenseNumber || !fullName || !medicalCouncil) {
            return res.status(400).json({
                success: false,
                message: 'License number, full name, and medical council are required'
            });
        }

        // Query verified_doctors collection
        const doctorsRef = db.collection('verified_doctors');
        const snapshot = await doctorsRef
            .where('licenseNumber', '==', licenseNumber.toUpperCase())
            .where('fullName', '==', fullName.trim())
            .where('medicalCouncil', '==', medicalCouncil)
            .limit(1)
            .get();

        if (snapshot.empty) {
            return res.status(404).json({
                success: false,
                message: 'Doctor credentials not found or invalid'
            });
        }

        const doctorData = snapshot.docs[0].data();

        return res.status(200).json({
            success: true,
            message: 'Doctor verified successfully',
            data: {
                licenseNumber: doctorData.licenseNumber,
                fullName: doctorData.fullName,
                medicalCouncil: doctorData.medicalCouncil,
                verified: true
            }
        });
    } catch (error) {
        console.error('Doctor verification error:', error);
        return res.status(500).json({
            success: false,
            message: 'Error verifying doctor credentials',
            error: error.message
        });
    }
});

/**
 * @route   POST /api/auth/verify-staff
 * @desc    Verify staff credentials against Firestore
 * @access  Public
 */
router.post('/verify-staff', async (req, res) => {
    try {
        const { email, organizationId, employeeId } = req.body;

        if (!email || !organizationId || !employeeId) {
            return res.status(400).json({
                success: false,
                message: 'Email, organization ID, and employee ID are required'
            });
        }

        // Check if organization exists
        const orgDoc = await db.collection('verified_organizations').doc(organizationId).get();

        if (!orgDoc.exists) {
            return res.status(404).json({
                success: false,
                message: 'Organization not found'
            });
        }

        const orgData = orgDoc.data();
        const allowedDomains = orgData.emailDomains || [];

        // Check email domain
        const emailDomain = email.split('@')[1].toLowerCase();
        if (!allowedDomains.includes(emailDomain)) {
            return res.status(403).json({
                success: false,
                message: 'Email domain not authorized for this organization'
            });
        }

        // Check employee ID
        const employeeDoc = await db
            .collection('verified_organizations')
            .doc(organizationId)
            .collection('employees')
            .doc(employeeId)
            .get();

        if (!employeeDoc.exists) {
            return res.status(404).json({
                success: false,
                message: 'Employee ID not found in organization'
            });
        }

        return res.status(200).json({
            success: true,
            message: 'Staff verified successfully',
            data: {
                organizationId,
                organizationName: orgData.name,
                employeeId,
                verified: true
            }
        });
    } catch (error) {
        console.error('Staff verification error:', error);
        return res.status(500).json({
            success: false,
            message: 'Error verifying staff credentials',
            error: error.message
        });
    }
});

/**
 * @route   GET /api/auth/profile
 * @desc    Get user profile
 * @access  Private
 */
router.get('/profile', verifyToken, async (req, res) => {
    try {
        const userDoc = await db.collection('users').doc(req.user.uid).get();

        if (!userDoc.exists) {
            return res.status(404).json({
                success: false,
                message: 'User profile not found'
            });
        }

        const userData = userDoc.data();

        return res.status(200).json({
            success: true,
            data: {
                uid: userData.uid,
                email: userData.email,
                role: userData.role,
                emailVerified: userData.emailVerified,
                accountStatus: userData.accountStatus,
                createdAt: userData.createdAt,
                lastLogin: userData.lastLogin,
                // Role-specific data
                ...(userData.role === 'doctor' && {
                    licenseNumber: userData.licenseNumber,
                    fullName: userData.fullName,
                    medicalCouncil: userData.medicalCouncil
                }),
                ...(userData.role === 'staff' && {
                    organizationId: userData.organizationId,
                    employeeId: userData.employeeId
                })
            }
        });
    } catch (error) {
        console.error('Profile fetch error:', error);
        return res.status(500).json({
            success: false,
            message: 'Error fetching user profile',
            error: error.message
        });
    }
});

/**
 * @route   POST /api/auth/add-verified-doctor
 * @desc    Add a verified doctor to Firestore (Admin only)
 * @access  Private (Admin)
 */
router.post('/add-verified-doctor', async (req, res) => {
    try {
        const { licenseNumber, fullName, medicalCouncil, specialization } = req.body;

        if (!licenseNumber || !fullName || !medicalCouncil) {
            return res.status(400).json({
                success: false,
                message: 'License number, full name, and medical council are required'
            });
        }

        // Add to verified_doctors collection
        await db.collection('verified_doctors').add({
            licenseNumber: licenseNumber.toUpperCase(),
            fullName: fullName.trim(),
            medicalCouncil,
            specialization: specialization || 'General Physician',
            verifiedAt: new Date(),
            status: 'active'
        });

        return res.status(201).json({
            success: true,
            message: 'Doctor added to verified list successfully'
        });
    } catch (error) {
        console.error('Add doctor error:', error);
        return res.status(500).json({
            success: false,
            message: 'Error adding verified doctor',
            error: error.message
        });
    }
});

/**
 * @route   POST /api/auth/add-verified-organization
 * @desc    Add a verified organization to Firestore (Admin only)
 * @access  Private (Admin)
 */
router.post('/add-verified-organization', async (req, res) => {
    try {
        const { organizationId, name, emailDomains, employees } = req.body;

        if (!organizationId || !name || !emailDomains || !Array.isArray(emailDomains)) {
            return res.status(400).json({
                success: false,
                message: 'Organization ID, name, and email domains (array) are required'
            });
        }

        // Add organization
        await db.collection('verified_organizations').doc(organizationId).set({
            name,
            emailDomains: emailDomains.map(d => d.toLowerCase()),
            status: 'active',
            createdAt: new Date()
        });

        // Add employees if provided
        if (employees && Array.isArray(employees)) {
            const batch = db.batch();
            employees.forEach(emp => {
                const empRef = db
                    .collection('verified_organizations')
                    .doc(organizationId)
                    .collection('employees')
                    .doc(emp.employeeId);
                batch.set(empRef, {
                    employeeId: emp.employeeId,
                    email: emp.email,
                    name: emp.name || '',
                    status: 'active',
                    addedAt: new Date()
                });
            });
            await batch.commit();
        }

        return res.status(201).json({
            success: true,
            message: 'Organization added to verified list successfully'
        });
    } catch (error) {
        console.error('Add organization error:', error);
        return res.status(500).json({
            success: false,
            message: 'Error adding verified organization',
            error: error.message
        });
    }
});

module.exports = router;
