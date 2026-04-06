import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/services/auth_service.dart';
import '../../appointments/screens/doctor_appointment_screen.dart';
import 'doctor_patient_detail_screen.dart';

// ── Colors ──────────────────────────────────────────────────
const _blue = Color(0xFF2563EB);
const _blueLight = Color(0xFF60A5FA);
const _bg = Color(0xFFF8FAFC);
const _teal = Color(0xFF0D9488);
const _amber = Color(0xFFF59E0B);
const _red = Color(0xFFEF4444);

/// Shared tab switcher
final _tabIndex = ValueNotifier<int>(0);

// ═══════════════════════════════════════════════════════════════
//  MAIN SHELL
// ═══════════════════════════════════════════════════════════════
class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});
  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  @override
  void initState() {
    super.initState();
    _tabIndex.addListener(_onTabChange);
  }

  @override
  void dispose() {
    _tabIndex.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(
        index: _tabIndex.value,
        children: const [
          _HomeTab(),
          _PatientsTab(),
          _AppointmentsTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex.value,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        indicatorColor: _blueLight.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => _tabIndex.value = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: _blue),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: _blue),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: _blue),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: _blue),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HOME TAB  —  Real-time data
// ═══════════════════════════════════════════════════════════════
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    final doctorId = user?.uid ?? '';
    final name = user?.email?.split('@')[0] ?? 'Doctor';

    return CustomScrollView(
      slivers: [
        // ── Custom Header ───────────────────────────
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_blue, _blueLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _greeting(),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dr. $name',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuickStats(doctorId),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Today\'s Appointments',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E))),
                    TextButton(
                      onPressed: () => _tabIndex.value = 2,
                      child: const Text('View All',
                          style: TextStyle(color: _blue)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDynamicTodaySchedule(doctorId),
                const SizedBox(height: 28),
                const Text('Recent Patients',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E))),
                const SizedBox(height: 12),
                _buildDynamicRecentPatients(context),
                const SizedBox(height: 28),
                const Text('Quick Actions',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E))),
                const SizedBox(height: 12),
                const _QuickActionsGrid(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Realtime Stats (doctor-scoped) ─────────────────────────
  Widget _buildQuickStats(String doctorId) {
    return FutureBuilder<List<AggregateQuerySnapshot>>(
      future: Future.wait([
        // Count unique patients who have had appointments with this doctor
        FirebaseFirestore.instance
            .collection('appointments')
            .where('doctorId', isEqualTo: doctorId)
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('appointment_slots')
            .where('doctorId', isEqualTo: doctorId)
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('appointments')
            .where('doctorId', isEqualTo: doctorId)
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
      ]),
      builder: (context, snapshot) {
        int totalAppts = 0;
        int totalSlots = 0;
        int pending = 0;

        if (snapshot.hasData) {
          totalAppts = snapshot.data![0].count ?? 0;
          totalSlots = snapshot.data![1].count ?? 0;
          pending = snapshot.data![2].count ?? 0;
        }

        return Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.people_rounded,
                label: 'Total Appointments',
                value: '$totalAppts',
                color: _blue,
                bgColor: _blue.withValues(alpha: 0.1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.access_time_filled_rounded,
                label: 'Active Slots',
                value: '$totalSlots',
                color: _teal,
                bgColor: _teal.withValues(alpha: 0.1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.assignment_late_rounded,
                label: 'Pending',
                value: '$pending',
                color: _amber,
                bgColor: _amber.withValues(alpha: 0.1),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Today's Schedule (Mapped visually) ──────────────────────
  Widget _buildDynamicTodaySchedule(String doctorId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointment_slots')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('date')
          .orderBy('startTime')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                'Query Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: const Column(
              children: [
                Icon(Icons.event_busy, color: Colors.grey, size: 40),
                SizedBox(height: 12),
                Text('No slots scheduled for today',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final start = d['startTime'] as String? ?? '';
              final end = d['endTime'] as String? ?? '';
              final booked = d['bookedCount'] as int? ?? 0;
              final max = d['totalSlots'] as int? ?? 1;

              final isFull = booked >= max;
              final progress = max > 0 ? (booked / max) : 0.0;
              final Color indicatorColor = isFull ? _red : _teal;

              return Column(
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: indicatorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.schedule, color: indicatorColor),
                    ),
                    title: Text('$start - $end',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[200],
                            valueColor:
                                AlwaysStoppedAnimation<Color>(indicatorColor),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 4),
                          Text('$booked / $max patients booked',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    trailing: isFull
                        ? Chip(
                            backgroundColor: _red.withValues(alpha: 0.1),
                            side: BorderSide.none,
                            label: const Text('Full',
                                style: TextStyle(
                                    color: _red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)))
                        : Chip(
                            backgroundColor: _teal.withValues(alpha: 0.1),
                            side: BorderSide.none,
                            label: const Text('Open',
                                style: TextStyle(
                                    color: _teal,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold))),
                  ),
                  if (doc.id != docs.last.id)
                    Divider(height: 1, color: Colors.grey[200]),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── Recent Patients (doctor-scoped) ────────────────────────
  Widget _buildDynamicRecentPatients(BuildContext context) {
    final doctorId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid ?? '';
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('appointmentDate', descending: true)
          .limit(10)
          .get(),
      builder: (context, apptSnap) {
        if (!apptSnap.hasData) return const SizedBox();

        // Collect unique patient IDs
        final patientIds = apptSnap.data!.docs
            .map((d) => d['patientId'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .take(5)
            .toList();

        if (patientIds.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.people_outline, color: Colors.grey, size: 40),
                SizedBox(height: 12),
                Text('No patients yet', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(patientIds.map((id) =>
              FirebaseFirestore.instance.collection('patients').doc(id).get())),
          builder: (context, patSnap) {
            if (!patSnap.hasData) return const SizedBox();
            final docs = patSnap.data!.where((d) => d.exists).toList();

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final name = d['fullName'] as String? ?? 'Patient';
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
                  final profile = d['profile'] as Map<String, dynamic>? ?? {};
                  final blood = profile['bloodGroup'] as String? ?? '';

                  return Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _blueLight.withValues(alpha: 0.2),
                          foregroundColor: _blue,
                          child: Text(initial,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            blood.isNotEmpty
                                ? 'Blood: $blood'
                                : 'Appointment patient',
                            style: const TextStyle(fontSize: 13)),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DoctorPatientDetailScreen(
                                patientId: doc.id,
                                doctorId: doctorId,
                                patientName: name,
                              ),
                            ),
                          );
                        },
                      ),
                      if (doc.id != docs.last.id)
                        Divider(height: 1, color: Colors.grey[100]),
                    ],
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Quick Actions Grid ────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: Icons.event_available_rounded,
        label: 'My Schedule',
        color: _teal,
        onTap: () => _tabIndex.value = 2,
      ),
      (
        icon: Icons.manage_search_rounded,
        label: 'Find Patient',
        color: _blue,
        onTap: () => _tabIndex.value = 1,
      ),
      (
        icon: Icons.science_outlined,
        label: 'Lab Records',
        color: _amber,
        onTap: () {},
      ),
      (
        icon: Icons.assignment_outlined,
        label: 'Prescriptions',
        color: _red,
        onTap: () {},
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: actions
          .map((a) => _QuickTile(a.icon, a.label, a.color, a.onTap))
          .toList(),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color baseColor;
  final VoidCallback onTap;
  const _QuickTile(this.icon, this.label, this.baseColor, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: baseColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PATIENTS TAB  —  Doctor-scoped (only doctor's patients)
// ═══════════════════════════════════════════════════════════════
class _PatientsTab extends StatefulWidget {
  const _PatientsTab();
  @override
  State<_PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<_PatientsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final doctorId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('My Patients',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
        ),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('appointments')
            .where('doctorId', isEqualTo: doctorId)
            .get(),
        builder: (context, apptSnap) {
          if (apptSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _blue));
          }

          // Collect unique patient IDs from all this doctor's appointments
          final patientIds = apptSnap.data?.docs
                  .map((d) => d['patientId'] as String? ?? '')
                  .where((id) => id.isNotEmpty)
                  .toSet()
                  .toList() ??
              [];

          if (patientIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No patients yet',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                      'Patients who book appointments with you will appear here',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return FutureBuilder<List<DocumentSnapshot>>(
            future: Future.wait(patientIds.map((id) => FirebaseFirestore
                .instance
                .collection('patients')
                .doc(id)
                .get())),
            builder: (context, patSnap) {
              if (patSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _blue));
              }

              var docs = (patSnap.data ?? []).where((d) => d.exists).toList();

              // Apply search filter
              if (_searchQuery.isNotEmpty) {
                docs = docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final name = (d['fullName'] as String? ?? '').toLowerCase();
                  final email = (d['email'] as String? ?? '').toLowerCase();
                  return name.contains(_searchQuery) ||
                      email.contains(_searchQuery);
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No patients found',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 16)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final d = doc.data() as Map<String, dynamic>;
                  final name = d['fullName'] as String? ?? 'Patient';
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
                  final email = d['email'] as String? ?? '';
                  final profile = d['profile'] as Map<String, dynamic>? ?? {};
                  final blood = profile['bloodGroup'] as String? ?? '—';

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DoctorPatientDetailScreen(
                            patientId: doc.id,
                            doctorId: doctorId,
                            patientName: name,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10)
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: _blueLight.withValues(alpha: 0.15),
                          child: Text(initial,
                              style: const TextStyle(
                                  color: _blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ),
                        title: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(email, style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  _MiniTag('Blood: $blood', Colors.red),
                                  const SizedBox(width: 8),
                                  const _MiniTag('Tap to view records', _blue),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing:
                            const Icon(Icons.chevron_right, color: Colors.grey),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  APPOINTMENTS TAB
// ═══════════════════════════════════════════════════════════════
class _AppointmentsTab extends StatelessWidget {
  const _AppointmentsTab();
  @override
  Widget build(BuildContext context) {
    final uid =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid ?? '';
    return DoctorAppointmentsScreen(doctorId: uid);
  }
}

// ═══════════════════════════════════════════════════════════════
//  PROFILE TAB
// ═══════════════════════════════════════════════════════════════
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = authService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          FirebaseFirestore.instance.collection('users').doc(uid).get(),
          FirebaseFirestore.instance.collection('doctors').doc(uid).get(),
        ]),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _blue));
          }

          final userData = (snap.data?[0] as DocumentSnapshot?)?.data()
                  as Map<String, dynamic>? ??
              {};
          final docData = (snap.data?[1] as DocumentSnapshot?)?.data()
                  as Map<String, dynamic>? ??
              {};

          final name = (userData['fullName'] as String?)?.trim().isNotEmpty ==
                  true
              ? userData['fullName'] as String
              : authService.currentUser?.email?.split('@').first ?? 'Doctor';

          final email = authService.currentUser?.email ?? '';
          final license = userData['licenseNumber'] as String? ?? '—';
          final spec =
              docData['specialization'] as String? ?? 'General Practice';
          final hosp = docData['hospital'] as String? ?? 'Independent';
          final fee = docData['consultationFee'] as String? ?? 'N/A';
          final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                elevation: 0,
                title: const Text('Doctor Profile',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Edit profile coming soon')),
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E3A8A), _blue, _blueLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            CircleAvatar(
                              radius: 40,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              child: Text(initial,
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ),
                            const SizedBox(height: 10),
                            Text('Dr. $name',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified,
                                      color: Colors.white, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    spec,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Work info
                      _InfoCard(
                        title: 'Professional Details',
                        icon: Icons.business_center_outlined,
                        rows: [
                          _InfoRow(
                              Icons.badge_outlined, 'License Number', license),
                          _InfoRow(
                              Icons.local_hospital_outlined, 'Hospital', hosp),
                          _InfoRow(Icons.payments_outlined, 'Consultation Fee',
                              '₹$fee'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Contact
                      _InfoCard(
                        title: 'Contact',
                        icon: Icons.contact_mail_outlined,
                        rows: [
                          _InfoRow(
                              Icons.email_outlined, 'Email Address', email),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10),
                          ],
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.logout, color: _red),
                              title: const Text('Sign Out',
                                  style: TextStyle(
                                      color: _red,
                                      fontWeight: FontWeight.w600)),
                              onTap: () async {
                                await authService.logout();
                                if (context.mounted) {
                                  context.go('/login');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Shared Info Cards for Profile ──────────────────────────────
class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> rows;
  const _InfoCard(
      {required this.title, required this.icon, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _blue, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E1B4B))),
            ],
          ),
          const SizedBox(height: 16),
          ...rows,
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
        children: [
          Icon(icon, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1E1E))),
            ],
          ),
        ],
      ),
    );
  }
}
