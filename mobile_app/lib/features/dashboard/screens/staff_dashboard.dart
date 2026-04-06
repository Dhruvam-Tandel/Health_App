import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../auth/services/auth_service.dart';
import '../../appointments/screens/admin_appointment_screens.dart';
import '../../appointments/screens/admin_medical_reports_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  COLOUR PALETTE
// ═══════════════════════════════════════════════════════════════
const _purple = Color(0xFF7C3AED);
const _purpleLight = Color(0xFF8B5CF6);
const _purpleSurface = Color(0xFFF5F3FF);
const _green = Color(0xFF059669);
const _amber = Color(0xFFF59E0B);
const _red = Color(0xFFEF4444);
const _blue = Color(0xFF3B82F6);
const _bg = Color(0xFFF8F7FF);

/// Shared tab switcher so child widgets can trigger tab changes.
final _tabIndex = ValueNotifier<int>(0);

// ═══════════════════════════════════════════════════════════════
//  MAIN SHELL
// ═══════════════════════════════════════════════════════════════
class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});
  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
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
          _TasksTab(),
          _PatientsTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex.value,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        indicatorColor: _purpleLight.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => _tabIndex.value = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: _purpleLight),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: _purpleLight),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: _purpleLight),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: _purpleLight),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HOME TAB  —  fully dynamic
// ═══════════════════════════════════════════════════════════════
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = authService.currentUser?.uid ?? '';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (ctx, snap) {
        final userData = snap.data?.data() as Map<String, dynamic>? ?? {};
        final name = (userData['fullName'] as String?)?.trim() ?? 'Admin';
        final adminId = (userData['adminId'] as String?) ?? '';

        return CustomScrollView(
          slivers: [
            // ── Sliver App Bar ──────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                  onPressed: () {},
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: _HeaderBanner(name: name, adminId: adminId),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Live stat cards ──────────────────────────
                    const _LiveStatsRow(),
                    const SizedBox(height: 28),

                    // ── Today's appointments ─────────────────────
                    _sectionHeader(context, "Today's Appointments",
                        subtitle:
                            DateFormat('EEEE, d MMM').format(DateTime.now())),
                    const SizedBox(height: 12),
                    const _TodayAppointments(),
                    const SizedBox(height: 28),

                    // ── Quick Actions ────────────────────────────
                    _sectionHeader(context, 'Quick Actions'),
                    const SizedBox(height: 12),
                    const _QuickActionsGrid(),
                    const SizedBox(height: 28),

                    // ── Recent bookings stream ───────────────────
                    _sectionHeader(context, 'Recent Bookings'),
                    const SizedBox(height: 12),
                    const _RecentBookings(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(BuildContext context, String title,
      {String? subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1B4B)),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(subtitle,
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ],
    );
  }
}

// ── Gradient header with real name ───────────────────────────
class _HeaderBanner extends StatelessWidget {
  final String name;
  final String adminId;
  const _HeaderBanner({required this.name, required this.adminId});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? '🌅 Good Morning'
        : hour < 18
            ? '☀️ Good Afternoon'
            : '🌙 Good Evening';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4C1D95), _purple, _purpleLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                name.isEmpty ? 'Admin' : name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
              if (adminId.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ID: $adminId',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Live stat cards from Firestore ────────────────────────────
class _LiveStatsRow extends StatelessWidget {
  const _LiveStatsRow();

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return Row(
      children: [
        // Total patients
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db.collection('patients').snapshots(),
            builder: (_, s) => _StatTile(
              label: 'Patients',
              icon: Icons.people_alt_rounded,
              color: _green,
              value: s.hasData ? '${s.data!.size}' : '—',
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Today's slots
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db
                .collection('appointment_slots')
                .where('date',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
                .where('date', isLessThan: Timestamp.fromDate(todayEnd))
                .snapshots(),
            builder: (_, s) => _StatTile(
              label: 'Slots Today',
              icon: Icons.event_available_rounded,
              color: _blue,
              value: s.hasData ? '${s.data!.size}' : '—',
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Pending appointments
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db
                .collection('appointments')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (_, s) => _StatTile(
              label: 'Pending',
              icon: Icons.pending_actions_rounded,
              color: _amber,
              value: s.hasData ? '${s.data!.size}' : '—',
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String value;
  const _StatTile(
      {required this.label,
      required this.icon,
      required this.color,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Today's appointments from Firestore ─────────────────────
class _TodayAppointments extends StatelessWidget {
  const _TodayAppointments();

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointment_slots')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('date', isLessThan: Timestamp.fromDate(todayEnd))
          .orderBy('date')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _ShimmerCard(height: 100);
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.event_busy_rounded,
            message: 'No slots scheduled for today',
            sub: 'Go to Appointments to create slots',
          );
        }
        return Column(
          children: docs.take(3).map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final doctorName = d['doctorName'] as String? ?? 'Doctor';
            final start = d['startTime'] as String? ?? '';
            final end = d['endTime'] as String? ?? '';
            final booked = (d['bookedCount'] as num?)?.toInt() ?? 0;
            final total = (d['totalSlots'] as num?)?.toInt() ?? 1;
            final pct = total > 0 ? booked / total : 0.0;
            final isFull = booked >= total;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isFull
                      ? _red.withValues(alpha: 0.2)
                      : _green.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  // Time badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _purpleSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      start,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _purple),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _cleanDrName(doctorName),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text('$start – $end',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                        const SizedBox(height: 6),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.grey[200],
                            color: isFull ? _red : _green,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      Text('$booked/$total',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isFull ? _red : _green,
                              fontSize: 14)),
                      Text('Booked',
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: Icons.add_circle_outline_rounded,
        label: 'Create Slot',
        color: _green,
        onTap: () => _tabIndex.value = 1,
      ),
      (
        icon: Icons.pending_actions_rounded,
        label: 'Pending\nApprovals',
        color: _amber,
        onTap: () => _tabIndex.value = 1,
      ),
      (
        icon: Icons.people_rounded,
        label: 'Patients',
        color: _blue,
        onTap: () => _tabIndex.value = 2,
      ),
      (
        icon: Icons.medical_services_outlined,
        label: 'Medical\nReports',
        color: _purple,
        onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AdminMedicalReportsScreen()),
            ),
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
  final Color color;
  final VoidCallback onTap;
  const _QuickTile(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent bookings ────────────────────────────────────────────
class _RecentBookings extends StatelessWidget {
  const _RecentBookings();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _ShimmerCard(height: 180);
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.inbox_rounded,
            message: 'No appointments yet',
            sub: 'Bookings will appear here',
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => Divider(
                height: 1, indent: 16, endIndent: 16, color: Colors.grey[100]),
            itemBuilder: (ctx, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final status = (d['status'] as String?) ?? 'pending';
              final doctorName = (d['doctorName'] as String?) ?? 'Doctor';
              final patientName = (d['patientName'] as String?) ?? 'Patient';
              final dateTs = d['appointmentDate'] as Timestamp?;
              final dateStr = dateTs != null
                  ? DateFormat('d MMM').format(dateTs.toDate())
                  : '—';
              final time = (d['startTime'] as String?) ?? '';

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: _statusColor(status).withValues(alpha: 0.12),
                  child: Icon(_statusIcon(status),
                      color: _statusColor(status), size: 18),
                ),
                title: Text(
                  patientName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  '$dateStr  •  $time  •  ${_cleanDrName(doctorName)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                trailing: _StatusBadge(status),
              );
            },
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TASKS TAB  → Appointment Management screen
// ═══════════════════════════════════════════════════════════════
class _TasksTab extends StatelessWidget {
  const _TasksTab();
  @override
  Widget build(BuildContext context) => const AdminAppointmentsScreen();
}

// ═══════════════════════════════════════════════════════════════
//  PATIENTS TAB  —  live from Firestore
// ═══════════════════════════════════════════════════════════════
class _PatientsTab extends StatefulWidget {
  const _PatientsTab();
  @override
  State<_PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<_PatientsTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Patients',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search patients…',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon:
                      const Icon(Icons.search, size: 20, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('patients')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snap.data?.docs ?? [];
          if (_query.isNotEmpty) {
            final q = _query.toLowerCase();
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final name = (data['fullName'] ?? data['email'] ?? '')
                  .toString()
                  .toLowerCase();
              final email = (data['email'] ?? '').toString().toLowerCase();
              return name.contains(q) || email.contains(q);
            }).toList();
          }
          if (docs.isEmpty) {
            return const _EmptyState(
              icon: Icons.people_outline,
              message: 'No patients found',
              sub: 'Patients who sign up will appear here',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final profile = d['profile'] as Map<String, dynamic>? ?? {};
              final name =
                  (profile['fullName'] as String?)?.trim().isNotEmpty == true
                      ? profile['fullName'] as String
                      : (d['email'] as String?)?.split('@').first ?? 'Patient';
              final email = d['email'] as String? ?? '';
              final status = d['accountStatus'] as String? ?? 'active';
              final blood = profile['bloodGroup'] as String? ?? '';
              final initials = name.isNotEmpty ? name[0].toUpperCase() : 'P';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: _purple.withValues(alpha: 0.1),
                    child: Text(
                      initials,
                      style: const TextStyle(
                          color: _purple,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ),
                  title: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(email,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (blood.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(blood,
                              style: const TextStyle(
                                  color: _red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: status == 'active'
                              ? _green.withValues(alpha: 0.1)
                              : _amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status == 'active' ? 'Active' : 'Pending',
                          style: TextStyle(
                              color: status == 'active' ? _green : _amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PROFILE TAB  —  dynamic from Firestore + auth
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
          FirebaseFirestore.instance.collection('staff').doc(uid).get(),
        ]),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _purple));
          }

          final userData = (snap.data?[0] as DocumentSnapshot?)?.data()
                  as Map<String, dynamic>? ??
              {};
          final staffData = (snap.data?[1] as DocumentSnapshot?)?.data()
                  as Map<String, dynamic>? ??
              {};

          final name =
              (userData['fullName'] as String?)?.trim().isNotEmpty == true
                  ? userData['fullName'] as String
                  : authService.currentUser?.email?.split('@').first ?? 'Admin';

          final email = authService.currentUser?.email ?? '';
          final adminId = userData['adminId'] as String? ?? '—';
          final department =
              staffData['department'] as String? ?? 'Administration';
          final initials = name.isNotEmpty ? name[0].toUpperCase() : 'A';

          return CustomScrollView(
            slivers: [
              // ── Profile header SliverAppBar ────────────────
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                elevation: 0,
                title: const Text('Admin Profile',
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
                        colors: [Color(0xFF4C1D95), _purple, _purpleLight],
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
                              child: Text(initials,
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ),
                            const SizedBox(height: 10),
                            Text(name,
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
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.admin_panel_settings,
                                      color: Colors.white, size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'System Administrator',
                                    style: TextStyle(
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
                        title: 'Work Information',
                        icon: Icons.business_center_outlined,
                        rows: [
                          _InfoRow(Icons.badge_outlined, 'Admin ID', adminId),
                          _InfoRow(Icons.business_outlined, 'Department',
                              department),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Contact
                      _InfoCard(
                        title: 'Contact',
                        icon: Icons.contact_mail_outlined,
                        rows: [
                          _InfoRow(Icons.email_outlined, 'Email', email),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Live appointment summary
                      const _AppointmentSummaryCard(),
                      const SizedBox(height: 12),

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
                              title: const Text('Logout',
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

// ── Info Card ─────────────────────────────────────────────────
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
              Icon(icon, color: _purple, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E1B4B))),
            ],
          ),
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.only(bottom: 10),
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
                      color: Color(0xFF1E1B4B))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Live appointment summary on profile ──────────────────────
class _AppointmentSummaryCard extends StatelessWidget {
  const _AppointmentSummaryCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('appointments').snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        final pending =
            docs.where((d) => (d.data() as Map)['status'] == 'pending').length;
        final confirmed = docs
            .where((d) => (d.data() as Map)['status'] == 'confirmed')
            .length;
        final total = docs.length;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_purple, _purpleLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  const Text('Appointment Overview',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _MiniStat('Total', '$total', Colors.white),
                  const SizedBox(width: 16),
                  _MiniStat('Pending', '$pending', Colors.amber[300]!),
                  const SizedBox(width: 16),
                  _MiniStat(
                      'Confirmed', '$confirmed', Colors.greenAccent[200]!),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED HELPERS
// ═══════════════════════════════════════════════════════════════

String _cleanDrName(String name) {
  final t = name.trim();
  if (t.toLowerCase().startsWith('dr.') || t.toLowerCase().startsWith('dr ')) {
    return t;
  }
  return 'Dr. $t';
}

Color _statusColor(String status) {
  switch (status) {
    case 'confirmed':
      return _green;
    case 'pending':
      return _amber;
    case 'cancelled':
      return _red;
    case 'completed':
      return _blue;
    default:
      return Colors.grey;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'confirmed':
      return Icons.check_circle_outline;
    case 'pending':
      return Icons.pending_outlined;
    case 'cancelled':
      return Icons.cancel_outlined;
    case 'completed':
      return Icons.done_all;
    default:
      return Icons.info_outline;
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;
  const _EmptyState(
      {required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(sub, style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double height;
  const _ShimmerCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
