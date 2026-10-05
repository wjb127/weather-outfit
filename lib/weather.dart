import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'model.dart';

class WeatherService {
  WeatherService(this.prefs);
  final SharedPreferences prefs;
  List<ForecastPoint> points = [];
  DateTime? fetchedAt;
  bool cached = false;
  String? error;
  String? _key;
  Future<void> load(City city) async {
    final key =
        'forecast:${city.lat.toStringAsFixed(3)},${city.lon.toStringAsFixed(3)}';
    if (_key != key) {
      points = [];
      fetchedAt = null;
    }
    _key = key;
    error = null;
    cached = false;
    Map<String, dynamic>? cache;
    final saved = prefs.getString(key);
    if (saved != null) {
      try {
        cache = jsonDecode(saved);
        points = parseForecast(cache!['body']);
        fetchedAt = DateTime.parse(cache['fetched']);
        cached = true;
      } catch (_) {
        cache = null;
      }
    }
    if (cache != null &&
        DateTime.now().toUtc().isBefore(DateTime.parse(cache['expires']))) {
      return;
    }
    // Error backoff prevents refresh tapping from replaying 429/failed requests.
    final retry = prefs.getString('$key:retry');
    if (retry != null &&
        DateTime.now().toUtc().isBefore(DateTime.parse(retry))) {
      error = 'Weather unavailable. Retry later or enter a temperature.';
      return;
    }
    try {
      final uri = Uri.https(
        'api.met.no',
        '/weatherapi/locationforecast/2.0/compact',
        {
          'lat': city.lat.toStringAsFixed(3),
          'lon': city.lon.toStringAsFixed(3),
        },
      );
      final headers = {
        'User-Agent': 'WeatherOutfit/1.0 wjb127@naver.com',
        'Accept': 'application/json',
      };
      if (cache?['modified'] != null) {
        headers['If-Modified-Since'] = cache!['modified'];
      }
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
      final expiry = _expires(response.headers['expires']);
      if (response.statusCode == 304 && cache != null) {
        cache['expires'] = expiry;
        await prefs.setString(key, jsonEncode(cache));
        return;
      }
      if (response.statusCode != 200) {
        throw const HttpException('Forecast not available');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final parsed = parseForecast(body);
      if (parsed.isEmpty) throw const FormatException();
      fetchedAt = DateTime.now().toUtc();
      points = parsed;
      cached = false;
      await prefs.setString(
        key,
        jsonEncode({
          'body': body,
          'fetched': fetchedAt!.toIso8601String(),
          'expires': expiry,
          'modified': response.headers['last-modified'],
        }),
      );
    } catch (_) {
      await prefs.setString(
        '$key:retry',
        DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String(),
      );
      error = points.isEmpty
          ? 'Weather unavailable. Enter a temperature.'
          : 'Offline: saved forecast. Check download time.';
    }
  }

  String _expires(String? h) {
    var t = DateTime.now().toUtc().add(const Duration(hours: 1));
    if (h != null) {
      try {
        final parsed = HttpDate.parse(h);
        if (parsed.isAfter(t)) t = parsed;
      } catch (_) {}
    }
    return t.toIso8601String();
  }
}
