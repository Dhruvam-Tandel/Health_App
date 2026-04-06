import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../health_records/screens/attachment_viewer_screen.dart';

// ══════════════════════════════════════════════════════════════
// Doctor's Patient Detail Screen
// Shows patient profile + records (tap record → full detail)
// ══════════════════════════════════════════════════════════════

const _blue = Color(0xFF2563EB);
const _teal = Color(0xFF0D9488);
const _bg = Color(0xFFF8FAFC);

class DoctorPatientDetailScreen extends StatelessWidget {
  final String patientId;
  final String doctorId;
  final String patientName;

  const DoctorPatientDetailScreen({
    super.key,
    required this.patientId,
    required this.doctorId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    final initial = patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _bg,
        body: NestedScrollView(
          headerSliverBuilder: (ctx, inner) => [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E3A8A), _blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: Text(initial,
                              style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                        const SizedBox(height: 10),
                        Text(patientName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Patient',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              bottom: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: [
                  Tab(icon: Icon(Icons.person_outline), text: 'Profile'),
                  Tab(icon: Icon(Icons.folder_outlined), text: 'Records'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _PatientProfileView(patientId: patientId),
              _PatientRecordsView(patientId: patientId),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Profile view — fetches from patients collection
// ──────────────────────────────────────────────────────────────
class _PatientProfileView extends StatelessWidget {
  final String patientId;
  const _PatientProfileView({required this.patientId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .get(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _blue));
        }
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final profile = data['profile'] as Map<String, dynamic>? ?? {};
        final medInfo = data['medicalInfo'] as Map<String, dynamic>? ?? {};

        final fields = [
          (Icons.email_outlined, 'Email', data['email'] as String? ?? '—'),
          (
            Icons.cake_outlined,
            'Date of Birth',
            profile['dateOfBirth'] as String? ?? '—'
          ),
          (Icons.wc_outlined, 'Gender', profile['gender'] as String? ?? '—'),
          (
            Icons.phone_outlined,
            'Phone',
            profile['phoneNumber'] as String? ?? '—'
          ),
          (
            Icons.bloodtype_outlined,
            'Blood Group',
            profile['bloodGroup'] as String? ?? '—'
          ),
          (
            Icons.location_on_outlined,
            'Address',
            profile['address'] as String? ?? '—'
          ),
          (
            Icons.contact_emergency_outlined,
            'Emergency Contact',
            profile['emergencyContact'] as String? ?? '—'
          ),
        ];

        final allergies = (medInfo['allergies'] as List? ?? []).join(', ');
        final conditions =
            (medInfo['chronicConditions'] as List? ?? []).join(', ');
        final meds = (medInfo['currentMedications'] as List? ?? []).join(', ');

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(
              title: 'Personal Information',
              icon: Icons.person_outline,
              color: _blue,
              children: fields.map((f) => _InfoRow(f.$1, f.$2, f.$3)).toList(),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Medical Information',
              icon: Icons.medical_information_outlined,
              color: _teal,
              children: [
                _InfoRow(Icons.warning_amber_outlined, 'Allergies',
                    allergies.isNotEmpty ? allergies : 'None'),
                _InfoRow(Icons.health_and_safety_outlined, 'Chronic Conditions',
                    conditions.isNotEmpty ? conditions : 'None'),
                _InfoRow(Icons.medication_outlined, 'Current Medications',
                    meds.isNotEmpty ? meds : 'None'),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Records view — tappable cards with full detail bottom sheet
// ──────────────────────────────────────────────────────────────
class _PatientRecordsView extends StatelessWidget {
  final String patientId;
  const _PatientRecordsView({required this.patientId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('health_records')
          .where('patientId', isEqualTo: patientId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _blue));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Could not load records',
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('${snap.error}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No health records found',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                const SizedBox(height: 8),
                Text('Records added by this patient will appear here',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final title = d['title'] as String? ?? 'Health Record';
            final category = d['category'] as String? ?? '';
            final type = d['recordType'] as String? ?? category;
            final ts = d['date'] as Timestamp?;
            final dateStr = ts != null
                ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
                : '';
            final role = d['addedByRole'] as String? ?? 'patient';
            final Color roleColor = role == 'doctor' ? _blue : _teal;
            final String roleLabel =
                role == 'doctor' ? 'Added by Doctor' : 'Added by Patient';

            final categoryIcon = _categoryIcon(category);

            return GestureDetector(
              onTap: () => _showRecordDetail(context, d),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(categoryIcon, color: _blue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          if (type.isNotEmpty)
                            Text(type,
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
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
                              const Spacer(),
                              Text(dateStr,
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[400])),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right,
                        color: Colors.grey, size: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'vitals':
        return Icons.monitor_heart_outlined;
      case 'lab reports':
        return Icons.science_outlined;
      case 'imaging':
        return Icons.image_outlined;
      case 'prescriptions':
        return Icons.medication_outlined;
      case 'visits':
        return Icons.local_hospital_outlined;
      case 'vaccinations':
        return Icons.vaccines_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  void _showRecordDetail(BuildContext context, Map<String, dynamic> d) {
    final title = d['title'] as String? ?? 'Health Record';
    final category = d['category'] as String? ?? '—';
    final recordType = d['recordType'] as String? ?? '—';
    final description = d['description'] as String? ?? '';
    final doctorName = d['doctorName'] as String? ?? '';
    final hospital = d['hospital'] as String? ?? '';
    final notes = d['notes'] as String? ?? '';
    final addedByRole = d['addedByRole'] as String? ?? 'patient';
    final vitalsData = d['data'] as Map<String, dynamic>? ?? {};
    final attachments = (d['attachments'] as List?)?.cast<String>() ?? [];

    final ts = d['date'] as Timestamp?;
    final dateStr = ts != null
        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
        : '—';
    final createdTs = d['createdAt'] as Timestamp?;
    final createdStr = createdTs != null
        ? '${createdTs.toDate().day}/${createdTs.toDate().month}/${createdTs.toDate().year}'
        : '—';

    final roleColor = addedByRole == 'doctor' ? _blue : _teal;
    final roleLabel =
        addedByRole == 'doctor' ? 'Added by Doctor' : 'Added by Patient';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.82,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          Icon(_categoryIcon(category), color: _blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(roleLabel,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: roleColor,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 24, color: Colors.grey[100]),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  children: [
                    _detailBlock('Record Info', [
                      _detailRow('Category', category),
                      _detailRow('Type', recordType),
                      _detailRow('Date', dateStr),
                      _detailRow('Recorded On', createdStr),
                    ]),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _detailBlock('Description', [
                        _detailRow('Details', description),
                      ]),
                    ],
                    if (vitalsData.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _detailBlock(
                        'Measurements / Vitals Data',
                        vitalsData.entries
                            .map((e) =>
                                _detailRow(_formatKey(e.key), '${e.value}'))
                            .toList(),
                      ),
                    ],
                    if (doctorName.isNotEmpty || hospital.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _detailBlock('Medical Provider', [
                        if (doctorName.isNotEmpty)
                          _detailRow('Doctor', doctorName),
                        if (hospital.isNotEmpty)
                          _detailRow('Hospital / Clinic', hospital),
                      ]),
                    ],
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _detailBlock('Notes', [
                        _detailRow('Notes', notes),
                      ]),
                    ],
                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Attachments',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _blue)),
                            const SizedBox(height: 10),
                            ...attachments.map((url) {
                                  final isImage = url.toLowerCase().contains('.jpg') ||
                                      url.toLowerCase().contains('.jpeg') ||
                                      url.toLowerCase().contains('.png') ||
                                      url.toLowerCase().contains('.webp');
                                      
                                  if (isImage) {
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AttachmentViewerScreen(url: url),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            url,
                                            height: 150,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  return GestureDetector(
                                    onTap: () async {
                                      try {
                                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                      } catch (_) {}
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.attach_file,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(url,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: _blue,
                                                    decoration:
                                                        TextDecoration.underline),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatKey(String key) {
    final result = key.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => ' ${m.group(0)}',
    );
    if (result.isEmpty) return key;
    return result[0].toUpperCase() + result.substring(1);
  }
}

// ── Detail Sheet Helpers ───────────────────────────────────────
Widget _detailBlock(String title, List<Widget> rows) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: _blue)),
        const SizedBox(height: 12),
        ...rows,
      ],
    ),
  );
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B)),
          ),
        ),
      ],
    ),
  );
}

// ── Shared Section / InfoRow ───────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
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
          Row(children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Colors.grey[400]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1E1E))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
