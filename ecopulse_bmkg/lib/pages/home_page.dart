import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Beranda: menunjukkan rantai Cuaca → Energi → Karbon → Komunitas dengan angka nyata.
class HomePage extends StatelessWidget {
  final AppState s;
  final ValueChanged<int> onGo;
  const HomePage(this.s, {super.key, required this.onGo});

  String km(double m) => m < 1000
      ? '${m.toStringAsFixed(0)} m'
      : '${(m / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final st = s.statOf(DateTime.now());
    final a = s.air;
    final cur = s.slots.first;
    final rad = s.nowHour?.rad ?? 0;
    final off = s.offsetTodayKg;
    final act = s.actionsKg;
    final total = off + act;
    final rec = s.recommendedTypes();
    GreenPlace? near;
    for (final p in s.places) {
      if (p.type == rec.first) {
        near = p;
        break;
      }
    }

    final airTxt =
        '${cur.desc}, awan ${cur.cloud}%, radiasi ${rad.toStringAsFixed(0)} W/m²'
        '${a != null ? ' • AQI ${a.aqi} (${aqiInfo(a.aqi).label})' : ''}';
    final energyTxt =
        'Panel ${s.pvWp.toStringAsFixed(0)} Wp • ${kScenarios[s.scenario]} → produksi ${st.prod.toStringAsFixed(2)} kWh '
        'dari kebutuhan ${st.load.toStringAsFixed(2)} kWh (${st.selfPct.toStringAsFixed(0)}% tertutup energi bersih)';
    final carbonTxt =
        'Offset energi ${off.toStringAsFixed(3)} kg + Aksi Hijau ${act.toStringAsFixed(2)} kg '
        '= ${total.toStringAsFixed(2)} kg CO₂ dihindari';
    final commTxt = near != null
        ? 'Rekomendasi: ${near.name} (${km(near.dist)}) • ${s.joined.length} komunitas diikuti'
        : 'Belum ada tempat ditemukan di sekitar • ${s.joined.length} komunitas diikuti';

    return PageList(
      children: [
        Container(
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
                  const Icon(Icons.location_on, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      s.displayPlace,
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Dampak hijaumu hari ini',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '${total.toStringAsFixed(2)} kg CO₂',
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                '≈ ${(total / 0.06).toStringAsFixed(0)} pohon menyerap selama sehari',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
        const Section(
          'Alur Dampakmu',
          sub: 'Setiap tahap memakai hasil tahap sebelumnya. Ketuk untuk membuka',
        ),
        _step(
          1,
          Icons.cloud_rounded,
          C.sky,
          'Udara & Cuaca',
          airTxt,
          'Awan dan radiasi ini menentukan produksi panelmu →',
          1,
        ),
        _arrow(),
        _step(
          2,
          Icons.bolt_rounded,
          C.gold,
          'Energi (simulasi inputmu)',
          energyTxt,
          'Energi bersih yang terpakai menjadi carbon offset →',
          2,
        ),
        _arrow(),
        _step(
          3,
          Icons.co2_rounded,
          C.emerald,
          'Karbon',
          carbonTxt,
          'Penyumbang emisi terbesarmu (${s.topSource}) menentukan rekomendasi komunitas →',
          3,
        ),
        _arrow(),
        _step(
          4,
          Icons.groups_rounded,
          const Color(0xFF8B5CF6),
          'Komunitas',
          commTxt,
          'Gabung untuk membuka misi yang menambah Aksi Hijau →',
          4,
        ),
        const Section(
          'Langkah Hari Ini',
          sub: 'Disusun otomatis dari data di atas',
        ),
        for (final i in s.insights())
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onGo(i.tab),
            child: EcoCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: i.color.withValues(alpha: .15),
                    child: Icon(i.icon, color: i.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          i.body,
                          style: const TextStyle(fontSize: 12, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: C.slate),
                ],
              ),
            ),
          ),
        const Section('Bagaimana Fitur Saling Terhubung?'),
        const Explain(
          Icons.account_tree_rounded,
          'Rantai data EcoPulse',
          '1) Udara & Cuaca: BMKG dan Open-Meteo memberi awan, angin, radiasi, dan AQI.\n'
              '2) Energi: radiasi dan angin diubah menjadi produksi panel; kamu mengisi panel, baterai, perangkat listrik, dan skenario cuaca sendiri. '
              'Hasilnya: persen beban yang tertutup energi bersih.\n'
              '3) Karbon: energi bersih yang terpakai dikali 0,87 kg/kWh menjadi carbon offset. Persen yang sama dipakai di kalkulator jejak karbon, '
              'ditambah emisi transportasimu dan Aksi Hijau.\n'
              '4) Komunitas: sumber emisi terbesarmu dan kondisi udara menentukan jenis komunitas yang direkomendasikan. '
              'Bergabung membuka misi yang tercatat kembali sebagai Aksi Hijau di tab Karbon.',
        ),
      ],
    );
  }

  Widget _arrow() => const Padding(
    padding: EdgeInsets.only(bottom: 6),
    child: Center(
      child: Icon(Icons.arrow_downward_rounded, color: C.slate, size: 18),
    ),
  );

  Widget _step(
    int n,
    IconData icon,
    Color color,
    String title,
    String body,
    String link,
    int tab,
  ) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => onGo(tab),
    child: EcoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: .15),
            child: Text(
              '$n',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(fontSize: 12.5, height: 1.45),
                ),
                const SizedBox(height: 4),
                Text(
                  link,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.slate),
        ],
      ),
    ),
  );
}
