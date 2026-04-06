import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../health_records/screens/attachment_viewer_screen.dart';

// ══════════════════════════════════════════════════════════════
// Admin Medical Reports Screen
// Lists completed appointments → admin can add medical reports
// (photos, X-rays, PDFs) for each patient
// ══════════════════════════════════════════════════════════════

const _purple = Color(0xFF7C3AED);
const _blue = Color(0xFF3B82F6);
const _green = Color(0xFF059669);
const _bg = Color(0xFFF8F7FF);

class AdminMedicalReportsScreen extends StatefulWidget {
  const AdminMedicalReportsScreen({super.key});

  @override
  State<AdminMedicalReportsScreen> createState() =>
      _AdminMedicalReportsScreenState();
}

class _AdminMedicalReportsScreenState extends State<AdminMedicalReportsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Medical Reports',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search patient by name or email...',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('status', isEqualTo: 'completed')
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _purple));
          }
          if (snap.hasError) {
            return Center(
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.red)));
          }

          var docs = snap.data?.docs ?? [];

          // Filter by search
          if (_search.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final email =
                  (data['patientEmail'] as String? ?? '').toLowerCase();
              final doctor =
                  (data['doctorName'] as String? ?? '').toLowerCase();
              return email.contains(_search) || doctor.contains(_search);
            }).toList();
          }

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in_outlined,
                      size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No completed appointments yet',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Completed appointments will appear here',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final apptId = docs[i].id;
              final patientId = d['patientId'] as String? ?? '';
              final patientEmail = d['patientEmail'] as String? ?? '';
              final doctorName = d['doctorName'] as String? ?? 'Doctor';
              final ts = d['appointmentDate'] as Timestamp?;
              final dateStr = ts != null
                  ? DateFormat('dd MMM yyyy').format(ts.toDate())
                  : '';
              final timeSlot = d['timeSlot'] as String? ?? '';
              final initial =
                  patientEmail.isNotEmpty ? patientEmail[0].toUpperCase() : 'P';

              return _CompletedApptCard(
                appointmentId: apptId,
                patientId: patientId,
                patientEmail: patientEmail,
                doctorName: doctorName,
                dateStr: dateStr,
                timeSlot: timeSlot,
                initial: initial,
              );
            },
          );
        },
      ),
    );
  }
}

// ── Completed Appointment Card ─────────────────────────────────
class _CompletedApptCard extends StatelessWidget {
  final String appointmentId;
  final String patientId;
  final String patientEmail;
  final String doctorName;
  final String dateStr;
  final String timeSlot;
  final String initial;

  const _CompletedApptCard({
    required this.appointmentId,
    required this.patientId,
    required this.patientEmail,
    required this.doctorName,
    required this.dateStr,
    required this.timeSlot,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _green.withValues(alpha: 0.1),
                  child: Text(initial,
                      style: const TextStyle(
                          color: _green, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patientEmail,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                      Text('Dr. $doctorName',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(timeSlot,
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: _green, size: 16),
                  const SizedBox(width: 6),
                  const Text('Completed',
                      style: TextStyle(
                          color: _green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // View Reports button
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _PatientReportsScreen(
                              patientId: patientId,
                              patientEmail: patientEmail,
                              appointmentId: appointmentId),
                        ),
                      );
                    },
                    icon:
                        const Icon(Icons.folder_open, size: 14, color: _purple),
                    label: const Text('View / Add Reports',
                        style: TextStyle(
                            fontSize: 12,
                            color: _purple,
                            fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      backgroundColor: _purple.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Patient Reports Screen — view existing + add new reports
// ══════════════════════════════════════════════════════════════
class _PatientReportsScreen extends StatelessWidget {
  final String patientId;
  final String patientEmail;
  final String appointmentId;

  const _PatientReportsScreen({
    required this.patientId,
    required this.patientEmail,
    required this.appointmentId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Patient Records',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(patientEmail,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _AddReportSheet(
                patientId: patientId,
                patientEmail: patientEmail,
                appointmentId: appointmentId),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Report',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('health_records')
            .where('patientId', isEqualTo: patientId)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _purple));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _emptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return _RecordItem(data: d, docId: docs[i].id);
            },
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No records yet',
              style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 8),
          Text('Tap + Add Report to add medical records',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Record Item Card ───────────────────────────────────────────
class _RecordItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  const _RecordItem({required this.data, required this.docId});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Record';
    final category = data['category'] as String? ?? '';
    final role = data['addedByRole'] as String? ?? 'patient';
    final ts = data['date'] as Timestamp?;
    final dateStr =
        ts != null ? DateFormat('dd MMM yyyy').format(ts.toDate()) : '';
    final attachments = (data['attachments'] as List?)?.cast<String>() ?? [];

    final roleColor = role == 'doctor'
        ? _blue
        : role == 'staff' || role == 'admin'
            ? _purple
            : _green;
    final roleLabel = role == 'doctor'
        ? 'Doctor'
        : role == 'staff' || role == 'admin'
            ? 'Admin/Staff'
            : 'Patient';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_iconFor(category), color: _purple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(category,
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(dateStr,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(roleLabel,
                        style: TextStyle(
                            fontSize: 10,
                            color: roleColor,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: attachments.map((url) {
                final isImage = url.toLowerCase().contains('.jpg') ||
                    url.toLowerCase().contains('.png') ||
                    url.toLowerCase().contains('.jpeg') ||
                    url.toLowerCase().contains('.webp');
                return GestureDetector(
                  onTap: () async {
                    if (isImage) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AttachmentViewerScreen(url: url),
                        ),
                      );
                    } else {
                      final uri = Uri.parse(url);
                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            isImage
                                ? Icons.image_outlined
                                : Icons.picture_as_pdf_outlined,
                            size: 14,
                            color: _blue),
                        const SizedBox(width: 5),
                        Text(
                          url.length > 25 ? '${url.substring(0, 22)}...' : url,
                          style: const TextStyle(
                              fontSize: 11,
                              color: _blue,
                              decoration: TextDecoration.underline),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(String cat) {
    switch (cat.toLowerCase()) {
      case 'imaging':
        return Icons.image_outlined;
      case 'lab reports':
        return Icons.science_outlined;
      case 'prescriptions':
        return Icons.medication_outlined;
      case 'vitals':
        return Icons.monitor_heart_outlined;
      default:
        return Icons.description_outlined;
    }
  }
}

// ══════════════════════════════════════════════════════════════
// Add Report Bottom Sheet — Admin adds medical reports
// ══════════════════════════════════════════════════════════════
class _AddReportSheet extends StatefulWidget {
  final String patientId;
  final String patientEmail;
  final String appointmentId;

  const _AddReportSheet({
    required this.patientId,
    required this.patientEmail,
    required this.appointmentId,
  });

  @override
  State<_AddReportSheet> createState() => _AddReportSheetState();
}

class _AddReportSheetState extends State<_AddReportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = 'Imaging';
  String _recordType = 'X-Ray';
  DateTime _date = DateTime.now();
  bool _saving = false;

  // Attachment URLs (manual entry — simulated file upload)
  final List<TextEditingController> _attachmentCtrls = [
    TextEditingController()
  ];

  static const _categories = {
    'Imaging': ['X-Ray', 'MRI', 'CT Scan', 'Ultrasound', 'ECG/EKG', 'Other'],
    'Lab Reports': [
      'Blood Test',
      'Urine Test',
      'Liver Function Test',
      'Kidney Function Test',
      'Thyroid Test',
      'Lipid Profile',
      'Complete Blood Count (CBC)',
      'Other'
    ],
    'Prescriptions': ['Doctor Prescription', 'Other'],
    'Vitals': [
      'Blood Pressure',
      'Heart Rate',
      'Temperature',
      'Blood Sugar',
      'Oxygen Saturation',
      'Other'
    ],
    'General': ['General', 'Other'],
  };

  List<String> get _types => _categories[_category] ?? ['Other'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _attachmentCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData(
          colorScheme: const ColorScheme.light(primary: _purple),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Collect non-empty attachment URLs
      final attachments = _attachmentCtrls
          .map((c) => c.text.trim())
          .where((u) => u.isNotEmpty)
          .toList();

      // Fetch patient name
      String patientName = widget.patientEmail;
      try {
        final pd = await FirebaseFirestore.instance
            .collection('patients')
            .doc(widget.patientId)
            .get();
        patientName = pd.data()?['fullName'] ?? widget.patientEmail;
      } catch (_) {}

      await FirebaseFirestore.instance.collection('health_records').add({
        'patientId': widget.patientId,
        'patientName': patientName,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category,
        'recordType': _recordType,
        'date': Timestamp.fromDate(_date),
        'doctorName': '',
        'hospital': '',
        'notes': _notesCtrl.text.trim(),
        'addedBy': uid,
        'addedByRole': 'staff',
        'appointmentId': widget.appointmentId,
        'data': {},
        'attachments': attachments,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medical report added successfully!'),
            backgroundColor: _green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_box_outlined,
                        color: _purple, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Add Medical Report',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleCtrl,
                decoration: _decor('Report Title *',
                    'e.g. Chest X-Ray Report, CBC Blood Test'),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Category + Type row
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: _decor('Category', ''),
                    isExpanded: true,
                    onChanged: (v) => setState(() {
                      _category = v!;
                      _recordType = _types.first;
                    }),
                    items: _categories.keys
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _recordType,
                    decoration: _decor('Type', ''),
                    isExpanded: true,
                    onChanged: (v) =>
                        setState(() => _recordType = v ?? 'Other'),
                    items: _types
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // Date
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: _purple),
                      const SizedBox(width: 10),
                      Text(
                        'Report Date: ${_date.day}/${_date.month}/${_date.year}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_calendar_outlined,
                          size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: _decor('Description / Findings',
                    'Describe findings, test results...'),
              ),
              const SizedBox(height: 12),

              // Notes
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: _decor('Notes (optional)', 'Additional notes...'),
              ),
              const SizedBox(height: 16),

              // Attachments
              Row(
                children: [
                  const Icon(Icons.attach_file, color: _purple, size: 18),
                  const SizedBox(width: 8),
                  const Text('Attachments (File URLs / Links)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _purple)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(
                        () => _attachmentCtrls.add(TextEditingController())),
                    icon: const Icon(Icons.add, size: 14, color: _purple),
                    label: const Text('Add',
                        style: TextStyle(fontSize: 12, color: _purple)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...List.generate(_attachmentCtrls.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _attachmentCtrls[i],
                          decoration: _decor(
                            'URL ${i + 1}',
                            'https://storage.example.com/report.jpg',
                          ),
                        ),
                      ),
                      if (_attachmentCtrls.length > 1) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() {
                            _attachmentCtrls[i].dispose();
                            _attachmentCtrls.removeAt(i);
                          }),
                          child: const Icon(Icons.remove_circle_outline,
                              color: Colors.red, size: 20),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save Medical Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decor(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint.isEmpty ? null : hint,
      hintStyle: const TextStyle(fontSize: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _purple),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      isDense: true,
    );
  }
}
