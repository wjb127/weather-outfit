import 'app_strings_model.dart';

import 'dart:convert';

import 'package:timezone/timezone.dart' as tz;

class OutfitRule {
  OutfitRule(this.minimum, this.clothes, {this.categories = const {}});
  final double minimum;
  final String clothes;
  final Map<String, String> categories;
  Map<String, dynamic> toJson() => {
    'minimum': minimum,
    'clothes': clothes,
    'categories': categories,
  };
  factory OutfitRule.fromJson(Map<String, dynamic> j) => OutfitRule(
    (j['minimum'] as num).toDouble(),
    j['clothes'],
    categories: Map<String, String>.from(j['categories'] ?? {}),
  );
}

List<OutfitRule> defaultRules() => [
  OutfitRule(-15, ModelStrings.msg1),
  OutfitRule(-10, ModelStrings.msg2),
  OutfitRule(0, ModelStrings.msg3),
  OutfitRule(5, ModelStrings.msg4),
  OutfitRule(10, ModelStrings.msg5),
  OutfitRule(15, ModelStrings.msg6),
  OutfitRule(20, ModelStrings.msg7),
];
void validateRules(List<OutfitRule> r) {
  if (r.isEmpty ||
      r.any(
        (x) =>
            !x.minimum.isFinite ||
            x.minimum.abs() > 100 ||
            x.clothes.trim().isEmpty,
      ) ||
      r.map((x) => x.minimum).toSet().length != r.length) {
    throw const FormatException(ModelStrings.msg8);
  }
}

String outfitFor(double c, List<OutfitRule> r) {
  validateRules(r);
  if (!c.isFinite) throw const FormatException();
  final sorted = [...r]..sort((a, b) => a.minimum.compareTo(b.minimum));
  return sorted
      .lastWhere((x) => c >= x.minimum, orElse: () => sorted.first)
      .clothes;
}

double toF(double c) => c * 9 / 5 + 32;
double toC(double f) => (f - 32) * 5 / 9;

class City {
  const City(this.name, this.lat, this.lon, this.zone);
  final String name, zone;
  final double lat, lon;
  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': lat,
    'lon': lon,
    'zone': zone,
  };
  factory City.fromJson(Map<String, dynamic> j) => City(
    j['name'],
    (j['lat'] as num).toDouble(),
    (j['lon'] as num).toDouble(),
    j['zone'],
  );
  void validate() {
    if (name.trim().isEmpty ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      throw const FormatException();
    }
    tz.getLocation(zone);
  }
}

const cities = [
  City(ModelStrings.msg9, 37.5665, 126.978, 'Asia/Seoul'),
  City(ModelStrings.msg10, 35.6762, 139.6503, 'Asia/Tokyo'),
  City(ModelStrings.msg11, 40.7128, -74.006, 'America/New_York'),
  City(ModelStrings.msg12, 51.5074, -0.1278, 'Europe/London'),
  City(ModelStrings.msg13, 48.8566, 2.3522, 'Europe/Paris'),
  City(ModelStrings.msg14, 52.52, 13.405, 'Europe/Berlin'),
  City(ModelStrings.msg15, 34.0522, -118.2437, 'America/Los_Angeles'),
  City(ModelStrings.msg16, 43.6532, -79.3832, 'America/Toronto'),
  City(ModelStrings.msg17, -33.8688, 151.2093, 'Australia/Sydney'),
  City(ModelStrings.msg18, 1.3521, 103.8198, 'Asia/Singapore'),
  City(ModelStrings.msg19, 13.7563, 100.5018, 'Asia/Bangkok'),
  City(ModelStrings.msg20, 19.076, 72.8777, 'Asia/Kolkata'),
  City(ModelStrings.msg21, 25.2048, 55.2708, 'Asia/Dubai'),
  City(ModelStrings.msg22, -23.5505, -46.6333, 'America/Sao_Paulo'),
  City(ModelStrings.msg23, -33.9249, 18.4241, 'Africa/Johannesburg'),
  City(ModelStrings.msg24, -36.8485, 174.7633, 'Pacific/Auckland'),
];

class Settings {
  Settings();
  City city = cities.first;
  List<OutfitRule> rules = defaultRules();
  bool fahrenheit = false, morning = false, evening = false, deviceTime = false;
  String deviceZone = 'UTC';
  String get reminderZone => deviceTime ? deviceZone : city.zone;
  int am = 450, pm = 1110;
  List<int> days = [1, 2, 3, 4, 5, 6, 7];
  String get encoded => jsonEncode({
    'city': city.toJson(),
    'rules': rules.map((r) => r.toJson()).toList(),
    'f': fahrenheit,
    'morning': morning,
    'evening': evening,
    'am': am,
    'pm': pm,
    'days': days,
    'deviceTime': deviceTime,
    'deviceZone': deviceZone,
  });
  factory Settings.decode(String data) {
    final j = jsonDecode(data);
    final s = Settings();
    s.city = City.fromJson(j['city']);
    s.rules = (j['rules'] as List).map((r) => OutfitRule.fromJson(r)).toList();
    s.fahrenheit = j['f'];
    s.morning = j['morning'];
    s.evening = j['evening'];
    s.am = j['am'];
    s.pm = j['pm'];
    s.deviceTime = j['deviceTime'] ?? false;
    s.deviceZone = j['deviceZone'] ?? 'UTC';
    tz.getLocation(s.deviceZone);
    s.days = (j['days'] as List).cast<int>();
    s.city.validate();
    validateRules(s.rules);
    if (s.am < 0 ||
        s.am >= 1440 ||
        s.pm < 0 ||
        s.pm >= 1440 ||
        s.days.any((d) => d < 1 || d > 7)) {
      throw const FormatException();
    }
    return s;
  }
}

class ForecastPoint {
  ForecastPoint(this.time, this.celsius, this.rain);
  final DateTime time;
  final double celsius, rain;
}

List<ForecastPoint> parseForecast(Map<String, dynamic> j) {
  final result = <ForecastPoint>[];
  for (final row in j['properties']['timeseries'] as List) {
    final data = row['data'];
    final c = (data['instant']['details']['air_temperature'] as num).toDouble();
    final rain =
        ((data['next_1_hours'] ??
                    data['next_6_hours'] ??
                    {})['details']?['precipitation_amount']
                as num?)
            ?.toDouble() ??
        0;
    if (c.isFinite) {
      result.add(ForecastPoint(DateTime.parse(row['time']).toUtc(), c, rain));
    }
  }
  result.sort((a, b) => a.time.compareTo(b.time));
  return result;
}

ForecastPoint? forecastAt(List<ForecastPoint> p, DateTime when) {
  if (p.isEmpty ||
      when.toUtc().isBefore(p.first.time.subtract(const Duration(hours: 1))) ||
      when.toUtc().isAfter(p.last.time.add(const Duration(hours: 1)))) {
    return null;
  }
  return p.reduce(
    (a, b) =>
        a.time.difference(when).abs() <= b.time.difference(when).abs() ? a : b,
  );
}

List<tz.TZDateTime> reminderDates(Settings s, int minute, DateTime now) {
  final z = tz.getLocation(s.reminderZone),
      local = tz.TZDateTime.from(now, tz.getLocation(s.reminderZone));
  final result = <tz.TZDateTime>[];
  for (var d = 0; d < 8; d++) {
    final date = tz.TZDateTime(
      z,
      local.year,
      local.month,
      local.day + d,
      minute ~/ 60,
      minute % 60,
    );
    if (date.isAfter(local) && s.days.contains(date.weekday)) result.add(date);
  }
  return result.take(7).toList();
}
