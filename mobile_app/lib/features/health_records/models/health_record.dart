import 'package:cloud_firestore/cloud_firestore.dart';

class HealthRecord {
  final String id;
  final String patientId;
  final String patientName; // For display in doctor/staff views
  final String title;
  final String description;
  final String category; // Main category: Vitals, Lab Reports, Imaging, etc.
  final String recordType; // Specific type within category
  final DateTime date;
  final String? doctorName;
  final String? hospital;
  final String? notes;
  final Map<String, dynamic> data; // Flexible data storage for different types
  final List<String> attachments;
  final String addedBy; // User ID who added the record
  final String addedByRole; // Role: patient, doctor, staff
  final DateTime createdAt;
  final DateTime updatedAt;

  HealthRecord({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.title,
    required this.description,
    required this.category,
    required this.recordType,
    required this.date,
    this.doctorName,
    this.hospital,
    this.notes,
    this.data = const {},
    this.attachments = const [],
    required this.addedBy,
    required this.addedByRole,
    required this.createdAt,
    required this.updatedAt,
  });

  // Create from Firestore document
  factory HealthRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return HealthRecord(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? 'Unknown Patient',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'General',
      recordType: data['recordType'] ?? 'Other',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      doctorName: data['doctorName'],
      hospital: data['hospital'],
      notes: data['notes'],
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      attachments: List<String>.from(data['attachments'] ?? []),
      addedBy: data['addedBy'] ?? '',
      addedByRole: data['addedByRole'] ?? 'patient',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'title': title,
      'description': description,
      'category': category,
      'recordType': recordType,
      'date': Timestamp.fromDate(date),
      'doctorName': doctorName,
      'hospital': hospital,
      'notes': notes,
      'data': data,
      'attachments': attachments,
      'addedBy': addedBy,
      'addedByRole': addedByRole,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

// Record Categories
class RecordCategory {
  static const String vitals = 'Vitals';
  static const String labReports = 'Lab Reports';
  static const String imaging = 'Imaging';
  static const String prescriptions = 'Prescriptions';
  static const String visits = 'Visits';
  static const String vaccinations = 'Vaccinations';
  static const String allergies = 'Allergies';
  static const String procedures = 'Procedures';
  static const String general = 'General';

  static List<String> get all => [
        vitals,
        labReports,
        imaging,
        prescriptions,
        visits,
        vaccinations,
        allergies,
        procedures,
        general,
      ];
}

// Vitals Types
class VitalsType {
  static const String bloodPressure = 'Blood Pressure';
  static const String heartRate = 'Heart Rate';
  static const String temperature = 'Temperature';
  static const String weight = 'Weight';
  static const String height = 'Height';
  static const String bloodSugar = 'Blood Sugar';
  static const String oxygenSaturation = 'Oxygen Saturation';
  static const String bmi = 'BMI';

  static List<String> get all => [
        bloodPressure,
        heartRate,
        temperature,
        weight,
        height,
        bloodSugar,
        oxygenSaturation,
        bmi,
      ];
}

// Lab Report Types
class LabReportType {
  static const String bloodTest = 'Blood Test';
  static const String urineTest = 'Urine Test';
  static const String liverFunction = 'Liver Function Test';
  static const String kidneyFunction = 'Kidney Function Test';
  static const String thyroid = 'Thyroid Test';
  static const String lipidProfile = 'Lipid Profile';
  static const String diabetesPanel = 'Diabetes Panel';
  static const String completeBloodCount = 'Complete Blood Count (CBC)';
  static const String other = 'Other';

  static List<String> get all => [
        bloodTest,
        urineTest,
        liverFunction,
        kidneyFunction,
        thyroid,
        lipidProfile,
        diabetesPanel,
        completeBloodCount,
        other,
      ];
}

// Imaging Types
class ImagingType {
  static const String xray = 'X-Ray';
  static const String mri = 'MRI';
  static const String ctScan = 'CT Scan';
  static const String ultrasound = 'Ultrasound';
  static const String ecg = 'ECG/EKG';
  static const String mammogram = 'Mammogram';
  static const String other = 'Other';

  static List<String> get all => [
        xray,
        mri,
        ctScan,
        ultrasound,
        ecg,
        mammogram,
        other,
      ];
}

// Helper function to get types based on category
List<String> getTypesForCategory(String category) {
  switch (category) {
    case RecordCategory.vitals:
      return VitalsType.all;
    case RecordCategory.labReports:
      return LabReportType.all;
    case RecordCategory.imaging:
      return ImagingType.all;
    default:
      return ['General', 'Other'];
  }
}
