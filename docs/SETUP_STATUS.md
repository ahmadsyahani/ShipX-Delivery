> Status terbaru — 4 November 2026: backend/MySQL dan Flutter Android berhasil dijalankan. Catatan lama di bagian "Status fondasi" di bawah dipertahankan sebagai histori; kendala cache/MySQL lama sudah terselesaikan.

## Status terbaru: keputusan admin dan status Flutter — 4 November 2026

Konfirmasi/penolakan pending sudah tersedia pada web admin React. Penolakan wajib alasan dan melepas reservasi; konfirmasi menahan stok, expiry dan konflik versi tetap enforced. Flutter menampilkan Dikonfirmasi/Ditolak, alasan, refresh dan polling saat halaman aktif. Migration order_decisions sudah Ran. 58 tes backend / 742 assertions, suite Flutter dengan lima tes baru, analyzer, build APK/Vite, dua skenario browser dan uji race MySQL lolos. Lihat [ORDER_DECISIONS_CHECKPOINT.md](ORDER_DECISIONS_CHECKPOINT.md). `.env` dan data pengguna dipertahankan; uji HP checkpoint ini menyusul. Tahap berikut master kurir/kendaraan, penugasan trip dan pengantaran manual.

## Checkpoint sebelumnya: admin React + Inertia + shadcn/ui — 4 November 2026

Seluruh halaman admin aktif telah dimigrasikan atas persetujuan pengguna ke React + TypeScript + Inertia, memakai komponen shadcn/ui asli dan Tailwind 4. Baca [ADMIN_UI_MIGRATION.md](ADMIN_UI_MIGRATION.md) untuk struktur, cara menjalankan dan QA. 50 tes backend / 633 assertions, typecheck, build dan 2 skenario browser desktop/mobile lolos. Tidak ada perubahan .env, reset database atau perubahan source Flutter. Keputusan lama Blade tanpa React sudah digantikan; Blade kini hanya root view Inertia. Konfirmasi/dispatch admin tetap belum tersedia.

## Checkpoint sebelumnya: stok dan checkout — 4 November 2026

Baca [CHECKOUT_CHECKPOINT.md](CHECKOUT_CHECKPOINT.md) untuk fitur saat ini, bukti uji dan cara mencoba. Stok, keranjang, quote, checkout COD, reservasi, riwayat/detail dan pembatalan sudah tersedia; migration inventory/orders telah Ran. 45 tes backend / 359 assertions, 31 tes Flutter ditambah 3 tes layar checkout serta race MySQL lolos; analyzer bersih. `.env` tetap identik. Checkout Android belum terkonfirmasi selesai dan pengguna memilih tes otomatis dahulu. Konfirmasi/dispatch admin belum diimplementasikan. Status yang berbeda pada checkpoint di bawah merupakan histori.

## Checkpoint depot, alamat dan slot — 4 November 2026

- Tersedia menu admin **Depot** dan **Slot pengiriman**: lokasi dan radius depot, ongkir tetap, zona waktu, TTL pending, durasi layanan, tambah/edit/nonaktif slot dan konflik versi edit. Slot diisi dalam zona waktu depot dan disimpan UTC. Zona waktu dikunci setelah slot dibuat.
- Flutter memiliki tab **Pengiriman**: tambah/edit alamat dan penerima, pin peta atau koordinat manual, daftar alamat sendiri, soft delete dengan konfirmasi, pemilihan alamat yang masih dalam cakupan, pemilih tanggal dan slot aktif. Pilihan bertahan saat pindah tab, belum membuat pesanan/reservation. Refresh membersihkan pilihan slot dan memvalidasi cakupan ulang.
- Default depot pengguna **belum diberi koordinat, radius atau ongkir contoh**. Isi lokasi sebenarnya melalui `/admin/depot`, lalu buat slot di `/admin/slots`. Sampai konfigurasi lengkap, aplikasi menjelaskan wilayah belum siap dan server menolak penyimpanan alamat dengan 409 DELIVERY_NOT_CONFIGURED.
- Migration tambahan depot/addresses/delivery_slots berhasil dijalankan pada MySQL tanpa reset tabel/data. `.env` memiliki hash SHA-256 yang sama seperti sebelum perubahan.
- **32 test backend, 255 assertions lolos**: kepemilikan alamat, role, akun nonaktif, radius dan titik nol, metadata, partial update, soft delete idempoten, versi lama, pergeseran wilayah depot, waktu lokal vs UTC, cutoff tepat waktu, slot duplikat/nonaktif dan tanggal invalid.
- **19 test Flutter lolos**, analyzer bersih, APK debug berhasil dibangun. Delapan test baru mencakup zona waktu, depot belum siap, pilihan alamat/slot, alamat luar cakupan, data kosong, retry jaringan, form wajib dan error server yang mempertahankan isian.
- `php scripts/verify-delivery-mysql.php` **lolos**: request API melalui kernel Laravel memakai MySQL asli di dalam satu transaksi uji; settings, create/update alamat, konflik versi, radius, daftar slot pada tanggal lokal dan soft delete. Seluruh fixture/config sementara di-rollback. Ini bukan pengujian race paralel atau HTTP melalui jaringan.
- Bug saat QA diperbaiki: form alamat panjang sekarang menjaga semua kolom tetap terpasang agar validasi tidak hilang saat scroll; tanggal cutoff ditampilkan dalam zona depot; respons pagination alamat lama diabaikan setelah refresh; slot yang lewat cutoff dibersihkan berdasarkan waktu server + Stopwatch perangkat.
- Peta menggunakan flutter_map 8.3.2, latlong2 0.10.1 dan url_launcher 6.3.3. Tile OSM HTTPS dengan identitas aplikasi, cache bawaan paket, atribusi terlihat dan tanpa prefetch area. Peta dibuka ketika pengguna memilih pin; tidak meminta lokasi GPS. `MAP_TILE_URL` dapat diganti saat build. Lihat [dokumentasi tile layer](https://docs.fleaflet.dev/layers/raster-tile-layer) dan [kebijakan OSM](https://operations.osmfoundation.org/policies/tiles/). Tile online memerlukan internet dan tidak memiliki jaminan ketersediaan; koordinat manual tetap bisa diisi.
- **Batas pengujian:** alur alamat/slot lengkap telah diuji widget/API/MySQL. Penggunaan peta online dan alur lengkap di HP dengan konfigurasi depot pengguna belum dikonfirmasi, karena lokasi depot sebenarnya belum diisi. Hasil integration test katalog di HP di bagian berikut adalah checkpoint sebelumnya.

Cara mencoba: isi Depot di admin → tambah slot aktif dengan cutoff mendatang → di Flutter pilih Pengiriman → tambah alamat dalam radius → pilih alamat dan jadwal. Sambungan HP saat development tetap USB reverse port 8000. Stok, keranjang, quote dan checkout adalah tahap berikutnya.

## Verifikasi katalog di HP — 4 November 2026

Pengguna sudah membuat akun admin dan satu produk aktif, `Air Mineral`. Produk tersebut cocok dengan respons GET `/api/v1/catalog` melalui HTTP nyata. HP I2405 kembali terotorisasi setelah pengguna menyetujui dialog USB debugging; ADB reverse port 8000 aktif.

Integration test Android terbaru **lolos**: health, register customer sementara, pencarian produk sungguhan, membuka/menutup detail, `/me`, pemulihan sesi dari secure storage, logout, login ulang dan logout akhir. Pencari test diperbaiki agar membedakan teks pada kolom pencarian dari label kartu produk. Akun/token uji dibersihkan; produk pengguna tetap satu dan aktif. Data produk pengguna tidak dimodifikasi.

Untuk mencoba sendiri, buka aplikasi normal di HP dan pilih **Buat akun pelanggan**. Akun admin digunakan untuk web; katalog mobile ditujukan untuk customer. Sambungan saat ini memakai USB reverse dan base URL `http://127.0.0.1:8000/api/v1`. Verifikasi visual web lewat otomasi browser masih belum selesai.

## Pembaruan tampilan dan katalog sebelumnya — 4 November 2026

- Admin Blade + Tailwind: login, ringkasan, daftar/filter produk, tambah/edit, validasi dan status aktif/nonaktif. Root `/` mengarah ke admin. Aset Vite production berhasil dibangun; server lokal berjalan di `http://127.0.0.1:8000` saat pengujian.
- Flutter: tampilan login/register diperbarui; pelanggan mendapat tab Katalog/Akun, pencarian produk, pagination, detail, refresh, retry dan empty state. Role courier/admin tetap mendapat halaman akun sesuai scope saat ini.
- Migration katalog dijalankan tanpa reset database. Produk aktif bisa ditelusuri melalui GET `/api/v1/catalog`; belum ada stok/checkout. Depot baru identitas katalog, belum konfigurasi lokasi pengiriman.
- Backend: **21 test, 151 assertions lolos**. Flutter: **11 test lolos**, analyze bersih, build APK debug berhasil. Test mencakup penolakan SKU duplikat, metadata invalid, role tidak sah, produk nonaktif, XSS escaping, konflik edit, pagination, detail, kondisi kosong/offline, respons pencarian terlambat, serta layar 320px dengan skala teks 1,5.
- `python scripts/verify-catalog-http.py` lolos terhadap HTTP Laravel dan MySQL nyata: CSRF wajib, login admin, aset CSS/JS, create, register customer, katalog, nonaktif, konflik versi dan logout. Script membuat fixture unik dan membersihkan akun/token/produk miliknya sendiri dalam finally; hanya untuk server development lokal di port 8000.
- Bug yang diperbaiki: PATCH kini wajib membawa lock_version; retry setelah refresh gagal mengulang halaman yang benar; respons pencarian lama diabaikan; notifikasi sesi setelah widget disposed dihindari.
- `.env` tidak diubah. Akun dan produk uji tidak disimpan sebagai data bisnis.
- **Batas verifikasi terbaru:** pengguna memilih uji otomatis dahulu, HP menyusul. APK baru belum dipasang/diuji di HP pada checkpoint ini. Pratinjau browser otomatis tidak tersedia dan akses aplikasi Chrome timeout, sehingga visual web belum ditinjau langsung. Kelulusan integration test HP pada bagian auth di bawah adalah hasil checkpoint sebelumnya, bukan bukti UI katalog terbaru.

### Mencoba tampilan

Buka `http://127.0.0.1:8000/admin/login`. Gunakan akun admin sendiri; bila belum ada, dari backend jalankan `php artisan shipx:create-staff admin` dan isi password secara interaktif. Setelah login, buka Produk, tambah barang dengan metadata kemasan dan pilih status Aktif. Katalog awal memang kosong sampai produk sungguhan ditambahkan.

Untuk HP melalui USB setelah tersambung:

```powershell
adb reverse tcp:8000 tcp:8000
cd mobile
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Build APK terbaru default memakai alamat emulator `10.0.2.2`; gunakan perintah di atas agar build untuk HP memakai USB reverse. Login sebagai customer untuk melihat katalog. Fitur pemesanan baru dikerjakan setelah alamat, slot dan stok siap.

## Checkpoint auth dan Flutter–API sebelumnya

- Workspace aktual `C:/Users/Ahmad Syahani/Desktop/shipx`. Tidak ditemukan AGENTS.md pada project/ancestor yang diperiksa. Tidak ada metadata Git di root/backend/mobile, sehingga tidak tersedia diff terhadap commit. Source, platform Android dan lockfile lokal dipertahankan.
- `.env` tidak dibaca untuk ditampilkan dan tidak diubah; SHA-256 sebelum/sesudah sama. Tidak menjalankan setup ulang, key:generate, migrate:fresh atau reset DB.
- Backend awal: 3 test lolos, 3 migration bawaan sudah Ran. Backend akhir: 14 test/84 assertions lolos (lihat output aktual jika test bertambah). Dua migration tambahan users identity dan personal_access_tokens dijalankan pada MySQL, semuanya Ran.
- Laravel tetap 13.40.0; hanya dependensi Sanctum v4.3.3 ditambahkan melalui Composer, lockfile diperbarui.
- Flutter analyze: No issues found. Lima test unit/widget lolos. `flutter build apk --debug` berhasil.
- Dart HTTP client nyata berhasil memeriksa health Laravel di `127.0.0.1:8000` melalui `dart run tool/check_api.dart`.
- HP Android I2405 terotorisasi lewat ADB. Integration test di perangkat berhasil: health, register customer ke MySQL, `/me`, pemulihan token dari Android secure storage setelah instance aplikasi dibuat ulang, logout, login ulang dan logout akhir. Akun smoke sementara telah dihapus setelah dipastikan tanpa token aktif.
- Flutter memakai flutter_secure_storage 11.2.0; backup Android dinonaktifkan. HTTP hanya debug; build produksi memerlukan HTTPS.
- Backend security test mencakup hash/password, expiry 30 hari, token invalid, pencabutan token saat ini (token perangkat lain tetap berlaku), normalisasi email, validasi password, register tidak bisa memilih role/is_active, rate limit, akun nonaktif, akses customer/courier ke admin, pemisahan session admin dari bearer mobile, login/logout session dan CSRF.
- Modul katalog, alamat, slot, order, stok, trip dan optimasi masih belum dibuat. Beranda tiap role dan halaman admin baru fondasi autentikasi.

## Menjalankan ulang melalui USB

Backend yang sudah berjalan tidak perlu dijalankan ulang. Sambungkan HP dan otorisasi USB debugging, lalu:

```powershell
adb devices -l
adb reverse tcp:8000 tcp:8000
cd mobile
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Alamat loopback ini bekerja karena ADB reverse; perlu diatur ulang setelah USB terputus. Alternatif tetap emulator `10.0.2.2` atau IP LAN laptop. Default API_BASE_URL source tetap untuk emulator.

Pengujian ulang:

```powershell
# dari backend
php artisan test
php artisan migrate:status
# dari mobile
flutter analyze
flutter test test
dart run tool/check_api.dart
flutter test integration_test/auth_flow_test.dart -d <device-id> --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1 --dart-define=SMOKE_EMAIL=<email-unik@example.test>
```

Integration test membuat akun customer sementara di database backend yang dituju. Gunakan email baru yang khusus pengujian dan database development; akun uji dapat dibersihkan setelah selesai. Test berakhir dengan logout. `flutter test test` menjalankan unit/widget saja tanpa membutuhkan HP/API. Hasil integration test tidak membuktikan koneksi lewat Wi-Fi atau locking/konkurensi MySQL untuk fitur stok yang belum ada.

Untuk akun staf: dari backend jalankan `php artisan shipx:create-staff admin` atau `courier`, isi data/password secara interaktif. Tidak ada staf/kredensial bawaan yang otomatis ditambahkan. Admin web di `/admin/login` memakai session+CSRF; semua rute `/admin` terlindungi admin aktif.

Implementasi mengikuti [dokumentasi Sanctum Laravel 13](https://laravel.com/framework/docs/13.x/sanctum) dan [konfigurasi flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage).

# Status fondasi — 4 November 2026

## Berhasil

- Kerangka Laravel v13.0.0 dibuat; composer.lock mengunci framework v13.40.0 dan dependensi hasil resolusi.
- PHP lokal 8.5.2; ekstensi pdo_mysql, curl, mbstring, openssl, fileinfo, zip tersedia.
- Paket Composer terunduh/diekstrak dan autoload berhasil dibuat menggunakan dump-autoload tanpa optimasi. Proses install awal dihentikan setelah terlalu lama pada optimized autoload; post-install/package discovery belum berhasil dijalankan.
- npm install berhasil, package-lock.json tersedia; npm run build berhasil (Vite 7.3.7, aset Tailwind/JS dihasilkan).
- routes/api.php dan bootstrap/app.php lolos pemeriksaan sintaks PHP.
- Script initialize-mobile.ps1 lolos parser PowerShell.
- Source Flutter dibuat dan Dart formatter memproses empat file; pemeriksaan format ulang menunjukkan tidak ada perubahan. Formatter tetap exit 1 karena telemetry di profil pengguna tidak dapat ditulis. Ini bukan kelulusan flutter analyze.
- Kontrak API fase pertama, PRD, ERD, README, script pembentukan Android, serta test health/widget disiapkan.

## Kendala aktual

| Pemeriksaan | Hasil |
| --- | --- |
| MySQL 127.0.0.1:3306 | Koneksi ditolak; database belum dibuat dan tidak ada migration dijalankan |
| Laravel boot/key:generate/package:discover/test/route:list | Terhalang: PHP is_writable pada backend/bootstrap/cache bernilai false. Runtime meminta direktori writable. APP_KEY belum dihasilkan |
| Flutter CLI | Terhalang izin cache lockfile di C:/Android/flutter/bin/cache |
| Flutter analyze/test/build APK | Belum dijalankan; paket dan platform Android belum digenerate |
| Mobile → API end-to-end | Belum terverifikasi |

Folder Laravel ada, tetapi pengecekan is_writable oleh PHP gagal dalam lingkungan eksekusi ini. Tidak mengubah kode vendor atau permission global untuk melewati pemeriksaan tersebut. Jalankan setup dari terminal pengguna yang mempunyai akses tulis ke folder project dan SDK. Jika tetap gagal, perbaiki izin folder terkait melalui pengaturan lokal; jangan menganggap menjalankan sebagai administrator selalu diperlukan.

## Langkah lokal berikutnya

1. Buka folder shipx di VS Code. Aktifkan MySQL dari Laragon dan siapkan database shipx beserta kredensial development.
2. Di backend: composer install; pastikan .env ada tanpa menimpa konfigurasi sendiri; php artisan key:generate; php artisan package:discover; php artisan test --filter=ApiHealthTest; php artisan route:list --path=api.
3. Atur DB_USERNAME/DB_PASSWORD pada .env lokal. Health tidak memerlukan database; migration domain belum dibuat.
4. Jalankan php artisan serve dan kunjungi /api/v1/health. Untuk HP fisik gunakan binding/IP LAN sesuai README.
5. Jalankan scripts/initialize-mobile.ps1, lalu flutter analyze, flutter test, dan flutter run sesuai README. Script membuat platform Android tanpa --overwrite; source aplikasi dan test sudah disediakan.

Tidak ada autentikasi, endpoint pemesanan, dashboard admin terproteksi, algoritma rute, atau migration domain yang diklaim selesai. Fase berikutnya adalah implementasi autentikasi dan role setelah fondasi dapat dieksekusi.

## Reproduksibilitas

Arsip source berisi lockfile Composer/npm, bukan vendor/node_modules, kredensial .env, cache, atau hasil build. Flutter belum mempunyai pubspec.lock karena pub get belum dijalankan; setelah dependency resolution pertama berhasil, commit lockfile Flutter. APP_KEY dibuat per lingkungan, bukan dibundel.
