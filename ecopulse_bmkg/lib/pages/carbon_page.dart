import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Satu stream bersama untuk angka real-time (tidak dibuat ulang tiap build).
final Stream<int> _tick = Stream<int>.periodic(
  const Duration(seconds: 1),
  (i) => i,
).asBroadcastStream();

class CarbonPage extends StatelessWidget {
  final AppState s;
  final ValueChanged<int> onGo;
  const CarbonPage(this.s, {super.key, required this.onGo});

  static const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const tips = {
    'Listrik': 'Naikkan kapasitas panel di simulasi Energi, kurangi jam pakai perangkat, dan jalankan beban yang bisa ditunda di Jam Emas Surya.',
    'Motor': 'Gabungkan perjalanan, jalan kaki/sepeda untuk jarak dekat, atau pakai angkutan umum.',
    'Mobil': 'Gunakan carpool, KRL/MRT/bus, atau kendaraan listrik yang diisi dari panel surya.',
    'Bus/KRL': 'Pilihan transportasimu sudah rendah emisi. Pertahankan!',
  };

  Widget _slider(
    String l,
    double v,
    double max,
    String u,
    ValueChanged<double> f,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(fontSize: 13)),
          Text(
            '${v.toStringAsFixed(0)} $u',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
      Slider(
        value: v.clamp(0.0, max).toDouble(),
        min: 0,
        max: max,
        activeColor: C.emerald,
        onChanged: f,
      ),
    ],
  );

  Widget _eq(IconData i, String v, String l) => Expanded(
    child: Column(
      children: [
        Icon(i, color: Colors.white, size: 20),
        Text(
          v,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          l,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final st = s.statOf(today);
    final off = s.offsetTodayKg;
    final act = s.actionsKg;

    // ---- laporan komparatif 2 minggu (data nyata per jam) ----
    final thisWeek = [
      for (var i = 6; i >= 0; i--)
        safe(s.offsetKgOfDay(today.subtract(Duration(days: i)))),
    ];
    final lastWeek = [
      for (var i = 13; i >= 7; i--)
        safe(s.offsetKgOfDay(today.subtract(Duration(days: i)))),
    ];
    final totThis = thisWeek.fold<double>(0, (a, b) => a + b);
    final totLast = lastWeek.fold<double>(0, (a, b) => a + b);
    final delta = totLast <= 0 ? 0.0 : (totThis - totLast) / totLast * 100;
    double peak = 0.1;
    for (final v in [...thisWeek, ...lastWeek]) {
      if (v > peak) peak = v;
    }

    // ---- kalkulator jejak karbon ----
    final parts = s.footprintParts();
    final total = parts.values.fold<double>(0, (a, b) => a + b);
    final top = s.topSource;
    const colors = <String, Color>{
      'Listrik': C.gold,
      'Motor': C.sky,
      'Mobil': Colors.redAccent,
      'Bus/KRL': C.emerald,
    };

    return PageList(
      children: [
        // ---------- Hero real-time ----------
        Container(
          padding: const EdgeInsets.all(22),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [C.emerald, Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: StreamBuilder<int>(
            stream: _tick,
            builder: (context, _) {
              final kg = s.impactTodayKg;
              return Column(
                children: [
                  const Text(
                    'Total CO₂ dihindari hari ini (real-time)',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${kg.toStringAsFixed(4)} kg',
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Energi bersih + Aksi Hijau',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _eq(
                        Icons.park_rounded,
                        (kg / 0.06).toStringAsFixed(0),
                        'pohon menyerap\nselama sehari',
                      ),
                      _eq(
                        Icons.two_wheeler_rounded,
                        (kg / 0.084).toStringAsFixed(1),
                        'km motor\ntidak terpakai',
                      ),
                      _eq(
                        Icons.local_gas_station_rounded,
                        (kg / 2.31).toStringAsFixed(2),
                        'liter bensin\ntidak terbakar',
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),

        // ---------- Sumber angka (hubungan antar fitur) ----------
        Row(
          children: [
            Expanded(
              child: Metric(
                'Dari Energi',
                off.toStringAsFixed(3),
                'kg',
                C.gold,
                note:
                    '${st.used.toStringAsFixed(2)} kWh energi bersih terpakai',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Metric(
                'Dari Aksi Hijau',
                act.toStringAsFixed(2),
                'kg',
                C.emerald,
                note: '${s.done.length} dari ${kActions.length} aksi',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => onGo(2),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Ubah simulasi Energi'),
          ),
        ),

        // ---------- Aksi hijau ----------
        const Section(
          'Aksi Hijau Hari Ini',
          sub: 'Centang yang sudah kamu lakukan. Gratis dan tanpa alat',
        ),
        EcoCard(
          child: Column(
            children: [
              for (final a in kActions)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: C.emerald,
                  value: s.done.contains(a.id),
                  onChanged: (_) => s.toggleAction(a.id),
                  secondary: Icon(a.icon, color: C.emerald),
                  title: Text(a.label, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    '≈ ${a.kg.toStringAsFixed(2)} kg CO₂ (estimasi)',
                    style: const TextStyle(fontSize: 11, color: C.slate),
                  ),
                ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Dihindari lewat aksimu'),
                  Text(
                    '${act.toStringAsFixed(2)} kg CO₂',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: C.emerald,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ---------- Kalkulator ----------
        const Section(
          'Kalkulator Jejak Karbon Harian',
          sub:
              'Listrik otomatis dari tab Energi; transportasi kamu isi sendiri',
        ),
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: C.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Listrik: ${s.dailyKwh.toStringAsFixed(2)} kWh/hari dari perangkatmu, ${st.selfPct.toStringAsFixed(0)}% ditutup energi bersih → ${(parts['Listrik'] ?? 0).toStringAsFixed(2)} kg CO₂',
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _slider('Motor', s.motor, 100, 'km', (v) => s.setActivity(m: v)),
              _slider('Mobil', s.mobil, 100, 'km', (v) => s.setActivity(c: v)),
              _slider(
                'Bus / KRL / MRT',
                s.publik,
                100,
                'km',
                (v) => s.setActivity(b: v),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Jejak karbon harian'),
                  Text(
                    '${total.toStringAsFixed(2)} kg CO₂',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: total < 6 ? C.emerald : C.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (total > 0) ...[
                LayoutBuilder(
                  builder: (context, box) {
                    final w = box.maxWidth;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: w,
                        height: 12,
                        child: Row(
                          children: [
                            for (final e in parts.entries)
                              if (e.value > 0)
                                Container(
                                  width: w * e.value / total,
                                  height: 12,
                                  color: colors[e.key],
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final e in parts.entries)
                      Pill(
                        '${e.key}: ${e.value.toStringAsFixed(2)} kg',
                        colors[e.key] ?? C.slate,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  total < 6
                      ? 'Bagus! Di bawah rata-rata nasional (±6 kg CO₂/hari, perkiraan).'
                      : 'Di atas rata-rata nasional (±6 kg CO₂/hari, perkiraan).',
                  style: const TextStyle(fontSize: 12, color: C.slate),
                ),
                const SizedBox(height: 6),
                Text(
                  'Penyumbang terbesar ($top): ${tips[top] ?? ''}',
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => onGo(4),
                  icon: const Icon(Icons.groups_rounded),
                  label: const Text('Cari komunitas yang membantu'),
                ),
              ] else
                const Text(
                  'Isi jarak perjalananmu atau tambah perangkat di tab Energi untuk mulai menghitung.',
                  style: TextStyle(fontSize: 12, color: C.slate),
                ),
            ],
          ),
        ),

        // ---------- Laporan komparatif ----------
        const Section(
          'Laporan Komparatif 7 Hari',
          sub: 'Carbon offset energi (kg CO₂): minggu ini vs minggu lalu',
        ),
        EcoCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Metric(
                      'Minggu ini',
                      totThis.toStringAsFixed(2),
                      'kg',
                      C.emerald,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Metric(
                      'Minggu lalu',
                      totLast.toStringAsFixed(2),
                      'kg',
                      C.slate,
                      note:
                          '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}% perubahan',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Wrap(
                spacing: 10,
                children: [
                  Pill('● Minggu lalu', C.slate),
                  Pill('● Minggu ini', C.emerald),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    minY: 0,
                    maxY: peak * 1.2,
                    gridData: const FlGridData(
                      show: true,
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 38,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, m) {
                            final i = v.toInt().clamp(0, 6).toInt();
                            final d = today.subtract(Duration(days: 6 - i));
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                days[d.weekday - 1],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < 7; i++)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 3,
                          barRods: [
                            BarChartRodData(
                              toY: lastWeek[i],
                              color: C.slate.withValues(alpha: .5),
                              width: 9,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            BarChartRodData(
                              toY: thisWeek[i],
                              color: C.emerald,
                              width: 9,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ---------- Penjelasan ----------
        const Section('Cara Perhitungan'),
        const Explain(
          Icons.calculate_rounded,
          'Bagaimana Carbon Offset dihitung?',
          'Setiap jam, energi bersih yang terpakai = minimum(produksi panel + turbin, beban perangkatmu). Carbon offset = Σ energi bersih terpakai (kWh) × 0,87 kg CO₂/kWh. '
              'Nilai hari ini berjalan real-time. Perhitungan konservatif karena tidak memasukkan energi di baterai. Produksi dan beban datang dari input di tab Energi.',
        ),
        const Explain(
          Icons.link_rounded,
          'Hubungan Karbon dengan fitur lain',
          'Listrik di kalkulator = kWh perangkatmu × 0,87 × (1 − persen energi bersih dari simulasi Energi). Penyumbang emisi terbesar menentukan jenis komunitas yang direkomendasikan. '
              'Misi komunitas yang kamu selesaikan tercatat di sini sebagai Aksi Hijau.',
          color: C.sky,
        ),
        const Explain(
          Icons.checklist_rounded,
          'Dari mana angka Aksi Hijau & faktor emisi?',
          'Jalan kaki/sepeda menggantikan motor 6 km × 0,084 = ± 0,50 kg. Angkutan umum: (0,084 − 0,05) × 6 = ± 0,20 kg. Matikan lampu/kipas ± 0,3 kWh × 0,87 = ± 0,26 kg. '
              'Cabut charger ± 0,1 kWh × 0,87 = ± 0,09 kg. Botol & tas sendiri ± 0,1 kg (perkiraan kasar). Motor 0,084, mobil 0,192, bus/KRL 0,05 kg per km. Semua angka estimasi edukasi.',
          color: C.emerald,
        ),
      ],
    );
  }
}
