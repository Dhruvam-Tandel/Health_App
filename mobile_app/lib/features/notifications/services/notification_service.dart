import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Handles background FCM messages (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background FCM message: ${message.notification?.title}');
}

/// Notification Service — manages both Local & Push (FCM) notifications.
///
/// Demonstrates:
///  - Initializing notification plugins
///  - Creating Android notification channels
///  - Showing instant local notifications
///  - Scheduling notifications at a future time
///  - Receiving Firebase Cloud Messaging (FCM) push notifications
///  - Handling notification tap actions
class NotificationService {
  // ── Singleton ───────────────────────────────────────────────────────────
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // ── Plugin instances ────────────────────────────────────────────────────
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // ── Notification Channel (Android 8+) ──────────────────────────────────
  static const String _channelId = 'smart_health_vault_channel';
  static const String _channelName = 'Smart Health Vault Notifications';
  static const String _channelDesc =
      'Notifications for appointments, reminders, and health alerts';

  // ── Callback for notification taps ──────────────────────────────────────
  Function(String?)? onNotificationTap;

  // ── FCM Token ───────────────────────────────────────────────────────────
  String? fcmToken;

  // ── Notification log (for UI display) ──────────────────────────────────
  final List<Map<String, String>> notificationLog = [];

  // ═══════════════════════════════════════════════════════════════════════
  //  INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════

  /// Initialize all notification systems (call once in main.dart)
  Future<void> initialize() async {
    // 1. Initialize timezone data (needed for scheduled notifications)
    tz_data.initializeTimeZones();

    // 2. Initialize local notifications plugin
    await _initLocalNotifications();

    // 3. Request notification permissions
    await _requestPermissions();

    // 4. Initialize Firebase Cloud Messaging
    await _initFCM();

    debugPrint('✅ NotificationService initialized');
  }

  /// Initialize the flutter_local_notifications plugin
  Future<void> _initLocalNotifications() async {
    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher', // App icon used for notifications
    );

    // Combined initialization settings
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    // Initialize the plugin with tap handler
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android 8+
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    }
  }

  /// Request notification permissions (Android 13+ and iOS)
  Future<bool> _requestPermissions() async {
    // Request FCM permissions (works for both Android & iOS)
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized;
    debugPrint('🔔 Notification permission: ${granted ? "GRANTED" : "DENIED"}');

    // Also request from local notifications plugin on Android
    if (Platform.isAndroid) {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    return granted;
  }

  /// Initialize Firebase Cloud Messaging (FCM)
  Future<void> _initFCM() async {
    // Get the FCM token (used to send push notifications to this device)
    fcmToken = await _firebaseMessaging.getToken();
    debugPrint('📱 FCM Token: $fcmToken');

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      fcmToken = newToken;
      debugPrint('📱 FCM Token refreshed: $newToken');
    });

    // --- Foreground FCM messages ---
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          '🔔 Foreground FCM: ${message.notification?.title}');

      // Show as local notification when app is in foreground
      if (message.notification != null) {
        showInstantNotification(
          title: message.notification!.title ?? 'New Notification',
          body: message.notification!.body ?? '',
          payload: message.data['screen'] ?? 'fcm',
        );
      }
    });

    // --- Notification opened app from background ---
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 FCM opened app: ${message.notification?.title}');
      onNotificationTap?.call(message.data['screen']);
    });

    // --- Check if app was opened from a terminated state notification ---
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
          '🔔 App opened from FCM: ${initialMessage.notification?.title}');
      onNotificationTap?.call(initialMessage.data['screen']);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  LOCAL NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Notification details configuration (reusable)
  NotificationDetails get _notificationDetails {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
      ),
    );
  }

  /// Show an instant local notification (fires immediately)
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _localNotifications.show(
      id,
      title,
      body,
      _notificationDetails,
      payload: payload,
    );

    // Log the notification
    _addToLog(title, body, 'Instant');
    debugPrint('🔔 Instant notification shown: $title');
  }

  /// Schedule a notification for a future date/time
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    _addToLog(title, body, 'Scheduled');
    debugPrint('🔔 Scheduled notification: $title at $scheduledDate');
  }

  /// Schedule a notification after a delay (e.g., 5 seconds, 1 minute)
  Future<void> scheduleAfterDelay({
    required String title,
    required String body,
    required Duration delay,
    String? payload,
  }) async {
    final scheduledDate = DateTime.now().add(delay);
    await scheduleNotification(
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      payload: payload,
    );
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    debugPrint('🔔 All notifications cancelled');
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  HEALTH-SPECIFIC NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Appointment reminder notification
  Future<void> showAppointmentReminder({
    required String doctorName,
    required DateTime appointmentTime,
  }) async {
    await showInstantNotification(
      title: '📅 Appointment Reminder',
      body:
          'You have an appointment with Dr. $doctorName at ${_formatTime(appointmentTime)}',
      payload: 'appointments',
    );
  }

  /// Medication reminder notification
  Future<void> showMedicationReminder({
    required String medicationName,
    required String dosage,
  }) async {
    await showInstantNotification(
      title: '💊 Medication Reminder',
      body: 'Time to take $medicationName ($dosage)',
      payload: 'medications',
    );
  }

  /// Health tip notification
  Future<void> showHealthTipNotification() async {
    const tips = [
      'Drink at least 8 glasses of water today! 💧',
      'Take a 10-minute walk to boost your energy! 🚶',
      'Remember to stretch if you\'ve been sitting for a while! 🧘',
      'Eat a serving of fruits and vegetables today! 🥗',
      'Get 7-9 hours of sleep tonight for better health! 😴',
    ];
    final tip = tips[DateTime.now().second % tips.length];

    await showInstantNotification(
      title: '🌿 Health Tip',
      body: tip,
      payload: 'health_tip',
    );
  }

  /// Schedule a daily hydration reminder
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    var scheduledDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      hour,
      minute,
    );

    // If the time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(DateTime.now())) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await scheduleNotification(
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      payload: 'daily_reminder',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  HANDLERS & HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Called when user taps a notification
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped — payload: ${response.payload}');
    onNotificationTap?.call(response.payload);
  }

  /// Add to the in-memory notification log
  void _addToLog(String title, String body, String type) {
    notificationLog.insert(0, {
      'title': title,
      'body': body,
      'type': type,
      'time': _formatTime(DateTime.now()),
    });
    // Keep only the last 50
    if (notificationLog.length > 50) notificationLog.removeLast();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }
}
