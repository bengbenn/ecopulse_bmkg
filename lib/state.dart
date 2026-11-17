import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'services.dart';
import 'theme.dart';

class PlanStep {
  final Hour h;
  final double renew, load, bat, grid, soc; // kW (1 jam = kWh), soc dalam %
  final int src; // 0 terbarukan, 1 baterai, 2 PLN
  const PlanStep(
    this.h,
    this.renew,
    this.load,
    this.bat,
    this.grid,
    this.soc,
    this.src,
  );
}

class SunWindow {
  final DateTime start;
  final double avg; // W/m2
  const SunWindow(this.start, this.avg);
}

class DayStat {
  final double prod, load, used; // kWh
  const DayStat(this.prod, this.load, this.used);
  double get selfPct =>
      load <= 0 ? 0.0 : (used / load * 100).clamp(0.0, 100.0).toDouble();
}

class Insight {
  final IconData icon;
  final String title, body;
  final Color color;
  final int tab; // tab tujuan
  const Insight(this.icon, this.title, this.body, this.color, this.tab);
}

class AppState extends ChangeNotifier {
  // ------------- lokasi -------------
  double lat = -6.1647, lon = 106.8470;
  String place = 'Jakarta', adm4 = '31.71.03.1001';
  String? bmkgName, gpsNote;

  // ------------- data -------------
  bool loading = true, offline = false, bmkgLive = false, placesError = false;
  List<Hour> hours = [];
  List<Slot> slots = [];
  Air? air;
  List<GreenPlace> places = [];

  // ------------- input simulasi energi (manual) -------------
  double pvWp = 100, windW = 0, batWh = 500, batPct = 60;
  int scenario = 0;
  List<Appliance> appliances = List.of(kDefaultAppliances);

  // ------------- aktivitas harian (kalkulator karbon) -------------
  double motor = 6, mobil = 0, publik = 0;

  // ------------- komunitas & aksi -------------
  Set<String> joined = {}; // format: id|jenis|nama
  Set<String> done = {}; // id aksi hijau yang selesai hari ini

  SharedPreferences? _p;
  String _doneDay = '';

  double get pvKwp => pvWp / 1000;
  double get windKw => windW / 1000;
  double get batKwh => batWh / 1000;
  String get displayPlace =>
      (bmkgName != null && bmkgName!.isNotEmpty) ? bmkgName! : place;

  // ============================ init & simpan ============================
  Future<void> init() async {
    hours = Services.demoHours();
    slots = _slotsFromHours();
    notifyListeners();

    try {
      _p = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('EcoPulse preferences unavailable: $e');
    }
    final p = _p;
    if (p != null) {
      pvWp = p.getDouble('pvWp') ?? pvWp;
      windW = p.getDouble('windW') ?? windW;
      batWh = p.getDouble('batWh') ?? batWh;
      batPct = p.getDouble('batPct') ?? batPct;
      scenario = p.getInt('scenario') ?? 0;
      motor = p.getDouble('motor') ?? motor;
      mobil = p.getDouble('mobil') ?? mobil;
      publik = p.getDouble('publik') ?? publik;
      adm4 = p.getString('adm4') ?? adm4;
      joined = (p.getStringList('joined') ?? []).toSet();
    }
    _doneDay = _dayKey;
    done = (p?.getStringList(_dayKey) ?? []).toSet();
    final apps = p?.getStringList('apps');
    if (apps != null) {
      try {
        appliances = apps
            .map(
              (e) => Appliance.fromJson(jsonDecode(e) as Map<String, dynamic>),
            )
            .toList();
      } catch (_) {}
    }
    final sl = p?.getDouble('lat');
    final sn = p?.getDouble('lon');
    if (sl != null && sn != null) {
      lat = sl;
      lon = sn;
      place = p?.getString('place') ?? place;
      await refresh();
    } else {
      await useGps();
    }
  }

  String get _dayKey {
    final n = DateTime.now();
    return 'act_${n.year}-${n.month}-${n.day}';
  }

  void _save() {
    final p = _p;
    if (p == null) return;
    p.setDouble('pvWp', pvWp);
    p.setDouble('windW', windW);
    p.setDouble('batWh', batWh);
    p.setDouble('batPct', batPct);
    p.setInt('scenario', scenario);
    p.setDouble('motor', motor);
    p.setDouble('mobil', mobil);
    p.setDouble('publik', publik);
    p.setString('adm4', adm4);
    p.setStringList('joined', joined.toList());
    p.setStringList(
      'apps',
      appliances.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  void _change() {
    _save();
    notifyListeners();
  }

  // ============================ input pengguna ============================
  void updateCfg({
    double? pv,
    double? wind,
    double? bat,
    double? pct,
    int? scn,
  }) {
    pvWp = pv ?? pvWp;
    windW = wind ?? windW;
    batWh = bat ?? batWh;
    batPct = pct ?? batPct;
    scenario = scn ?? scenario;
    _change();
  }

  void applyPreset(Preset p) {
    pvWp = p.pvWp;
    batWh = p.batWh;
    _change();
  }

  void setActivity({double? m, double? c, double? b}) {
    motor = m ?? motor;
    mobil = c ?? mobil;
    publik = b ?? publik;
    _change();
  }

  void addAppliance(Appliance a) {
    appliances = [...appliances, a];
    _change();
  }

  void removeAppliance(int i) {
    if (i < 0 || i >= appliances.length) return;
    appliances = [...appliances]..removeAt(i);
    _change();
  }

  void resetAppliances() {
    appliances = List.of(kDefaultAppliances);
    _change();
  }

  /// Reset centang Aksi Hijau bila tanggal sudah berganti.
  void _syncDay() {
    if (_dayKey == _doneDay) return;
    _doneDay = _dayKey;
    done = (_p?.getStringList(_dayKey) ?? []).toSet();
  }

  void toggleAction(String id) {
    _syncDay();
    done.contains(id) ? done.remove(id) : done.add(id);
    _p?.setStringList(_dayKey, done.toList());
    notifyListeners();
  }

  double get actionsKg => kActions
      .where((a) => done.contains(a.id))
      .fold<double>(0, (s, a) => s + a.kg);

  bool isJoined(String id) => joined.any((e) => e.startsWith('$id|'));

  void toggleJoin(GreenPlace p) {
    if (isJoined(p.id)) {
      joined.removeWhere((e) => e.startsWith('${p.id}|'));
    } else {
      joined.add('${p.id}|${p.type.name}|${p.name.replaceAll('|', ' ')}');
    }
    _change();
  }

  List<String> get joinedNames => joined
      .map((e) => e.split('|').length >= 3 ? e.split('|')[2] : e)
      .toList();

  Set<PlaceType> get joinedTypes {
    final out = <PlaceType>{};
    for (final e in joined) {
      final parts = e.split('|');
      if (parts.length < 2) continue;
      for (final t in PlaceType.values) {
        if (t.name == parts[1]) out.add(t);
      }
    }
    return out;
  }

  // ============================ lokasi ============================
  Future<void> useGps() async {
    loading = true;
    notifyListeners();
    final p = await Services.locate().timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        debugPrint('EcoPulse location lookup timed out; using default location.');
        return null;
      },
    );
    if (p != null) {
      lat = p.latitude;
      lon = p.longitude;
      place = 'Lokasi Anda';
      gpsNote = null;
      _p?.remove('lat');
      _p?.remove('lon');
    } else {
      gpsNote = 'GPS tidak tersedia/ditolak. Memakai lokasi default (Jakarta). Pilih kota lain lewat ikon lokasi.';
    }
    await refresh();
  }

  Future<void> selectCity(City c) async {
    lat = c.lat;
    lon = c.lon;
    place = c.name;
    adm4 = c.adm4;
    gpsNote = null;
    _p?.setDouble('lat', lat);
    _p?.setDouble('lon', lon);
    _p?.setString('place', place);
    _save();
    await refresh();
  }

  Future<void> setAdm4(String v) async {
    adm4 = v.trim();
    _save();
    await refresh();
  }

  // ============================ ambil data ============================
  Future<void> refresh() async {
    _syncDay();
    loading = true;
    notifyListeners();
    final needName = place == 'Lokasi Anda';
    final r = await Future.wait<Object?>([
      Services.bmkg(adm4, lat, lon),
      Services.weather(lat, lon),
      Services.air(lat, lon),
      Services.places(lat, lon),
      needName ? Services.reverse(lat, lon) : Future<String?>.value(null),
    ]);
    final nm = r[4] as String?;
    if (needName && nm != null) place = nm;
    final b = r[0] as BmkgResult?;
    final w = r[1] as List<Hour>?;
    offline = w == null;
    hours = w ?? Services.demoHours();
    bmkgLive = b != null;
    bmkgName = b?.name;
    slots = b?.slots ?? _slotsFromHours();
    air = r[2] as Air?;
    final pl = r[3] as List<GreenPlace>?;
    places = pl ?? [];
    placesError = pl == null;
    loading = false;
    notifyListeners();
  }

  List<Slot> _slotsFromHours() {
    final n = DateTime.now();
    final f = DateTime(n.year, n.month, n.day, n.hour);
    final out = <Slot>[];
    for (final h in hours) {
      if (h.t.isBefore(f)) continue;
      if (out.length >= 8) break;
      if (out.isEmpty || h.t.difference(out.last.t).inHours >= 3) {
        out.add(Slot(h.t, h.temp, h.hum, h.wind, h.cloud, wmo(h.code)));
      }
    }
    return out.isEmpty ? [Slot(f, 28, 70, 2, 40, 'Berawan')] : out;
  }

  // ============================ ENERGI: Cuaca -> Produksi -> Beban ============================
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  List<Hour> hoursOf(DateTime d) =>
      hours.where((h) => _sameDay(h.t, d)).toList();

  Hour? get nowHour {
    final n = DateTime.now();
    for (final h in hours) {
      if (_sameDay(h.t, n) && h.t.hour == n.hour) return h;
    }
    return null;
  }

  /// Radiasi efektif. Skenario hanya berlaku untuk hari ini dan ke depan; riwayat tetap data nyata.
  double radOf(Hour h) {
    final n = DateTime.now();
    if (scenario == 0 || h.t.isBefore(DateTime(n.year, n.month, n.day)))
      return h.rad;
    final hr = h.t.hour + 0.0;
    final clear = (hr < 6 || hr > 18) ? 0.0 : 950 * sin(pi * (hr - 6) / 12);
    return clear * kScenarioFactor[scenario];
  }

  double solarKw(Hour h) =>
      pvKwp * radOf(h) / 1000 * 0.8; // performance ratio 0.8
  double renewKw(Hour h) => solarKw(h) + h.windKw(windKw);
  double loadAt(int hour) =>
      appliances.fold<double>(0, (s, a) => s + a.kwAt(hour));
  double get dailyKwh => appliances.fold<double>(0, (s, a) => s + a.kwhPerDay);
  double usedRenew(Hour h) =>
      min(renewKw(h), loadAt(h.t.hour)); // konservatif, tanpa baterai

  DayStat statOf(DateTime d) {
    double prod = 0, load = 0, used = 0;
    for (final h in hoursOf(d)) {
      final r = renewKw(h), l = loadAt(h.t.hour);
      prod += r;
      load += l;
      used += min(r, l);
    }
    return DayStat(prod, load, used);
  }

  double _selfPctFor(double kwp, List<Hour> hs, double totalLoad) {
    double used = 0;
    for (final h in hs) {
      used += min(
        kwp * radOf(h) / 1000 * 0.8 + h.windKw(windKw),
        loadAt(h.t.hour),
      );
    }
    return totalLoad <= 0 ? 0.0 : used / totalLoad * 100;
  }

  double _totalLoadToday(List<Hour> hs) =>
      hs.fold<double>(0, (s, h) => s + loadAt(h.t.hour));

  /// Batas maksimal persen beban yang bisa ditutup panel TANPA baterai (beban malam tidak tertutup).
  double get maxSelfPct {
    final hs = hoursOf(DateTime.now());
    return safe(_selfPctFor(30, hs, _totalLoadToday(hs)));
  }

  /// Kapasitas panel (Wp) agar [targetPct]% beban hari ini tertutup (tanpa baterai); null bila mustahil.
  double? neededWp(double targetPct) {
    final hs = hoursOf(DateTime.now());
    final totalLoad = _totalLoadToday(hs);
    if (hs.isEmpty || totalLoad <= 0 || targetPct <= 0) return null;
    if (_selfPctFor(30, hs, totalLoad) < targetPct) return null;
    double lo = 0, hi = 30;
    for (var i = 0; i < 30; i++) {
      final mid = (lo + hi) / 2;
      if (_selfPctFor(mid, hs, totalLoad) >= targetPct) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return hi * 1000;
  }

  /// True bila pengguna sudah punya data beban atau perjalanan (rekomendasi bermakna).
  bool get hasFootprint =>
      footprintParts().values.fold<double>(0, (a, b) => a + b) > 0;

  SunWindow? bestSolarWindow() {
    final now = DateTime.now();
    final f = DateTime(now.year, now.month, now.day, now.hour);
    final i = hours.indexWhere((h) => !h.t.isBefore(f));
    if (i < 0) return null;
    final end = min(i + 24, hours.length);
    SunWindow? best;
    for (var k = i; k + 3 <= end; k++) {
      final avg =
          (radOf(hours[k]) + radOf(hours[k + 1]) + radOf(hours[k + 2])) / 3;
      if (best == null || avg > best.avg) best = SunWindow(hours[k].t, avg);
    }
    return best;
  }

  /// Simulasi baterai & rencana sumber daya per jam.
  List<PlanStep> plan({int n = 12}) {
    final now = DateTime.now();
    final f = DateTime(now.year, now.month, now.day, now.hour);
    final i = hours.indexWhere((h) => !h.t.isBefore(f));
    if (i < 0) return [];
    final cap = batKwh;
    double soc = cap * batPct / 100;
    final reserve = cap * 0.2;
    final out = <PlanStep>[];
    for (final h in hours.sublist(i, min(i + n, hours.length))) {
      final r = renewKw(h);
      final l = loadAt(h.t.hour);
      double bat = 0, grid = 0;
      if (r >= l) {
        soc = min(cap, soc + (r - l) * 0.9); // efisiensi pengisian 90%
      } else {
        final d = l - r;
        final avail = max(0.0, soc - reserve);
        bat = min(avail, d);
        soc -= bat;
        grid = d - bat;
      }
      final src = grid > 0.0005 ? 2 : (r >= l ? 0 : 1);
      out.add(
        PlanStep(h, r, l, bat, grid, cap <= 0 ? 0 : soc / cap * 100, src),
      );
    }
    return out;
  }

  // ============================ KARBON: Energi -> Emisi ============================
  double offsetKgOfDay(DateTime d) =>
      hoursOf(d).fold<double>(0, (s, h) => s + usedRenew(h)) * gridFactor;

  /// Carbon offset hari ini (kg CO2), real-time sampai detik ini.
  double get offsetTodayKg {
    final n = DateTime.now();
    double s = 0;
    for (final h in hoursOf(n)) {
      if (h.t.hour < n.hour) {
        s += usedRenew(h);
      } else if (h.t.hour == n.hour) {
        s += usedRenew(h) * (n.minute * 60 + n.second) / 3600;
      }
    }
    return safe(s * gridFactor);
  }

  double get impactTodayKg => offsetTodayKg + actionsKg;

  /// Jejak karbon harian. Listrik diambil dari daftar perangkat + persentase energi bersih hasil simulasi Energi.
  Map<String, double> footprintParts() {
    final self = statOf(DateTime.now()).selfPct;
    return {
      'Listrik': safe(dailyKwh * gridFactor * (1 - self / 100)),
      'Motor': motor * 0.084,
      'Mobil': mobil * 0.192,
      'Bus/KRL': publik * 0.05,
    };
  }

  String get topSource {
    String best = 'Listrik';
    double bv = -1;
    footprintParts().forEach((k, v) {
      if (v > bv) {
        bv = v;
        best = k;
      }
    });
    return best;
  }

  // ============================ KOMUNITAS: Emisi -> Tujuan untuk pengguna ============================
  List<PlaceType> recommendedTypes() {
    final t = topSource;
    final r = (t == 'Motor' || t == 'Mobil')
        ? <PlaceType>[
            PlaceType.ngo,
            PlaceType.park,
            PlaceType.recycle,
            PlaceType.solar,
          ]
        : (t == 'Listrik')
        ? <PlaceType>[
            PlaceType.solar,
            PlaceType.ngo,
            PlaceType.recycle,
            PlaceType.park,
          ]
        : <PlaceType>[
            PlaceType.recycle,
            PlaceType.park,
            PlaceType.ngo,
            PlaceType.solar,
          ];
    final a = air;
    if (a != null && a.aqi > 100) {
      r.remove(PlaceType.park); // udara buruk: taman bukan prioritas hari ini
      r.add(PlaceType.park);
    }
    return r;
  }

  double get maxRadToday =>
      hoursOf(DateTime.now()).fold<double>(0, (m, h) => max(m, radOf(h)));

  /// Alasan/tujuan komunitas bagi pengguna, disusun dari data fitur lain.
  String purpose(PlaceType t) {
    final a = air;
    final aqiTxt = a == null
        ? ''
        : ' Udara hari ini ${aqiInfo(a.aqi).label.toLowerCase()} (AQI ${a.aqi}).';
    final parts = footprintParts();
    switch (t) {
      case PlaceType.park:
        if (a != null && a.aqi > 100) {
          return 'Taman cocok untuk jalan kaki/bersepeda tanpa emisi, tetapi kualitas udara sedang buruk (AQI ${a.aqi}). Tunda kunjungan sampai udara membaik.';
        }
        return 'Tempat jalan kaki/bersepeda tanpa emisi, mengganti perjalanan motor.$aqiTxt Satu perjalanan 6 km setara ±0,50 kg CO₂.';
      case PlaceType.recycle:
        return 'Tempat menyetor sampah plastik/kertas. Mendukung aksi "Bawa botol & tas sendiri" (±0,10 kg CO₂ per hari) dan mengurangi sampah di sekitarmu.';
      case PlaceType.solar:
        return 'Contoh instalasi surya nyata sebelum kamu memasang panel. Radiasi puncak di lokasimu hari ini ±${maxRadToday.toStringAsFixed(0)} W/m²; simulasi Energi memperkirakan panelmu ${pvWp.toStringAsFixed(0)} Wp menghasilkan ${statOf(DateTime.now()).prod.toStringAsFixed(2)} kWh.';
      case PlaceType.ngo:
        if (!hasFootprint) {
          return 'Ikut kampanye dan kegiatan lingkungan untuk belajar dan berbagi kebiasaan hemat energi bersama teman. Isi data di tab Energi dan Karbon agar rekomendasi lebih tepat.';
        }
        return 'Ikut kampanye dan kegiatan lingkungan. Penyumbang emisi terbesarmu hari ini: $topSource (${(parts[topSource] ?? 0).toStringAsFixed(2)} kg CO₂). Komunitas membantu mengubah kebiasaan itu bersama teman.';
    }
  }

  // ============================ BERANDA: langkah berikutnya ============================
  List<Insight> insights() {
    final out = <Insight>[];
    final a = air;
    if (a != null) {
      final info = aqiInfo(a.aqi);
      out.add(
        a.aqi > 100
            ? Insight(
                Icons.masks_rounded,
                'Udara kurang sehat (AQI ${a.aqi})',
                'Pakai masker bila keluar dan tunda olahraga di luar ruangan. Pilih angkutan umum agar tidak menambah polusi.',
                info.color,
                1,
              )
            : Insight(
                Icons.air_rounded,
                'Udara ${info.label.toLowerCase()} (AQI ${a.aqi})',
                'Aman untuk jalan kaki atau bersepeda hari ini, dan itu langsung mengurangi emisi transportasimu.',
                info.color,
                3,
              ),
      );
    }
    final sw = bestSolarWindow();
    if (sw != null && sw.avg > 200) {
      out.add(
        Insight(
          Icons.wb_sunny_rounded,
          'Jam Emas Surya ${hh(sw.start)}–${hh(sw.start.add(const Duration(hours: 3)))}',
          'Jadwalkan mengisi daya laptop/HP dan pekerjaan listrik yang bisa ditunda pada jam ini.',
          C.gold,
          2,
        ),
      );
    }
    final parts = footprintParts();
    final top = topSource;
    if (!hasFootprint) {
      out.add(
        const Insight(
          Icons.edit_note_rounded,
          'Lengkapi datamu',
          'Tambah perangkat listrik di tab Energi dan jarak perjalanan di tab Karbon agar rekomendasi komunitas akurat.',
          C.slate,
          2,
        ),
      );
    } else {
      out.add(
        Insight(
          Icons.co2_rounded,
          'Emisi terbesarmu: $top (${(parts[top] ?? 0).toStringAsFixed(2)} kg)',
          top == 'Listrik'
              ? 'Naikkan kapasitas panel di simulasi Energi atau kurangi jam pakai perangkat, lalu cari komunitas surya terdekat.'
              : 'Kurangi dengan aksi jalan kaki/angkutan umum, dan gabung komunitas yang mendukung kebiasaan itu.',
          C.slate,
          4,
        ),
      );
    }
    final undone = kActions.where((ac) => !done.contains(ac.id)).toList();
    if (undone.isNotEmpty) {
      out.add(
        Insight(
          Icons.checklist_rounded,
          'Aksi berikutnya: ${undone.first.label}',
          'Dampak ±${undone.first.kg.toStringAsFixed(2)} kg CO₂. Centang di tab Karbon setelah kamu lakukan.',
          C.emerald,
          3,
        ),
      );
    }
    return out;
  }

  int get activeSrc {
    final p = plan(n: 1);
    return p.isEmpty ? 2 : p.first.src;
  }
}
