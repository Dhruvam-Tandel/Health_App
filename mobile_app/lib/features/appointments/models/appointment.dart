import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────
// Enums
// ─────────────────────────────────────────
enum AppointmentStatus { pending, confirmed, rejected, completed, cancelled }

extension AppointmentStatusExt on AppointmentStatus {
  String get label {
    switch (this) {
      case AppointmentStatus.pending:
        return 'Pending';
      case AppointmentStatus.confirmed:
        return 'Confirmed';
      case AppointmentStatus.rejected:
        return 'Rejected';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  static AppointmentStatus fromString(String s) {
    switch (s) {
      case 'confirmed':
        return AppointmentStatus.confirmed;
      case 'rejected':
        return AppointmentStatus.rejected;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      default:
        return AppointmentStatus.pending;
    }
  }
}

// ─────────────────────────────────────────
// Doctor Profile (lightweight, for search)
// ─────────────────────────────────────────
class DoctorProfile {
  final String uid;
  final String name;
  final String email;
  final String specialization;
  final String qualification;
  final String experience;
  final String hospital;
  final String consultationFee;
  final List<String> diseases; // diseases/conditions treated

  const DoctorProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.specialization,
    required this.qualification,
    required this.experience,
    required this.hospital,
    required this.consultationFee,
    required this.diseases,
  });

  factory DoctorProfile.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final profile = d['profile'] as Map<String, dynamic>? ?? {};

    // consultationFee may be stored as int, double, or String
    String parseFee(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      return v.toString();
    }

    return DoctorProfile(
      uid: doc.id,
      name: d['fullName'] ??
          profile['fullName'] ??
          d['email']?.split('@')[0] ??
          'Doctor',
      email: d['email'] ?? '',
      specialization: profile['specialization'] ?? d['specialization'] ?? '',
      qualification: profile['qualifications'] is List
          ? (profile['qualifications'] as List).join(', ')
          : profile['qualification'] ?? '',
      experience: profile['experience'] ?? '',
      hospital: profile['clinicAddress'] ?? profile['hospital'] ?? '',
      consultationFee:
          parseFee(profile['consultationFee'] ?? d['consultationFee']),
      diseases: List<String>.from(profile['diseases'] ?? d['diseases'] ?? []),
    );
  }

  bool matchesQuery(String q) {
    final query = q.toLowerCase();
    return name.toLowerCase().contains(query) ||
        specialization.toLowerCase().contains(query) ||
        diseases.any((d) => d.toLowerCase().contains(query));
  }
}

// ─────────────────────────────────────────
// Appointment Slot  (created by admin)
// ─────────────────────────────────────────
class AppointmentSlot {
  final String id;
  final String doctorId;
  final String doctorName;
  final String specialization;
  final DateTime date;
  final String startTime; // e.g. "10:00 AM"
  final String endTime;
  final int maxPatients;
  final int bookedCount;
  final String consultationFee;
  final bool isActive;
  final DateTime createdAt;

  const AppointmentSlot({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.specialization,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.maxPatients,
    required this.bookedCount,
    required this.consultationFee,
    required this.isActive,
    required this.createdAt,
  });

  bool get isFull => bookedCount >= maxPatients;
  int get availableSlots => maxPatients - bookedCount;

  factory AppointmentSlot.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppointmentSlot(
      id: doc.id,
      doctorId: d['doctorId'] ?? '',
      doctorName: d['doctorName'] ?? '',
      specialization: d['specialization'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: d['startTime'] ?? '',
      endTime: d['endTime'] ?? '',
      maxPatients: (d['maxPatients'] ?? 1) as int,
      bookedCount: (d['bookedCount'] ?? 0) as int,
      consultationFee: d['consultationFee'] ?? '',
      isActive: d['isActive'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'doctorId': doctorId,
        'doctorName': doctorName,
        'specialization': specialization,
        'date': Timestamp.fromDate(date),
        'startTime': startTime,
        'endTime': endTime,
        'maxPatients': maxPatients,
        'bookedCount': bookedCount,
        'consultationFee': consultationFee,
        'isActive': isActive,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

// ─────────────────────────────────────────
// Appointment  (booking made by patient)
// ─────────────────────────────────────────
class Appointment {
  final String id;
  final String slotId;
  final String patientId;
  final String patientEmail;
  final String doctorId;
  final String doctorName;
  final String specialization;
  final DateTime appointmentDate;
  final String timeSlot;
  final String reason; // reason / symptoms
  final AppointmentStatus status;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Appointment({
    required this.id,
    required this.slotId,
    required this.patientId,
    required this.patientEmail,
    required this.doctorId,
    required this.doctorName,
    required this.specialization,
    required this.appointmentDate,
    required this.timeSlot,
    required this.reason,
    required this.status,
    this.adminNote,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      slotId: d['slotId'] ?? '',
      patientId: d['patientId'] ?? '',
      patientEmail: d['patientEmail'] ?? '',
      doctorId: d['doctorId'] ?? '',
      doctorName: d['doctorName'] ?? '',
      specialization: d['specialization'] ?? '',
      appointmentDate:
          (d['appointmentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timeSlot: d['timeSlot'] ?? '',
      reason: d['reason'] ?? '',
      status: AppointmentStatusExt.fromString(d['status'] ?? 'pending'),
      adminNote: d['adminNote'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'slotId': slotId,
        'patientId': patientId,
        'patientEmail': patientEmail,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'specialization': specialization,
        'appointmentDate': Timestamp.fromDate(appointmentDate),
        'timeSlot': timeSlot,
        'reason': reason,
        'status': status.name,
        'adminNote': adminNote,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
