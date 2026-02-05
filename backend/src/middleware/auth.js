const { auth } = require('../config/firebase');

/**
 * Middleware to verify Firebase ID token
 */
const verifyToken = async (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'No token provided'
            });
        }

        const idToken = authHeader.split('Bearer ')[1];

        // Verify the ID token
        const decodedToken = await auth.verifyIdToken(idToken);

        // Attach user info to request
        req.user = {
            uid: decodedToken.uid,
            email: decodedToken.email,
            emailVerified: decodedToken.email_verified
        };

        next();
    } catch (error) {
        console.error('Token verification error:', error);
        return res.status(401).json({
            success: false,
            message: 'Invalid or expired token',
            error: error.message
        });
    }
};

/**
 * Middleware to check if user has specific role
 */
const checkRole = (allowedRoles) => {
    return async (req, res, next) => {
        try {
            const { db } = require('../config/firebase');
            const userDoc = await db.collection('users').doc(req.user.uid).get();

            if (!userDoc.exists) {
                return res.status(404).json({
                    success: false,
                    message: 'User not found'
                });
            }

            const userData = userDoc.data();
            const userRole = userData.role;

            if (!allowedRoles.includes(userRole)) {
                return res.status(403).json({
                    success: false,
                    message: 'Access denied. Insufficient permissions.'
                });
            }

            // Attach role to request
            req.userRole = userRole;
            req.userData = userData;

            next();
        } catch (error) {
            console.error('Role check error:', error);
            return res.status(500).json({
                success: false,
                message: 'Error checking user role',
                error: error.message
            });
        }
    };
};

module.exports = { verifyToken, checkRole };
