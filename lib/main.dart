import 'app_strings_main.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import 'ads.dart';
import 'model.dart';
import 'weather.dart';
import 'reminders.dart';

import 'package:flutter_timezone/flutter_timezone.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  runApp(const WeatherOutfit());
}

class WeatherOutfit extends StatelessWidget {
  const WeatherOutfit({super.key, this.services = true});
  final bool services;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: "Today's Weather Outfit",
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff376b65)),
      scaffoldBackgroundColor: const Color(0xfff6f5ef),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: OutfitPage(services: services),
  );
}

class OutfitPage extends StatefulWidget {
  const OutfitPage({super.key, required this.services});
  final bool services;
  @override
  State<OutfitPage> createState() => _OutfitPageState();
}

class _OutfitPageState extends State<OutfitPage> with WidgetsBindingObserver {
  Settings s = Settings();
  final ads = AdsController();
  final reminders = Reminders();
  final manual = TextEditingController();
  SharedPreferences? prefs;
  WeatherService? weather;
  bool busy = false;
  int tab = 0, count = 0;
  double? manualC;
  String? message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    prefs = await SharedPreferences.getInstance();
    try {
      final saved = prefs!.getString('settings');
      if (saved != null) s = Settings.decode(saved);
    } catch (_) {
      message = AppStrings.msg3;
    }
    weather = WeatherService(prefs!);
    if (widget.services) {
      await _deviceZone();
      try {
        await reminders.initialize();
      } catch (_) {
        message = AppStrings.msg4;
      }
      ads.initialize();
    }
    if (mounted) setState(() {});
    if (widget.services) await _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.services) {
      _deviceZone().then((_) => reminders.initialize()).then((_) {
        if (mounted) _refresh();
      });
    }
  }

  Future<void> _deviceZone() async {
    try {
      final zone = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.getLocation(zone);
      s.deviceZone = zone;
    } catch (_) {
      if (s.deviceTime) {
        message = AppStrings.msg5;
      }
    }
  }

  Future<void> _refresh() async {
    if (busy || weather == null) return;
    setState(() => busy = true);
    final selected = s.city;
    await weather!.load(selected);
    if (!mounted) return;
    if (selected != s.city) {
      weather!.points = [];
      setState(() => busy = false);
      return _refresh();
    }
    await _reschedule();
    if (mounted) setState(() => busy = false);
  }

  Future<void> _reschedule() async {
    try {
      count = await reminders.schedule(
        s,
        weather?.points ?? [],
        weather?.fetchedAt,
      );
    } catch (_) {
      message = AppStrings.msg6;
    }
  }

  Future<void> _save({bool region = false}) async {
    await prefs?.setString('settings', s.encoded);
    if (region && widget.services) {
      await _refresh();
    } else {
      await _reschedule();
    }
    if (mounted) setState(() {});
  }

  String temp(double c) =>
      '${(s.fahrenheit ? toF(c) : c).toStringAsFixed(1)}°${s.fahrenheit ? AppStrings.msg1 : AppStrings.msg2}';
  String clock(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final now = tz.TZDateTime.now(tz.getLocation(s.city.zone));
    final p = forecastAt(weather?.points ?? [], now), c = manualC ?? p?.celsius;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.msg7),
        actions: [
          IconButton(
            tooltip: AppStrings.msg8,
            onPressed: busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checkroom), label: AppStrings.msg9),
          NavigationDestination(icon: Icon(Icons.tune), label: AppStrings.msg10),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            label: AppStrings.msg11,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (message != null) Text(message!),
            if (tab == 0) ...[
              Text(
                AppStrings.msg12,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.city.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${s.city.zone} · ${clock(now.hour * 60 + now.minute)}',
                      ),
                      const SizedBox(height: 18),
                      Text(
                        c == null ? AppStrings.msg13 : temp(c),
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        c == null
                            ? AppStrings.msg14
                            : outfitFor(c, s.rules),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (manualC != null)
                        const Text(AppStrings.msg15),
                      if (manualC == null && p != null && p.rain > 0)
                        const Text(AppStrings.msg16),
                      const SizedBox(height: 12),
                      const Text(
                        AppStrings.msg17,
                      ),
                    ],
                  ),
                ),
              ),
              if (weather?.error != null) Text(weather!.error!),
              if (weather?.fetchedAt != null)
                Text(
                  'Forecast downloaded: ${weather!.fetchedAt!.toLocal()}${weather!.cached ? ' · saved' : ''}',
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: manual,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'Manual temperature (${s.fahrenheit ? '°F' : '°C'})',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      final n = double.tryParse(manual.text);
                      if (n == null ||
                          !n.isFinite ||
                          (s.fahrenheit ? toC(n) : n).abs() > 100) {
                        setState(
                          () => message =
                              AppStrings.msg18,
                        );
                        return;
                      }
                      setState(() {
                        manualC = s.fahrenheit ? toC(n) : n;
                        message = null;
                      });
                    },
                    child: const Text(AppStrings.msg19),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => setState(() => manualC = null),
                child: const Text(AppStrings.msg20),
              ),
              SwitchListTile(
                title: const Text(AppStrings.msg21),
                value: s.fahrenheit,
                onChanged: (v) {
                  setState(() {
                    s.fahrenheit = v;
                    manual.clear();
                  });
                  _save();
                },
              ),
              OutlinedButton.icon(
                onPressed: _cityDialog,
                icon: const Icon(Icons.location_city),
                label: const Text('Change city / region'),
              ),
              TextButton(
                onPressed: () => launchUrl(Uri.parse('https://api.met.no/')),
                child: const Text(AppStrings.msg22),
              ),
              if (widget.services) SetupBanner(ads: ads),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://creativecommons.org/licenses/by/4.0/'),
                ),
                child: const Text(AppStrings.msg23),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://wjb127.github.io/weather-outfit/privacy.html',
                  ),
                ),
                child: const Text(AppStrings.msg24),
              ),
              ListenableBuilder(
                listenable: ads,
                builder: (_, _) => ads.privacyRequired
                    ? TextButton(
                        onPressed: ads.privacyOptions,
                        child: const Text(AppStrings.msg25),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
            if (tab == 1) ...[
              Text(
                AppStrings.msg26,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text(
                AppStrings.msg27,
              ),
              const SizedBox(height: 12),
              for (final r in ([
                ...s.rules,
              ]..sort((a, b) => b.minimum.compareTo(a.minimum))))
                Card(
                  child: ListTile(
                    title: Text(r.clothes),
                    subtitle: Text('From ${r.minimum}°C'),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _ruleDialog(r),
                  ),
                ),
              OutlinedButton(
                onPressed: () => _ruleDialog(null),
                child: const Text(AppStrings.msg28),
              ),
              TextButton(
                onPressed: () {
                  setState(() => s.rules = defaultRules());
                  _save();
                },
                child: const Text(AppStrings.msg29),
              ),
            ],
            if (tab == 2) ...[
              Text(
                AppStrings.msg30,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('Reminder timezone · ${s.reminderZone}'),
              SwitchListTile(
                title: const Text(AppStrings.msg31),
                subtitle: Text(
                  'Off: selected city time. Device: ${s.deviceZone}',
                ),
                value: s.deviceTime,
                onChanged: (v) {
                  setState(() => s.deviceTime = v);
                  _save();
                },
              ),
              SwitchListTile(
                title: const Text(AppStrings.msg32),
                subtitle: Text(clock(s.am)),
                value: s.morning,
                onChanged: (v) => _toggle(true, v),
              ),
              TextButton(
                onPressed: () => _time(true),
                child: const Text(AppStrings.msg33),
              ),
              SwitchListTile(
                title: const Text(AppStrings.msg34),
                subtitle: Text(clock(s.pm)),
                value: s.evening,
                onChanged: (v) => _toggle(false, v),
              ),
              TextButton(
                onPressed: () => _time(false),
                child: const Text(AppStrings.msg35),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(
                        [AppStrings.msg36, AppStrings.msg37, AppStrings.msg38, AppStrings.msg39, AppStrings.msg40, AppStrings.msg41, AppStrings.msg42][d -
                            1],
                      ),
                      selected: s.days.contains(d),
                      onSelected: (v) {
                        setState(() {
                          v ? s.days.add(d) : s.days.remove(d);
                        });
                        _save();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                reminders.allowed ? 'Notifications enabled · $count scheduled' : AppStrings.msg43,
              ),
              FilledButton(
                onPressed: () async {
                  await reminders.permission();
                  await _save();
                },
                child: const Text(AppStrings.msg44),
              ),
              const SizedBox(height: 16),
              const Text(
                AppStrings.msg45,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(bool am, bool v) async {
    if (v && !reminders.allowed) await reminders.permission();
    if (am) {
      s.morning = v;
    } else {
      s.evening = v;
    }
    await _save();
  }

  Future<void> _time(bool am) async {
    final m = am ? s.am : s.pm;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (t == null) return;
    if (am) {
      s.am = t.hour * 60 + t.minute;
    } else {
      s.pm = t.hour * 60 + t.minute;
    }
    await _save();
  }

  Future<void> _cityDialog() async {
    final c = await showDialog<City>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text(AppStrings.msg46),
        children: [
          for (final city in cities)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, city),
              child: Text(city.name),
            ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(ctx, const City('Custom', 0, 0, 'UTC')),
            child: const Text('Custom city / coordinates'),
          ),
        ],
      ),
    );
    if (c == null || !mounted) return;
    if (c.name == 'Custom') {
      await _customCity();
      return;
    }
    setState(() {
      s.city = c;
      manualC = null;
    });
    await _save(region: true);
  }

  Future<void> _customCity() async {
    final name = TextEditingController(text: s.city.name),
        lat = TextEditingController(text: '${s.city.lat}'),
        lon = TextEditingController(text: '${s.city.lon}'),
        zone = TextEditingController(text: s.city.zone);
    final route = DialogRoute<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.msg47),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final pair in [
                (name, AppStrings.msg48),
                (lat, AppStrings.msg49),
                (lon, AppStrings.msg50),
                (zone, 'IANA timezone (e.g. Europe/Paris)'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: pair.$1,
                    decoration: InputDecoration(labelText: pair.$2),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.msg51),
          ),
          FilledButton(
            onPressed: () {
              try {
                final c = City(
                  name.text,
                  double.parse(lat.text),
                  double.parse(lon.text),
                  zone.text,
                );
                c.validate();
                setState(() {
                  s.city = c;
                  manualC = null;
                });
                Navigator.pop(ctx);
                _save(region: true);
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(AppStrings.msg52),
                  ),
                );
              }
            },
            child: const Text(AppStrings.msg53),
          ),
        ],
      ),
    );
    await Navigator.of(context).push(route);
    await route.completed;
    name.dispose();
    lat.dispose();
    lon.dispose();
    zone.dispose();
  }

  Future<void> _ruleDialog(OutfitRule? rule) async {
    final min = TextEditingController(
          text: rule == null ? '' : '${rule.minimum}',
        ),
        clothes = TextEditingController(text: rule?.clothes ?? '');
    final parts = {
      for (final kind in ['Top', 'Bottom', 'Outerwear', 'Other'])
        kind: TextEditingController(text: rule?.categories[kind] ?? ''),
    };
    final route = DialogRoute<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.msg54),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: min,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: AppStrings.msg55),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('clothes-combination'),
                controller: clothes,
                decoration: const InputDecoration(
                  labelText: AppStrings.msg56,
                ),
              ),
              const SizedBox(height: 12),
              const Text(AppStrings.msg57),
              for (final part in parts.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: part.value,
                    decoration: InputDecoration(labelText: part.key),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (rule != null && s.rules.length > 1)
            TextButton(
              onPressed: () {
                s.rules.remove(rule);
                Navigator.pop(ctx);
                _save();
              },
              child: const Text(AppStrings.msg58),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.msg51),
          ),
          FilledButton(
            onPressed: () {
              try {
                final categories = {
                  for (final part in parts.entries)
                    if (part.value.text.trim().isNotEmpty)
                      part.key: part.value.text.trim(),
                };
                final candidate = [
                  ...s.rules.where((x) => x != rule),
                  OutfitRule(
                    double.parse(min.text),
                    categories.isEmpty
                        ? clothes.text.trim()
                        : categories.entries
                              .map((p) => '${p.key}: ${p.value}')
                              .join(' + '),
                    categories: categories,
                  ),
                ];
                validateRules(candidate);
                setState(() => s.rules = candidate);
                Navigator.pop(ctx);
                _save();
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      AppStrings.msg59,
                    ),
                  ),
                );
              }
            },
            child: const Text(AppStrings.msg53),
          ),
        ],
      ),
    );
    await Navigator.of(context).push(route);
    await route.completed;
    min.dispose();
    clothes.dispose();
    for (final part in parts.values) {
      part.dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    manual.dispose();
    ads.dispose();
    super.dispose();
  }
}
