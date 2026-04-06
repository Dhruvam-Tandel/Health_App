import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/appointment_service.dart';

// ══════════════════════════════════════════════════════════════
// Doctor Prescription Screen
// Shown when doctor marks appointment as Completed.
// Doctor fills diagnosis, medicines, instructions, next visit.
// Saves a health_record (addedByRole: doctor) + completes appointment.
// ══════════════════════════════════════════════════════════════

const _blue = Color(0xFF2563EB);
const _teal = Color(0xFF0D9488);
const _bg = Color(0xFFF8FAFC);

class DoctorPrescriptionScreen extends StatefulWidget {
  final String appointmentId;
  final String patientId;
  final String patientEmail;
  final String patientName;
  final String doctorName;
  final String slotId;

  const DoctorPrescriptionScreen({
    super.key,
    required this.appointmentId,
    required this.patientId,
    required this.patientEmail,
    required this.patientName,
    required this.doctorName,
    required this.slotId,
  });

  @override
  State<DoctorPrescriptionScreen> createState() =>
      _DoctorPrescriptionScreenState();
}

class _DoctorPrescriptionScreenState extends State<DoctorPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisCtrl = TextEditingController();
  final _chiefComplaintCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _nextVisit;
  bool _saving = false;

  // Medicines list
  final List<_Medicine> _medicines = [_Medicine()];

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    _chiefComplaintCtrl.dispose();
    _instructionsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addMedicine() => setState(() => _medicines.add(_Medicine()));
  void _removeMedicine(int i) {
    if (_medicines.length > 1) setState(() => _medicines.removeAt(i));
  }

  Future<void> _pickNextVisit() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData(
          colorScheme: const ColorScheme.light(primary: _blue),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _nextVisit = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Build medicines map list
      final medsList = _medicines
          .where((m) => m.nameCtrl.text.trim().isNotEmpty)
          .map((m) => {
                'name': m.nameCtrl.text.trim(),
                'dosage': m.dosageCtrl.text.trim(),
                'frequency': m.frequency,
                'duration': m.durationCtrl.text.trim(),
              })
          .toList();

      // Fetch patient name
      String patientName = widget.patientName;
      if (patientName.isEmpty || patientName == 'Unknown') {
        try {
          final pd = await FirebaseFirestore.instance
              .collection('patients')
              .doc(widget.patientId)
              .get();
          patientName = pd.data()?['fullName'] ?? widget.patientEmail;
        } catch (_) {}
      }

      // Save prescription as health record
      await FirebaseFirestore.instance.collection('health_records').add({
        'patientId': widget.patientId,
        'patientName': patientName,
        'title': 'Prescription – ${_diagnosisCtrl.text.trim()}',
        'description': _chiefComplaintCtrl.text.trim(),
        'category': 'Prescriptions',
        'recordType': 'Doctor Prescription',
        'date': Timestamp.fromDate(DateTime.now()),
        'doctorName': widget.doctorName,
        'hospital': '',
        'notes': _notesCtrl.text.trim(),
        'addedBy': uid,
        'addedByRole': 'doctor',
        'appointmentId': widget.appointmentId,
        'data': {
          'diagnosis': _diagnosisCtrl.text.trim(),
          'chiefComplaint': _chiefComplaintCtrl.text.trim(),
          'medicines': medsList,
          'instructions': _instructionsCtrl.text.trim(),
          if (_nextVisit != null)
            'nextVisit':
                '${_nextVisit!.day}/${_nextVisit!.month}/${_nextVisit!.year}',
        },
        'attachments': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mark appointment as completed
      await AppointmentService().completeAppointment(widget.appointmentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription saved & appointment completed!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Write Prescription',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text('SAVE',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Patient banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), _blue],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    radius: 24,
                    child: Text(
                      widget.patientName.isNotEmpty
                          ? widget.patientName[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.patientName.isNotEmpty
                              ? widget.patientName
                              : widget.patientEmail,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        Text(widget.patientEmail,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Completing',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Section 1: Diagnosis ─────────────────────────────
            _SectionCard(
              icon: Icons.medical_information_outlined,
              title: 'Clinical Details',
              color: _blue,
              child: Column(
                children: [
                  _Field(
                    ctrl: _chiefComplaintCtrl,
                    label: 'Chief Complaint',
                    hint: 'Reason patient visited...',
                    required: true,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    ctrl: _diagnosisCtrl,
                    label: 'Diagnosis',
                    hint: 'e.g. Acute pharyngitis, Hypertension...',
                    required: true,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Section 2: Medicines ─────────────────────────────
            _SectionCard(
              icon: Icons.medication_outlined,
              title: 'Medicines',
              color: _teal,
              trailing: TextButton.icon(
                onPressed: _addMedicine,
                icon: const Icon(Icons.add, size: 16, color: _teal),
                label: const Text('Add',
                    style: TextStyle(color: _teal, fontSize: 13)),
              ),
              child: Column(
                children: List.generate(_medicines.length, (i) {
                  final m = _medicines[i];
                  return _MedicineRow(
                    medicine: m,
                    index: i,
                    onRemove: () => _removeMedicine(i),
                    showRemove: _medicines.length > 1,
                  );
                }),
              ),
            ),
            const SizedBox(height: 14),

            // ── Section 3: Instructions ──────────────────────────
            _SectionCard(
              icon: Icons.assignment_outlined,
              title: 'Instructions & Notes',
              color: const Color(0xFF7C3AED),
              child: Column(
                children: [
                  _Field(
                    ctrl: _instructionsCtrl,
                    label: 'Patient Instructions',
                    hint:
                        'Rest for 3 days, drink plenty of fluids, avoid cold food...',
                    required: false,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    ctrl: _notesCtrl,
                    label: 'Doctor Notes (internal)',
                    hint: 'Internal notes about the visit...',
                    required: false,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Section 4: Next Visit ────────────────────────────
            _SectionCard(
              icon: Icons.event_outlined,
              title: 'Follow-up',
              color: const Color(0xFFF59E0B),
              child: GestureDetector(
                onTap: _pickNextVisit,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: Color(0xFFF59E0B), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _nextVisit != null
                              ? 'Next visit: ${_nextVisit!.day}/${_nextVisit!.month}/${_nextVisit!.year}'
                              : 'Tap to set next visit date (optional)',
                          style: TextStyle(
                            color: _nextVisit != null
                                ? Colors.black87
                                : Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Submit Button ────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.done_all_rounded),
                label: Text(_saving
                    ? 'Saving...'
                    : 'Complete Appointment & Save Prescription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Medicine Model ─────────────────────────────────────────────
class _Medicine {
  final nameCtrl = TextEditingController();
  final dosageCtrl = TextEditingController();
  final durationCtrl = TextEditingController();
  String frequency = 'Once daily';

  void dispose() {
    nameCtrl.dispose();
    dosageCtrl.dispose();
    durationCtrl.dispose();
  }
}

// ── Medicine Row ───────────────────────────────────────────────
class _MedicineRow extends StatefulWidget {
  final _Medicine medicine;
  final int index;
  final VoidCallback onRemove;
  final bool showRemove;
  const _MedicineRow({
    required this.medicine,
    required this.index,
    required this.onRemove,
    required this.showRemove,
  });
  @override
  State<_MedicineRow> createState() => _MedicineRowState();
}

class _MedicineRowState extends State<_MedicineRow> {
  static const _frequencies = [
    'Once daily',
    'Twice daily',
    'Three times daily',
    'Four times daily',
    'As needed',
    'Every morning',
    'Every night',
    'Every 8 hours',
    'Every 12 hours',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _teal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${widget.index + 1}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: _teal,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Medicine',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13, color: _teal)),
              const Spacer(),
              if (widget.showRemove)
                GestureDetector(
                  onTap: widget.onRemove,
                  child: const Icon(Icons.remove_circle_outline,
                      color: Colors.red, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.medicine.nameCtrl,
            decoration:
                _inputDecor('Medicine Name *', 'e.g. Amoxicillin 500mg'),
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: widget.medicine.dosageCtrl,
                decoration: _inputDecor('Dosage', 'e.g. 1 tablet'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: widget.medicine.durationCtrl,
                decoration: _inputDecor('Duration', 'e.g. 5 days'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: widget.medicine.frequency,
            decoration: _inputDecor('Frequency', ''),
            onChanged: (v) =>
                setState(() => widget.medicine.frequency = v ?? 'Once daily'),
            items: _frequencies
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecor(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 12),
      hintStyle: const TextStyle(fontSize: 12),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _teal),
      ),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14, color: color)),
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool required;
  final int maxLines;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.required,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: required
          ? (v) => (v?.trim().isEmpty ?? true) ? '$label is required' : null
          : null,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _blue),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      ),
    );
  }
}
