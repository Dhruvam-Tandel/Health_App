import 'package:flutter/material.dart';
import '../services/notification_service.dart';

// ── Design Tokens ──────────────────────────────────────────────────────────
const _green = Color(0xFF10B981);
const _greenDark = Color(0xFF059669);
const _blue = Color(0xFF3B82F6);
const _purple = Color(0xFF8B5CF6);
const _amber = Color(0xFFF59E0B);
const _red = Color(0xFFEF4444);
const _pink = Color(0xFFEC4899);
const _bg = Color(0xFFF0FDF4);

/// Screen demonstrating Local & Push Notifications.
///
/// Features:
///  - Instant notification triggers (multiple types)
///  - Scheduled notification (5 seconds, 10 seconds, custom)
///  - FCM token display
///  - Notification history log
///  - Permission status display
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notifService = NotificationService();
  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    try {
      await _notifService.initialize();
      // Set up tap callback
      _notifService.onNotificationTap = (payload) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Notification tapped! Payload: $payload'),
              backgroundColor: _green,
            ),
          );
        }
      };
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = e.toString();
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _green,
            foregroundColor: Colors.white,
            elevation: 0,
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
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.notifications_active_rounded,
                                  color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Notifications',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold)),
                                  Text('Local & Push Alerts',
                                      style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.75),
                                          fontSize: 13)),
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

          // ── Body ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Status Banner ─────────────────────────────────────
                  _StatusBanner(
                    isInitialized: _isInitialized,
                    error: _initError,
                    fcmToken: _notifService.fcmToken,
                  ),

                  const SizedBox(height: 20),

                  // ── Instant Notifications Section ──────────────────────
                  const Text('Instant Notifications',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E))),
                  const SizedBox(height: 6),
                  Text('Tap a button to trigger a notification immediately.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 14),

                  _NotifButton(
                    icon: Icons.notifications_rounded,
                    label: 'Basic Alert',
                    subtitle: 'Simple instant notification',
                    color: _green,
                    onTap: () => _notifService.showInstantNotification(
                      title: 'New Alert',
                      body: 'This is your instant notification from Smart Health Vault!',
                      payload: 'basic_alert',
                    ).then((_) => _refresh()),
                  ),
                  const SizedBox(height: 10),

                  _NotifButton(
                    icon: Icons.calendar_today_rounded,
                    label: 'Appointment Reminder',
                    subtitle: 'Simulates an upcoming appointment alert',
                    color: _blue,
                    onTap: () => _notifService.showAppointmentReminder(
                      doctorName: 'Sharma',
                      appointmentTime: DateTime.now().add(const Duration(hours: 2)),
                    ).then((_) => _refresh()),
                  ),
                  const SizedBox(height: 10),

                  _NotifButton(
                    icon: Icons.medication_rounded,
                    label: 'Medication Reminder',
                    subtitle: 'Simulates a medicine dosage alert',
                    color: _purple,
                    onTap: () => _notifService.showMedicationReminder(
                      medicationName: 'Paracetamol',
                      dosage: '500mg',
                    ).then((_) => _refresh()),
                  ),
                  const SizedBox(height: 10),

                  _NotifButton(
                    icon: Icons.favorite_rounded,
                    label: 'Health Tip',
                    subtitle: 'Shows a random health tip notification',
                    color: _pink,
                    onTap: () => _notifService.showHealthTipNotification()
                        .then((_) => _refresh()),
                  ),

                  const SizedBox(height: 28),

                  // ── Scheduled Notifications Section ────────────────────
                  const Text('Scheduled Notifications',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E))),
                  const SizedBox(height: 6),
                  Text('Schedule notifications to fire after a delay.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 14),

                  _NotifButton(
                    icon: Icons.timer_rounded,
                    label: 'Schedule in 5 Seconds',
                    subtitle: 'Notification will appear after 5 seconds',
                    color: _amber,
                    onTap: () {
                      _notifService.scheduleAfterDelay(
                        title: '⏰ Scheduled Alert',
                        body: 'This notification was scheduled 5 seconds ago!',
                        delay: const Duration(seconds: 5),
                        payload: 'scheduled_5s',
                      ).then((_) => _refresh());
                      _showSnack('Notification scheduled! Will appear in 5 seconds...');
                    },
                  ),
                  const SizedBox(height: 10),

                  _NotifButton(
                    icon: Icons.alarm_rounded,
                    label: 'Schedule in 10 Seconds',
                    subtitle: 'Notification will appear after 10 seconds',
                    color: Color(0xFF06B6D4),
                    onTap: () {
                      _notifService.scheduleAfterDelay(
                        title: '⏰ Scheduled Reminder',
                        body: 'This notification was scheduled 10 seconds ago!',
                        delay: const Duration(seconds: 10),
                        payload: 'scheduled_10s',
                      ).then((_) => _refresh());
                      _showSnack('Notification scheduled! Will appear in 10 seconds...');
                    },
                  ),
                  const SizedBox(height: 10),

                  _NotifButton(
                    icon: Icons.water_drop_rounded,
                    label: 'Hydration Reminder (1 min)',
                    subtitle: 'Reminds you to drink water in 1 minute',
                    color: _blue,
                    onTap: () {
                      _notifService.scheduleAfterDelay(
                        title: '💧 Hydration Reminder',
                        body: 'Time to drink a glass of water! Stay hydrated.',
                        delay: const Duration(minutes: 1),
                        payload: 'hydration',
                      ).then((_) => _refresh());
                      _showSnack('Hydration reminder set for 1 minute from now!');
                    },
                  ),

                  const SizedBox(height: 28),

                  // ── Cancel All ─────────────────────────────────────────
                  _NotifButton(
                    icon: Icons.cancel_rounded,
                    label: 'Cancel All Notifications',
                    subtitle: 'Clear all pending scheduled notifications',
                    color: _red,
                    onTap: () {
                      _notifService.cancelAllNotifications();
                      _showSnack('All notifications cancelled!');
                    },
                  ),

                  const SizedBox(height: 28),

                  // ── FCM Token Section ──────────────────────────────────
                  const Text('Firebase Cloud Messaging (FCM)',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E))),
                  const SizedBox(height: 6),
                  Text('Push notifications are received via FCM.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.key_rounded,
                                color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            const Text('FCM Device Token',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            if (_notifService.fcmToken != null)
                              GestureDetector(
                                onTap: () => _showSnack('FCM token copied concept!'),
                                child: const Icon(Icons.copy_rounded,
                                    color: Colors.white38, size: 16),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _notifService.fcmToken ?? 'Loading token...',
                          style: const TextStyle(
                            color: Color(0xFF4ADE80),
                            fontSize: 11,
                            fontFamily: 'monospace',
                            height: 1.5,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // FCM info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _amber.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: _amber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'To test push notifications, use the Firebase Console → Cloud Messaging → Send test message using the FCM token above.',
                            style: TextStyle(
                              color: Colors.amber[800],
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Notification History Log ──────────────────────────
                  Row(
                    children: [
                      const Text('Notification Log',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E1E))),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_notifService.notificationLog.length} sent',
                          style: const TextStyle(
                            color: _greenDark,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_notifService.notificationLog.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.notifications_off_rounded,
                              color: Colors.grey[300], size: 40),
                          const SizedBox(height: 12),
                          Text('No notifications sent yet',
                              style: TextStyle(color: Colors.grey[400])),
                          const SizedBox(height: 4),
                          Text('Tap the buttons above to send notifications',
                              style: TextStyle(
                                  color: Colors.grey[350], fontSize: 12)),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: _notifService.notificationLog
                            .asMap()
                            .entries
                            .map((entry) {
                          final i = entry.key;
                          final log = entry.value;
                          final typeColor = log['type'] == 'Instant'
                              ? _green
                              : log['type'] == 'Scheduled'
                                  ? _amber
                                  : _blue;
                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    log['type'] == 'Instant'
                                        ? Icons.flash_on_rounded
                                        : Icons.schedule_rounded,
                                    color: typeColor,
                                    size: 20,
                                  ),
                                ),
                                title: Text(log['title'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                subtitle: Text(log['body'] ?? '',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: typeColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(log['type'] ?? '',
                                          style: TextStyle(
                                              color: typeColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(log['time'] ?? '',
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              if (i <
                                  _notifService.notificationLog.length - 1)
                                Divider(height: 1, color: Colors.grey[100]),
                            ],
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _green),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  STATUS BANNER
// ═══════════════════════════════════════════════════════════════════════════════
class _StatusBanner extends StatelessWidget {
  final bool isInitialized;
  final String? error;
  final String? fcmToken;

  const _StatusBanner({
    required this.isInitialized,
    this.error,
    this.fcmToken,
  });

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _amber.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  color: _amber, strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('Initializing notification service...',
                style: TextStyle(color: Colors.amber[800], fontSize: 13)),
          ],
        ),
      );
    }

    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _red.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: _red, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Init error: $error',
                  style: const TextStyle(color: _red, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _green.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _green, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Notifications ready — Local & FCM active',
                style: TextStyle(
                    color: _greenDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('ACTIVE',
                style: TextStyle(
                    color: _greenDark,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  NOTIFICATION BUTTON WIDGET
// ═══════════════════════════════════════════════════════════════════════════════
class _NotifButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _NotifButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E1E1E))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.grey[300], size: 14),
          ],
        ),
      ),
    );
  }
}
