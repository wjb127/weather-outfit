import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:weather_outfit/main.dart';
import 'package:weather_outfit/model.dart';

void main() {
  setUp(() {
    zones.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
  });
  test('Boundaries, cold gap, Fahrenheit and saved custom rules', () {
    final r = defaultRules();
    for (final row in <double, int>{
      -30: 0,
      -15: 0,
      -12: 0,
      -10: 1,
      -0.1: 1,
      0: 2,
      4.9: 2,
      5: 3,
      10: 4,
      15: 5,
      20: 6,
      45: 6,
    }.entries) {
      expect(outfitFor(row.key, r), r[row.value].clothes);
      expect(toC(toF(row.key)), closeTo(row.key, 0.0001));
    }
    expect(
      () => validateRules([OutfitRule(1, 'a'), OutfitRule(1, 'b')]),
      throwsFormatException,
    );
    final s = Settings()
      ..rules = [OutfitRule(8, 'My jacket'), OutfitRule(-5, 'My coat')];
    expect(outfitFor(8, Settings.decode(s.encoded).rules), 'My jacket');
  });
  test('City reminder wall clock survives DST and respects weekdays', () {
    final s = Settings()..city = cities[2];
    final dates = reminderDates(s, 450, DateTime.utc(2026, 10, 31));
    expect(dates.every((d) => d.hour == 7 && d.minute == 30), isTrue);
    expect(dates.map((d) => d.timeZoneOffset).toSet().length, 2);
    s.days = [1, 3, 5];
    expect(
      reminderDates(
        s,
        1110,
        DateTime.utc(2026, 10, 31),
      ).every((d) => s.days.contains(d.weekday)),
      isTrue,
    );
  });
  testWidgets('Manual offline recommendation needs no ad or permission', (
    tester,
  ) async {
    await tester.pumpWidget(const WeatherOutfit(services: false));
    await tester.pumpAndSettle();
    expect(find.text('Weather Outfit'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '10');
    await tester.tap(find.text('Recommend'));
    await tester.pumpAndSettle();
    expect(find.text('Short sleeves + cardigan'), findsOneWidget);
  });
}
