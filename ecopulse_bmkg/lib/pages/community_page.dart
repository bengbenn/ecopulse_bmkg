import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class CommunityPage extends StatefulWidget {
  final AppState s;
  final ValueChanged<int> onGo;
  const CommunityPage(this.s, {super.key, required this.onGo});
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  int view = 0; // 0 peta, 1 daftar
  final Set<PlaceType> filter = {...PlaceType.values};
  GreenPlace? sel;

  AppState get s => widget.s;

  /// Urut berdasarkan relevansi untuk pengguna, lalu jarak.
  List<GreenPlace> get shown {
    final rec = s.recommendedTypes();
    final l = s.places.where((p) => filter.contains(p.type)).toList();
    l.sort((a, b) {
      final c = rec.indexOf(a.type).compareTo(rec.indexOf(b.type));
      return c != 0 ? c : a.dist.compareTo(b.dist);
    });
    return l;
  }

  String km(double m) => m < 1000
      ? '${m.toStringAsFixed(0)} m'
      : '${(m / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final rec = s.recommendedTypes();
    final nearest = s.places.isEmpty ? '-' : km(s.places.first.dist);
    final jt = s.joinedTypes;
    final missionDone =
        jt.where((t) => s.done.contains(kMissions[t]!.actionId)).length;
    final missionKg = jt
        .where((t) => s.done.contains(kMissions[t]!.actionId))
        .fold<double>(0, (a, t) => a + actionById(kMissions[t]!.actionId).kg);

    return PageList(
      children: [
        Row(
          children: [
            Expanded(
              child: Metric(
                'Tempat hijau',
                '${s.places.length}',
                '',
                C.emerald,
                note: 'radius 7 km',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Metric('Terdekat', nearest, '', C.sky)),
            const SizedBox(width: 10),
            Expanded(
              child: Metric('Diikuti', '${s.joined.length}', '', C.gold),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ---------- Tujuan untukmu ----------
        Section(
          'Kenapa Komunitas Untukmu?',
          sub: s.hasFootprint
              ? 'Disusun dari emisi terbesarmu (${s.topSource}) dan kondisi udara hari ini'
              : 'Isi perangkat (Energi) dan perjalanan (Karbon) agar rekomendasi akurat',
        ),
        for (final t in rec.take(2)) _forYou(t),

        // ---------- Komunitas yang diikuti ----------
        if (s.joined.isNotEmpty) ...[
          const Section('Komunitas yang Kamu Ikuti'),
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final n in s.joinedNames)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $n', style: const TextStyle(fontSize: 13)),
                  ),
                const Divider(height: 20),
                Text(
                  'Misi selesai hari ini: $missionDone dari ${jt.length}  •  +${missionKg.toStringAsFixed(2)} kg CO₂ (tercatat di tab Karbon)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: C.emerald,
                  ),
                ),
              ],
            ),
          ),
        ],

        // ---------- Peta / daftar ----------
        const Section('Tempat & Komunitas Nyata di Sekitarmu'),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.map_rounded),
              label: Text('Peta'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.list_rounded),
              label: Text('Daftar'),
            ),
          ],
          selected: {view},
          onSelectionChanged: (v) => setState(() => view = v.first),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ActionChip(
              avatar: const Icon(Icons.select_all_rounded, size: 16),
              label: const Text('Semua', style: TextStyle(fontSize: 12)),
              onPressed: () => setState(
                () => filter
                  ..clear()
                  ..addAll(PlaceType.values),
              ),
            ),
            for (final t in PlaceType.values)
              FilterChip(
                avatar: Icon(t.icon, size: 16, color: t.color),
                label: Text(t.label, style: const TextStyle(fontSize: 12)),
                selected: filter.contains(t),
                onSelected: (v) =>
                    setState(() => v ? filter.add(t) : filter.remove(t)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (s.placesError)
          EcoCard(
            color: C.gold.withValues(alpha: .18),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: C.gold),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Data komunitas (OpenStreetMap) gagal dimuat. Coba lagi beberapa saat.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: s.refresh,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        if (view == 0) ..._map() else ..._list(),

        const Section('Tentang Fitur Ini'),
        const Explain(
          Icons.flag_rounded,
          'Apa gunanya komunitas untukmu?',
          '1) Menemukan tempat nyata terdekat yang sesuai kebutuhanmu, bukan daftar umum.\n'
              '2) Urutan rekomendasi mengikuti penyumbang emisi terbesarmu dan kualitas udara hari ini.\n'
              '3) Setelah bergabung, kamu mendapat misi singkat. Menyelesaikannya menambah Aksi Hijau di tab Karbon, jadi dampaknya terlihat di total harianmu.',
        ),
        const Explain(
          Icons.place_rounded,
          'Dari mana datanya?',
          'Tempat diambil dari OpenStreetMap (Overpass API) di sekitar posisimu, dan peta juga OpenStreetMap: gratis tanpa API key. '
              'Cakupan bergantung pada pemetaan relawan; bila daerahmu masih sedikit, kamu bisa ikut menambahkannya di openstreetmap.org. '
              'Tombol Rute hanya membuka tautan Google Maps (gratis).',
          color: C.sky,
        ),
      ],
    );
  }

  Widget _forYou(PlaceType t) {
    final m = kMissions[t]!;
    final a = actionById(m.actionId);
    final count = s.places.where((p) => p.type == t).length;
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: t.color.withValues(alpha: .15),
                child: Icon(t.icon, color: t.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Pill('$count tempat', t.color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            s.purpose(t),
            style: const TextStyle(fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Misi: ${m.title} (≈ ${a.kg.toStringAsFixed(2)} kg CO₂)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.color,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              filter
                ..clear()
                ..add(t);
              view = 0;
            }),
            icon: const Icon(Icons.map_rounded, size: 18),
            label: const Text('Lihat di peta'),
          ),
        ],
      ),
    );
  }

  List<Widget> _map() {
    final list = shown;
    final selected = list.contains(sel) ? sel : null;
    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 380,
          child: FlutterMap(
            key: ValueKey('${s.lat}_${s.lon}'),
            options: MapOptions(
              initialCenter: LatLng(s.lat, s.lon),
              initialZoom: 13.5,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.ecopulse_bmkg',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(s.lat, s.lon),
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.person_pin_circle_rounded,
                      color: Colors.pinkAccent,
                      size: 38,
                    ),
                  ),
                  for (final p in list)
                    Marker(
                      point: LatLng(p.lat, p.lon),
                      width: 38,
                      height: 38,
                      child: GestureDetector(
                        onTap: () => setState(() => sel = p),
                        child: Container(
                          decoration: BoxDecoration(
                            color: p.type.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: p == selected ? 3.5 : 1.5,
                            ),
                          ),
                          child: Icon(
                            p.type.icon,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      if (selected != null)
        _placeCard(selected)
      else
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Ketuk penanda di peta untuk melihat detail dan misinya.',
            style: TextStyle(fontSize: 11, color: C.slate),
          ),
        ),
    ];
  }

  List<Widget> _list() {
    final l = shown;
    if (l.isEmpty) {
      return [
        const EcoCard(
          child: Text('Belum ada tempat yang cocok dengan filter/lokasi ini.'),
        ),
      ];
    }
    return [for (final p in l) _placeCard(p)];
  }

  Widget _placeCard(GreenPlace p) {
    final joined = s.isJoined(p.id);
    final m = kMissions[p.type]!;
    final a = actionById(m.actionId);
    final isRec = s.recommendedTypes().take(2).contains(p.type);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: p.type.color.withValues(alpha: .15),
                child: Icon(p.type.icon, color: p.type.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${p.type.label} • ${km(p.dist)} dari kamu',
                      style: const TextStyle(fontSize: 11, color: C.slate),
                    ),
                  ],
                ),
              ),
              if (isRec) const Pill('Cocok untukmu', C.emerald),
            ],
          ),
          const SizedBox(height: 10),
          if (joined)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: C.emerald,
              value: s.done.contains(m.actionId),
              onChanged: (_) => s.toggleAction(m.actionId),
              title: Text(
                'Misi: ${m.title}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '≈ ${a.kg.toStringAsFixed(2)} kg CO₂ • tercatat di tab Karbon',
                style: const TextStyle(fontSize: 11, color: C.slate),
              ),
            )
          else
            Text(
              'Gabung untuk membuka misi: ${m.title} (≈ ${a.kg.toStringAsFixed(2)} kg CO₂).',
              style: const TextStyle(fontSize: 12, color: C.slate),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: joined ? C.slate : C.emerald,
                  ),
                  onPressed: () => s.toggleJoin(p),
                  icon: Icon(joined ? Icons.check_rounded : Icons.add_rounded),
                  label: Text(joined ? 'Diikuti' : 'Gabung'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openUrl(
                    'https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lon}',
                  ),
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Rute'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
