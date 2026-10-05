import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'model.dart';

class Reminders {
  final plugin = FlutterLocalNotificationsPlugin();
  bool allowed = false;
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<void> initialize() async {
    if (!supported) return;
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('notification_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    allowed =
        await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        (await plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.checkPermissions())
            ?.isEnabled ??
        false;
  }

  Future<bool> permission() async {
    if (!supported) return false;
    allowed =
        await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        await plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true, badge: false) ??
        false;
    return allowed;
  }

  Future<int> schedule(
    Settings s,
    List<ForecastPoint> points,
    DateTime? downloaded,
  ) async {
    if (!supported) return 0;
    await plugin.cancelAll();
    if (!allowed) return 0;
    var id = 0;
    for (final minute in [if (s.morning) s.am, if (s.evening) s.pm]) {
      for (final date in reminderDates(s, minute, DateTime.now())) {
        final p = forecastAt(points, date);
        final body = p == null
            ? 'Open the app for a fresh outfit recommendation.'
            : '${s.fahrenheit ? toF(p.celsius).round() : p.celsius.round()}°${s.fahrenheit ? 'F' : 'C'} · ${outfitFor(p.celsius, s.rules)}${p.rain > 0 ? ' · Bring rain protection' : ''}. Forecast saved ${downloaded?.toIso8601String().substring(0, 16) ?? 'earlier'} UTC.';
        await plugin.zonedSchedule(
          id++,
          '${s.city.name} · ${minute < 720 ? 'Morning' : 'Evening'} outfit',
          body,
          date,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'outfit_reminders',
              'Outfit reminders',
              channelDescription: 'Your clothing recommendations',
              importance: Importance.defaultImportance,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
    return id;
  }
}
