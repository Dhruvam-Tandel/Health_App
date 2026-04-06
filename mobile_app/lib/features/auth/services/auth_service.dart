import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../health_records/services/health_record_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ──────────────────────────────────────────────────────────────────────────
  // SIGN UP — Email + Password (all roles)
  // Doctor: also requires licenseNumber verification
  // Admin/Staff: also requires adminId verification
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> signup(
    String email,
    String password,
    String role, {
    // Doctor fields
    String? licenseNumber,
    String? fullName,
    String? specialization,
    String? experience,
    String? consultationFee,
    String? hospital,
    // Admin/Staff fields
    String? adminId,
    String? department,
  }) async {
    if (!_isValidEmail(email)) throw 'Please enter a valid email address';

    // ── Role-specific pre-verification ──────────────────────────────────────
    if (role == 'doctor') {
      if (licenseNumber == null || licenseNumber.trim().isEmpty) {
        throw 'Medical license number is required for doctor registration.';
      }
    }

    if (role == 'staff') {
      if (adminId == null || adminId.trim().isEmpty) {
        throw 'Admin ID is required for staff registration.';
      }
    }

    // ── Create Firebase Auth user ────────────────────────────────────────────
    UserCredential userCred;
    try {
      userCred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw 'Password must be at least 6 characters.';
      } else if (e.code == 'email-already-in-use') {
        throw 'An account already exists with this email.';
      } else if (e.code == 'invalid-email') {
        throw 'The email address is not valid.';
      }
      throw e.message ?? 'Signup failed';
    }

    // ── Send email verification ──────────────────────────────────────────────
    await userCred.user!.sendEmailVerification();

    final uid = userCred.user!.uid;
    final now = FieldValue.serverTimestamp();

    // ── Base user document ────────────────────────────────────────────────────
    final userDoc = <String, dynamic>{
      'uid': uid,
      'email': email,
      'role': role,
      'fullName': fullName?.trim() ?? '',
      'emailVerified': false,
      'accountStatus': 'pending_email_verification',
      'createdAt': now,
      'lastLogin': now,
    };

    // ── Role-specific extra fields ────────────────────────────────────────────
    if (role == 'doctor' && licenseNumber != null) {
      userDoc['licenseNumber'] = licenseNumber.trim().toUpperCase();
    }
    if (role == 'staff' && adminId != null) {
      userDoc['adminId'] = adminId.trim().toUpperCase();
    }

    await _firestore.collection('users').doc(uid).set(userDoc);

    // ── Role-specific collections ─────────────────────────────────────────────
    if (role == 'doctor') {
      await _firestore.collection('doctors').doc(uid).set({
        'uid': uid,
        'email': email,
        'fullName': fullName?.trim() ?? '',
        'licenseNumber': licenseNumber?.trim().toUpperCase() ?? '',
        'emailVerified': false,
        'accountStatus': 'pending_email_verification',
        'createdAt': now,
        'lastLogin': now,
        'profile': {
          'fullName': fullName?.trim() ?? '',
          'specialization': specialization?.trim() ?? '',
          'experience': experience?.trim() ?? '',
          'consultationFee': consultationFee?.trim() ?? '',
          'hospital': hospital?.trim() ?? '',
          'phoneNumber': '',
          'bio': '',
          'diseases': <String>[],
        },
      });
    } else if (role == 'patient') {
      await _firestore.collection('patients').doc(uid).set({
        'uid': uid,
        'email': email,
        'fullName': fullName?.trim() ?? '',
        'emailVerified': false,
        'accountStatus': 'pending_email_verification',
        'createdAt': now,
        'lastLogin': now,
        'profile': {
          'fullName': fullName?.trim() ?? '',
          'dateOfBirth': null,
          'gender': '',
          'phoneNumber': '',
          'address': '',
          'bloodGroup': '',
          'emergencyContact': '',
        },
        'medicalInfo': {
          'allergies': [],
          'chronicConditions': [],
          'currentMedications': [],
        },
      });
    } else if (role == 'staff') {
      await _firestore.collection('staff').doc(uid).set({
        'uid': uid,
        'email': email,
        'fullName': fullName?.trim() ?? '',
        'adminId': adminId?.trim().toUpperCase() ?? '',
        'department': department?.trim() ?? '',
        'emailVerified': false,
        'accountStatus': 'pending_email_verification',
        'createdAt': now,
        'lastLogin': now,
      });
    }

    if (kDebugMode) print('Signup successful: $email ($role)');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LOGIN — Email + Password (all roles)
  // ──────────────────────────────────────────────────────────────────────────

  Future<String?> login(String email, String password) async {
    if (!_isValidEmail(email)) throw 'Please enter a valid email address';

    try {
      final userCred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      await userCred.user!.reload();
      final user = _auth.currentUser;

      if (user != null && !user.emailVerified) {
        await _firestore.collection('users').doc(user.uid).set(
            {'lastLoginAttempt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
        throw 'Please verify your email address. Check your inbox for the verification link.';
      }

      await _firestore.collection('users').doc(userCred.user!.uid).set({
        'lastLogin': FieldValue.serverTimestamp(),
        'emailVerified': true,
        'accountStatus': 'active',
      }, SetOptions(merge: true));

      // Also update role-specific collection
      final doc =
          await _firestore.collection('users').doc(userCred.user!.uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final role = data['role'] as String?;

        // Mark email verified in role collection too
        if (role == 'doctor') {
          await _firestore.collection('doctors').doc(userCred.user!.uid).set(
              {'emailVerified': true, 'accountStatus': 'active'},
              SetOptions(merge: true));
        }

        return role;
      }
      return 'patient';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw 'No account found with this email address.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw 'Incorrect password. Please try again.';
      } else if (e.code == 'invalid-email') {
        throw 'The email address is not valid.';
      } else if (e.code == 'user-disabled') {
        throw 'This account has been disabled.';
      }
      throw e.message ?? 'Login failed';
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GOOGLE Sign-In (patients only)
  // ──────────────────────────────────────────────────────────────────────────

  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      final uid = cred.user!.uid;
      final now = FieldValue.serverTimestamp();

      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        // New Google user — create as patient
        await _firestore.collection('users').doc(uid).set({
          'uid': uid,
          'email': cred.user!.email,
          'role': 'patient',
          'fullName': cred.user!.displayName ?? '',
          'emailVerified': true,
          'accountStatus': 'active',
          'createdAt': now,
          'lastLogin': now,
        });

        await _firestore.collection('patients').doc(uid).set({
          'uid': uid,
          'email': cred.user!.email,
          'fullName': cred.user!.displayName ?? '',
          'emailVerified': true,
          'accountStatus': 'active',
          'createdAt': now,
          'lastLogin': now,
          'profile': {
            'fullName': cred.user!.displayName ?? '',
            'dateOfBirth': null,
            'gender': '',
            'phoneNumber': cred.user!.phoneNumber ?? '',
            'address': '',
            'bloodGroup': '',
            'emergencyContact': '',
          },
          'medicalInfo': {
            'allergies': [],
            'chronicConditions': [],
            'currentMedications': [],
          },
        });
        return 'patient';
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .set({'lastLogin': now}, SetOptions(merge: true));

      return (doc.data() as Map<String, dynamic>)['role'] as String?;
    } catch (e) {
      throw 'Google Sign-In failed: $e';
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Utilities
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> resendVerificationEmail([String? email]) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'Please try logging in again to resend verification email';
    }
    if (user.emailVerified) throw 'Email already verified';
    await user.sendEmailVerification();
  }

  Future<void> logout() async {
    HealthRecordService().clearCache();
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  User? get currentUser => _auth.currentUser;
}
