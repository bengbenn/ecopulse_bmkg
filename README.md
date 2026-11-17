# EcoPulse BMKG – EcoAir & Energy Sync

Aplikasi Flutter untuk **Web, Android, dan iOS** yang menghubungkan data cuaca BMKG dengan rekomendasi energi bersih dan pelacakan emisi karbon.
**100% gratis: semua data dari API terbuka, tanpa API key, tanpa akun penagihan.**

## Menjalankan aplikasi

Jalankan perintah dari folder proyek ini:
```powershell
flutter pub get
flutter run -d chrome
```
Untuk Android atau emulator, gunakan `flutter run`. GPS di web hanya bekerja lewat HTTPS atau `localhost`.

## Membagikan aplikasi tanpa biaya

| Tujuan | Cara gratis |
|---|---|
| **Web** | `flutter build web --release`, lalu seret folder `build/web` ke **netlify.com/drop**, atau pakai GitHub Pages / Firebase Hosting (paket gratis). Dapat link HTTPS. |
| **Android** | `flutter build apk --release`, kirim file `build/app/outputs/flutter-apk/app-release.apk` ke HP lalu instal. |
| **iPhone** | Buka link web di Safari → Bagikan → *Tambah ke Layar Utama* (jalan seperti aplikasi, tanpa Mac dan tanpa akun developer). Build iOS native butuh Mac + Xcode. |

GPS di web hanya bekerja lewat HTTPS atau `localhost`.

## Sumber data (semua terbuka)

| Data | Sumber | Keterangan |
|---|---|---|
| Cuaca (suhu, kelembapan, angin, awan, deskripsi) | **BMKG** `api.bmkg.go.id/publik/prakiraan-cuaca?adm4=...` | Perlu kode wilayah `adm4`; default Jakarta (Kemayoran). Di luar area itu otomatis memakai Open-Meteo. |
| Radiasi surya, angin per jam (14 hari lalu + 3 hari ke depan) | **Open-Meteo** Forecast API | Gratis non-komersial, tanpa key |
| AQI, PM2.5, PM10, NO₂, O₃, SO₂, CO, CO₂ | **Open-Meteo** Air Quality (model CAMS) | Data model grid, bukan sensor lokal |
| Peta | **OpenStreetMap** (tile) via `flutter_map` | © OpenStreetMap contributors |
| Taman, bank sampah, pembangkit surya, LSM sekitar | **OpenStreetMap** via Overpass API | Tempat nyata; cakupan tergantung pemetaan relawan |
| Nama lokasi dari GPS | **Nominatim** (OpenStreetMap) | Gratis, batas pemakaian wajar |

Cantumkan "Sumber data: BMKG, Open-Meteo, © OpenStreetMap contributors" di laporan/presentasi. Baca syarat penggunaan masing-masing layanan sebelum dipakai di luar tugas (server tile & Overpass publik tidak untuk lalu lintas besar).

## Fitur

- **Udara:** cuaca BMKG, AQI real-time, polutan vs batas WHO, prakiraan AQI 12 jam, peringatan dini, penjelasan istilah.
- **Energi:** simulasi input manual untuk kapasitas panel, baterai, tingkat isi baterai, turbin, perangkat listrik, dan skenario cuaca; hasil serta grafik diperbarui saat input berubah.
- **Karbon:** carbon offset dari Energi, emisi transportasi manual, Aksi Hijau, kalkulator jejak karbon, dan laporan komparatif 7 hari.
- **Komunitas:** rekomendasi tempat berdasarkan sumber emisi terbesarmu dan kualitas udara; bergabung membuka misi yang dihitung sebagai Aksi Hijau pada Karbon.

## Hubungan antar fitur

1. **Udara & Cuaca → Energi:** radiasi dan angin dari prakiraan menentukan produksi panel/turbin; skenario manual dapat dipakai untuk simulasi cuaca alternatif.
2. **Energi → Karbon:** perangkat menentukan kebutuhan listrik, sedangkan produksi energi bersih menentukan pemakaian energi bersih dan estimasi emisi/offset.
3. **Karbon → Komunitas:** kalkulator Karbon memilih penyumbang emisi terbesar. Komunitas menjelaskan tujuan rekomendasi (misalnya tempat surya untuk emisi listrik atau taman untuk perjalanan tanpa emisi), dengan kualitas udara sebagai pertimbangan.
4. **Komunitas → Karbon:** misi dari komunitas yang diikuti menambah Aksi Hijau setelah dicentang; dampaknya terlihat pada total Karbon.
5. **Beranda** merangkum rantai tersebut dan menyediakan tautan ke tiap fitur.

Jika bagian Karbon gagal dirender, aplikasi menampilkan pengganti yang ramah alih-alih layar merah; detail error tetap dicetak sebagai `EcoPulse error:` di Debug Console untuk pelacakan.

## Struktur kode

```
lib/
  main.dart        entry point, navigasi responsif, penanganan error widget
  pages/           beranda, udara, energi, karbon, komunitas
  theme.dart       warna & tema Dark/Light
  models.dart      model data, konstanta asumsi, preset, aksi hijau
  services.dart    BMKG, Open-Meteo, Overpass, Nominatim, GPS, DeviceController (IoT)
  state.dart       state aplikasi, simulasi baterai, carbon offset
  settings.dart    pilih lokasi (GPS/kota) & kode BMKG adm4
  widgets.dart     komponen UI bersama
  pages/           air_page, energy_page, carbon_page, community_page
```

## Catatan

- Faktor emisi (0,87 kg/kWh), tarif listrik (Rp1.445/kWh), dan profil beban rumah adalah **asumsi** di `models.dart`; sebutkan sebagai estimasi.
- Jika semua API gagal (tanpa internet), aplikasi menampilkan Mode Offline dengan data contoh.
