#!/usr/bin/env bash
# EcoPulse BMKG - setup otomatis untuk macOS / Linux
# Cara pakai (di dalam folder ini):  bash setup.sh
# Hasil: folder "ecopulse_app" (proyek Flutter lengkap) dibuat di sebelah folder ini.
set -e

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter belum terpasang. Pasang dulu: https://docs.flutter.dev/get-started/install"
  exit 1
fi

SRC="$(cd "$(dirname "$0")" && pwd)"
OUT="$(dirname "$SRC")/ecopulse_app"

echo "[1/4] Membuat proyek Flutter (Android, iOS, Web)..."
flutter create --platforms=android,ios,web --project-name ecopulse_bmkg --org id.ecopulse "$OUT"

echo "[2/4] Menyalin kode EcoPulse..."
rm -rf "$OUT/lib" "$OUT/test"
cp -R "$SRC/lib" "$OUT/lib"
cp "$SRC/pubspec.yaml" "$OUT/pubspec.yaml"

echo "[3/4] Menambahkan izin internet & lokasi..."
MANIFEST="$OUT/android/app/src/main/AndroidManifest.xml"
if ! grep -q "ACCESS_FINE_LOCATION" "$MANIFEST"; then
  perl -0pi -e 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\n    <application#' "$MANIFEST"
fi
perl -pi -e 's#android:label="[^"]*"#android:label="EcoPulse BMKG"#' "$MANIFEST"

PLIST="$OUT/ios/Runner/Info.plist"
if ! grep -q "NSLocationWhenInUseUsageDescription" "$PLIST"; then
  perl -0pi -e 's#</dict>\s*</plist>#<key>NSLocationWhenInUseUsageDescription</key>\n\t<string>Lokasi dipakai untuk cuaca, kualitas udara, dan komunitas hijau terdekat.</string>\n</dict>\n</plist>#' "$PLIST"
fi

perl -pi -e 's#ecopulse_bmkg#EcoPulse BMKG#g' "$OUT/web/index.html"

echo "[4/4] Mengunduh paket (flutter pub get)..."
(cd "$OUT" && flutter pub get)

echo ""
echo "SELESAI. Proyek ada di: $OUT"
echo "Jalankan:  cd \"$OUT\" && flutter run -d chrome"
