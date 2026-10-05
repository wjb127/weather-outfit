import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:weather_outfit/model.dart';
import 'package:weather_outfit/reminders.dart';
import 'package:weather_outfit/weather.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native weather cache and fourteen cancellable local reminders', (
    t,
  ) async {
    zones.initializeTimeZones();
    final prefs = await SharedPreferences.getInstance();
    final weather = WeatherService(prefs);
    await weather.load(cities.first);
    expect(weather.points, isNotEmpty, reason: weather.error);
    expect(weather.fetchedAt, isNotNull);
    final first = weather.fetchedAt;
    await weather.load(cities.first);
    expect(weather.cached, isTrue);
    expect(weather.fetchedAt, first);
    final reminders = Reminders();
    await reminders.initialize();
    expect(reminders.allowed, isTrue);
    final settings = Settings()
      ..morning = true
      ..evening = true;
    expect(
      await reminders.schedule(settings, weather.points, weather.fetchedAt),
      14,
    );
    expect((await reminders.plugin.pendingNotificationRequests()).length, 14);
    settings.morning = false;
    settings.evening = false;
    expect(
      await reminders.schedule(settings, weather.points, weather.fetchedAt),
      0,
    );
    expect(await reminders.plugin.pendingNotificationRequests(), isEmpty);
    if (Platform.isAndroid) {
      await reminders.plugin.show(
        99,
        'Outfit test',
        'Notification delivery check',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'outfit_reminders',
            'Outfit reminders',
          ),
        ),
      );
      expect(
        (await reminders.plugin.getActiveNotifications()).any(
          (n) => n.id == 99,
        ),
        isTrue,
      );
      await reminders.plugin.cancel(99);
    }
  });
}
