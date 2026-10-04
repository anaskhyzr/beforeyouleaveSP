import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/location.dart';
import '../screens/checklist_screen.dart';
import 'hive_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  await HiveService.init();

  // Handle background actions such as 'check_all'
  final actionId = notificationResponse.actionId;
  final payload = notificationResponse.payload;

  if (actionId == 'check_all' && payload != null) {
    if (payload.startsWith('checklist:')) {
      final locId = payload.substring('checklist:'.length);
      await HiveService.checkAllItemsForLocation(locId);
      await HiveService.updateLocationLastLeft(locId, DateTime.now());
    }
  }
}

class ReminderService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static GlobalKey<NavigatorState>? _navigatorKey;

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (navigatorKey != null) {
      _navigatorKey = navigatorKey;
    }

    if (kIsWeb) return;
    try {
      tz.initializeTimeZones();
      const android =
          AndroidInitializationSettings('@drawable/ic_stat_notification');
      const ios = DarwinInitializationSettings();

      await _notifications.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();

      await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Error initializing ReminderService: $e');
    }
  }

  static void _onNotificationTapped(NotificationResponse response) async {
    await HiveService.init();

    final actionId = response.actionId;
    final payload = response.payload;

    if (payload == null) return;

    if (actionId == 'check_all') {
      if (payload.startsWith('checklist:')) {
        final locId = payload.substring('checklist:'.length);
        await HiveService.checkAllItemsForLocation(locId);
        await HiveService.updateLocationLastLeft(locId, DateTime.now());
      }
      return;
    }

    // If 'see_list' or body tapped
    if (payload.startsWith('checklist:')) {
      final locId = payload.substring('checklist:'.length);
      final location = await HiveService.getLocation(locId);
      if (location != null && _navigatorKey?.currentState != null) {
        _navigatorKey!.currentState!.push(
          MaterialPageRoute(
            builder: (_) => ChecklistScreen(location: location),
          ),
        );
      }
    } else if (payload == 'dashboard') {
      _navigatorKey?.currentState?.popUntil((route) => route.isFirst);
    }
  }

  /// Show geofence departure notification with interactive actions
  static Future<void> showDepartureNotification({
    required Location location,
    int? distanceMeters,
  }) async {
    if (kIsWeb) return;

    final distanceStr = distanceMeters != null ? ' (~${distanceMeters}m away)' : '';
    final notificationId = _notificationId('departure_${location.id}');

    final androidDetails = AndroidNotificationDetails(
      'geofence_departures',
      'Departure Alerts',
      icon: 'ic_stat_notification',
      channelDescription:
          'Alerts when leaving a configured location perimeter.',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'check_all',
          'Check All',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'see_list',
          'See List',
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      sound: 'default',
      categoryIdentifier: 'departure_actions',
    );

    await _notifications.show(
      notificationId,
      'Leaving ${location.name}?',
      'You are heading out$distanceStr. Don\'t forget your essentials!',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: 'checklist:${location.id}',
    );
  }

  /// Schedule daily time-based departure reminder
  static Future<void> scheduleDailyDepartureReminder({
    required Location location,
  }) async {
    if (location.reminderMinutes == null) {
      await cancel('timer_${location.id}');
      return;
    }

    try {
      await cancel('timer_${location.id}');

      final now = tz.TZDateTime.now(tz.local);
      final minutesFromMidnight = location.reminderMinutes!;
      var scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        minutesFromMidnight ~/ 60,
        minutesFromMidnight % 60,
      );

      if (!scheduledTime.isAfter(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'checklist_reminders',
        'Departure Time Reminders',
        icon: 'ic_stat_notification',
        channelDescription:
            'Time-based reminders when scheduled departure time arrives.',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      );

      const iosDetails = DarwinNotificationDetails(sound: 'default');

      await _notifications.zonedSchedule(
        _notificationId('timer_${location.id}'),
        'Departure Reminder: ${location.name}',
        'Have you left yet or about to leave?',
        scheduledTime,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'dashboard',
      );
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
    }
  }

  static Future<void> showInstantTestNotification() async {
    if (kIsWeb) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'checklist_reminders',
        'Checklist reminders',
        icon: 'ic_stat_notification',
        channelDescription:
            'Reminders to check your belongings before leaving.',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(sound: 'default'),
    );

    await _notifications.show(
      999,
      'Before You Leave',
      'Don\'t forget your essentials before heading out!',
      details,
      payload: 'dashboard',
    );
  }

  static Future<void> cancel(String id) async {
    try {
      await _notifications.cancel(_notificationId(id));
    } catch (_) {}
  }

  static String formatMinutes(int? minutes) {
    if (minutes == null) return 'No reminder set';
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  static int _notificationId(String id) => id.hashCode & 0x7fffffff;
}