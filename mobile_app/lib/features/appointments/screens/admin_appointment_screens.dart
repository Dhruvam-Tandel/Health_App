import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import '../services/appointment_service.dart';

// ══════════════════════════════════════════════════════════════
// ADMIN/STAFF — Full Appointment Management Screen
// Tabs: Pending Approvals | All Appointments | Manage Slots
// ══════════════════════════════════════════════════════════════
class AdminAppointmentsScreen extends StatefulWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  State<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState extends State<AdminAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Appointments Management'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions), text: 'Pending'),
            Tab(icon: Icon(Icons.list_alt), text: 'All'),
            Tab(icon: Icon(Icons.date_range), text: 'Slots'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PendingApprovalsTab(),
          _AllAppointmentsTab(),
          _ManageSlotsTab(),
        ],
      ),
    );
  }
}

// ── Tab 1: Pending Approvals ───────────────────────────────────
class _PendingApprovalsTab extends StatelessWidget {
  const _PendingApprovalsTab();

  @override
  Widget build(BuildContext context) {
    final svc = AppointmentService();
    return StreamBuilder<List<Appointment>>(
      stream: svc.getAllAppointments(statusFilter: 'pending'),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final appts = snap.data ?? [];
        if (appts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 72, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('All caught up!',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('No pending appointment requests',
                    style: TextStyle(color: Colors.grey[400])),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: appts.length,
          itemBuilder: (ctx, i) => _PendingApptCard(appt: appts[i]),
        );
      },
    );
  }
}

class _PendingApptCard extends StatelessWidget {
  final Appointment appt;
  const _PendingApptCard({required this.appt});

  @override
  Widget build(BuildContext context) {
    final svc = AppointmentService();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.hourglass_empty,
                      color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appt.patientEmail,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Requested ${DateFormat('dd MMM, hh:mm a').format(appt.createdAt)}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            // Details
            _Row(Icons.person, 'Doctor', 'Dr. ${appt.doctorName}'),
            const SizedBox(height: 6),
            _Row(Icons.medical_services, 'Specialty', appt.specialization),
            const SizedBox(height: 6),
            _Row(Icons.calendar_today, 'Date',
                DateFormat('EEE, dd MMM yyyy').format(appt.appointmentDate)),
            const SizedBox(height: 6),
            _Row(Icons.access_time, 'Time', appt.timeSlot),
            const SizedBox(height: 6),
            _Row(Icons.notes, 'Reason', appt.reason),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(context, svc, appt.id),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showApproveDialog(context, svc, appt.id),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showApproveDialog(BuildContext ctx, AppointmentService svc, String id) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add an optional note for the patient:'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. Please bring previous reports',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              await svc.approveAppointment(id, note: noteCtrl.text.trim());
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Appointment approved!'),
                  backgroundColor: Colors.green,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext ctx, AppointmentService svc, String id) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Provide reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection…',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(dCtx);
              await svc.rejectAppointment(id, reason: reasonCtrl.text.trim());
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Appointment rejected'),
                  backgroundColor: Colors.red,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: All Appointments ────────────────────────────────────
class _AllAppointmentsTab extends StatefulWidget {
  const _AllAppointmentsTab();

  @override
  State<_AllAppointmentsTab> createState() => _AllAppointmentsTabState();
}

class _AllAppointmentsTabState extends State<_AllAppointmentsTab> {
  String _filter = 'all';
  final _svc = AppointmentService();

  final _filters = [
    ('all', 'All'),
    ('pending', 'Pending'),
    ('confirmed', 'Confirmed'),
    ('rejected', 'Rejected'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Container(
          height: 50,
          color: Colors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _filters.length,
            itemBuilder: (ctx, i) {
              final isSelected = _filter == _filters[i].$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_filters[i].$2),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _filter = _filters[i].$1),
                  selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  checkmarkColor: const Color(0xFF8B5CF6),
                  labelStyle: TextStyle(
                    color:
                        isSelected ? const Color(0xFF8B5CF6) : Colors.grey[700],
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<Appointment>>(
            stream: _svc.getAllAppointments(
                statusFilter: _filter == 'all' ? null : _filter),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final appts = snap.data ?? [];
              if (appts.isEmpty) {
                return Center(
                  child: Text('No appointments',
                      style: TextStyle(color: Colors.grey[500])),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: appts.length,
                itemBuilder: (ctx, i) => _AdminApptListTile(appt: appts[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminApptListTile extends StatelessWidget {
  final Appointment appt;
  const _AdminApptListTile({required this.appt});

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(appt.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: c.withValues(alpha: 0.1),
          child: Icon(_statusIcon(appt.status), color: c, size: 20),
        ),
        title: Text(
          'Dr. ${appt.doctorName}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(appt.patientEmail,
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            Text(
              '${DateFormat('dd MMM').format(appt.appointmentDate)} • ${appt.timeSlot}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(appt.status.label,
              style: TextStyle(
                  color: c, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Color _statusColor(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.confirmed:
        return Colors.green;
      case AppointmentStatus.rejected:
        return Colors.red;
      case AppointmentStatus.completed:
        return Colors.blue;
      case AppointmentStatus.cancelled:
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.confirmed:
        return Icons.check_circle;
      case AppointmentStatus.rejected:
        return Icons.cancel;
      case AppointmentStatus.completed:
        return Icons.done_all;
      case AppointmentStatus.cancelled:
        return Icons.block;
      default:
        return Icons.hourglass_empty;
    }
  }
}

// ── Tab 3: Manage Slots ────────────────────────────────────────
class _ManageSlotsTab extends StatelessWidget {
  const _ManageSlotsTab();

  @override
  Widget build(BuildContext context) {
    final svc = AppointmentService();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateSlotScreen()),
        ),
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.add),
        label: const Text('Create Slot'),
      ),
      body: StreamBuilder<List<AppointmentSlot>>(
        stream: svc.getAllSlots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final slots = snap.data ?? [];
          if (slots.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available,
                      size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No slots created',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Tap + to create appointment slots for doctors',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: slots.length,
            itemBuilder: (ctx, i) =>
                _AdminSlotCard(slot: slots[i], service: svc),
          );
        },
      ),
    );
  }
}

class _AdminSlotCard extends StatelessWidget {
  final AppointmentSlot slot;
  final AppointmentService service;
  const _AdminSlotCard({required this.slot, required this.service});

  @override
  Widget build(BuildContext context) {
    final isFull = slot.isFull;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: slot.isActive
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
              : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person,
                      color: Color(0xFF8B5CF6), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${slot.doctorName}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        slot.specialization,
                        style: const TextStyle(
                            color: Color(0xFF8B5CF6), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: slot.isActive,
                  activeThumbColor: const Color(0xFF8B5CF6),
                  onChanged: (v) => service.toggleSlot(slot.id, v),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                _chip(Icons.calendar_today,
                    DateFormat('dd MMM yyyy').format(slot.date)),
                const SizedBox(width: 8),
                _chip(Icons.access_time, '${slot.startTime} - ${slot.endTime}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(Icons.people,
                    '${slot.bookedCount}/${slot.maxPatients} booked',
                    color: isFull ? Colors.red : Colors.green),
                if (slot.consultationFee.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _chip(Icons.currency_rupee, slot.consultationFee),
                ],
                const Spacer(),
                if (!slot.isActive || slot.bookedCount == 0)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    onPressed: () => _deleteConfirm(context),
                    tooltip: 'Delete Slot',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color ?? Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: color ?? Colors.grey[700])),
        ],
      ),
    );
  }

  void _deleteConfirm(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Slot'),
        content: const Text(
            'Are you sure you want to delete this slot? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              await service.deleteSlot(slot.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Row helper ─────────────────────────────────────────────────
class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text('$label: ',
            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Create Slot Screen (Admin)
// ══════════════════════════════════════════════════════════════
class CreateSlotScreen extends StatefulWidget {
  const CreateSlotScreen({super.key});

  @override
  State<CreateSlotScreen> createState() => _CreateSlotScreenState();
}

class _CreateSlotScreenState extends State<CreateSlotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _svc = AppointmentService();

  DoctorProfile? _selectedDoctor;
  List<DoctorProfile> _doctors = [];
  bool _loadingDoctors = true;

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _maxPatientsCtrl = TextEditingController(text: '10');
  final _feeCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _maxPatientsCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    try {
      final docs = await _svc.getAllDoctors();
      if (mounted) {
        setState(() {
          _doctors = docs;
          _loadingDoctors = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingDoctors = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load doctors: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _timeOfDayToString(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickStartTime() async {
    final t = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (t != null) setState(() => _startTime = t);
  }

  Future<void> _pickEndTime() async {
    final t = await showTimePicker(
        context: context,
        initialTime: _startTime ?? const TimeOfDay(hour: 10, minute: 0));
    if (t != null) setState(() => _endTime = t);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDoctor == null) {
      _showError('Please select a doctor');
      return;
    }
    if (_selectedDate == null) {
      _showError('Please select a date');
      return;
    }
    if (_startTime == null || _endTime == null) {
      _showError('Please select start and end times');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _svc.createSlot(
        doctorId: _selectedDoctor!.uid,
        doctorName: _selectedDoctor!.name,
        specialization: _selectedDoctor!.specialization,
        date: _selectedDate!,
        startTime: _timeOfDayToString(_startTime!),
        endTime: _timeOfDayToString(_endTime!),
        maxPatients: int.tryParse(_maxPatientsCtrl.text) ?? 10,
        consultationFee: _feeCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slot created successfully!'),
            backgroundColor: Color(0xFF8B5CF6),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Create Appointment Slot'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: _loadingDoctors
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Doctor Selection
                    _sectionLabel('Select Doctor *'),
                    const SizedBox(height: 8),
                    if (_doctors.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.orange),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No doctors found. Please register doctors first.',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<DoctorProfile>(
                        initialValue: _selectedDoctor,
                        hint: const Text('Choose a doctor'),
                        isExpanded: true,
                        items: _doctors.map((d) {
                          return DropdownMenuItem(
                            value: d,
                            child: Text(
                              'Dr. ${d.name}${d.specialization.isNotEmpty ? ' (${d.specialization})' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (d) => setState(() => _selectedDoctor = d),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Date
                    _sectionLabel('Appointment Date *'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 12),
                            Text(
                              _selectedDate == null
                                  ? 'Select Date'
                                  : DateFormat('EEE, dd MMMM yyyy')
                                      .format(_selectedDate!),
                              style: TextStyle(
                                color: _selectedDate == null
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Time
                    _sectionLabel('Time Slot *'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickStartTime,
                            child: _timePicker('Start Time', _startTime),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickEndTime,
                            child: _timePicker('End Time', _endTime),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Max patients + fee
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Max Patients *'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _maxPatientsCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.people),
                                ),
                                validator: (v) => (v == null ||
                                        v.isEmpty ||
                                        int.tryParse(v) == null)
                                    ? 'Required'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Fee (₹)'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _feeCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.currency_rupee),
                                  hintText: 'Optional',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Create Slot',
                                style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String s) => Text(s,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14));

  Widget _timePicker(String label, TimeOfDay? time) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time,
              color: time == null ? Colors.grey : const Color(0xFF8B5CF6),
              size: 18),
          const SizedBox(width: 8),
          Text(
            time == null ? label : _timeOfDayToString(time),
            style: TextStyle(color: time == null ? Colors.grey : Colors.black),
          ),
        ],
      ),
    );
  }
}
