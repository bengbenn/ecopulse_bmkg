import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

// ---------------- Konstanta asumsi (ubah sesuai referensi) ----------------
const double gridFactor =
    0.87; // kg CO2 per kWh listrik grid (estimasi Indonesia)
const double tariffPerKwh =
    1445; // Rp/kWh (estimasi tarif PLN rumah tangga non-subsidi)

/// Cegah NaN/Infinity masuk ke widget (penyebab umum layar merah).
double safe(double v) => (v.isNaN || v.isInfinite) ? 0.0 : v;

String hh(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:00';

String rp(double v) {
  final s = safe(v).round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return 'Rp$b';
}

// ---------------- Cuaca ----------------
class Hour {
  final DateTime t;
  final double temp, wind, rad; // wind m/s, rad W/m2
  final int hum, cloud, code;
  const Hour(
    this.t,
    this.temp,
    this.hum,
    this.cloud,
    this.wind,
    this.rad,
    this.code,
  );

  /// Turbin mini: cut-in 3 m/s, daya penuh 12 m/s, naik kubik.
  double windKw(double rated) =>
      rated * pow(((wind - 3) / 9).clamp(0.0, 1.0).toDouble(), 3).toDouble();
}

class Slot {
  final DateTime t;
  final double temp, wind;
  final int hum, cloud;
  final String desc;
  const Slot(this.t, this.temp, this.hum, this.wind, this.cloud, this.desc);
}

String wmo(int c) {
  if (c == 0) return 'Cerah';
  if (c == 1 || c == 2) return 'Cerah Berawan';
  if (c == 3) return 'Berawan';
  if (c == 45 || c == 48) return 'Berkabut';
  if (c >= 51 && c <= 57) return 'Gerimis';
  if (c == 65 || c == 67 || c == 82) return 'Hujan Lebat';
  if (c >= 61 && c <= 66) return 'Hujan';
  if (c == 80 || c == 81) return 'Hujan Lokal';
  if (c >= 95) return 'Hujan Petir';
  return 'Berawan';
}

IconData weatherIcon(String d) {
  final x = d.toLowerCase();
  if (x.contains('petir')) return Icons.thunderstorm_rounded;
  if (x.contains('hujan') || x.contains('gerimis'))
    return Icons.water_drop_rounded;
  if (x.contains('kabut')) return Icons.foggy;
  if (x.contains('berawan')) return Icons.wb_cloudy_rounded;
  return Icons.wb_sunny_rounded;
}

// ---------------- Udara ----------------
class AirPoint {
  final DateTime t;
  final int aqi;
  const AirPoint(this.t, this.aqi);
}

class Air {
  final int aqi;
  final double pm25, pm10, no2, o3, so2, co, co2;
  final List<AirPoint> forecast;
  const Air(
    this.aqi,
    this.pm25,
    this.pm10,
    this.no2,
    this.o3,
    this.so2,
    this.co,
    this.co2,
    this.forecast,
  );
}

class AqiInfo {
  final String label, advice;
  final Color color;
  const AqiInfo(this.label, this.color, this.advice);
}

AqiInfo aqiInfo(int a) {
  if (a <= 50)
    return const AqiInfo(
      'Baik',
      C.emerald,
      'Udara bersih. Aman untuk semua aktivitas di luar ruangan.',
    );
  if (a <= 100) {
    return const AqiInfo(
      'Sedang',
      C.gold,
      'Kelompok sensitif (asma, lansia, anak-anak) sebaiknya mengurangi aktivitas berat di luar.',
    );
  }
  if (a <= 150) {
    return const AqiInfo(
      'Tidak Sehat bagi Kelompok Sensitif',
      Colors.orange,
      'Kelompok sensitif hindari aktivitas luar ruangan. Gunakan masker bila perlu.',
    );
  }
  if (a <= 200) {
    return const AqiInfo(
      'Tidak Sehat',
      Colors.redAccent,
      'Kurangi aktivitas luar ruangan, pakai masker N95/KN95, tutup jendela, nyalakan air purifier.',
    );
  }
  if (a <= 300) {
    return const AqiInfo(
      'Sangat Tidak Sehat',
      Color(0xFF9333EA),
      'Hindari aktivitas luar ruangan. Tetap di dalam ruangan dengan udara tersaring.',
    );
  }
  return const AqiInfo(
    'Berbahaya',
    Color(0xFF7F1D1D),
    'Kondisi darurat kesehatan. Tetap di dalam ruangan dan ikuti arahan otoritas setempat.',
  );
}

// ---------------- Energi: input manual ----------------
/// Perangkat listrik yang diinput pengguna. Beban per jam dibangun dari daftar ini.
class Appliance {
  final String name;
  final double watt, hours; // daya (W), lama pakai per hari (jam)
  final int start; // jam mulai (0-23)
  const Appliance(this.name, this.watt, this.hours, this.start);

  double get kwhPerDay => watt * hours / 1000;

  /// Daya (kW) pada jam tertentu.
  double kwAt(int hour) {
    final k = (hour - start + 24) % 24;
    if (k >= hours.ceil()) return 0;
    return watt / 1000 * min(1.0, hours - k);
  }

  Map<String, dynamic> toJson() => {
    'n': name,
    'w': watt,
    'h': hours,
    's': start,
  };
  factory Appliance.fromJson(Map<String, dynamic> j) => Appliance(
    j['n'] as String,
    (j['w'] as num).toDouble(),
    (j['h'] as num).toDouble(),
    (j['s'] as num).toInt(),
  );
}

const List<Appliance> kDefaultAppliances = [
  Appliance('Lampu LED', 12, 5, 18),
  Appliance('Laptop', 60, 6, 8),
  Appliance('Kipas angin', 45, 8, 21),
  Appliance('Charger HP', 10, 3, 20),
];

/// Skenario cuaca untuk simulasi "bagaimana jika" (mengalikan profil langit cerah).
const List<String> kScenarios = ['Data nyata', 'Cerah', 'Berawan', 'Hujan'];
const List<double> kScenarioFactor = [1.0, 0.95, 0.45, 0.15];

class Preset {
  final String name, note;
  final double pvWp, batWh;
  const Preset(this.name, this.note, this.pvWp, this.batWh);
}

const List<Preset> kPresets = [
  Preset('Powerbank surya', 'Panel 20 Wp, baterai 50 Wh', 20, 50),
  Preset('Kamar / kos', 'Panel 100 Wp, baterai 500 Wh', 100, 500),
  Preset(
    'Sekolah / kampus',
    'Atap 3.000 Wp, baterai 5 kWh (simulasi proyek)',
    3000,
    5000,
  ),
];

// ---------------- Komunitas ----------------
enum PlaceType {
  park('Taman & Ruang Hijau', C.emerald, 120.0, Icons.park_rounded),
  recycle('Daur Ulang & Bank Sampah', C.sky, 210.0, Icons.recycling_rounded),
  solar('Pembangkit Surya', C.gold, 50.0, Icons.solar_power_rounded),
  ngo('Komunitas / LSM', Color(0xFF8B5CF6), 270.0, Icons.groups_rounded);

  final String label;
  final Color color;
  final double hue;
  final IconData icon;
  const PlaceType(this.label, this.color, this.hue, this.icon);
}

class GreenPlace {
  final String id, name;
  final double lat, lon, dist; // dist dalam meter dari lokasi pengguna
  final PlaceType type;
  const GreenPlace(
    this.id,
    this.name,
    this.lat,
    this.lon,
    this.type,
    this.dist,
  );
}

// ---------------- Aksi hijau & misi komunitas ----------------
class GreenAction {
  final String id, label;
  final double kg; // estimasi kg CO2 yang dihindari
  final IconData icon;
  const GreenAction(this.id, this.label, this.kg, this.icon);
}

const List<GreenAction> kActions = [
  GreenAction(
    'walk',
    'Jalan kaki / sepeda ke sekolah (±6 km pergi-pulang)',
    0.50,
    Icons.directions_walk_rounded,
  ),
  GreenAction(
    'bus',
    'Naik angkutan umum, bukan motor (±6 km)',
    0.20,
    Icons.directions_bus_rounded,
  ),
  GreenAction(
    'light',
    'Matikan lampu & kipas saat tidak dipakai',
    0.26,
    Icons.lightbulb_outline_rounded,
  ),
  GreenAction(
    'plug',
    'Cabut charger & perangkat standby',
    0.09,
    Icons.power_off_rounded,
  ),
  GreenAction(
    'bottle',
    'Bawa botol minum & tas belanja sendiri',
    0.10,
    Icons.local_drink_rounded,
  ),
];

GreenAction actionById(String id) => kActions.firstWhere((a) => a.id == id);

/// Setiap jenis komunitas membuka satu misi yang terhubung ke Aksi Hijau (dan ke total Karbon).
class Mission {
  final String title, actionId;
  const Mission(this.title, this.actionId);
}

const Map<PlaceType, Mission> kMissions = {
  PlaceType.park: Mission('Jalan kaki / bersepeda ke taman ini', 'walk'),
  PlaceType.recycle: Mission(
    'Setor sampah plastik & bawa botol sendiri',
    'bottle',
  ),
  PlaceType.solar: Mission(
    'Pelajari instalasinya, lalu terapkan hemat listrik di rumah',
    'light',
  ),
  PlaceType.ngo: Mission(
    'Ikut kegiatan & ajak teman naik angkutan umum',
    'bus',
  ),
};

class City {
  final String name,
      adm4; // adm4 = kode wilayah BMKG (kosong bila belum diketahui)
  final double lat, lon;
  const City(this.name, this.lat, this.lon, [this.adm4 = '']);
}

const List<City> kCities = [
  City('Jakarta', -6.1647, 106.8470, '31.71.03.1001'),
  City('Bandung', -6.9175, 107.6191),
  City('Semarang', -6.9667, 110.4167),
  City('Yogyakarta', -7.7956, 110.3695),
  City('Surabaya', -7.2575, 112.7521),
  City('Medan', 3.5952, 98.6722),
  City('Palembang', -2.9761, 104.7754),
  City('Makassar', -5.1477, 119.4327),
  City('Denpasar', -8.6705, 115.2126),
  City('Balikpapan', -1.2379, 116.8529),
];
