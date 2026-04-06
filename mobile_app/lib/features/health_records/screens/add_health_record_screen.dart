import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:minio/minio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/health_record.dart';
import '../services/health_record_service.dart';

// ══════════════════════════════════════════════════════════════
// Design tokens
// ══════════════════════════════════════════════════════════════
const _green = Color(0xFF10B981);
const _blue = Color(0xFF3B82F6);
const _purple = Color(0xFF8B5CF6);
const _amber = Color(0xFFF59E0B);
const _bg = Color(0xFFF8FAFC);

// Category metadata for beautiful chips
const _categoryMeta = {
  'Vitals': (icon: Icons.monitor_heart_rounded, color: _green),
  'Lab Reports': (icon: Icons.science_rounded, color: _blue),
  'Imaging': (icon: Icons.image_rounded, color: _purple),
  'Prescriptions': (icon: Icons.medication_rounded, color: _amber),
  'General': (icon: Icons.folder_rounded, color: Color(0xFF6B7280)),
};

// ══════════════════════════════════════════════════════════════
// Screen
// ══════════════════════════════════════════════════════════════
class AddHealthRecordScreen extends StatefulWidget {
  final String? patientId;
  final String? patientName;

  const AddHealthRecordScreen({
    super.key,
    this.patientId,
    this.patientName,
  });

  @override
  State<AddHealthRecordScreen> createState() => _AddHealthRecordScreenState();
}

class _AddHealthRecordScreenState extends State<AddHealthRecordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _svc = HealthRecordService();

  // Form controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Vitals
  final _systolicCtrl = TextEditingController();
  final _diastolicCtrl = TextEditingController();
  final _heartRateCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _bloodSugarCtrl = TextEditingController();
  final _oxygenCtrl = TextEditingController();

  // State
  String _category = RecordCategory.vitals;
  String _type = VitalsType.bloodPressure;
  DateTime _date = DateTime.now();
  bool _saving = false;

  // File attachments
  final List<_PickedFile> _files = [];
  bool _uploading = false;
  double _uploadProgress = 0;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
    _updateType();
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _descCtrl,
      _doctorCtrl,
      _hospitalCtrl,
      _notesCtrl,
      _systolicCtrl,
      _diastolicCtrl,
      _heartRateCtrl,
      _tempCtrl,
      _weightCtrl,
      _heightCtrl,
      _bloodSugarCtrl,
      _oxygenCtrl,
    ]) {
      c.dispose();
    }
    _animCtrl.dispose();
    super.dispose();
  }

  void _updateType() {
    final types = getTypesForCategory(_category);
    setState(() => _type = types.first);
  }

  // ── File Picking ────────────────────────────────────────────
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'jpg', 'jpeg', 'png', 'webp', // Images / X-rays
        'pdf', // Lab reports / docs
        'doc', 'docx', // Word documents
        'heic', 'heif', // iPhone photos
      ],
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      for (final f in result.files) {
        if (f.path != null && !_files.any((e) => e.path == f.path)) {
          _files.add(_PickedFile(
            path: f.path!,
            name: f.name,
            size: f.size,
            extension: f.extension?.toLowerCase() ?? '',
          ));
        }
      }
    });
  }

  void _removeFile(int i) => setState(() => _files.removeAt(i));

  // ── Upload files to AWS S3 ──────────────────────────────────────
  Future<List<String>> _uploadFiles(String patientId, String patientName) async {
    if (_files.isEmpty) return [];
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    final urls = <String>[];
    
    // Initialize Minio client with AWS credentials from .env
    final minio = Minio(
      endPoint: dotenv.env['AWS_S3_ENDPOINT'] ?? 's3.amazonaws.com',
      port: int.tryParse(dotenv.env['AWS_S3_PORT'] ?? '443') ?? 443,
      accessKey: dotenv.env['AWS_S3_ACCESS_KEY'] ?? '',
      secretKey: dotenv.env['AWS_S3_SECRET_KEY'] ?? '',
      region: dotenv.env['AWS_S3_REGION'] ?? 'us-east-1',
      useSSL: true,
    );
    
    final bucket = dotenv.env['AWS_S3_BUCKET'] ?? 'smart-health-vault-attachments';

    for (int i = 0; i < _files.length; i++) {
      final f = _files[i];
      // Sanitize inputs for valid S3 URLs
      final safePatientName = patientName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final safeCategory = _category.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final safeFileName = f.name.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
      
      final objectName = 'health_records/${safePatientName}_$patientId/$safeCategory/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';
      
      setState(() {
        _uploadProgress = i / _files.length;
      });
      
      // Upload using stream for large files
      final file = File(f.path);
      final length = await file.length();
      final stream = file.openRead().map((chunk) => Uint8List.fromList(chunk));
      
      await minio.putObject(bucket, objectName, stream, size: length);
      
      // Generate standard AWS S3 public access URL
      final region = dotenv.env['AWS_S3_REGION'] ?? 'us-east-1';
      final url = 'https://$bucket.s3.$region.amazonaws.com/$objectName';
      urls.add(url);
      
      setState(() {
        _uploadProgress = (i + 1) / _files.length;
      });
    }

    setState(() => _uploading = false);
    return urls;
  }

  // ── Save ───────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Not authenticated';

      final patientId = widget.patientId ?? user.uid;
      final patientName = widget.patientName ?? user.displayName ?? 'Unknown';

      // Upload files first
      final attachmentUrls = await _uploadFiles(patientId, patientName);

      await _svc.createHealthRecord(
        patientId: patientId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        recordType: _type,
        date: _date,
        doctorName:
            _doctorCtrl.text.trim().isEmpty ? null : _doctorCtrl.text.trim(),
        hospital: _hospitalCtrl.text.trim().isEmpty
            ? null
            : _hospitalCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        data: _buildVitalsData(),
        attachments: attachmentUrls,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Health record saved successfully!'),
          backgroundColor: _green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _buildVitalsData() {
    if (_category != RecordCategory.vitals) return {};
    final d = <String, dynamic>{};
    switch (_type) {
      case VitalsType.bloodPressure:
        d['systolic'] = _systolicCtrl.text;
        d['diastolic'] = _diastolicCtrl.text;
        d['unit'] = 'mmHg';
      case VitalsType.heartRate:
        d['value'] = _heartRateCtrl.text;
        d['unit'] = 'bpm';
      case VitalsType.temperature:
        d['value'] = _tempCtrl.text;
        d['unit'] = '°F';
      case VitalsType.weight:
        d['value'] = _weightCtrl.text;
        d['unit'] = 'kg';
      case VitalsType.height:
        d['value'] = _heightCtrl.text;
        d['unit'] = 'cm';
      case VitalsType.bloodSugar:
        d['value'] = _bloodSugarCtrl.text;
        d['unit'] = 'mg/dL';
      case VitalsType.oxygenSaturation:
        d['value'] = _oxygenCtrl.text;
        d['unit'] = '%';
    }
    return d;
  }

  // ── Date Picker ─────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData(colorScheme: const ColorScheme.light(primary: _green)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final catMeta = _categoryMeta[_category]!;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: catMeta.color,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Add Health Record',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_saving || _uploading)
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
              onPressed: _save,
              child: const Text('SAVE',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              // ── Patient Banner (if adding for another patient) ──────
              if (widget.patientName != null)
                _buildBanner(widget.patientName!, catMeta.color),

              // ── Category Selector ───────────────────────────────────
              _buildSection(
                icon: Icons.grid_view_rounded,
                title: 'Category',
                color: catMeta.color,
                child: _buildCategoryChips(),
              ),
              const SizedBox(height: 14),

              // ── Type Selector ───────────────────────────────────────
              _buildSection(
                icon: Icons.tune_rounded,
                title: 'Record Type',
                color: catMeta.color,
                child: _buildTypeDropdown(catMeta.color),
              ),
              const SizedBox(height: 14),

              // ── Basic Info ──────────────────────────────────────────
              _buildSection(
                icon: Icons.info_outline_rounded,
                title: 'Basic Info',
                color: catMeta.color,
                child: Column(children: [
                  _field(
                    ctrl: _titleCtrl,
                    label: 'Record Title *',
                    hint: 'e.g. Blood Pressure Check, CBC Blood Test',
                    icon: Icons.title_rounded,
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  _dateField(catMeta.color),
                  const SizedBox(height: 12),
                  _field(
                    ctrl: _descCtrl,
                    label: 'Description / Findings',
                    hint: 'Describe test results, observations...',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                    required: false,
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Vitals Fields ───────────────────────────────────────
              if (_category == RecordCategory.vitals) ...[
                _buildSection(
                  icon: Icons.monitor_heart_rounded,
                  title: 'Measurement',
                  color: _green,
                  child: _buildVitalsFields(),
                ),
                const SizedBox(height: 14),
              ],

              // ── Provider Info ───────────────────────────────────────
              _buildSection(
                icon: Icons.local_hospital_rounded,
                title: 'Medical Provider (Optional)',
                color: catMeta.color,
                child: Column(children: [
                  _field(
                    ctrl: _doctorCtrl,
                    label: 'Doctor Name',
                    hint: 'Dr. Sharma',
                    icon: Icons.person_outline_rounded,
                    required: false,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    ctrl: _hospitalCtrl,
                    label: 'Hospital / Clinic',
                    hint: 'Apollo Hospital, City Clinic...',
                    icon: Icons.business_outlined,
                    required: false,
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // ── File Attachments ────────────────────────────────────
              _buildSection(
                icon: Icons.attach_file_rounded,
                title: 'Attachments',
                color: catMeta.color,
                trailing: _addFileButton(catMeta.color),
                child: _buildFileSection(catMeta.color),
              ),
              const SizedBox(height: 14),

              // ── Notes ───────────────────────────────────────────────
              _buildSection(
                icon: Icons.sticky_note_2_outlined,
                title: 'Additional Notes',
                color: catMeta.color,
                child: _field(
                  ctrl: _notesCtrl,
                  label: 'Notes (optional)',
                  hint: 'Any additional observations or instructions...',
                  icon: Icons.edit_note_rounded,
                  maxLines: 3,
                  required: false,
                ),
              ),
              const SizedBox(height: 24),

              // ── Upload Progress ─────────────────────────────────────
              if (_uploading) ...[
                Text(
                  'Uploading files... ${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(color: _green, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.grey[200],
                    color: _green,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Save Button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_saving || _uploading) ? null : _save,
                  icon: (_saving || _uploading)
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving
                      ? 'Saving...'
                      : _uploading
                          ? 'Uploading...'
                          : 'Save Health Record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: catMeta.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section Container ────────────────────────────────────────
  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
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
            if (trailing != null) ...[const Spacer(), trailing],
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ── Patient Banner ────────────────────────────────────────────
  Widget _buildBanner(String name, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0.05)
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.person_pin_rounded, color: color, size: 22),
        const SizedBox(width: 10),
        Text('Adding record for: ',
            style: TextStyle(color: color, fontSize: 13)),
        Text(name,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  // ── Category Chips ────────────────────────────────────────────
  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categoryMeta.entries.map((e) {
        final selected = _category == e.key;
        return GestureDetector(
          onTap: () {
            setState(() => _category = e.key);
            _updateType();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? e.value.color
                  : e.value.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: e.value.color.withValues(alpha: selected ? 0 : 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(e.value.icon,
                    size: 16, color: selected ? Colors.white : e.value.color),
                const SizedBox(width: 6),
                Text(
                  e.key,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : e.value.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Type Dropdown ─────────────────────────────────────────────
  Widget _buildTypeDropdown(Color color) {
    final types = getTypesForCategory(_category);
    return DropdownButtonFormField<String>(
      value: types.contains(_type) ? _type : types.first,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.category_outlined, color: color),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color),
        ),
        filled: true,
        fillColor: _bg,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      ),
      items:
          types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: (v) => setState(() => _type = v ?? types.first),
    );
  }

  // ── Date Field ────────────────────────────────────────────────
  Widget _dateField(Color color) {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              DateFormat('EEEE, dd MMM yyyy').format(_date),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Icon(Icons.edit_calendar_outlined, color: Colors.grey[400], size: 18),
        ]),
      ),
    );
  }

  // ── Text Field ────────────────────────────────────────────────
  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    required bool required,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: required
          ? (v) => (v?.trim().isEmpty ?? true) ? '$label is required' : null
          : null,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _green),
        ),
        filled: true,
        fillColor: _bg,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      ),
    );
  }

  // ── Vitals Fields ─────────────────────────────────────────────
  Widget _buildVitalsFields() {
    InputDecoration d(String label, String suffix) => InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _green),
          ),
          filled: true,
          fillColor: _bg,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        );

    String? req(v) => (v == null || v.isEmpty) ? 'Required' : null;

    switch (_type) {
      case VitalsType.bloodPressure:
        return Row(children: [
          Expanded(
            child: TextFormField(
              controller: _systolicCtrl,
              keyboardType: TextInputType.number,
              decoration: d('Systolic', 'mmHg'),
              validator: req,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child:
                Text('/', style: TextStyle(fontSize: 22, color: Colors.grey)),
          ),
          Expanded(
            child: TextFormField(
              controller: _diastolicCtrl,
              keyboardType: TextInputType.number,
              decoration: d('Diastolic', 'mmHg'),
              validator: req,
            ),
          ),
        ]);
      case VitalsType.heartRate:
        return TextFormField(
            controller: _heartRateCtrl,
            keyboardType: TextInputType.number,
            decoration: d('Heart Rate', 'bpm'),
            validator: req);
      case VitalsType.temperature:
        return TextFormField(
            controller: _tempCtrl,
            keyboardType: TextInputType.number,
            decoration: d('Temperature', '°F'),
            validator: req);
      case VitalsType.weight:
        return TextFormField(
            controller: _weightCtrl,
            keyboardType: TextInputType.number,
            decoration: d('Weight', 'kg'),
            validator: req);
      case VitalsType.height:
        return TextFormField(
            controller: _heightCtrl,
            keyboardType: TextInputType.number,
            decoration: d('Height', 'cm'),
            validator: req);
      case VitalsType.bloodSugar:
        return TextFormField(
            controller: _bloodSugarCtrl,
            keyboardType: TextInputType.number,
            decoration: d('Blood Sugar', 'mg/dL'),
            validator: req);
      case VitalsType.oxygenSaturation:
        return TextFormField(
            controller: _oxygenCtrl,
            keyboardType: TextInputType.number,
            decoration: d('Oxygen Saturation', '%'),
            validator: req);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Add File Button ────────────────────────────────────────────
  Widget _addFileButton(Color color) {
    return TextButton.icon(
      onPressed: _pickFiles,
      icon: Icon(Icons.add_rounded, size: 16, color: color),
      label: Text('Add Files', style: TextStyle(fontSize: 12, color: color)),
      style: TextButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // ── File Section ───────────────────────────────────────────────
  Widget _buildFileSection(Color color) {
    if (_files.isEmpty) {
      return GestureDetector(
        onTap: _pickFiles,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withValues(alpha: 0.2), style: BorderStyle.solid),
          ),
          child: Column(children: [
            Icon(Icons.cloud_upload_outlined,
                size: 40, color: color.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Text('Tap to upload X-Rays, Images, PDFs',
                style: TextStyle(
                    color: color.withValues(alpha: 0.7), fontSize: 13)),
            const SizedBox(height: 4),
            Text('JPG, PNG, PDF, DOCX supported',
                style: TextStyle(color: Colors.grey[400], fontSize: 11)),
          ]),
        ),
      );
    }

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: _files.length + 1, // +1 for add more button
          itemBuilder: (ctx, i) {
            if (i == _files.length) return _addMoreTile(color);
            return _fileTile(_files[i], i, color);
          },
        ),
      ],
    );
  }

  Widget _fileTile(_PickedFile f, int i, Color color) {
    final isImage =
        ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'].contains(f.extension);
    final isPdf = f.extension == 'pdf';

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color.withValues(alpha: 0.06),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: isImage
              ? Image.file(File(f.path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.description_rounded,
                        color: isPdf ? Colors.red : _blue,
                        size: 30,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          f.name.length > 12
                              ? '${f.name.substring(0, 10)}...'
                              : f.name,
                          style:
                              const TextStyle(fontSize: 9, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeFile(i),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
        // Size badge
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatSize(f.size),
              style: const TextStyle(color: Colors.white, fontSize: 9),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addMoreTile(Color color) {
    return GestureDetector(
      onTap: _pickFiles,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: 0.06),
          border: Border.all(
              color: color.withValues(alpha: 0.2), style: BorderStyle.solid),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_photo_alternate_outlined, color: color, size: 26),
          const SizedBox(height: 4),
          Text('Add more', style: TextStyle(color: color, fontSize: 10)),
        ]),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}K';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ── Picked File Model ─────────────────────────────────────────
class _PickedFile {
  final String path;
  final String name;
  final int size;
  final String extension;

  const _PickedFile({
    required this.path,
    required this.name,
    required this.size,
    required this.extension,
  });
}
