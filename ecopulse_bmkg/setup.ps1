# EcoPulse BMKG - setup otomatis untuk Windows (PowerShell)
# Cara pakai (di dalam folder ini):
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
# Hasil: folder "ecopulse_app" (proyek Flutter lengkap) dibuat di sebelah folder ini.

$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host 'Flutter belum terpasang. Pasang dulu: https://docs.flutter.dev/get-started/install' -ForegroundColor Red
  exit 1
}

$src = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path (Split-Path -Parent $src) 'ecopulse_app'
$utf8 = New-Object System.Text.UTF8Encoding $false

Write-Host '[1/4] Membuat proyek Flutter (Android, iOS, Web)...' -ForegroundColor Green
flutter create --platforms=android,ios,web --project-name ecopulse_bmkg --org id.ecopulse "$out"

Write-Host '[2/4] Menyalin kode EcoPulse...' -ForegroundColor Green
Remove-Item (Join-Path $out 'lib') -Recurse -Force
Copy-Item (Join-Path $src 'lib') (Join-Path $out 'lib') -Recurse
Copy-Item (Join-Path $src 'pubspec.yaml') (Join-Path $out 'pubspec.yaml') -Force
Remove-Item (Join-Path $out 'test') -Recurse -Force -ErrorAction SilentlyContinue

Write-Host '[3/4] Menambahkan izin internet & lokasi...' -ForegroundColor Green
# Android
$manifest = Join-Path $out 'android\app\src\main\AndroidManifest.xml'
$m = Get-Content $manifest -Raw
if ($m -notmatch 'ACCESS_FINE_LOCATION') {
  $perm = '<uses-permission android:name="android.permission.INTERNET"/>' + "`n    " +
          '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>' + "`n    " +
          '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>' + "`n    " +
          '<application'
  $m = $m -replace '<application', $perm
}
$m = $m -replace 'android:label="[^"]*"', 'android:label="EcoPulse BMKG"'
[System.IO.File]::WriteAllText($manifest, $m, $utf8)

# iOS
$plist = Join-Path $out 'ios\Runner\Info.plist'
$p = Get-Content $plist -Raw
if ($p -notmatch 'NSLocationWhenInUseUsageDescription') {
  $add = '<key>NSLocationWhenInUseUsageDescription</key>' + "`n`t" +
         '<string>Lokasi dipakai untuk cuaca, kualitas udara, dan komunitas hijau terdekat.</string>' + "`n" +
         '</dict>' + "`n" + '</plist>'
  $p = $p -replace '</dict>\s*</plist>', $add
}
[System.IO.File]::WriteAllText($plist, $p, $utf8)

# Web (judul halaman)
$index = Join-Path $out 'web\index.html'
$h = Get-Content $index -Raw
$h = $h -replace 'ecopulse_bmkg', 'EcoPulse BMKG'
[System.IO.File]::WriteAllText($index, $h, $utf8)

Write-Host '[4/4] Mengunduh paket (flutter pub get)...' -ForegroundColor Green
Push-Location $out
flutter pub get
Pop-Location

Write-Host ''
Write-Host 'SELESAI. Proyek ada di: ' $out -ForegroundColor Cyan
Write-Host 'Jalankan:  cd "' $out '"  lalu  flutter run -d chrome' -ForegroundColor Cyan
