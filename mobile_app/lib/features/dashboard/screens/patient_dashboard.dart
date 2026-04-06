import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../auth/services/auth_service.dart';
import '../../health_records/screens/health_records_list_screen.dart';
import '../../health_records/screens/add_health_record_screen.dart';
import '../../appointments/screens/patient_appointment_screens.dart';
import '../../api_integration/screens/health_articles_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../analytics/screens/health_analytics_screen.dart';

// ── Design Tokens ──────────────────────────────────────────
const _green = Color(0xFF10B981);
const _greenDark = Color(0xFF059669);
const _blue = Color(0xFF3B82F6);
const _purple = Color(0xFF8B5CF6);
const _amber = Color(0xFFF59E0B);
const _bg = Color(0xFFF0FDF4);
const _red = Color(0xFFEF4444);

// Shared tab switcher
final _patientTab = ValueNotifier<int>(0);

// Rotating health tips
const _healthTips = [
  'Drink at least 8 glasses of water daily for optimal hydration.',
  'Walk 10,000 steps a day to maintain a healthy heart.',
  'Sleep 7–9 hours each night to support immune function.',
  'Eat a rainbow of fruits and vegetables every day.',
  'Limit screen time and take eye breaks every 20 minutes.',
];

// ═══════════════════════════════════════════════════════════
//  SHELL
// ═══════════════════════════════════════════════════════════
class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});
  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  @override
  void initState() {
    super.initState();
    _patientTab.addListener(_onTab);
  }

  @override
  void dispose() {
    _patientTab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(
        index: _patientTab.value,
        children: const [
          _HomeTab(),
          _RecordsTab(),
          _AppointmentsTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _patientTab.value,
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: _green.withValues(alpha: 0.15),
        onDestinationSelected: (i) => _patientTab.value = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: _green),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded, color: _green),
            label: 'Records',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded, color: _green),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded, color: _green),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  HOME TAB
// ═══════════════════════════════════════════════════════════
class _HomeTab extends StatefulWidget {
  const _HomeTab();
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  int _tipIndex = 0;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _nextTip() =>
      setState(() => _tipIndex = (_tipIndex + 1) % _healthTips.length);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final uid = auth.currentUser?.uid ?? '';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('patients').doc(uid).get(),
      builder: (ctx, snap) {
        final patData = snap.data?.data() as Map<String, dynamic>? ?? {};
        final profile = patData['profile'] as Map<String, dynamic>? ?? {};
        final fullName = patData['fullName'] as String? ??
            auth.currentUser?.email?.split('@').first ??
            'Patient';
        final blood = profile['bloodGroup'] as String? ?? '—';
        final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P';

        return CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────
            SliverAppBar(
              expandedHeight: 190,
              pinned: true,
              backgroundColor: _green,
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
                      colors: [Color(0xFF064E3B), _green],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.2),
                                child: Text(initial,
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_greeting(),
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                          fontSize: 13)),
                                  Text(fullName,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Spacer(),
                              if (blood != '—')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.bloodtype,
                                          color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(blood,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                            ],
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
                    // ── Dynamic Stats ─────────────────────
                    _DynamicStats(uid: uid),
                    const SizedBox(height: 28),

                    // ── Quick Actions ─────────────────────
                    const Text('Quick Actions',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E))),
                    const SizedBox(height: 14),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.45,
                      children: [
                        _ActionCard(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Add Record',
                          color: _green,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddHealthRecordScreen()),
                          ),
                        ),
                        _ActionCard(
                          icon: Icons.event_available_rounded,
                          label: 'Book Appointment',
                          color: _blue,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const PatientBookAppointmentScreen()),
                          ),
                        ),
                        _ActionCard(
                          icon: Icons.local_hospital_rounded,
                          label: 'My Records',
                          color: _purple,
                          onTap: () => _patientTab.value = 1,
                        ),
                        _ActionCard(
                          icon: Icons.calendar_month_rounded,
                          label: 'My Appointments',
                          color: _amber,
                          onTap: () => _patientTab.value = 2,
                        ),
                        _ActionCard(
                          icon: Icons.public_rounded,
                          label: 'Health Articles',
                          color: Color(0xFFEC4899),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HealthArticlesScreen()),
                          ),
                        ),
                        _ActionCard(
                          icon: Icons.notifications_active_rounded,
                          label: 'Notifications',
                          color: Color(0xFFEF4444),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const NotificationsScreen()),
                          ),
                        ),
                        _ActionCard(
                          icon: Icons.bar_chart_rounded,
                          label: 'Health Analytics',
                          color: Color(0xFF06B6D4),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HealthAnalyticsScreen()),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Recent Activity ───────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Activity',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E1E))),
                        TextButton(
                          onPressed: () => _patientTab.value = 1,
                          child: const Text('View All',
                              style: TextStyle(color: _green)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _RecentActivity(uid: uid),

                    const SizedBox(height: 28),

                    // ── Health Tip ────────────────────────
                    GestureDetector(
                      onTap: _nextTip,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Container(
                          key: ValueKey(_tipIndex),
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF064E3B), _greenDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.lightbulb_rounded,
                                    color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('Health Tip',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15)),
                                        const Spacer(),
                                        Text('Tap for next',
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.6),
                                                fontSize: 10)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _healthTips[_tipIndex],
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.85),
                                          fontSize: 13,
                                          height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
    );
  }
}

// ── Dynamic Stats Widget ───────────────────────────────────
class _DynamicStats extends StatelessWidget {
  final String uid;
  const _DynamicStats({required this.uid});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return StreamBuilder<List<QuerySnapshot>>(
      stream: Stream.fromFuture(
        Future.wait([
          db
              .collection('health_records')
              .where('patientId', isEqualTo: uid)
              .get(),
          db
              .collection('appointments')
              .where('patientId', isEqualTo: uid)
              .get(),
          db
              .collection('appointments')
              .where('patientId', isEqualTo: uid)
              .where('status', isEqualTo: 'pending')
              .get(),
        ]),
      ),
      builder: (ctx, snap) {
        final records = snap.data?[0].size ?? 0;
        final appts = snap.data?[1].size ?? 0;
        final pending = snap.data?[2].size ?? 0;
        final loading = !snap.hasData;

        return Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.folder_rounded,
                label: 'My Records',
                value: loading ? '...' : '$records',
                color: _blue,
                onTap: () => _patientTab.value = 1,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.calendar_today_rounded,
                label: 'Appointments',
                value: loading ? '...' : '$appts',
                color: _green,
                onTap: () => _patientTab.value = 2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.hourglass_top_rounded,
                label: 'Pending',
                value: loading ? '...' : '$pending',
                color: _amber,
                onTap: () => _patientTab.value = 2,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4))
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
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Action Card ─────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(label,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Recent Activity: merged health_records + appointments ──
class _RecentActivity extends StatelessWidget {
  final String uid;
  const _RecentActivity({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QuerySnapshot>>(
      stream: Stream.fromFuture(Future.wait([
        FirebaseFirestore.instance
            .collection('health_records')
            .where('patientId', isEqualTo: uid)
            .orderBy('date', descending: true)
            .limit(3)
            .get(),
        FirebaseFirestore.instance
            .collection('appointments')
            .where('patientId', isEqualTo: uid)
            .orderBy('appointmentDate', descending: true)
            .limit(3)
            .get(),
      ])),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(color: _green)),
          );
        }

        // Build merged event list
        final List<Map<String, dynamic>> events = [];

        for (final doc in snap.data![0].docs) {
          final d = doc.data() as Map<String, dynamic>;
          final ts = d['date'] as Timestamp?;
          events.add({
            'icon': Icons.folder_rounded,
            'color': _blue,
            'title': d['title'] as String? ?? 'Health Record',
            'sub': d['recordType'] as String? ?? d['category'] as String? ?? '',
            'time': ts != null ? _relTime(ts.toDate()) : '',
            'sort': ts?.millisecondsSinceEpoch ?? 0,
          });
        }

        for (final doc in snap.data![1].docs) {
          final d = doc.data() as Map<String, dynamic>;
          final ts = d['appointmentDate'] as Timestamp?;
          final status = d['status'] as String? ?? 'pending';
          final statusColor = status == 'confirmed'
              ? _green
              : status == 'cancelled'
                  ? _red
                  : _amber;
          events.add({
            'icon': Icons.event_available_rounded,
            'color': statusColor,
            'title': 'Appointment',
            'sub': 'Status: ${status[0].toUpperCase()}${status.substring(1)}',
            'time': ts != null ? _relTime(ts.toDate()) : '',
            'sort': ts?.millisecondsSinceEpoch ?? 0,
          });
        }

        events.sort((a, b) => (b['sort'] as int).compareTo(a['sort'] as int));
        final display = events.take(5).toList();

        if (display.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.history_rounded, color: Colors.grey[300], size: 40),
                const SizedBox(height: 12),
                Text('No recent activity yet',
                    style: TextStyle(color: Colors.grey[400])),
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
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: display.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return Column(
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (e['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(e['icon'] as IconData,
                          color: e['color'] as Color, size: 20),
                    ),
                    title: Text(e['title'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(e['sub'] as String,
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12)),
                    trailing: Text(e['time'] as String,
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 11)),
                  ),
                  if (i < display.length - 1)
                    Divider(height: 1, color: Colors.grey[100]),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _relTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ═══════════════════════════════════════════════════════════
//  RECORDS TAB
// ═══════════════════════════════════════════════════════════
class _RecordsTab extends StatelessWidget {
  const _RecordsTab();
  @override
  Widget build(BuildContext context) => const HealthRecordsListScreen();
}

// ═══════════════════════════════════════════════════════════
//  APPOINTMENTS TAB
// ═══════════════════════════════════════════════════════════
class _AppointmentsTab extends StatelessWidget {
  const _AppointmentsTab();
  @override
  Widget build(BuildContext context) => const PatientMyAppointmentsScreen();
}

// ═══════════════════════════════════════════════════════════
//  PROFILE TAB  —  Dynamic from Firestore
// ═══════════════════════════════════════════════════════════
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final uid = auth.currentUser?.uid ?? '';
    final email = auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: Future.wait([
          FirebaseFirestore.instance.collection('patients').doc(uid).get(),
          FirebaseFirestore.instance.collection('users').doc(uid).get(),
        ]),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _green));
          }

          final patData = snap.data?[0].data() as Map<String, dynamic>? ?? {};
          final profile = patData['profile'] as Map<String, dynamic>? ?? {};
          final medInfo = patData['medicalInfo'] as Map<String, dynamic>? ?? {};

          final fullName =
              patData['fullName'] as String? ?? email.split('@').first;
          final dob = profile['dateOfBirth'] as String? ?? '—';
          final gender = profile['gender'] as String? ?? '—';
          final phone = profile['phoneNumber'] as String? ?? '—';
          final blood = profile['bloodGroup'] as String? ?? '—';
          final address = profile['address'] as String? ?? '—';
          final emergency = profile['emergencyContact'] as String? ?? '—';
          final allergies = (medInfo['allergies'] as List?)?.join(', ');
          final conditions =
              (medInfo['chronicConditions'] as List?)?.join(', ');
          final meds = (medInfo['currentMedications'] as List?)?.join(', ');
          final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 230,
                pinned: true,
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                title: const Text('My Profile',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit profile coming soon')),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF064E3B), _green],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 16),
                            CircleAvatar(
                              radius: 42,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              child: Text(initial,
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ),
                            const SizedBox(height: 10),
                            Text(fullName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (blood != '—')
                                  _Badge(
                                    icon: Icons.bloodtype,
                                    label: blood,
                                    color: Colors.redAccent,
                                  ),
                                if (gender != '—') ...[
                                  const SizedBox(width: 8),
                                  _Badge(
                                    icon: Icons.person,
                                    label: gender,
                                    color: _blue,
                                  ),
                                ],
                              ],
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
                      _InfoCard(
                          title: 'Personal Information',
                          icon: Icons.person_outline,
                          rows: [
                            _InfoRow(
                                Icons.badge_outlined, 'Full Name', fullName),
                            _InfoRow(Icons.email_outlined, 'Email', email),
                            _InfoRow(Icons.cake_outlined, 'Date of Birth', dob),
                            _InfoRow(Icons.wc_outlined, 'Gender', gender),
                            _InfoRow(Icons.phone_outlined, 'Phone', phone),
                            _InfoRow(
                                Icons.location_on_outlined, 'Address', address),
                            _InfoRow(Icons.contact_emergency_outlined,
                                'Emergency Contact', emergency),
                          ]),
                      const SizedBox(height: 12),
                      _InfoCard(
                          title: 'Medical Information',
                          icon: Icons.medical_information_outlined,
                          rows: [
                            _InfoRow(
                                Icons.bloodtype_outlined, 'Blood Group', blood),
                            _InfoRow(
                                Icons.warning_amber_outlined,
                                'Allergies',
                                allergies?.isNotEmpty == true
                                    ? allergies!
                                    : 'None'),
                            _InfoRow(
                                Icons.health_and_safety_outlined,
                                'Chronic Conditions',
                                conditions?.isNotEmpty == true
                                    ? conditions!
                                    : 'None'),
                            _InfoRow(
                                Icons.medication_outlined,
                                'Current Medications',
                                meds?.isNotEmpty == true ? meds! : 'None'),
                          ]),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10)
                          ],
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.logout, color: _red),
                          title: const Text('Sign Out',
                              style: TextStyle(
                                  color: _red, fontWeight: FontWeight.w600)),
                          onTap: () async {
                            await auth.logout();
                            if (context.mounted) context.go('/login');
                          },
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

// ── Shared Profile Widgets ─────────────────────────────────
class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> rows;
  const _InfoCard(
      {required this.title, required this.icon, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
              Icon(icon, color: _green, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF064E3B))),
            ],
          ),
          const SizedBox(height: 14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 12),
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
