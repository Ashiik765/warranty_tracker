import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;
import 'dart:io';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // ------------------------------------------------------------
  // INITIALIZE NOTIFICATIONS
  // ------------------------------------------------------------
  static Future<void> initialize() async {
    tzData.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iOSSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    // Added foreground + click handler
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        print("🔔 Notification clicked: ${details.payload}");
      },
    );

    // Ask for notification permission on Android 13+
    if (Platform.isAndroid) {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      final result = await android?.requestPermission();
      print("🔔 Android notification permission: $result");
    }
  }

  // ------------------------------------------------------------
  // SCHEDULE A NOTIFICATION
  // ------------------------------------------------------------
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'warranty_channel',
      'Warranty Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    final iOSDetails = DarwinNotificationDetails();

    final notificationDetails =
        NotificationDetails(android: androidDetails, iOS: iOSDetails);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    print("📅 Notification scheduled at: $scheduledTime");
  }

  // ------------------------------------------------------------
  // CANCEL SPECIFIC NOTIFICATION
  // ------------------------------------------------------------
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // ------------------------------------------------------------
  // CANCEL ALL NOTIFICATIONS
  // ------------------------------------------------------------
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}