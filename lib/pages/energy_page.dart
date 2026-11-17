import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class EnergyPage extends StatelessWidget {
  final AppState s;
  final ValueChanged<int> onGo;
  const EnergyPage(this.s, {super.key, required this.onGo});

  static const names = ['Energi Terbarukan', 'Baterai', 'Listrik PLN'];
  static const icons = [
    Icons.solar_power_rounded,
    Icons.battery_charging_full_rounded,
    Icons.power_rounded,
  ];
  static const cols = [C.emerald, C.gold, C.slate];

  String reason(PlanStep p) {
    final r = p.renew.toStringAsFixed(3), l = p.load.toStringAsFixed(3);
    if (p.src == 0)
      return 'Produksi $r kW ≥ beban $l kW, jadi beban ditopang energi terbarukan dan surplusnya mengisi baterai.';
    if (p.src == 1)
      return 'Produksi $r kW < beban $l kW. Kekurangan ${p.bat.toStringAsFixed(3)} kW diambil dari baterai (sisa ${p.soc.toStringAsFixed(0)}%).';
    return 'Produksi $r kW rendah dan baterai di batas aman 20%. ${p.grid.toStringAsFixed(3)} kW dipenuhi listrik PLN.';
  }

  LineChartBarData _line(
    List<FlSpot> pts,
    Color c, {
    bool dashed = false,
    bool fill = false,
  }) => LineChartBarData(
    spots: pts,
    isCurved: true,
    color: c,
    barWidth: 3,
    dashArray: dashed ? [6, 4] : null,
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(show: fill, color: c.withValues(alpha: .12)),
  );

  Future<void> _addAppliance(BuildContext context) async {
    final n = TextEditingController();
    final w = TextEditingController();
    final h = TextEditingController(text: '2');
    final st = TextEditingController(text: '8');
    String? err;
    const kb = TextInputType.numberWithOptions(decimal: true);
    final r = await showDialog<Appliance>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Tambah perangkat listrik'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: n,
                  decoration: const InputDecoration(
                    labelText: 'Nama (mis. Setrika)',
                  ),
                ),
                TextField(
                  controller: w,
                  keyboardType: kb,
                  decoration: const InputDecoration(
                    labelText: 'Daya',
                    suffixText: 'watt',
                  ),
                ),
                TextField(
                  controller: h,
                  keyboardType: kb,
                  decoration: const InputDecoration(
                    labelText: 'Dipakai per hari',
                    suffixText: 'jam',
                  ),
                ),
                TextField(
                  controller: st,
                  keyboardType: kb,
                  decoration: const InputDecoration(
                    labelText: 'Mulai jam (0–23)',
                  ),
                ),
                if (err != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      err!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final watt = double.tryParse(w.text.replaceAll(',', '.'));
                final hrs = double.tryParse(h.text.replaceAll(',', '.'));
                final start = int.tryParse(st.text.trim());
                if (n.text.trim().isEmpty ||
                    watt == null ||
                    hrs == null ||
                    start == null ||
                    watt <= 0 ||
                    hrs <= 0 ||
                    hrs > 24 ||
                    start < 0 ||
                    start > 23) {
                  setSt(
                    () => err = 'Isi nama, daya > 0, jam pakai 0–24, dan jam mulai 0–23.',
                  );
                  return;
                }
                Navigator.pop(ctx, Appliance(n.text.trim(), watt, hrs, start));
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    n.dispose();
    w.dispose();
    h.dispose();
    st.dispose();
    if (r != null) s.addAppliance(r);
  }

  @override
  Widget build(BuildContext context) {
    final plan = s.plan();
    if (plan.isEmpty)
      return const PageList(
        children: [
          EcoCard(
            child: Text('Data prakiraan belum tersedia. Tekan muat ulang.'),
          ),
        ],
      );
    final now = plan.first;
    final today = s.hoursOf(DateTime.now());
    final st = s.statOf(DateTime.now());
    final sw = s.bestSolarWindow();
    final cur = s.slots.first;
    double peak = 0.01;
    for (final h in today) {
      for (final v in [s.solarKw(h), h.windKw(s.windKw), s.loadAt(h.t.hour)]) {
        if (safe(v) > peak) peak = safe(v);
      }
    }
    final mx = s.maxSelfPct;
    final nHalf = s.neededWp(mx * 0.5), nNear = s.neededWp(mx * 0.9);
    String need(double? v) => v == null ? '-' : '≈ ${v.round()} Wp';

    return PageList(
      children: [
        // ---------- Jam emas ----------
        if (sw != null)
          EcoCard(
            color: C.gold.withValues(alpha: .15),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny_rounded, color: C.gold, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jam Emas Surya (24 jam ke depan)',
                        style: TextStyle(fontSize: 12, color: C.slate),
                      ),
                      Text(
                        '${hh(sw.start)} – ${hh(sw.start.add(const Duration(hours: 3)))}  •  ${sw.avg.toStringAsFixed(0)} W/m²',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Waktu terbaik mengisi daya dengan panel surya atau menjalankan beban yang boleh ditunda.',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // ---------- Input dari Udara ----------
        EcoCard(
          color: C.sky.withValues(alpha: .12),
          child: Row(
            children: [
              const Icon(Icons.cloud_rounded, color: C.sky),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Input dari Udara: ${cur.desc}, awan ${cur.cloud}%, angin ${cur.wind.toStringAsFixed(1)} m/s, radiasi puncak hari ini ${s.maxRadToday.toStringAsFixed(0)} W/m². Data ini menentukan produksi di bawah.',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
              TextButton(onPressed: () => onGo(1), child: const Text('Udara')),
            ],
          ),
        ),

        // ---------- Rekomendasi sekarang ----------
        EcoCard(
          color: cols[now.src].withValues(alpha: .15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rekomendasi sumber daya jam ini',
                style: TextStyle(color: C.slate, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(icons[now.src], size: 36, color: cols[now.src]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      names[now.src],
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Kenapa? ${reason(now)}',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),

        // ---------- INPUT MANUAL ----------
        const Section(
          'Input Simulasi',
          sub: 'Ubah angka di bawah, hasil dan grafik langsung berubah',
        ),
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Skenario cuaca',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < kScenarios.length; i++)
                    ChoiceChip(
                      label: Text(kScenarios[i]),
                      selected: s.scenario == i,
                      onSelected: (_) => s.updateCfg(scn: i),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Data nyata memakai prakiraan Open-Meteo. Skenario lain mengandaikan hari ini cerah/berawan/hujan.',
                style: TextStyle(fontSize: 11, color: C.slate),
              ),
              const Divider(height: 24),
              const Text(
                'Contoh cepat',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final p in kPresets)
                    ActionChip(
                      label: Text(p.name),
                      tooltip: p.note,
                      onPressed: () => s.applyPreset(p),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 150,
                    child: NumField(
                      label: 'Panel surya',
                      suffix: 'Wp',
                      value: s.pvWp,
                      min: 0,
                      max: 20000,
                      onChanged: (v) => s.updateCfg(pv: v),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: NumField(
                      label: 'Baterai',
                      suffix: 'Wh',
                      value: s.batWh,
                      min: 0,
                      max: 20000,
                      onChanged: (v) => s.updateCfg(bat: v),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: NumField(
                      label: 'Level baterai',
                      suffix: '%',
                      value: s.batPct,
                      min: 0,
                      max: 100,
                      onChanged: (v) => s.updateCfg(pct: v),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: NumField(
                      label: 'Turbin angin',
                      suffix: 'W',
                      value: s.windW,
                      min: 0,
                      max: 3000,
                      onChanged: (v) => s.updateCfg(wind: v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ---------- Perangkat listrik ----------
        const Section(
          'Perangkat Listrik Saya',
          sub: 'Beban per jam dibangun dari daftar ini',
        ),
        for (var i = 0; i < s.appliances.length; i++)
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.power_rounded, color: C.slate),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.appliances[i].name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${s.appliances[i].watt.toStringAsFixed(0)} W • ${s.appliances[i].hours.toStringAsFixed(1)} jam/hari • mulai ${hh(DateTime(2000, 1, 1, s.appliances[i].start))} • ${s.appliances[i].kwhPerDay.toStringAsFixed(2)} kWh',
                        style: const TextStyle(fontSize: 11, color: C.slate),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus',
                  onPressed: () => s.removeAppliance(i),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: C.emerald),
                onPressed: () => _addAppliance(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah perangkat'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: s.resetAppliances,
              child: const Text('Reset contoh'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Total pemakaian: ${s.dailyKwh.toStringAsFixed(2)} kWh per hari',
          style: const TextStyle(fontSize: 12, color: C.slate),
        ),
        const SizedBox(height: 14),

        // ---------- Hasil ----------
        const Section(
          'Hasil Simulasi Hari Ini',
          sub: 'Angka ini dipakai oleh tab Karbon dan Beranda',
        ),
        GridView.extent(
          maxCrossAxisExtent: 220,
          childAspectRatio: 1.7,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Metric('Produksi', st.prod.toStringAsFixed(2), 'kWh', C.gold),
            Metric('Kebutuhan', st.load.toStringAsFixed(2), 'kWh', C.slate),
            Metric(
              'Energi bersih terpakai',
              st.selfPct.toStringAsFixed(0),
              '%',
              C.emerald,
              note: 'tanpa baterai',
            ),
            Metric('Hemat biaya', rp(st.used * tariffPerKwh), '', C.sky),
          ],
        ),
        const SizedBox(height: 14),
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Butuh panel berapa?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                mx <= 0
                    ? 'Tambah perangkat listrik dulu agar bisa dihitung.'
                    : 'Batas maksimal tanpa baterai: ${mx.toStringAsFixed(0)}% (beban malam hari tidak bisa ditutup panel).\nMenutup 50% dari batas itu (${(mx * .5).round()}%): ${need(nHalf)}\nMenutup 90% dari batas itu (${(mx * .9).round()}%): ${need(nNear)}',
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 4),
              const Text(
                'Dihitung dari radiasi hari ini dan daftar perangkatmu, tanpa baterai.',
                style: TextStyle(fontSize: 11, color: C.slate),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => onGo(3),
                icon: const Icon(Icons.co2_rounded),
                label: Text(
                  'Lihat dampak karbon (${(st.used * gridFactor).toStringAsFixed(2)} kg)',
                ),
              ),
            ],
          ),
        ),

        // ---------- Grafik ----------
        const Section('Produksi vs Beban Hari Ini', sub: 'kW per jam'),
        EcoCard(
          child: Column(
            children: [
              const Wrap(
                spacing: 14,
                children: [
                  Pill('● Surya', C.gold),
                  Pill('● Angin', C.sky),
                  Pill('● Beban', C.slate),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 190,
                child: today.isEmpty
                    ? const Center(child: Text('Belum ada data'))
                    : LineChart(
                        LineChartData(
                          minY: 0,
                          maxY: peak * 1.2,
                          minX: 0,
                          maxX: 23,
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
                                reservedSize: 36,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 4,
                                getTitlesWidget: (v, m) => Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${v.toInt()}:00',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          lineBarsData: [
                            _line(
                              [
                                for (final h in today)
                                  FlSpot(
                                    h.t.hour.toDouble(),
                                    safe(s.solarKw(h)),
                                  ),
                              ],
                              C.gold,
                              fill: true,
                            ),
                            _line([
                              for (final h in today)
                                FlSpot(
                                  h.t.hour.toDouble(),
                                  safe(h.windKw(s.windKw)),
                                ),
                            ], C.sky),
                            _line(
                              [
                                for (final h in today)
                                  FlSpot(
                                    h.t.hour.toDouble(),
                                    safe(s.loadAt(h.t.hour)),
                                  ),
                              ],
                              C.slate,
                              dashed: true,
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),

        // ---------- Rencana ----------
        const Section(
          'Rencana 12 Jam ke Depan',
          sub: 'Simulasi baterai + rekomendasi sumber per jam',
        ),
        for (final p in plan)
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    hh(p.h.t),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(icons[p.src], color: cols[p.src]),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        names[p.src],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Produksi ${p.renew.toStringAsFixed(3)} kW • Beban ${p.load.toStringAsFixed(3)} kW • Baterai ${p.soc.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 10, color: C.slate),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${s.radOf(p.h).toStringAsFixed(0)} W/m²',
                  style: const TextStyle(color: C.slate, fontSize: 11),
                ),
              ],
            ),
          ),

        // ---------- Penjelasan ----------
        const Section('Cara Kerja'),
        const Explain(
          Icons.swap_horiz_rounded,
          'Rekomendasi sumber daya',
          'Setiap jam sistem membandingkan produksi energi terbarukan dengan bebanmu:\n'
              '1) Produksi ≥ beban → Energi Terbarukan; surplus mengisi baterai.\n'
              '2) Produksi < beban dan baterai di atas cadangan 20% → kekurangan dari Baterai.\n'
              '3) Baterai habis → sisanya dari Listrik PLN.',
        ),
        const Explain(
          Icons.wb_sunny_rounded,
          'Rumus panel surya & turbin',
          'Panel: Daya (kW) = Kapasitas (kWp) × Radiasi (W/m²) ÷ 1000 × 0,8 (rugi inverter, suhu, debu). '
              'Turbin kecil: mulai berputar 3 m/s, daya penuh 12 m/s, dan naik kubik di antaranya. Baterai: efisiensi 90% dan cadangan 20%.',
          color: C.gold,
        ),
        const Explain(
          Icons.link_rounded,
          'Hubungan dengan fitur lain',
          'Radiasi, awan, dan angin dari tab Udara menjadi produksi di sini. Persen energi bersih yang terpakai dan kWh perangkatmu dipakai tab Karbon '
              'untuk carbon offset dan kalkulator jejak karbon.',
          color: C.sky,
        ),
        const Explain(
          Icons.rule_rounded,
          'Asumsi & batasan',
          'Perhitungan harian bersifat konservatif karena tidak memasukkan energi yang disimpan di baterai. Tarif Rp1.445/kWh dan faktor emisi 0,87 kg CO₂/kWh '
              'adalah estimasi (ubah di models.dart). Angka ini untuk perencanaan, bukan pembacaan meter.',
          color: C.slate,
        ),
      ],
    );
  }
}
