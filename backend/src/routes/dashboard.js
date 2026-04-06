const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const { verifyToken } = require('../middleware/auth');

const db = admin.firestore();

// ============================================================================
// PATIENT DASHBOARD ENDPOINTS
// ============================================================================

/**
 * GET /api/dashboard/patient/stats
 * Get patient dashboard statistics
 */
router.get('/patient/stats', verifyToken, async (req, res) => {
    try {
        const userId = req.user.uid;

        // Get counts from Firestore
        const [recordsSnapshot, appointmentsSnapshot, prescriptionsSnapshot] = await Promise.all([
            db.collection('health_records').where('patientId', '==', userId).get(),
            db.collection('appointments').where('patientId', '==', userId).get(),
            db.collection('prescriptions').where('patientId', '==', userId).get(),
        ]);

        res.json({
            success: true,
            data: {
                records: recordsSnapshot.size,
                appointments: appointmentsSnapshot.size,
                prescriptions: prescriptionsSnapshot.size,
            },
        });
    } catch (error) {
        console.error('Error fetching patient stats:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch dashboard statistics',
            error: error.message,
        });
    }
});

/**
 * GET /api/dashboard/patient/recent-activity
 * Get recent activity for patient
 */
router.get('/patient/recent-activity', verifyToken, async (req, res) => {
    try {
        const userId = req.user.uid;
        const limit = parseInt(req.query.limit) || 10;

        // Get recent records
        const recordsSnapshot = await db
            .collection('health_records')
            .where('patientId', '==', userId)
            .orderBy('createdAt', 'desc')
            .limit(limit)
            .get();

        const activities = recordsSnapshot.docs.map(doc => ({
            id: doc.id,
            type: 'record',
            ...doc.data(),
        }));

        res.json({
            success: true,
            data: activities,
        });
    } catch (error) {
        console.error('Error fetching recent activity:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch recent activity',
            error: error.message,
        });
    }
});

// ============================================================================
// DOCTOR DASHBOARD ENDPOINTS
// ============================================================================

/**
 * GET /api/dashboard/doctor/stats
 * Get doctor dashboard statistics
 */
router.get('/doctor/stats', verifyToken, async (req, res) => {
    try {
        const userId = req.user.uid;

        // Get doctor's patients and appointments
        const [patientsSnapshot, appointmentsSnapshot, todayAppointmentsSnapshot] = await Promise.all([
            db.collection('doctor_patients').where('doctorId', '==', userId).get(),
            db.collection('appointments').where('doctorId', '==', userId).get(),
            db.collection('appointments')
                .where('doctorId', '==', userId)
                .where('date', '==', new Date().toISOString().split('T')[0])
                .get(),
        ]);

        // Count pending appointments
        const pendingAppointments = appointmentsSnapshot.docs.filter(
            doc => doc.data().status === 'pending'
        ).length;

        res.json({
            success: true,
            data: {
                totalPatients: patientsSnapshot.size,
                todayAppointments: todayAppointmentsSnapshot.size,
                pendingAppointments: pendingAppointments,
            },
        });
    } catch (error) {
        console.error('Error fetching doctor stats:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch dashboard statistics',
            error: error.message,
        });
    }
});

/**
 * GET /api/dashboard/doctor/today-schedule
 * Get today's appointments for doctor
 */
router.get('/doctor/today-schedule', verifyToken, async (req, res) => {
    try {
        const userId = req.user.uid;
        const today = new Date().toISOString().split('T')[0];

        const appointmentsSnapshot = await db
            .collection('appointments')
            .where('doctorId', '==', userId)
            .where('date', '==', today)
            .orderBy('time', 'asc')
            .get();

        const appointments = await Promise.all(
            appointmentsSnapshot.docs.map(async doc => {
                const appointmentData = doc.data();

                // Get patient details
                const patientDoc = await db.collection('patients').doc(appointmentData.patientId).get();
                const patientData = patientDoc.exists ? patientDoc.data() : {};

                return {
                    id: doc.id,
                    ...appointmentData,
                    patientName: patientData.fullName || 'Unknown Patient',
                };
            })
        );

        res.json({
            success: true,
            data: appointments,
        });
    } catch (error) {
        console.error('Error fetching today\'s schedule:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch today\'s schedule',
            error: error.message,
        });
    }
});

/**
 * GET /api/dashboard/doctor/recent-patients
 * Get recently seen patients
 */
router.get('/doctor/recent-patients', verifyToken, async (req, res) => {
    try {
        const userId = req.user.uid;
        const limit = parseInt(req.query.limit) || 10;

        const patientsSnapshot = await db
            .collection('doctor_patients')
            .where('doctorId', '==', userId)
            .orderBy('lastVisit', 'desc')
            .limit(limit)
            .get();

        const patients = await Promise.all(
            patientsSnapshot.docs.map(async doc => {
                const relationData = doc.data();
                const patientDoc = await db.collection('patients').doc(relationData.patientId).get();
                const patientData = patientDoc.exists ? patientDoc.data() : {};

                return {
                    id: relationData.patientId,
                    ...patientData,
                    lastVisit: relationData.lastVisit,
                };
            })
        );

        res.json({
            success: true,
            data: patients,
        });
    } catch (error) {
        console.error('Error fetching recent patients:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch recent patients',
            error: error.message,
        });
    }
});

// ============================================================================
// STAFF DASHBOARD ENDPOINTS
// ============================================================================

/**
 * GET /api/dashboard/staff/stats
 * Get staff dashboard statistics
 */
router.get('/staff/stats', verifyToken, async (req, res) => {
    try {
        const userId = req.user.uid;

        // Get staff member's organization
        const staffDoc = await db.collection('staff').doc(userId).get();
        if (!staffDoc.exists) {
            return res.status(404).json({
                success: false,
                message: 'Staff member not found',
            });
        }

        const staffData = staffDoc.data();
        const organizationId = staffData.organizationId;

        // Get counts
        const [tasksSnapshot, patientsSnapshot, pendingTasksSnapshot] = await Promise.all([
            db.collection('staff_tasks').where('assignedTo', '==', userId).get(),
            db.collection('patients').where('organizationId', '==', organizationId).get(),
            db.collection('staff_tasks')
                .where('assignedTo', '==', userId)
                .where('status', '==', 'pending')
                .get(),
        ]);

        res.json({
            success: true,
            data: {
                totalTasks: tasksSnapshot.size,
                totalPatients: patientsSnapshot.size,
                pendingTasks: pendingTasksSnapshot.size,
            },
        });
    } catch (error) {
        console.error('Error fetching staff stats:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch dashboard statistics',
            error: error.message,
        });
    }
});

/**
 * GET /api/dashboard/staff/today-tasks
 * Get today's tasks for staff member
 */
router.get('/staff/today-tasks', verifyToken, async (req, res) => {
    try {
        const userId = req.user.uid;
        const today = new Date().toISOString().split('T')[0];

        const tasksSnapshot = await db
            .collection('staff_tasks')
            .where('assignedTo', '==', userId)
            .where('dueDate', '==', today)
            .orderBy('priority', 'desc')
            .get();

        const tasks = tasksSnapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
        }));

        res.json({
            success: true,
            data: tasks,
        });
    } catch (error) {
        console.error('Error fetching today\'s tasks:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch today\'s tasks',
            error: error.message,
        });
    }
});

/**
 * GET /api/dashboard/staff/recent-activity
 * Get recent activity for staff member
 */
router.get('/staff/recent-activity', verifyToken, async (req, res) => {
    try {
        const userId = req.user.uid;
        const limit = parseInt(req.query.limit) || 10;

        const activitiesSnapshot = await db
            .collection('staff_activities')
            .where('staffId', '==', userId)
            .orderBy('timestamp', 'desc')
            .limit(limit)
            .get();

        const activities = activitiesSnapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
        }));

        res.json({
            success: true,
            data: activities,
        });
    } catch (error) {
        console.error('Error fetching recent activity:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch recent activity',
            error: error.message,
        });
    }
});

module.exports = router;
