import 'package:flutter/material.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

void showSettings(BuildContext context, AppState s) {
  final ctl = TextEditingController(text: s.adm4);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(ctx).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lokasi & Sumber Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Lokasi saat ini: ${s.displayPlace}',
              style: const TextStyle(color: C.slate, fontSize: 12),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: C.emerald,
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                s.useGps();
              },
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Gunakan GPS'),
            ),
            const SizedBox(height: 14),
            const Text(
              'Atau pilih kota',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in kCities)
                  ActionChip(
                    label: Text(c.name),
                    onPressed: () {
                      Navigator.pop(ctx);
                      s.selectCity(c);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Kode wilayah BMKG (adm4)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: ctl,
              decoration: InputDecoration(
                hintText: 'contoh: 31.71.03.1001',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kode adm4 (kelurahan/desa, format Kemendagri) dipakai untuk prakiraan cuaca resmi BMKG. '
              'Kosongkan bila tidak diketahui: aplikasi otomatis memakai Open-Meteo.',
              style: TextStyle(fontSize: 11, color: C.slate),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () {
                      Navigator.pop(ctx);
                      s.setAdm4(ctl.text);
                    },
                    child: const Text('Terapkan kode BMKG'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => openUrl('https://api.bmkg.go.id'),
                  child: const Text('Info API BMKG'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
