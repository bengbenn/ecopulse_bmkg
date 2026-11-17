import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class AirPage extends StatelessWidget {
  final AppState s;
  final ValueChanged<int>? onGo;
  const AirPage(this.s, {super.key, this.onGo});

  String hh(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final a = s.air;
    final cur = s.slots.first;
    final warnings = <String>[
      if (a != null && a.aqi > 100)
        'Kualitas udara ${aqiInfo(a.aqi).label.toLowerCase()} (AQI ${a.aqi}). Kurangi aktivitas luar ruangan.',
      if (s.slots.any(
        (e) =>
            e.desc.toLowerCase().contains('petir') ||
            e.desc.toLowerCase().contains('lebat'),
      ))
        'Potensi hujan lebat/petir dalam 24 jam. Amankan perangkat panel surya & turbin.',
      if (s.slots.take(4).map((e) => e.cloud).reduce((x, y) => x + y) /
              s.slots.take(4).length >
          80)
        'Awan tebal: produksi panel surya akan rendah. Siapkan cadangan baterai.',
      if (s.slots.any((e) => e.wind > 10))
        'Angin kencang (>10 m/s). Turbin angin bekerja optimal, periksa keamanan instalasi.',
    ];
    final src = s.offline
        ? 'Mode offline: data contoh'
        : s.bmkgLive
            ? 'Cuaca: BMKG • Radiasi & udara: Open-Meteo'
            : 'Cuaca, radiasi & udara: Open-Meteo (BMKG tidak aktif untuk lokasi ini)';

    return PageList(
      children: [
        if (s.gpsNote != null)
          EcoCard(
            color: C.gold.withValues(alpha: .18),
            padding: const EdgeInsets.all(12),
            child: Text(s.gpsNote!, style: const TextStyle(fontSize: 12)),
          ),
        Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: C.emerald),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                s.displayPlace,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Pill(
            src,
            s.offline ? Colors.redAccent : (s.bmkgLive ? C.emerald : C.sky),
          ),
        ),
        const SizedBox(height: 12),
        _hero(cur),
        _link(context),
        for (final w in warnings)
          EcoCard(
            color: C.gold.withValues(alpha: .18),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: C.gold),
                const SizedBox(width: 10),
                Expanded(child: Text(w, style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
        const Section(
          'Kualitas Udara',
          sub: 'Real-time (US AQI) dari model CAMS via Open-Meteo',
        ),
        if (a == null)
          const EcoCard(
            child: Text(
              'Data kualitas udara belum tersedia. Periksa koneksi lalu tekan muat ulang.',
            ),
          )
        else ...[
          _aqiCard(a),
          const Section(
            'Polutan & Emisi',
            sub: 'Dibandingkan dengan pedoman WHO 2021 (rata-rata 24 jam)',
          ),
          GridView.extent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 1.5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _tile('PM2.5', a.pm25, 'µg/m³', 15),
              _tile('PM10', a.pm10, 'µg/m³', 45),
              _tile('NO₂', a.no2, 'µg/m³', 25),
              _tile('O₃', a.o3, 'µg/m³', 60),
              _tile('SO₂', a.so2, 'µg/m³', 40),
              _tile('CO', a.co, 'µg/m³', 4000),
              _tile('CO₂', a.co2, 'ppm', null),
            ],
          ),
          const SizedBox(height: 14),
          if (a.forecast.length > 2) ...[
            const Section('Prakiraan AQI 12 Jam'),
            EcoCard(child: SizedBox(height: 170, child: _aqiChart(a))),
          ],
        ],
        const Section(
          'Prakiraan Cuaca 24 Jam',
          sub: 'Suhu, angin, dan tutupan awan',
        ),
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [for (final e in s.slots) _slot(context, e)],
          ),
        ),
        const SizedBox(height: 14),
        const Section('Penjelasan'),
        const Explain(
          Icons.air,
          'Apa itu AQI?',
          'Air Quality Index (AQI) merangkum konsentrasi polutan menjadi satu angka 0–500. Aplikasi ini memakai skala US AQI: '
              '0–50 Baik, 51–100 Sedang, 101–150 Tidak sehat bagi kelompok sensitif, 151–200 Tidak sehat, 201–300 Sangat tidak sehat, >300 Berbahaya. '
              'Nilai AQI ditentukan oleh polutan dengan sub-indeks tertinggi (umumnya PM2.5).',
        ),
        const Explain(
          Icons.grain,
          'PM2.5 & PM10',
          'Partikel halus berdiameter ≤2,5 µm (PM2.5) dan ≤10 µm (PM10) berasal dari kendaraan, pembakaran, industri, dan debu. '
              'PM2.5 paling berbahaya karena dapat masuk hingga paru-paru dalam dan aliran darah. Pedoman WHO 2021: PM2.5 ≤15 µg/m³ dan PM10 ≤45 µg/m³ (rata-rata 24 jam).',
          color: C.sky,
        ),
        const Explain(
          Icons.science_rounded,
          'NO₂, O₃, SO₂ & CO',
          'NO₂ dan CO terutama dari knalpot kendaraan; SO₂ dari pembakaran batu bara/solar industri; O₃ (ozon permukaan) terbentuk dari reaksi NO₂ dan sinar matahari. '
              'Konsentrasi tinggi memicu gangguan pernapasan dan jantung.',
          color: C.gold,
        ),
        const Explain(
          Icons.co2,
          'CO₂ & emisi',
          'CO₂ adalah gas rumah kaca utama. Konsentrasi atmosfer global saat ini sekitar 420+ ppm. CO₂ tidak berbahaya langsung bagi kesehatan pada level luar ruangan, '
              'tetapi menunjukkan dampak pembakaran bahan bakar fosil. Gunakan tab Karbon untuk melihat berapa CO₂ yang Anda hindari.',
          color: C.slate,
        ),
        const Explain(
          Icons.info_outline_rounded,
          'Sumber data & akurasi',
          'Prakiraan cuaca (suhu, kelembapan, angin, awan, deskripsi) diambil dari API publik BMKG (api.bmkg.go.id) berdasarkan kode wilayah adm4. '
              'BMKG belum menyediakan API publik untuk radiasi matahari dan AQI, sehingga radiasi surya & kualitas udara memakai Open-Meteo (model CAMS/ECMWF). '
              'Data udara berbasis model grid, bukan sensor di depan rumah Anda, jadi bisa berbeda dengan alat ukur lokal.',
        ),
      ],
    );
  }

  /// Keterkaitan Udara -> Energi: cuaca hari ini menentukan produksi panel.
  Widget _link(BuildContext context) {
    final st = s.statOf(DateTime.now());
    return EcoCard(
      color: C.gold.withValues(alpha: .15),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, color: C.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Terhubung ke Energi: radiasi puncak hari ini ${s.maxRadToday.toStringAsFixed(0)} W/m² → '
              'panel ${s.pvWp.toStringAsFixed(0)} Wp diperkirakan menghasilkan ${st.prod.toStringAsFixed(2)} kWh.',
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
          if (onGo != null)
            TextButton(onPressed: () => onGo!(2), child: const Text('Lihat')),
        ],
      ),
    );
  }

  Widget _hero(Slot c) {
    final rad = s.nowHour?.rad ?? 0;
    Widget mini(IconData i, String v, String l) => Column(
          children: [
            Icon(i, color: Colors.white, size: 18),
            Text(
              v,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(l,
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        );
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [C.emerald, C.sky],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(weatherIcon(c.desc), color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                c.desc,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
          Text(
            '${c.temp.toStringAsFixed(0)}°C',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              mini(Icons.water_drop, '${c.hum}%', 'Lembap'),
              mini(Icons.air, '${c.wind.toStringAsFixed(1)} m/s', 'Angin'),
              mini(Icons.cloud, '${c.cloud}%', 'Awan'),
              mini(Icons.wb_sunny, '${rad.toStringAsFixed(0)} W/m²', 'Radiasi'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aqiCard(Air a) {
    final info = aqiInfo(a.aqi);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${a.aqi}',
                style: TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w700,
                  color: info.color,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    info.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: info.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final x = (a.aqi / 300).clamp(0.0, 1.0).toDouble() *
                  (box.maxWidth - 18);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(
                        colors: [
                          C.emerald,
                          C.gold,
                          Colors.orange,
                          Colors.redAccent,
                          Color(0xFF9333EA),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: x,
                    top: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: info.color, width: 4),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(info.advice, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _tile(String n, double v, String unit, double? who) {
    final ratio = who == null ? null : v / who;
    final col = ratio == null
        ? C.slate
        : (ratio <= 1 ? C.emerald : (ratio <= 2 ? C.gold : Colors.redAccent));
    return Metric(
      n,
      v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1),
      unit,
      col,
      note: ratio == null
          ? 'global ± 420 ppm'
          : '${ratio.toStringAsFixed(1)}× batas WHO',
    );
  }

  Widget _aqiChart(Air a) {
    final fc = a.forecast;
    final mx = fc.fold<int>(0, (m, e) => e.aqi > m ? e.aqi : m);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: (mx < 10 ? 10 : mx) * 1.2,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= fc.length || i % 3 != 0) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    hh(fc[i].t),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < fc.length; i++)
                FlSpot(i.toDouble(), fc[i].aqi.toDouble()),
            ],
            isCurved: true,
            color: aqiInfo(a.aqi).color,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: aqiInfo(a.aqi).color.withValues(alpha: .15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slot(BuildContext context, Slot e) => Container(
        width: 100,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark(context) ? C.charcoal : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hh(e.t),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            Icon(weatherIcon(e.desc), color: C.sky),
            Text(
              '${e.temp.toStringAsFixed(0)}°C',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              e.desc,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: C.slate),
            ),
            Text(
              '${e.wind.toStringAsFixed(1)} m/s • ${e.cloud}%',
              style: const TextStyle(fontSize: 10, color: C.slate),
            ),
          ],
        ),
      );
}
