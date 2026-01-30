const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { z } = require('zod');
const prisma = require('../config/database');
const multer = require('multer');
const path = require('path');

// Configure multer for file uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, process.env.UPLOAD_DIR || './uploads');
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'verification-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({
    storage,
    limits: { fileSize: parseInt(process.env.MAX_FILE_SIZE) || 10485760 }, // 10MB
    fileFilter: (req, file, cb) => {
        const allowedTypes = /jpeg|jpg|png|pdf/;
        const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
        const mimetype = allowedTypes.test(file.mimetype);
        if (mimetype && extname) {
            return cb(null, true);
        }
        cb(new Error('Only images and PDFs are allowed'));
    }
});

// Validation schemas
const signupSchema = z.object({
    email: z.string().email(),
    password: z.string().min(6),
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

const loginSchema = z.object({
    email: z.string().email(),
    password: z.string(),
});

// Helper: Check if email domain is verified
function isVerifiedDomain(email, role) {
    const domain = email.split('@')[1].toLowerCase();

    if (role === 'DOCTOR') {
        const doctorDomains = (process.env.DOCTOR_EMAIL_DOMAINS || '').split(',');
        return doctorDomains.some(d => d.trim().toLowerCase() === domain);
    }

    if (role === 'STAFF') {
        const adminDomains = (process.env.ADMIN_EMAIL_DOMAINS || '').split(',');
        return adminDomains.some(d => d.trim().toLowerCase() === domain);
    }

    return true; // Patients can use any email
}

// POST /api/auth/signup
router.post('/signup', async (req, res) => {
    try {
        const data = signupSchema.parse(req.body);

        // Check if user already exists
        const existingUser = await prisma.user.findUnique({
            where: { email: data.email }
        });

        if (existingUser) {
            return res.status(400).json({ error: 'Email already registered' });
        }

        // Verify email domain for doctors and staff
        if ((data.role === 'DOCTOR' || data.role === 'STAFF') && !isVerifiedDomain(data.email, data.role)) {
            return res.status(400).json({
                error: `${data.role === 'DOCTOR' ? 'Doctor' : 'Staff'} registration requires an institutional email address. Please use your organization's email domain.`
            });
        }

        // Hash password
        const passwordHash = await bcrypt.hash(data.password, 10);

        // Create user with role-specific profile
        const user = await prisma.user.create({
            data: {
                email: data.email,
                passwordHash,
                role: data.role,
                emailVerified: false,
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

        // TODO: Send verification email

        res.status(201).json({
            message: data.role === 'PATIENT'
                ? 'Account created successfully! Please verify your email.'
                : 'Account created! Please upload your verification documents and wait for admin approval.',
            user: {
                id: user.id,
                email: user.email,
                role: user.role,
                accountStatus: user.accountStatus,
            }
        });

    } catch (error) {
        if (error instanceof z.ZodError) {
            return res.status(400).json({ error: error.errors });
        }
        console.error('Signup error:', error);
        res.status(500).json({ error: 'Signup failed' });
    }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
    try {
        const { email, password } = loginSchema.parse(req.body);

        // Find user
        const user = await prisma.user.findUnique({
            where: { email },
            include: {
                patient: true,
                doctor: true,
                staff: true,
            }
        });

        if (!user) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Verify password
        const validPassword = await bcrypt.compare(password, user.passwordHash);
        if (!validPassword) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Check account status
        if (user.accountStatus === 'SUSPENDED') {
            return res.status(403).json({ error: 'Account suspended' });
        }

        if (user.accountStatus === 'PENDING_VERIFICATION') {
            return res.status(403).json({
                error: 'Account pending verification. Please upload your verification documents or wait for admin approval.'
            });
        }

        // Generate tokens
        const accessToken = jwt.sign(
            { userId: user.id, role: user.role },
            process.env.JWT_ACCESS_SECRET,
            { expiresIn: process.env.JWT_ACCESS_EXPIRY || '15m' }
        );

        const refreshToken = jwt.sign(
            { userId: user.id },
            process.env.JWT_REFRESH_SECRET,
            { expiresIn: process.env.JWT_REFRESH_EXPIRY || '7d' }
        );

        // Store refresh token
        const expiresAt = new Date();
        expiresAt.setDate(expiresAt.getDate() + 7);

        await prisma.session.create({
            data: {
                userId: user.id,
                refreshToken,
                expiresAt,
            }
        });

        // Update last login
        await prisma.user.update({
            where: { id: user.id },
            data: { lastLogin: new Date() }
        });

        res.json({
            accessToken,
            refreshToken,
            user: {
                id: user.id,
                email: user.email,
                role: user.role,
                profile: user.patient || user.doctor || user.staff,
            }
        });

    } catch (error) {
        if (error instanceof z.ZodError) {
            return res.status(400).json({ error: error.errors });
        }
        console.error('Login error:', error);
        res.status(500).json({ error: 'Login failed' });
    }
});

// POST /api/auth/upload-verification (for doctors and staff)
router.post('/upload-verification', upload.single('document'), async (req, res) => {
    try {
        const { userId } = req.body;

        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        const user = await prisma.user.findUnique({
            where: { id: userId },
            include: { doctor: true, staff: true }
        });

        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        // Update verification document
        if (user.role === 'DOCTOR' && user.doctor) {
            await prisma.doctor.update({
                where: { id: user.doctor.id },
                data: { verificationDocument: req.file.path }
            });
        } else if (user.role === 'STAFF' && user.staff) {
            await prisma.staff.update({
                where: { id: user.staff.id },
                data: { verificationDocument: req.file.path }
            });
        }

        res.json({
            message: 'Verification document uploaded successfully. Waiting for admin approval.',
            filePath: req.file.path
        });

    } catch (error) {
        console.error('Upload error:', error);
        res.status(500).json({ error: 'Upload failed' });
    }
});

// POST /api/auth/refresh
router.post('/refresh', async (req, res) => {
    try {
        const { refreshToken } = req.body;

        if (!refreshToken) {
            return res.status(401).json({ error: 'Refresh token required' });
        }

        // Verify refresh token
        const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);

        // Check if session exists
        const session = await prisma.session.findUnique({
            where: { refreshToken },
            include: { user: true }
        });

        if (!session || session.expiresAt < new Date()) {
            return res.status(401).json({ error: 'Invalid or expired refresh token' });
        }

        // Generate new access token
        const accessToken = jwt.sign(
            { userId: session.user.id, role: session.user.role },
            process.env.JWT_ACCESS_SECRET,
            { expiresIn: process.env.JWT_ACCESS_EXPIRY || '15m' }
        );

        res.json({ accessToken });

    } catch (error) {
        res.status(401).json({ error: 'Invalid refresh token' });
    }
});

// POST /api/auth/logout
router.post('/logout', async (req, res) => {
    try {
        const { refreshToken } = req.body;

        if (refreshToken) {
            await prisma.session.delete({
                where: { refreshToken }
            }).catch(() => { }); // Ignore if not found
        }

        res.json({ message: 'Logged out successfully' });
    } catch (error) {
        res.status(500).json({ error: 'Logout failed' });
    }
});

module.exports = router;
