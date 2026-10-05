import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:weather_outfit/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native manual recommendation, custom rules and reminder defaults',
    (t) async {
      zones.initializeTimeZones();
      await t.pumpWidget(const WeatherOutfit(services: false));
      await t.pumpAndSettle();
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await t.pump();
      }
      await t.enterText(find.byType(TextField), '10');
      await t.ensureVisible(find.text('Recommend'));
      await t.tap(find.text('Recommend'));
      await t.pumpAndSettle();
      expect(find.text('Short sleeves + cardigan'), findsOneWidget);
      await t.drag(find.byType(ListView), const Offset(0, 1200));
      await t.pumpAndSettle();
      await binding.takeScreenshot('01-outfit-en');
      await t.tap(find.text('My rules'));
      await t.pumpAndSettle();
      await binding.takeScreenshot('02-rules-en');
      await t.tap(find.text('Short sleeves + cardigan'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('clothes-combination')),
        'My comfortable layer',
      );
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('My comfortable layer'), findsOneWidget);
      await t.tap(find.text('Reminders'));
      await t.pumpAndSettle();
      expect(find.text('07:30'), findsOneWidget);
      expect(find.text('18:30'), findsOneWidget);
      await binding.takeScreenshot('03-reminders-en');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await t.pumpWidget(const WeatherOutfit(services: false));
      await t.pumpAndSettle();
      await t.tap(find.text('My rules'));
      await t.pumpAndSettle();
      expect(find.text('My comfortable layer'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Restore original outfit rules'),
        400,
      );
      await t.tap(find.text('Restore original outfit rules'));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      await t.pump();
    },
  );
}
