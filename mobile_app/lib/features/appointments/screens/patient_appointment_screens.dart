import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import '../services/appointment_service.dart';

// ── File-level helpers ─────────────────────────────────────────

/// Returns "Dr. Name" but avoids "Dr. Dr. Name" if name already starts with "Dr."
String _doctorDisplayName(String name) {
  final trimmed = name.trim();
  if (trimmed.toLowerCase().startsWith('dr.') ||
      trimmed.toLowerCase().startsWith('dr ')) {
    return trimmed;
  }
  return 'Dr. $trimmed';
}

/// Parses a slot's date + endTime string (e.g. "11:00 AM") into a DateTime.
/// Returns null if parsing fails (slot is treated as not expired).
DateTime? _parseSlotEndDateTime(AppointmentSlot slot) {
  try {
    final timeStr = slot.endTime.trim(); // e.g. "11:00 AM"
    final parsed = DateFormat('h:mm a').parse(timeStr);
    return DateTime(
      slot.date.year,
      slot.date.month,
      slot.date.day,
      parsed.hour,
      parsed.minute,
    );
  } catch (_) {
    return null;
  }
}

// ══════════════════════════════════════════════════════════════
// PATIENT — Search & Book Appointment
// ══════════════════════════════════════════════════════════════
class PatientBookAppointmentScreen extends StatefulWidget {
  const PatientBookAppointmentScreen({super.key});

  @override
  State<PatientBookAppointmentScreen> createState() =>
      _PatientBookAppointmentScreenState();
}

class _PatientBookAppointmentScreenState
    extends State<PatientBookAppointmentScreen> {
  final _service = AppointmentService();
  final _searchCtrl = TextEditingController();

  List<DoctorProfile> _doctors = [];
  List<DoctorProfile> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() => _loading = true);
    try {
      final docs = await _service.searchDoctors('');
      if (mounted) {
        setState(() {
          _doctors = docs;
          _filtered = docs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? _doctors
          : _doctors.where((d) => d.matchesQuery(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Header
          Container(
            color: const Color(0xFF10B981),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find the right doctor',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'Search by doctor name or disease…',
                      hintStyle:
                          TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF10B981)),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearch('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _loadDoctors,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) =>
                              _DoctorCard(doctor: _filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No doctors found',
            style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different name or specialization',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

// ── Doctor Card ────────────────────────────────────────────────
class _DoctorCard extends StatelessWidget {
  final DoctorProfile doctor;
  const _DoctorCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DoctorSlotsScreen(doctor: doctor),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      doctor.name.isNotEmpty
                          ? doctor.name[0].toUpperCase()
                          : 'D',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _doctorDisplayName(doctor.name),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.medical_services,
                              size: 13, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              doctor.specialization.isEmpty
                                  ? 'General Practice'
                                  : doctor.specialization,
                              style: const TextStyle(
                                  color: Color(0xFF10B981), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (doctor.hospital.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.local_hospital,
                                size: 13, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                doctor.hospital,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (doctor.experience.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.work_outline,
                                size: 13, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              '${doctor.experience} experience',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (doctor.consultationFee.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '₹${doctor.consultationFee}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Doctor Slots Screen — pick a slot and book
// ══════════════════════════════════════════════════════════════
class DoctorSlotsScreen extends StatefulWidget {
  final DoctorProfile doctor;
  const DoctorSlotsScreen({super.key, required this.doctor});

  @override
  State<DoctorSlotsScreen> createState() => _DoctorSlotsScreenState();
}

class _DoctorSlotsScreenState extends State<DoctorSlotsScreen> {
  final _service = AppointmentService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_doctorDisplayName(widget.doctor.name)),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Doctor Info Banner
          Container(
            color: const Color(0xFF10B981),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medical_services,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.doctor.specialization.isEmpty
                            ? 'General Practice'
                            : widget.doctor.specialization,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15),
                      ),
                      if (widget.doctor.consultationFee.isNotEmpty)
                        Text(
                          'Consultation Fee: ₹${widget.doctor.consultationFee}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Available Slots
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Available Slots',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'Tap to book',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<AppointmentSlot>>(
              stream: _service.getSlotsForDoctor(widget.doctor.uid),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Filter out expired slots client-side
                final now = DateTime.now();
                final slots = (snap.data ?? []).where((s) {
                  // Parse end time to check if slot has already passed
                  final slotEndDateTime = _parseSlotEndDateTime(s);
                  return slotEndDateTime == null ||
                      slotEndDateTime.isAfter(now);
                }).toList();
                if (slots.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy,
                            size: 72, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No slots available',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check back later for new appointments',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: slots.length,
                  itemBuilder: (ctx, i) => _SlotCard(
                    slot: slots[i],
                    onBook: slots[i].isFull
                        ? null
                        : () => _showBookingDialog(slots[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingDialog(AppointmentSlot slot) {
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BookingBottomSheet(
        slot: slot,
        reasonCtrl: reasonCtrl,
        onConfirm: () async {
          if (reasonCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                  content: Text('Please describe your reason/symptoms')),
            );
            return;
          }
          Navigator.pop(ctx);
          await _confirmBooking(slot, reasonCtrl.text.trim());
        },
      ),
    );
  }

  Future<void> _confirmBooking(AppointmentSlot slot, String reason) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await _service.bookAppointment(slot: slot, reason: reason);
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Appointment Requested!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Your appointment is pending admin approval. You\'ll be notified once confirmed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // go back to doctor list
              },
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slot Card ─────────────────────────────────────────────────
class _SlotCard extends StatelessWidget {
  final AppointmentSlot slot;
  final VoidCallback? onBook;

  const _SlotCard({required this.slot, this.onBook});

  @override
  Widget build(BuildContext context) {
    final isFull = slot.isFull;
    final dateStr = DateFormat('EEE, dd MMM yyyy').format(slot.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFull
              ? Colors.grey[200]!
              : const Color(0xFF10B981).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Date column
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFull
                    ? Colors.grey[100]
                    : const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('dd').format(slot.date),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isFull ? Colors.grey : const Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(slot.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: isFull ? Colors.grey : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${slot.startTime} - ${slot.endTime}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isFull
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isFull
                              ? 'Fully Booked'
                              : '${slot.availableSlots} slot${slot.availableSlots != 1 ? 's' : ''} left',
                          style: TextStyle(
                            color: isFull ? Colors.red : Colors.green[700],
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (slot.consultationFee.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '₹${slot.consultationFee}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Book button
            ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isFull ? Colors.grey[300] : const Color(0xFF10B981),
                foregroundColor: isFull ? Colors.grey : Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(isFull ? 'Full' : 'Book'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Booking Bottom Sheet ───────────────────────────────────────
class _BookingBottomSheet extends StatelessWidget {
  final AppointmentSlot slot;
  final TextEditingController reasonCtrl;
  final VoidCallback onConfirm;

  const _BookingBottomSheet({
    required this.slot,
    required this.reasonCtrl,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 20),
          const Text(
            'Confirm Appointment',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Slot summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                _InfoRow(
                    icon: Icons.person,
                    label: 'Doctor',
                    value: _doctorDisplayName(slot.doctorName)),
                const SizedBox(height: 8),
                _InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value: DateFormat('EEE, dd MMM yyyy').format(slot.date)),
                const SizedBox(height: 8),
                _InfoRow(
                    icon: Icons.access_time,
                    label: 'Time',
                    value: '${slot.startTime} - ${slot.endTime}'),
                if (slot.consultationFee.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                      icon: Icons.currency_rupee,
                      label: 'Fee',
                      value: '₹${slot.consultationFee}'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Reason / Symptoms *',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Describe your symptoms or reason for visit…',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child:
                  const Text('Confirm Booking', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF10B981)),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
// PATIENT — My Appointments List
// ══════════════════════════════════════════════════════════════
class PatientMyAppointmentsScreen extends StatelessWidget {
  const PatientMyAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = AppointmentService();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Appointment>>(
        stream: svc.getMyAppointments(),
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
                  Icon(Icons.calendar_today_outlined,
                      size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No appointments yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PatientBookAppointmentScreen()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Book Now'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: appts.length,
            itemBuilder: (ctx, i) => _AppointmentCard(appt: appts[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const PatientBookAppointmentScreen()),
        ),
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add),
        label: const Text('Book Appointment'),
      ),
    );
  }
}

// ── Appointment Card (Patient View) ───────────────────────────
class _AppointmentCard extends StatelessWidget {
  final Appointment appt;
  const _AppointmentCard({required this.appt});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(appt.status);
    final canCancel = appt.status == AppointmentStatus.pending ||
        appt.status == AppointmentStatus.confirmed;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Status banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(appt.status), color: statusColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  appt.status.label,
                  style: TextStyle(
                      color: statusColor, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd MMM yyyy').format(appt.appointmentDate),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. ${appt.doctorName}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  appt.specialization,
                  style:
                      const TextStyle(color: Color(0xFF10B981), fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _chip(Icons.access_time, appt.timeSlot),
                    const SizedBox(width: 10),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Reason: ${appt.reason}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (appt.adminNote != null && appt.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            appt.adminNote!,
                            style: TextStyle(color: statusColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (canCancel) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _cancelConfirm(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Cancel Appointment'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        ],
      ),
    );
  }

  void _cancelConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content:
            const Text('Are you sure you want to cancel this appointment?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AppointmentService()
                  .cancelAppointment(appt.id, appt.slotId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
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
