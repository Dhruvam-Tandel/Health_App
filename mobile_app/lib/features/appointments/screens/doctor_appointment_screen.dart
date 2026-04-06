import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import '../services/appointment_service.dart';
import 'doctor_prescription_screen.dart';

// ══════════════════════════════════════════════════════════════
// DOCTOR — View All Assigned Appointments
// ══════════════════════════════════════════════════════════════
class DoctorAppointmentsScreen extends StatefulWidget {
  final String doctorId;
  const DoctorAppointmentsScreen({super.key, required this.doctorId});

  @override
  State<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _svc = AppointmentService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('My Appointments'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.event_available), text: 'Confirmed'),
            Tab(icon: Icon(Icons.history), text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ConfirmedTab(doctorId: widget.doctorId, service: _svc),
          _AllDoctorTab(doctorId: widget.doctorId, service: _svc),
        ],
      ),
    );
  }
}

// ── Confirmed Tab ──────────────────────────────────────────────
class _ConfirmedTab extends StatelessWidget {
  final String doctorId;
  final AppointmentService service;
  const _ConfirmedTab({required this.doctorId, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: service.getDoctorAppointments(doctorId),
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
                Icon(Icons.event_busy, size: 72, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No confirmed appointments',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text('Confirmed bookings will appear here',
                    style: TextStyle(color: Colors.grey[400])),
              ],
            ),
          );
        }
        // Group by date
        final grouped = <String, List<Appointment>>{};
        for (final a in appts) {
          final key =
              DateFormat('EEEE, dd MMMM yyyy').format(a.appointmentDate);
          grouped.putIfAbsent(key, () => []).add(a);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: grouped.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
                ...entry.value
                    .map((a) => _DoctorApptCard(appt: a, service: service)),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

// ── All Appointments Tab ───────────────────────────────────────
class _AllDoctorTab extends StatelessWidget {
  final String doctorId;
  final AppointmentService service;
  const _AllDoctorTab({required this.doctorId, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: service.getDoctorAllAppointments(doctorId),
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
          padding: const EdgeInsets.all(16),
          itemCount: appts.length,
          itemBuilder: (ctx, i) =>
              _DoctorApptCard(appt: appts[i], service: service),
        );
      },
    );
  }
}

// ── Doctor Appointment Card ────────────────────────────────────
class _DoctorApptCard extends StatelessWidget {
  final Appointment appt;
  final AppointmentService service;
  const _DoctorApptCard({required this.appt, required this.service});

  @override
  Widget build(BuildContext context) {
    final isConfirmed = appt.status == AppointmentStatus.confirmed;
    final statusColor = _statusColor(appt.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient row
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  child: Text(
                    appt.patientEmail.isNotEmpty
                        ? appt.patientEmail[0].toUpperCase()
                        : 'P',
                    style: const TextStyle(
                        color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appt.patientEmail,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        DateFormat('EEE, dd MMM yyyy')
                            .format(appt.appointmentDate),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    appt.status.label,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            // Time & Reason
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(appt.timeSlot,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    appt.reason,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Mark as complete button (only for confirmed)
            if (isConfirmed) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markComplete(context),
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('Mark as Completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _markComplete(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorPrescriptionScreen(
          appointmentId: appt.id,
          patientId: appt.patientId,
          patientEmail: appt.patientEmail,
          patientName: appt.patientEmail,
          doctorName: appt.doctorName,
          slotId: appt.slotId,
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
}
