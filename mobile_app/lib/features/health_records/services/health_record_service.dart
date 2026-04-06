import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/health_record.dart';

class HealthRecordService {
  // Singleton pattern — avoids re-creating Firestore/Auth instances
  static final HealthRecordService _instance = HealthRecordService._internal();
  factory HealthRecordService() => _instance;
  HealthRecordService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // In-memory role cache — cleared on signout
  String? _cachedRole;

  void clearCache() => _cachedRole = null;

  // Collection reference
  CollectionReference get _recordsCollection =>
      _firestore.collection('health_records');

  // Public accessor for screens that need the role
  Future<String> getCurrentUserRole() => _getCurrentUserRole();

  // Get current user's role (cached to avoid repeated Firestore reads)
  Future<String> _getCurrentUserRole() async {
    if (_cachedRole != null) return _cachedRole!;
    final user = _auth.currentUser;
    if (user == null) return 'patient';
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    _cachedRole = userDoc.data()?['role'] ?? 'patient';
    return _cachedRole!;
  }

  // Get patient name by ID
  Future<String> _getPatientName(String patientId) async {
    try {
      final patientDoc =
          await _firestore.collection('patients').doc(patientId).get();
      return patientDoc.data()?['fullName'] ?? 'Unknown Patient';
    } catch (e) {
      return 'Unknown Patient';
    }
  }

  // CREATE: Add new health record (All roles can add)
  Future<String> createHealthRecord({
    required String patientId, // For doctor/staff to specify patient
    required String title,
    required String description,
    required String category,
    required String recordType,
    required DateTime date,
    String? doctorName,
    String? hospital,
    String? notes,
    Map<String, dynamic>? data,
    List<String>? attachments, // ← Firebase Storage download URLs
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final role = await _getCurrentUserRole();
      final patientName = await _getPatientName(patientId);

      final docRef = await _recordsCollection.add({
        'patientId': patientId,
        'patientName': patientName,
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
        'recordType': recordType,
        'date': Timestamp.fromDate(date),
        'doctorName': doctorName?.trim(),
        'hospital': hospital?.trim(),
        'notes': notes?.trim(),
        'data': data ?? {},
        'attachments': attachments ?? [],
        'addedBy': user.uid,
        'addedByRole': role,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      throw 'Failed to create health record: ${e.toString()}';
    }
  }

  // READ: Get all health records for a patient (All roles can view)
  Stream<List<HealthRecord>> getHealthRecords(String patientId) {
    return _recordsCollection
        .where('patientId', isEqualTo: patientId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HealthRecord.fromFirestore(doc))
            .toList());
  }

  // READ: Get records for current user (Patient view)
  Stream<List<HealthRecord>> getMyHealthRecords() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return getHealthRecords(user.uid);
  }

  // READ: Get all patients' records (Doctor/Staff view)
  Stream<List<HealthRecord>> getAllPatientsRecords() {
    return _recordsCollection
        .orderBy('date', descending: true)
        .limit(100) // Limit for performance
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HealthRecord.fromFirestore(doc))
            .toList());
  }

  // READ: Get single health record by ID
  Future<HealthRecord?> getHealthRecordById(String recordId) async {
    try {
      final doc = await _recordsCollection.doc(recordId).get();
      if (!doc.exists) return null;
      return HealthRecord.fromFirestore(doc);
    } catch (e) {
      throw 'Failed to fetch health record: ${e.toString()}';
    }
  }

  // READ: Get records by category
  Stream<List<HealthRecord>> getHealthRecordsByCategory(
      String patientId, String category) {
    return _recordsCollection
        .where('patientId', isEqualTo: patientId)
        .where('category', isEqualTo: category)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HealthRecord.fromFirestore(doc))
            .toList());
  }

  // READ: Get records by type
  Stream<List<HealthRecord>> getHealthRecordsByType(
      String patientId, String recordType) {
    return _recordsCollection
        .where('patientId', isEqualTo: patientId)
        .where('recordType', isEqualTo: recordType)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HealthRecord.fromFirestore(doc))
            .toList());
  }

  // UPDATE: Update existing health record (All roles can update)
  Future<void> updateHealthRecord({
    required String recordId,
    required String title,
    required String description,
    required String category,
    required String recordType,
    required DateTime date,
    String? doctorName,
    String? hospital,
    String? notes,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _recordsCollection.doc(recordId).update({
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
        'recordType': recordType,
        'date': Timestamp.fromDate(date),
        'doctorName': doctorName?.trim(),
        'hospital': hospital?.trim(),
        'notes': notes?.trim(),
        'data': data ?? {},
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update health record: ${e.toString()}';
    }
  }

  // DELETE: Delete health record (Patient and Staff can delete)
  Future<void> deleteHealthRecord(String recordId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final role = await _getCurrentUserRole();

      // Check permissions
      if (role == 'patient' || role == 'staff') {
        await _recordsCollection.doc(recordId).delete();
      } else {
        throw 'You do not have permission to delete records';
      }
    } catch (e) {
      throw 'Failed to delete health record: ${e.toString()}';
    }
  }

  // UTILITY: Get record count for a patient
  Future<int> getRecordCount(String patientId) async {
    final snapshot =
        await _recordsCollection.where('patientId', isEqualTo: patientId).get();

    return snapshot.size;
  }

  // UTILITY: Get record count by category
  Future<Map<String, int>> getRecordCountByCategory(String patientId) async {
    final snapshot =
        await _recordsCollection.where('patientId', isEqualTo: patientId).get();

    final Map<String, int> counts = {};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      final category = data?['category'] as String? ?? 'General';
      counts[category] = (counts[category] ?? 0) + 1;
    }

    return counts;
  }

  // UTILITY: Search records by title or description
  Stream<List<HealthRecord>> searchHealthRecords(
      String patientId, String query) {
    return _recordsCollection
        .where('patientId', isEqualTo: patientId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HealthRecord.fromFirestore(doc))
            .where((record) =>
                record.title.toLowerCase().contains(query.toLowerCase()) ||
                record.description.toLowerCase().contains(query.toLowerCase()))
            .toList());
  }

  // UTILITY: Get recent records (last 10)
  Stream<List<HealthRecord>> getRecentRecords(String patientId) {
    return _recordsCollection
        .where('patientId', isEqualTo: patientId)
        .orderBy('date', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HealthRecord.fromFirestore(doc))
            .toList());
  }

  // UTILITY: Get records added by specific role
  Stream<List<HealthRecord>> getRecordsByAddedRole(
      String patientId, String role) {
    return _recordsCollection
        .where('patientId', isEqualTo: patientId)
        .where('addedByRole', isEqualTo: role)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HealthRecord.fromFirestore(doc))
            .toList());
  }

  // UTILITY: Get records within date range
  Stream<List<HealthRecord>> getRecordsByDateRange(
      String patientId, DateTime startDate, DateTime endDate) {
    return _recordsCollection
        .where('patientId', isEqualTo: patientId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HealthRecord.fromFirestore(doc))
            .toList());
  }
}
