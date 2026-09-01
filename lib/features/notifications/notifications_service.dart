// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum ScheduleNotificationResult { success, alreadyPassed, departureTooSoon, failed }

class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onResponse,
    );
    _initialized = true;
  }

  /// Requests notification permission at runtime.
  /// - iOS: handled automatically via DarwinInitializationSettings.
  /// - Android 13+ (API 33+): must call this explicitly before scheduling.
  /// Returns true if permission was granted.
  Future<bool> requestPermission() async {
    await init();
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  void _onResponse(NotificationResponse response) {
    // Payload is the trip ID; navigation is handled in main via GoRouter.
  }

  /// Schedules a departure notification.
  ///
  /// Requires Pro tier — pass [isPro] from [userTierProvider].isPro.
  /// Uses exact alarms when the permission is granted; falls back to inexact
  /// (still fires when the app is closed, just within a OS-managed window).
  Future<ScheduleNotificationResult> scheduleDepartureNotification({
    required bool isPro,
    required int id,
    required String tripId,
    required String trainNumber,
    required int departureMinutes,
    int minutesBefore = 15,
  }) async {
    if (!isPro) return ScheduleNotificationResult.failed;

    await init();

    final now = DateTime.now();
    final departureDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      departureMinutes ~/ 60,
      departureMinutes % 60,
    );

    final minutesUntilDeparture = departureDateTime.difference(now).inMinutes;
    if (minutesUntilDeparture < 0) return ScheduleNotificationResult.alreadyPassed;
    if (minutesUntilDeparture < 18) return ScheduleNotificationResult.departureTooSoon;

    final notifyAt = departureDateTime.subtract(Duration(minutes: minutesBefore));

    const androidDetails = AndroidNotificationDetails(
      'departures',
      'Départs',
      channelDescription: 'Notifications de départ de train',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _plugin.zonedSchedule(
        id,
        'Tunis GO — Train $trainNumber',
        'Départ dans $minutesBefore minutes',
        tz.TZDateTime.from(notifyAt.toUtc(), tz.UTC),
        details,
        payload: tripId,
        androidScheduleMode: await _resolveScheduleMode(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return ScheduleNotificationResult.success;
    } catch (_) {
      return ScheduleNotificationResult.failed;
    }
  }

  /// Schedules a daily repeating notification 15 minutes before [departureMinutes].
  /// Fires every day at the same time. Safe to call repeatedly — same [id] replaces any existing one.
  Future<void> scheduleDailyDepartureNotification({
    required int id,
    required String tripId,
    required String trainNumber,
    required int departureMinutes,
    int minutesBefore = 15,
  }) async {
    await init();

    final now = DateTime.now();
    var notifyAt = DateTime(
      now.year,
      now.month,
      now.day,
      departureMinutes ~/ 60,
      departureMinutes % 60,
    ).subtract(Duration(minutes: minutesBefore));
    // If the time already passed today, start from tomorrow
    if (notifyAt.isBefore(now)) {
      notifyAt = notifyAt.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'departures',
      'Départs',
      channelDescription: 'Notifications de départ de train',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _plugin.zonedSchedule(
        id,
        'Tunis GO — Train $trainNumber',
        'Départ dans $minutesBefore minutes',
        tz.TZDateTime.from(notifyAt.toUtc(), tz.UTC),
        details,
        payload: tripId,
        androidScheduleMode: await _resolveScheduleMode(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // Ignore scheduling errors for background favorites notifications
    }
  }

  // Uses exact alarms if SCHEDULE_EXACT_ALARM is granted (Android 12+),
  // otherwise falls back to inexact — both modes fire when the app is closed.
  Future<AndroidScheduleMode> _resolveScheduleMode() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return AndroidScheduleMode.exactAllowWhileIdle;
    final canExact = await androidPlugin.canScheduleExactNotifications();
    return canExact == true
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
}
