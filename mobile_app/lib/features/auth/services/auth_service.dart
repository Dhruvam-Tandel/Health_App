import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Verify Doctor License Number with Medical Council
  Future<bool> verifyDoctorLicense(
      String licenseNumber, String fullName, String medicalCouncil) async {
    try {
      // Check if license exists in verified_doctors collection
      final QuerySnapshot result = await _firestore
          .collection('verified_doctors')
          .where('licenseNumber', isEqualTo: licenseNumber.toUpperCase())
          .where('fullName', isEqualTo: fullName.trim())
          .where('medicalCouncil', isEqualTo: medicalCouncil)
          .limit(1)
          .get();

      return result.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) print('License verification error: $e');
      return false;
    }
  }

  // Verify Staff with Organization Email Domain
  Future<bool> verifyStaffOrganization(
      String email, String organizationId, String employeeId) async {
    try {
      // Check if organization exists and is verified
      final orgDoc = await _firestore
          .collection('verified_organizations')
          .doc(organizationId)
          .get();

      if (!orgDoc.exists) return false;

      final orgData = orgDoc.data() as Map<String, dynamic>;
      final allowedDomains = List<String>.from(orgData['emailDomains'] ?? []);

      // Check if email domain matches organization
      final emailDomain = email.split('@').last.toLowerCase();
      if (!allowedDomains.contains(emailDomain)) return false;

      // Verify employee ID exists in organization's employee list
      final employeeDoc = await _firestore
          .collection('verified_organizations')
          .doc(organizationId)
          .collection('employees')
          .doc(employeeId)
          .get();

      return employeeDoc.exists;
    } catch (e) {
      if (kDebugMode) print('Organization verification error: $e');
      return false;
    }
  }

  // Sign up with Email, Password, and Role (Enhanced with verification)
  Future<void> signup(
    String email,
    String password,
    String role, {
    String? licenseNumber,
    String? fullName,
    String? medicalCouncil,
    String? organizationId,
    String? employeeId,
  }) async {
    try {
      // Email format validation
      if (!_isValidEmail(email)) {
        throw 'Please enter a valid email address';
      }

      // Role-specific verification
      if (role == 'doctor') {
        if (licenseNumber == null ||
            fullName == null ||
            medicalCouncil == null) {
          throw 'Doctor registration requires license number, full name, and medical council';
        }

        final isVerified =
            await verifyDoctorLicense(licenseNumber, fullName, medicalCouncil);
        if (!isVerified) {
          throw 'Doctor license verification failed. Please ensure your license number, name, and medical council are correct.';
        }
      } else if (role == 'staff') {
        if (organizationId == null || employeeId == null) {
          throw 'Staff registration requires organization ID and employee ID';
        }

        final isVerified =
            await verifyStaffOrganization(email, organizationId, employeeId);
        if (!isVerified) {
          throw 'Staff verification failed. Please check your organization ID, employee ID, and email domain.';
        }
      }

      // Create Auth User
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      // Send email verification
      await userCred.user!.sendEmailVerification();

      // Create User Document in Firestore with verification status
      final userData = {
        'uid': userCred.user!.uid,
        'email': email,
        'role': role,
        'emailVerified': false,
        'accountStatus': 'pending_email_verification',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      };

      // Add role-specific data
      if (role == 'doctor') {
        if (licenseNumber != null) userData['licenseNumber'] = licenseNumber;
        if (fullName != null) userData['fullName'] = fullName;
        if (medicalCouncil != null) userData['medicalCouncil'] = medicalCouncil;
        userData['verifiedDoctor'] = true;
      } else if (role == 'staff') {
        if (organizationId != null) userData['organizationId'] = organizationId;
        if (employeeId != null) userData['employeeId'] = employeeId;
        userData['verifiedStaff'] = true;
      }

      // Save to users collection
      await _firestore
          .collection('users')
          .doc(userCred.user!.uid)
          .set(userData);

      // Create role-specific collection entry
      if (role == 'patient') {
        // Create entry in patients collection
        await _firestore.collection('patients').doc(userCred.user!.uid).set({
          'uid': userCred.user!.uid,
          'email': email,
          'emailVerified': false,
          'accountStatus': 'pending_email_verification',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'profile': {
            'fullName': '',
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
            'bloodPressure': '',
            'height': '',
            'weight': '',
          },
          'appointments': [],
          'prescriptions': [],
          'healthRecords': [],
        });
      } else if (role == 'doctor') {
        // Create entry in doctors collection
        await _firestore.collection('doctors').doc(userCred.user!.uid).set({
          'uid': userCred.user!.uid,
          'email': email,
          'licenseNumber': licenseNumber,
          'fullName': fullName,
          'medicalCouncil': medicalCouncil,
          'emailVerified': false,
          'accountStatus': 'pending_email_verification',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'profile': {
            'specialization': '',
            'experience': '',
            'qualifications': [],
            'phoneNumber': '',
            'clinicAddress': '',
            'consultationFee': '',
            'availability': {},
          },
          'patients': [],
          'appointments': [],
          'prescriptions': [],
        });
      } else if (role == 'staff') {
        // Create entry in staff collection
        await _firestore.collection('staff').doc(userCred.user!.uid).set({
          'uid': userCred.user!.uid,
          'email': email,
          'organizationId': organizationId,
          'employeeId': employeeId,
          'emailVerified': false,
          'accountStatus': 'pending_email_verification',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'profile': {
            'fullName': '',
            'department': '',
            'position': '',
            'phoneNumber': '',
          },
          'assignedPatients': [],
          'tasks': [],
        });
      }

      if (kDebugMode) {
        print('Signup Successful: $email ($role) - Email verification sent');
        print('Created entries in users and $role collection');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw 'The password provided is too weak. Use at least 6 characters.';
      } else if (e.code == 'email-already-in-use') {
        throw 'An account already exists with this email.';
      } else if (e.code == 'invalid-email') {
        throw 'The email address is not valid.';
      }
      throw e.message ?? 'Signup failed';
    } catch (e) {
      rethrow;
    }
  }

  // Login with email verification check
  Future<String?> login(String email, String password) async {
    try {
      // Email format validation
      if (!_isValidEmail(email)) {
        throw 'Please enter a valid email address';
      }

      // Authenticate
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      // Check if email is verified
      await userCred.user!.reload();
      final user = _auth.currentUser;

      if (user != null && !user.emailVerified) {
        // Update Firestore but don't allow full access (use set with merge to avoid 'not found' error)
        await _firestore.collection('users').doc(user.uid).set({
          'lastLoginAttempt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        throw 'Please verify your email address. Check your inbox for the verification link.';
      }

      // Update last login and email verification status (use set with merge to avoid 'not found' error)
      await _firestore.collection('users').doc(userCred.user!.uid).set({
        'lastLogin': FieldValue.serverTimestamp(),
        'emailVerified': true,
        'accountStatus': 'active',
      }, SetOptions(merge: true));

      // Fetch Role
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(userCred.user!.uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return data['role'] as String?;
      } else {
        return 'patient'; // Default fallback
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw 'No account found with this email address.';
      } else if (e.code == 'wrong-password') {
        throw 'Incorrect password. Please try again.';
      } else if (e.code == 'invalid-email') {
        throw 'The email address is not valid.';
      } else if (e.code == 'user-disabled') {
        throw 'This account has been disabled.';
      }
      throw e.message ?? 'Login failed';
    } catch (e) {
      rethrow;
    }
  }

  // Resend email verification
  Future<void> resendVerificationEmail([String? email]) async {
    try {
      User? user = _auth.currentUser;

      // If email is provided and no current user, try to sign in temporarily
      if (email != null && user == null) {
        // We can't resend without being logged in, so throw an error
        throw 'Please try logging in again to resend verification email';
      }

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      } else if (user != null && user.emailVerified) {
        throw 'Email already verified';
      } else {
        throw 'No user logged in';
      }
    } catch (e) {
      if (e is String) {
        throw e;
      }
      throw 'Failed to send verification email: $e';
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  // Google Sign-In (Patient only by default)
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCred = await _auth.signInWithCredential(credential);

      // User Check & Creation
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(userCred.user!.uid).get();
      if (!doc.exists) {
        // Google accounts are automatically verified
        await _firestore.collection('users').doc(userCred.user!.uid).set({
          'uid': userCred.user!.uid,
          'email': userCred.user!.email,
          'role': 'patient',
          'emailVerified': true,
          'accountStatus': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });

        // Create entry in patients collection
        await _firestore.collection('patients').doc(userCred.user!.uid).set({
          'uid': userCred.user!.uid,
          'email': userCred.user!.email,
          'emailVerified': true,
          'accountStatus': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'profile': {
            'fullName': userCred.user!.displayName ?? '',
            'dateOfBirth': null,
            'gender': '',
            'phoneNumber': userCred.user!.phoneNumber ?? '',
            'address': '',
            'bloodGroup': '',
            'emergencyContact': '',
          },
          'medicalInfo': {
            'allergies': [],
            'chronicConditions': [],
            'currentMedications': [],
            'bloodPressure': '',
            'height': '',
            'weight': '',
          },
          'appointments': [],
          'prescriptions': [],
          'healthRecords': [],
        });

        return 'patient';
      }

      // Update last login (use set with merge to avoid 'not found' error)
      await _firestore.collection('users').doc(userCred.user!.uid).set({
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return doc['role'] as String?;
    } catch (e) {
      throw 'Google Sign-In failed: $e';
    }
  }

  // Email validation helper
  bool _isValidEmail(String email) {
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  // Get Current User
  User? get currentUser => _auth.currentUser;
}
