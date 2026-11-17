import 'dart:convert';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class BmkgResult {
  final List<Slot> slots;
  final String name;
  BmkgResult(this.slots, this.name);
}

class Services {
  static Future<dynamic> _get(
    String url, {
    int sec = 15,
    Map<String, String>? headers,
  }) async {
    final r = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(Duration(seconds: sec));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return jsonDecode(r.body);
  }

  // ---------------- GPS ----------------
  static Future<Position?> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------- BMKG: prakiraan cuaca resmi (api.bmkg.go.id) ----------------
  static Future<BmkgResult?> bmkg(String adm4, double lat, double lon) async {
    if (adm4.isEmpty) return null;
    try {
      final j = await _get(
        'https://api.bmkg.go.id/publik/prakiraan-cuaca?adm4=$adm4',
      );
      if (j is! Map || j['data'] is! List || (j['data'] as List).isEmpty) {
        return null;
      }

      final lok = (j['lokasi'] ?? {}) as Map;
      final blat = double.tryParse('${lok['lat']}');
      final blon = double.tryParse('${lok['lon']}');

      // Abaikan BMKG bila lokasi kode adm4 terlalu jauh (>30 km) dari posisi pengguna.
      if (blat != null &&
          blon != null &&
          Geolocator.distanceBetween(lat, lon, blat, blon) > 30000) {
        return null;
      }

      final rawCuaca = j['data'][0]['cuaca'];
      if (rawCuaca is! List) return null;

      final all = rawCuaca.whereType<List>().expand((e) => e).toList();
      final since = DateTime.now().subtract(const Duration(hours: 3));
      final slots = <Slot>[];

      for (final m in all) {
        if (m is! Map) continue;
        final dt = DateTime.tryParse(m['local_datetime']?.toString() ?? '');
        if (dt == null || !dt.isAfter(since)) continue;

        slots.add(
          Slot(
            dt,
            (num.tryParse('${m['t']}') ?? 0).toDouble(),
            (num.tryParse('${m['hu']}') ?? 0).toInt(),
            (num.tryParse('${m['ws']}') ?? 0).toDouble() / 3.6, // km/jam -> m/s
            (num.tryParse('${m['tcc']}') ?? 0).toInt(),
            (m['weather_desc'] ?? 'Berawan').toString(),
          ),
        );
        if (slots.length >= 8) break;
      }

      if (slots.isEmpty) return null;
      final name = [
        lok['desa'],
        lok['kotkab'],
      ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
      return BmkgResult(slots, name);
    } catch (_) {
      return null;
    }
  }

  // ---------------- Open-Meteo: radiasi surya & angin real ----------------
  static Future<List<Hour>?> weather(double lat, double lon) async {
    try {
      final j = await _get(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
        '&hourly=temperature_2m,relative_humidity_2m,cloud_cover,wind_speed_10m,shortwave_radiation,weather_code'
        '&wind_speed_unit=ms&timezone=auto&past_days=14&forecast_days=3',
        sec: 25,
      );
      final h = j['hourly'];
      final times = h['time'] as List;
      double d(String k, int i) => ((h[k] as List)[i] as num?)?.toDouble() ?? 0;
      return List.generate(
        times.length,
        (i) => Hour(
          DateTime.parse(times[i]),
          d('temperature_2m', i),
          d('relative_humidity_2m', i).round(),
          d('cloud_cover', i).round(),
          d('wind_speed_10m', i),
          d('shortwave_radiation', i),
          d('weather_code', i).round(),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------- Open-Meteo Air Quality (model CAMS) ----------------
  static Future<Air?> air(double lat, double lon) async {
    try {
      final j = await _get(
        'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon'
        '&current=us_aqi,pm2_5,pm10,nitrogen_dioxide,ozone,sulphur_dioxide,carbon_monoxide,carbon_dioxide'
        '&hourly=us_aqi&forecast_days=2&timezone=auto',
      );
      final c = j['current'];
      double v(String k) => (c[k] as num?)?.toDouble() ?? 0;
      final ht = j['hourly']['time'] as List;
      final ha = j['hourly']['us_aqi'] as List;
      final from = DateTime.now().subtract(const Duration(hours: 1));
      final fc = <AirPoint>[];
      for (var i = 0; i < ht.length && fc.length < 13; i++) {
        final t = DateTime.parse(ht[i]);
        if (t.isAfter(from) && ha[i] != null) {
          fc.add(AirPoint(t, (ha[i] as num).toInt()));
        }
      }
      return Air(
        v('us_aqi').round(),
        v('pm2_5'),
        v('pm10'),
        v('nitrogen_dioxide'),
        v('ozone'),
        v('sulphur_dioxide'),
        v('carbon_monoxide'),
        v('carbon_dioxide'),
        fc,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------- OpenStreetMap (Overpass): tempat/komunitas hijau nyata ----------------
  static Future<List<GreenPlace>?> places(
    double lat,
    double lon, {
    int radius = 7000,
  }) async {
    try {
      final a = '(around:$radius,$lat,$lon)';
      final q = '[out:json][timeout:25];('
          'nwr["leisure"="park"]["name"]$a;'
          'nwr["leisure"="garden"]["name"]$a;'
          'nwr["amenity"="recycling"]["name"]$a;'
          'nwr["generator:source"="solar"]["name"]$a;'
          'nwr["office"="ngo"]["name"]$a;'
          ');out center 250;';
      final r = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: {'data': q},
      ).timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) return null;
      final els = jsonDecode(r.body)['elements'] as List;
      final byType = <PlaceType, List<GreenPlace>>{};
      final seen = <String>{};
      for (final e in els) {
        final tags = (e['tags'] ?? {}) as Map;
        final name = tags['name']?.toString();
        final plat = (e['lat'] ?? e['center']?['lat']) as num?;
        final plon = (e['lon'] ?? e['center']?['lon']) as num?;
        if (name == null || plat == null || plon == null) continue;
        PlaceType? t;
        if (tags['leisure'] == 'park' || tags['leisure'] == 'garden') {
          t = PlaceType.park;
        } else if (tags['amenity'] == 'recycling') {
          t = PlaceType.recycle;
        } else if (tags['generator:source'] == 'solar') {
          t = PlaceType.solar;
        } else if (tags['office'] == 'ngo') {
          t = PlaceType.ngo;
        }
        if (t == null || !seen.add('${t.name}\vert{}$name')) continue;
        final dist = Geolocator.distanceBetween(
          lat,
          lon,
          plat.toDouble(),
          plon.toDouble(),
        );
        byType.putIfAbsent(t, () => []).add(
              GreenPlace(
                '${e['type']}${e['id']}',
                name,
                plat.toDouble(),
                plon.toDouble(),
                t,
                dist,
              ),
            );
      }
      final out = <GreenPlace>[];
      for (final l in byType.values) {
        l.sort((x, y) => x.dist.compareTo(y.dist));
        out.addAll(l.take(15));
      }
      out.sort((x, y) => x.dist.compareTo(y.dist));
      return out;
    } catch (_) {
      return null;
    }
  }

  // ---------------- Nominatim (OpenStreetMap): nama lokasi dari koordinat ----------------
  static Future<String?> reverse(double lat, double lon) async {
    try {
      final j = await _get(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=14&accept-language=id&lat=$lat&lon=$lon',
        sec: 10,
        headers: {'User-Agent': 'EcoPulseBMKG/1.0 (proyek pelajar)'},
      );
      final a = (j['address'] ?? {}) as Map;
      final area = a['suburb'] ??
          a['village'] ??
          a['city_district'] ??
          a['neighbourhood'];
      final city = a['city'] ?? a['town'] ?? a['county'] ?? a['state'];
      final name = [area, city].where((e) => e != null).join(', ');
      return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  // ---------------- Data contoh bila internet/API gagal ----------------
  static List<Hour> demoHours() {
    final n = DateTime.now();
    final start = DateTime(
      n.year,
      n.month,
      n.day,
    ).subtract(const Duration(days: 14));
    return List.generate(17 * 24, (i) {
      final t = start.add(Duration(hours: i));
      final cloud = (45 + 35 * sin(i / 9.0)).round();
      final h = t.hour + 0.0;
      final rad = (h < 6 || h > 18)
          ? 0.0
          : 950 * sin(pi * (h - 6) / 12) * (1 - 0.7 * cloud / 100);
      return Hour(
        t,
        28 + 4 * sin(pi * (h - 8) / 12),
        75,
        cloud,
        2.5 + 2 * (1 + sin(i / 5.0)),
        rad,
        cloud > 70 ? 61 : (cloud > 40 ? 3 : 1),
      );
    });
  }
}
