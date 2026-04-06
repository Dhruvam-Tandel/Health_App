import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/appointment.dart';

class AppointmentService {
  // Singleton
  static final AppointmentService _instance = AppointmentService._internal();
  factory AppointmentService() => _instance;
  AppointmentService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Collection References ──────────────────────────────────────
  CollectionReference get _slots => _db.collection('appointment_slots');
  CollectionReference get _appointments => _db.collection('appointments');
  CollectionReference get _doctors => _db.collection('doctors');

  // ══════════════════════════════════════════════════════════════
  // DOCTOR SEARCH (for patients)
  // ══════════════════════════════════════════════════════════════

  /// Fetch all verified doctors for search
  Future<List<DoctorProfile>> searchDoctors(String query) async {
    final snapshot = await _doctors.get();
    final all =
        snapshot.docs.map((d) => DoctorProfile.fromFirestore(d)).toList();
    if (query.trim().isEmpty) return all;
    return all.where((d) => d.matchesQuery(query)).toList();
  }

  // ══════════════════════════════════════════════════════════════
  // SLOTS (admin creates)
  // ══════════════════════════════════════════════════════════════

  /// Create a new appointment slot
  Future<String> createSlot({
    required String doctorId,
    required String doctorName,
    required String specialization,
    required DateTime date,
    required String startTime,
    required String endTime,
    required int maxPatients,
    required String consultationFee,
  }) async {
    final ref = await _slots.add({
      'doctorId': doctorId,
      'doctorName': doctorName,
      'specialization': specialization,
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'maxPatients': maxPatients,
      'bookedCount': 0,
      'consultationFee': consultationFee,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// All future slots (admin view)
  Stream<List<AppointmentSlot>> getAllSlots() {
    return _slots
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
                DateTime.now().subtract(const Duration(days: 1))))
        .orderBy('date')
        .snapshots()
        .map((s) => s.docs.map(AppointmentSlot.fromFirestore).toList());
  }

  /// Slots for a specific doctor (patient booking)
  Stream<List<AppointmentSlot>> getSlotsForDoctor(String doctorId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _slots
        .where('doctorId', isEqualTo: doctorId)
        .where('isActive', isEqualTo: true)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .orderBy('date')
        .snapshots()
        .map((s) => s.docs.map(AppointmentSlot.fromFirestore).toList());
  }

  /// Delete a slot (admin)
  Future<void> deleteSlot(String slotId) async {
    await _slots.doc(slotId).delete();
  }

  /// Toggle slot active/inactive
  Future<void> toggleSlot(String slotId, bool isActive) async {
    await _slots.doc(slotId).update({'isActive': isActive});
  }

  // ══════════════════════════════════════════════════════════════
  // APPOINTMENTS (patient books)
  // ══════════════════════════════════════════════════════════════

  /// Book an appointment (patient action)
  Future<String> bookAppointment({
    required AppointmentSlot slot,
    required String reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw 'User not authenticated';

    // Use a Firestore transaction to safely increment bookedCount
    return _db.runTransaction<String>((tx) async {
      final slotDoc = await tx.get(_slots.doc(slot.id));
      if (!slotDoc.exists) throw 'Slot no longer available';

      final data = slotDoc.data() as Map<String, dynamic>;
      final booked = (data['bookedCount'] ?? 0) as int;
      final max = (data['maxPatients'] ?? 1) as int;

      if (booked >= max) throw 'This slot is fully booked';

      // Create appointment doc
      final apptRef = _appointments.doc();
      tx.set(apptRef, {
        'slotId': slot.id,
        'patientId': user.uid,
        'patientEmail': user.email ?? '',
        'doctorId': slot.doctorId,
        'doctorName': slot.doctorName,
        'specialization': slot.specialization,
        'appointmentDate': Timestamp.fromDate(slot.date),
        'timeSlot': '${slot.startTime} - ${slot.endTime}',
        'reason': reason.trim(),
        'status': 'pending',
        'adminNote': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Increment bookedCount on slot
      tx.update(_slots.doc(slot.id), {'bookedCount': booked + 1});

      return apptRef.id;
    });
  }

  /// Patient's own appointments
  Stream<List<Appointment>> getMyAppointments() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return _appointments
        .where('patientId', isEqualTo: user.uid)
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Appointment.fromFirestore).toList());
  }

  /// Cancel appointment (patient)
  Future<void> cancelAppointment(String appointmentId, String slotId) async {
    await _db.runTransaction((tx) async {
      tx.update(_appointments.doc(appointmentId), {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final slotDoc = await tx.get(_slots.doc(slotId));
      if (slotDoc.exists) {
        final data = slotDoc.data() as Map<String, dynamic>;
        final booked = (data['bookedCount'] ?? 1) as int;
        tx.update(
            _slots.doc(slotId), {'bookedCount': booked > 0 ? booked - 1 : 0});
      }
    });
  }

  // ══════════════════════════════════════════════════════════════
  // ADMIN / STAFF — APPROVAL
  // ══════════════════════════════════════════════════════════════

  /// All appointments (admin view)
  Stream<List<Appointment>> getAllAppointments({String? statusFilter}) {
    Query query = _appointments.orderBy('createdAt', descending: true);
    if (statusFilter != null && statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query
        .snapshots()
        .map((s) => s.docs.map(Appointment.fromFirestore).toList());
  }

  /// Approve appointment (admin)
  Future<void> approveAppointment(String apptId, {String? note}) async {
    await _appointments.doc(apptId).update({
      'status': 'confirmed',
      'adminNote': note,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject appointment (admin)
  Future<void> rejectAppointment(String apptId,
      {required String reason}) async {
    await _db.runTransaction((tx) async {
      final apptDoc = await tx.get(_appointments.doc(apptId));
      if (!apptDoc.exists) return;
      final data = apptDoc.data() as Map<String, dynamic>;
      final slotId = data['slotId'] as String? ?? '';

      tx.update(_appointments.doc(apptId), {
        'status': 'rejected',
        'adminNote': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (slotId.isNotEmpty) {
        final slotDoc = await tx.get(_slots.doc(slotId));
        if (slotDoc.exists) {
          final sd = slotDoc.data() as Map<String, dynamic>;
          final booked = (sd['bookedCount'] ?? 1) as int;
          tx.update(
              _slots.doc(slotId), {'bookedCount': booked > 0 ? booked - 1 : 0});
        }
      }
    });
  }

  /// Mark appointment completed (doctor)
  Future<void> completeAppointment(String apptId) async {
    await _appointments.doc(apptId).update({
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ══════════════════════════════════════════════════════════════
  // DOCTOR VIEW
  // ══════════════════════════════════════════════════════════════

  /// Doctor's assigned (confirmed) appointments
  Stream<List<Appointment>> getDoctorAppointments(String doctorId) {
    return _appointments
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'confirmed')
        .orderBy('appointmentDate')
        .snapshots()
        .map((s) => s.docs.map(Appointment.fromFirestore).toList());
  }

  /// Doctor's all appointments (any status)
  Stream<List<Appointment>> getDoctorAllAppointments(String doctorId) {
    return _appointments
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Appointment.fromFirestore).toList());
  }

  // ── Helpers ────────────────────────────────────────────────────

  /// Fetch all doctors list for admin slot creation
  Future<List<DoctorProfile>> getAllDoctors() async {
    final snap = await _doctors.get();
    return snap.docs.map(DoctorProfile.fromFirestore).toList();
  }
}
