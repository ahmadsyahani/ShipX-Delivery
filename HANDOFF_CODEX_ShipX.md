# Handoff ShipX untuk Codex

## Lokasi perangkat dan label item — 7 November 2026

Baca [LOCATION_AND_SIMPLE_LABELS_CHECKPOINT.md](docs/LOCATION_AND_SIMPLE_LABELS_CHECKPOINT.md). Pengguna memilih semua barang tampil sebagai item. Form alamat Flutter memakai GPS/peta tanpa input koordinat; geolocator14.1.2 dan izin foreground coarse/fine ditambahkan. Depot web memakai Leaflet1.9.4/pin/lokasi browser. Tidak ada pengambilan lokasi otomatis atau pelacakan background. Jadwal tidak menampilkan IANA; semua konversi zona depot tetap utuh. Ukuran teknis hilang dari layar utama, admin memakai detail kg/cm dan kapasitas kendaraan hasil ukuran ruang, lalu mengirim satuan API lama. Data bisnis, riwayat unit_label, .env dan kontrak tidak ditulis ulang. 66 tes Flutter dan analyzer lolos, build web/APK berhasil. HP sudah tidak terdeteksi saat APK siap; pemasangan GPS dan izin aktual menyusul.

## Seluruh tampilan mobile — 7 November 2026

APK akhir berhasil dipasang dan dibuka di HP I2405 dengan adb install -r, tanpa clear data; reverse port8000 aktif. Pengguna dapat meninjau tampilan pada aplikasi. Interaksi manual HP/kamera belum dikonfirmasi.

Baca [MOBILE_PAGES_CHECKPOINT.md](docs/MOBILE_PAGES_CHECKPOINT.md). Pengiriman, Keranjang, Akun (widget baru), pesanan/detail, form alamat, kurir/muatan/hasil, login dan cek koneksi diselaraskan dengan menu. Panel/intro/judul/jumlah pembayaran bersama tersedia. Pengiriman dapat menavigasi ke keranjang setelah memilih alamat/slot. Semua aturan API, checkout, fingerprint/idempotency, polling dan retry dipertahankan. 61 tes Flutter lolos, analyzer bersih; preview 320px/1.5x, 390px dan 820px meliputi checkout/dialog, alamat dan nomor pesanan panjang. Tidak mengubah backend/web admin/.env/data bisnis.

## Menu mobile kategori vertikal — 7 November 2026

Verifikasi: 61 tes Flutter, analyzer bersih, 92 backend/1450 assertions. APK debug dipasang dan dijalankan di HP I2405; pemetaan USB port8000 aktif. Preview widget test tersedia. Screenshot HP dilewati karena ShipX sudah bukan aplikasi foreground; interaksi manual kategori di HP belum dikonfirmasi. .env identik.

Pengguna menyetujui web admin, lalu meminta katalog mobile bergaya menu pemesanan TOMORO. Baca [MOBILE_MENU_CHECKPOINT.md](docs/MOBILE_MENU_CHECKPOINT.md). Header pencarian ringkas, rail kategori vertikal dan daftar produk bergulir terpisah, ilustrasi kemasan generik, quick-add dan bar keranjang. API katalog menambahkan categories lengkap dan filter category sebelum pagination; tidak ada migration/data bisnis/.env berubah. Font/palet sebelumnya dipakai; hero katalog navy besar telah diganti. Web admin tidak didesain ulang. USB HP menggunakan adb reverse8000 dan API_BASE_URL localhost, bukan default emulator.

## Checkpoint UI web dan Flutter — 7 November 2026

Baca [UI_REFRESH_CHECKPOINT.md](docs/UI_REFRESH_CHECKPOINT.md). Pengguna memilih perapian kedua UI. Plus Jakarta Sans dibundel lokal beserta OFL, tema teal/navy disatukan, dashboard/sidebar/login admin serta header/katalog/navigasi Flutter dirapikan. Heading ID panjang web, nama kendaraan/spesifikasi produk Flutter dan baris pemilih jadwal diperbaiki agar membungkus pada layar kecil. Perubahan ini hanya tampilan; checkpoint domain tetap hasil pengiriman di bawah. Tidak mengubah .env/setup/data bisnis. HP belum terdeteksi; verifikasi otomatis dan preview lokal tersedia.

## Checkpoint terbaru hasil pengiriman, foto dan COD

Verifikasi akhir checkpoint ini mencakup 91 tes backend / 1432 assertions, 53 tes Flutter dan 6 skenario browser. Uji race MySQL hasil lolos, migration 000009 Ran, dan 0 database QA serta 0 hasil/unggahan uji tertinggal di database bisnis. Foto server QA dibersihkan. Foto draft perangkat memakai nama unik dan cleanup sebelum submit, sementara permintaan belum pasti tetap disimpan untuk retry.

Baca [DELIVERY_RESULTS_CHECKPOINT.md](docs/DELIVERY_RESULTS_CHECKPOINT.md). Migration 000009 sudah Ran. Kurir mencatat hasil sesuai urutan, delivered seluruh order dengan foto privat dan COD tepat tagihan, atau failed beralasan/COD nol. Ledger trip keluar hanya untuk delivered, failed mempertahankan muatan. Hasil/proof/COD/version atomik dan idempotent. Semua tujuan selesai menjadi awaiting_reconciliation, claims tetap ditahan. Customer/admin dapat melihat hasil dan foto sesuai akses. Foto JPEG/PNG maksimal2MiB, staging24jam dan cleanup harian tersedia. Tema UI mobile pengguna dipakai. Tes Flutter53, browser6, analyzer/TypeScript/build/APK dan race MySQL hasil lolos. APK sempat tertahan cache Gradle, build ulang berhasil. .env utuh, perubahan masih lokal develop. Selanjutnya rekonsiliasi barang/uang dan penutupan trip. Uji kamera/foto HP fisik menyusul saat perangkat tersambung. Pernyataan hasil/COD belum tersedia di checkpoint lama merupakan histori.

## Checkpoint terbaru: konfirmasi muatan dan start trip — 5 November 2026

Baca [TRIP_DEPARTURES_CHECKPOINT.md](docs/TRIP_DEPARTURES_CHECKPOINT.md). Pengguna memilih estimasi waktu jalan manual dengan sumber + tinjauan admin untuk tahap ini, sehingga provider belum wajib. Admin mengisi semua ruas termasuk pulang, sumber, catatan dan penanganan; sistem menghitung tunggu/jendela/layanan. Review berlaku 24 jam, terikat versi dan diulang setelah replan. Flutter kurir menghitung semua SKU dan start dengan durable idempotency. Start menghitung ulang jadwal aktual, transfer ledger depot→trip, consume reservasi, orders out_for_delivery dan trip in_progress atomik; claims tetap ditahan, cancel/reopen sesudah start ditolak. Migration 000008 sudah Ran tanpa reset/.env berubah. 85 backend/1364 assertions, 48 Flutter, 6 browser, analyzer/build/APK dan race MySQL lolos. Perubahan lokal develop belum commit/push. HP tidak terdeteksi; APK belum dipasang. Berikutnya hasil delivered/failed, bukti, COD dan rekonsiliasi; tidak ada endpoint penyelesaian trip saat ini. Status “start belum tersedia” di checkpoint sebelumnya merupakan histori.

## Checkpoint terbaru: penugasan trip manual

Baca [MANUAL_TRIPS_CHECKPOINT.md](docs/MANUAL_TRIPS_CHECKPOINT.md). Admin dapat membuat/edit draft dan urutan manual, menetapkan, membuka ulang dan membatalkan sebelum berangkat. Validasi kapasitas dua dimensi, confirmed satu gelombang, versi/departure/reservasi dan claims pesanan/kurir/kendaraan atomik. Courier Flutter mempunyai tab Trip/Akun dan API assigned trip sendiri. Customer assigned tidak dapat cancel; reopen mengembalikan confirmed. Stok fisik belum dipindahkan. Migration 000007 sudah Ran, `.env` utuh, perubahan masih lokal develop bersama checkpoint armada. 77 tes backend/1187 assertions, 43 tes Flutter, 5 skenario browser, analyzer, TypeScript/build, APK dan race MySQL lolos. HP tidak terdeteksi; trip belum diuji langsung. Rute manual not_evaluated/ETA null. Berikutnya muatan/start, hasil/COD/rekonsiliasi dan kelayakan perjalanan. Jangan mengulang setup atau menganggap dispatch/optimasi aktif.

## Checkpoint terbaru: master kurir/kendaraan dan checkout HP lolos

Baca [FLEET_MASTERS_CHECKPOINT.md](docs/FLEET_MASTERS_CHECKPOINT.md). Menu admin Kurir/Kendaraan sudah tersedia (tambah/edit/filter/aktif/nonaktif, kapasitas dan konflik versi). Migration 000006 telah Ran; perubahan lokal pada develop, belum commit/push. Kata sandi/email/nonaktif kurir mencabut token. 67 tes backend / 1002 assertions, TypeScript/build, analyzer dan empat skenario browser lolos. Uji HP I2405 terisolasi kini **lolos** dari checkout multi-SKU sampai konfirmasi, pembatalan, penolakan/alasan dan login kurir; akun/pending asli tidak disentuh. Bug respons checkout lock_version null diperbaiki menjadi 0. QA database bersih dan reverse QA dilepas. .env tetap identik. Selanjutnya trip manual; dispatch/delivery/COD/rekonsiliasi belum tersedia. Status lama uji checkout HP belum selesai sudah digantikan.

## Checkpoint terbaru: keputusan admin dan status Flutter

Baca [ORDER_DECISIONS_CHECKPOINT.md](docs/ORDER_DECISIONS_CHECKPOINT.md). Admin kini dapat confirm/reject pending dengan dialog, alasan wajib untuk penolakan, lock_version dan idempotency; hanya admin web aktif + CSRF. Konfirmasi mempertahankan reservasi, penolakan menjadi rejected dan melepas sekali; deadline dicek sesudah lock. Migration order_decisions telah Ran tanpa reset/.env berubah. Flutter menampilkan status/alasan, refresh manual dan polling foreground 15 detik. 58 tes backend / 742 assertions, tes Flutter status, analyzer, build APK/Vite, dua skenario browser dan race MySQL keputusan lolos. Tidak ada QA DB tertinggal. APK belum dipasang ke HP. Selanjutnya master kurir/kendaraan dan trip manual; penugasan/delivery/COD/rekonsiliasi belum tersedia. Pernyataan admin baca-saja atau konfirmasi belum tersedia di checkpoint lama adalah histori.

## Checkpoint terbaru: admin React + Inertia + shadcn/ui asli

Pengguna menyetujui migrasi framework web. Baca [ADMIN_UI_MIGRATION.md](docs/ADMIN_UI_MIGRATION.md) terlebih dahulu. Semua halaman admin aktif sekarang React + TypeScript melalui Inertia, komponen shadcn asli diambil dari CLI resmi; Blade hanya root view Inertia. 50 tes backend / 633 assertions, TypeScript, build Vite dan 2 skenario browser desktop/mobile lolos. API Flutter, aturan domain dan .env dipertahankan; tidak ada migration/reset. Konflik versi, CSRF, role, mutasi stok berulang dan lock_version depot telah diverifikasi. Konfirmasi/dispatch pesanan tetap belum tersedia. Status dan keputusan Blade tanpa React di bagian historis di bawah sudah digantikan.

## Checkpoint terbaru: stok dan checkout, 4 November 2026

Baca [checkpoint stok/checkout](docs/CHECKOUT_CHECKPOINT.md) terlebih dahulu. Stok admin, keranjang Flutter, quote, checkout COD atomik, reservasi, riwayat dan pembatalan sudah diimplementasikan. Migration inventory/orders sudah Ran. Verifikasi ulang: 45 tes backend / 359 assertions, 31 tes Flutter + 3 tes layar checkout, analyzer dan race MySQL lolos; `.env` tetap identik. Uji checkout HP belum selesai terkonfirmasi dan pengguna memilih tes otomatis dahulu. Konfirmasi/dispatch admin belum tersedia. Catatan di bawah yang menyebut stok/order belum tersedia merupakan histori.

## Pembaruan terkini — depot, alamat dan slot, 4 November 2026

Fitur tahap ini tersedia: admin mengatur `/admin/depot` dan CRUD tanpa hapus `/admin/slots`; Flutter customer mempunyai tab Pengiriman untuk alamat/penerima, pin OSM atau koordinat manual, edit/nonaktif alamat, pilihan alamat dan slot menurut tanggal lokal depot. Endpoint customer baru: GET delivery-settings, GET delivery-slots, GET/POST addresses, PATCH/DELETE addresses/{id}. Semua auth/role enforced server, ID alamat user lain 404, radius dihitung Haversine, update/delete alamat memakai lock_version, dan slot disaring tepat cutoff.

Migration `2026_11_04_000003_create_delivery_settings_addresses_slots` telah Ran di MySQL. Tidak mengubah `.env`, akun atau produk pengguna. Depot sebenarnya belum dikonfigurasi: pengguna perlu mengisi lokasi/radius/ongkir di menu Depot sebelum alamat/slot bisa dipakai; jangan memasang koordinat contoh sebagai data bisnis. Waktu slot dari zona depot dikonversi UTC, service_date tetap lokal, timezone dikunci setelah slot pertama dibuat.

QA: 32 test backend/255 assertions, 19 test Flutter, analyzer bersih, APK debug berhasil. Script `php scripts/verify-delivery-mysql.php` memakai request API-kernel pada MySQL asli dalam transaksi yang di-rollback, lolos tanpa menyimpan fixture. Form panjang diperbaiki agar semua kolom tervalidasi, termasuk setelah scroll. Pemilihan alamat/slot hanya state layar, bertahan antar-tab, belum reservation/order. Uji lengkap dengan lokasi depot asli dan tile online di HP masih perlu konfirmasi pengguna. Lihat docs/SETUP_STATUS.md dan API_PHASE_1.md untuk kontrak/batasan.

Lanjut berikutnya: selesaikan uji pengguna setelah depot dan slot diisi, lalu fondasi ledger stok → keranjang → quote/checkout atomik. Domain stok/order belum diimplementasikan pada checkpoint ini.

## Verifikasi terbaru — katalog di HP, 4 November 2026

Pengguna telah membuat admin dan satu produk aktif `Air Mineral`. Katalog API sesuai dengan database. Integration test terbaru di HP I2405 sudah **lolos**: koneksi health, register sementara, pencarian produk pengguna, buka/tutup detail, validasi/pemulihan sesi, logout dan login ulang. Selector test dibedakan antara EditableText pencarian dan Text label produk. Akun/token uji dibersihkan; produk pengguna tidak dimodifikasi. ADB reverse 8000 aktif, API_BASE_URL pada build HP memakai `http://127.0.0.1:8000/api/v1`.

Status bagian berikut yang menyebut uji katalog HP tertunda adalah histori; checkpoint tersebut sudah selesai. Browser/web belum diverifikasi visual melalui otomasi. Pengguna dapat mendaftar akun customer sendiri lewat aplikasi; jangan memakai admin untuk menguji katalog customer. Langkah pengembangan berikut tetap konfigurasi depot, alamat/slot dan stok sebelum checkout.

## Pembaruan terakhir — tampilan admin dan katalog, 4 November 2026

Admin Laravel sekarang memiliki tampilan login, ringkasan, daftar/filter produk, tambah/edit dan kontrol aktif/nonaktif dengan Blade+Tailwind. Flutter memiliki tampilan auth baru serta tab Katalog/Akun untuk customer, pencarian, pagination, detail, refresh, retry dan kondisi kosong. Endpoint katalog bearer khusus customer aktif sudah tersedia. Courier/admin tetap hanya halaman akun pada mobile.

Migration `2026_11_04_000002_create_catalog_tables` sudah Ran di MySQL. Depot utama hanya identitas katalog; konfigurasi lokasi/cakupan/ongkir menyusul sebelum checkout. Produk menyimpan harga, satuan, berat, dimensi, volume hitungan server, status dan lock_version. SKU unik per depot. PUT/PATCH menolak edit versi lama. Produk nonaktif disaring API. Stok, keranjang, checkout dan pengantaran belum tersedia.

Verifikasi terbaru: 21 test backend (151 assertions), 11 test Flutter, analyze bersih, aset Vite dan APK debug berhasil. Uji HTTP+MySQL via `scripts/verify-catalog-http.py` lolos dari admin create hingga katalog/nonaktif/konflik versi; fixture dibersihkan. `.env` tetap utuh. Pengguna memilih uji otomatis dahulu karena HP belum tersambung. **UI katalog terbaru belum diuji langsung di HP; preview Chrome juga belum terverifikasi karena akses UI timeout.** Hasil integration test Android pada checkpoint auth berikut ini tetap merupakan histori.

Server saat pengujian: `http://127.0.0.1:8000`; admin login di `/admin/login`. Akun admin dibuat interaktif dengan command staf yang sudah ada, tanpa password bawaan. Detail cara mencoba dan batasan di docs/SETUP_STATUS.md. Lanjutkan pengecekan UI pada HP/browser ketika tersedia, kemudian konfigurasi depot, alamat/slot dan fondasi stok sebelum checkout.

## Pembaruan terbaru — 4 November 2026, checkpoint auth selesai

Bagian ini mengoreksi status historis pada bagian bawah handoff. Workspace aktual: `C:/Users/Ahmad Syahani/Desktop/shipx`; tidak ditemukan AGENTS.md yang berlaku maupun metadata Git, sehingga diff commit tidak tersedia. `.env` dipertahankan dengan hash identik.

- Backend/MySQL sudah terverifikasi; migration tambahan phone/role/is_active serta Sanctum personal_access_tokens sudah Ran. Laravel tetap versi terkunci 13.40.0; Sanctum 4.3.3 ditambahkan.
- Register customer, login, me dan logout token sekarang tersedia sesuai API_PHASE_1. Token 30 hari, role/aktivasi ditetapkan server, validasi/rate limit tersedia. Akun nonaktif ditolak pada login dan akses terlindungi. Public register tidak membuat courier/admin.
- Admin Blade: `/admin/login`, `/admin`, `/admin/logout`, session+CSRF dan middleware admin aktif. Halaman baru fondasi akses, belum modul bisnis. Buat akun admin/courier secara interaktif melalui `php artisan shipx:create-staff admin` atau `courier`; tidak ada akun bawaan.
- Flutter: login/register, secure token storage, validasi/pemulihan sesi, logout, beranda sesuai role dan akses halaman cek koneksi. Modul customer/courier masih placeholder yang menyatakan fitur belum tersedia.
- Flutter analyze bersih, 5 test unit/widget lolos, build APK debug berhasil. Integration test di HP Android I2405 melalui USB berhasil membuktikan health → register → me → restore secure token → logout → login → logout dengan Laravel/MySQL. Akun smoke dibersihkan setelah pengujian.
- Koneksi HP memakai `adb reverse tcp:8000 tcp:8000` dan `--dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1`; perlu USB/ADB reverse tetap aktif. Source tetap default emulator 10.0.2.2. Bukan bukti koneksi Wi-Fi.
- Detail bukti, cara run/test dan batasan ada di docs/SETUP_STATUS.md. Tahap berikutnya: master SKU → alamat/slot → quote/checkout/reservation multi-SKU; jangan mengulang setup/auth yang sudah berhasil.

Catatan status di bawah yang menyebut Flutter/auth belum dibuat adalah riwayat sebelum pembaruan ini.

## Tujuan dan cara kerja

Lanjutkan project ShipX dari source lokal pengguna. Baca dokumen dan source aktual sebelum mengubahnya. Jangan mengulang setup yang sudah berhasil. Bekerja bertahap dengan checkpoint yang bisa diuji. Pengguna memakai Windows, Laragon, VS Code dan PowerShell, dengan gaya komunikasi santai bahasa Indonesia. Pengguna ingin proyek cukup dalam secara teknis tetapi menghindari kompleksitas yang tidak dibutuhkan.

Jangan menganggap chat ini otomatis tersedia di sesi Codex baru. File ini adalah ringkasan keputusan dan progres; source lokal serta hasil pemeriksaan terbaru menjadi acuan implementasi.

## Keputusan yang disetujui

- Nama: ShipX, sebelumnya AntarGalon. Layanan tidak dibatasi ke galon; mendukung berbagai barang.
- Mobile: Flutter + Dart, target awal Android; satu aplikasi dengan tampilan customer/courier sesuai role.
- Backend: Laravel REST API; autentikasi direncanakan Laravel Sanctum.
- Web: admin Laravel + React + Inertia + TypeScript + Tailwind CSS + shadcn/ui asli (keputusan pengguna terbaru, 4 November 2026). Blade hanya menjadi root view Inertia.
- Database: MySQL; nama database lokal shipx.
- Source fondasi memakai skeleton Laravel 13.0.0; composer.lock pada saat dibuat mengunci framework 13.40.0. Periksa composer.lock aktual; jangan downgrade/upgrade tanpa kebutuhan. PHP yang terdeteksi saat setup 8.5.2.
- Tidak perlu microservices, repository generik, atau Redis untuk fondasi. Laravel queue/scheduler dengan driver database cukup ketika dibutuhkan.

## Lingkup produk aktif v0.2

Default rancangan sementara adalah katalog multi-produk milik satu operator dengan satu pusat pemenuhan/depot. Semua barang diambil dari depot sebelum perjalanan, lalu diantar ke beberapa pelanggan, dan kurir kembali ke depot.

Pengguna telah meminta dukungan barang lain dan nama ShipX. Pengguna BELUM secara eksplisit memilih model jasa pickup paket bebas dari alamat banyak pengirim. Jangan menambahkan model pickup-delivery marketplace secara diam-diam. Jika konteks implementasi menuntut perubahan model ini, jelaskan konsekuensinya dan kumpulkan keputusan terlebih dahulu.

- Customer: login, alamat + pin, keranjang multi-SKU, slot pengiriman, checkout, status dan pembatalan.
- Admin: produk, stok, pesanan, kendaraan/kurir, perencanaan rute, penugasan, rekonsiliasi.
- Courier: perjalanan sendiri, daftar tujuan, navigasi ke tujuan berikutnya, hasil pengiriman, foto bukti dan COD.
- Order dapat berisi beberapa SKU; kuantitas bilangan bulat dan satu unit jual dasar per SKU.
- Snapshot harga, nama/unit produk, berat/volume/dimensi, alamat dan jendela disimpan pada order.
- Kapasitas kendaraan divalidasi dengan total berat gram DAN volume kemasan cm³, bukan jumlah galon.
- Penjumlahan volume tidak menjamin barang secara geometris muat; admin meninjau bentuk/penanganan.
- Penukaran wadah 1:1 tidak berlaku pada alur umum. Deposit/wadah tukar/refill adalah fitur khusus di luar MVP generik, bukan fitur yang tetap diasumsikan berjalan.
- Pembayaran COD tunai seluruh tagihan; ongkir tetap per order pada MVP.
- Delivered seluruh order atau failed seluruh order. Tidak ada partial delivery.
- Jadwal per gelombang; tidak menyisipkan pesanan setelah kurir berangkat.
- Satu kendaraan/kurir per trip; belum mengoptimalkan pembagian banyak kendaraan sekaligus.
- Live tracking, payment gateway, multi-depot, langganan dan prediksi kebutuhan belum termasuk MVP.

## Optimasi rute

Fitur unggulan: menyusun urutan pengantaran berdasarkan estimasi waktu perjalanan jalan raya, kapasitas, jendela layanan dan durasi layanan. Navigasi ruas berikutnya dapat dibuka melalui Google Maps.

Rancangan awal: provider matriks waktu/jarak (kandidat Google Routes API), lalu algoritma sendiri nearest neighbor + 2-opt dalam Laravel. Integrasi provider belum dibuat; periksa dukungan mode kendaraan, tarif, kuota dan ketentuan penyimpanan data sebelum implementasi.

Bandingkan baseline urutan order masuk dengan kandidat menggunakan input/matriks sama. Periksa jendela layanan, waktu tunggu dan perjalanan pulang. Matriks bisa asimetris; hitung ulang biaya arah tiap ruas. Jika kandidat lebih buruk dan baseline layak, gunakan baseline. Jika tidak ditemukan solusi layak, tampilkan konflik; heuristik tidak membuktikan optimum global atau infeasibility matematis.

## Dokumen dan struktur

Folder project: shipx, lokasi absolut pada mesin pengguna belum dikonfirmasi. Pernah disarankan C:/laragon/www/shipx; jangan menganggap lokasi itu pasti benar. Mulai dari cwd Codex dan cari AGENTS.md yang berlaku.

- backend/: Laravel, routes/api.php, routes/web.php, resources, tests.
- mobile/: source Flutter, lib/core/api_config.dart, lib/core/health_api.dart, lib/main.dart, test/widget_test.dart.
- scripts/initialize-mobile.ps1: generate platform Android bila belum ada, set INTERNET permission dan debug-only cleartext, lalu flutter pub get.
- docs/PRD_ShipX.md: PRD aktif v0.2.
- docs/ERD_ShipX.md: ERD aktif v0.2.
- docs/API_PHASE_1.md: kontrak fase 1 aktif v0.2; membedakan rencana dan endpoint tersedia.
- docs/SETUP_STATUS.md: hasil pemeriksaan historis saat otomatisasi awal; progres pengguna di bawah lebih baru.
- docs/history/: rancangan khusus galon lama. Jangan mengimplementasikan domain galon dari folder ini sebagai aturan ShipX.

## Status terakhir yang telah dikonfirmasi pengguna

1. Pengguna mengikuti setup backend dan mengatakan berhasil tanpa error. Langkah checkpoint tersebut: composer install, .env, key:generate, health test dan membuka endpoint health. Verifikasi ulang secukupnya dari project aktual, jangan menganggap semua detail hasil sudah diamati asisten.
2. Pengguna mengikuti setup MySQL database shipx, konfigurasi .env, config:clear, migrate, migrate:status dan mengatakan semuanya berjalan baik.
3. Instruksi terakhir diberikan untuk koneksi Flutter: initialize-mobile.ps1, flutter analyze/test/devices, kemudian flutter run. Pengguna BELUM mengonfirmasi hasil langkah Flutter; ini checkpoint berikutnya.
4. Login, role, endpoint order, dashboard admin, migration domain, stok dan algoritma routing BELUM diimplementasikan oleh asisten dalam source fondasi yang diserahkan.
5. Migration yang telah dijalankan pengguna adalah migration bawaan Laravel; jangan menganggap seluruh ERD sudah menjadi tabel.

Saat setup otomatis awal, MySQL tidak aktif dan PHP/Flutter terhalang izin cache. Pengguna kemudian berhasil menjalankan backend/MySQL dari terminal lokal. Jangan menyajikan kendala backend lama sebagai masalah yang masih pasti terjadi. Cache Flutter masih perlu dibuktikan dari hasil lokal.

## Endpoint yang sudah dibuat

GET /api/v1/health, publik, tanpa kebutuhan database:

```json
{"data":{"service":"shipx-api","status":"ok","api_version":"v1"}}
```

Test backend: tests/Feature/ApiHealthTest.php. Flutter memeriksa kontrak health yang sama lewat tombol Periksa koneksi. Ini belum login atau bukti koneksi DB.

Default API_BASE_URL Flutter: http://10.0.2.2:8000/api/v1 untuk Android Emulator standar. HP fisik menggunakan IP LAN laptop pada jaringan yang sama. localhost pada HP bukan laptop. Gunakan --dart-define=API_BASE_URL=...; HTTP hanya debug, produksi HTTPS.

## Urutan kerja berikutnya

1. Baca AGENTS.md, dokumen aktif dan source aktual; periksa git status serta perubahan pengguna. Jangan menimpa .env, kredensial atau pekerjaan pengguna.
2. Pastikan baseline backend tetap lolos, cek migration status tanpa migrate:fresh. Verifikasi Flutter analyze/test dan koneksi HP/emulator ke /health. Pilih perangkat yang tersedia; jangan mengklaim APK berhasil sebelum build/run sungguh lulus.
3. Jika baseline siap, implementasi autentikasi: Sanctum, register customer, login, me, logout token; role customer/courier/admin dan is_active di server. Akun admin/kurir tidak dapat dibuat lewat register publik.
4. Web admin memakai session, CSRF dan middleware/policy admin, bukan bearer token yang ditanam di Blade.
5. Buat layar login/register Flutter serta secure token storage dan navigasi role. Uji token invalid/logout, role escalation dan akun nonaktif. Jangan hanya menyembunyikan menu.
6. Berikutnya master SKU → alamat/slot → quote/checkout/reservation multi-SKU → web antrean order → operasi pengiriman manual → optimasi.

## Invariant penting

- Harga dan total berat/volume dihitung server, tidak dipercaya dari client.
- Satu checkout multi-SKU atomik: jika stok satu item gagal, semuanya rollback.
- Reservation terpisah dari saldo fisik; seluruh account terkait dikunci dalam urutan konsisten.
- Jangan mengedit saldo tanpa ledger. Stock state aktif tersedia/karantina, bukan full/empty versi galon.
- Satu order/kurir/kendaraan tidak boleh punya dua alokasi aktif; ERD menggunakan tabel claims/locks dengan PK unik.
- Hasil delivery, item results, ledger dan COD ditulis satu transaksi dan aman dari request berulang.
- Rekonsiliasi stok per SKU/kondisi, bukan total campuran satuan semua barang; selisih butuh alasan/persetujuan.
- Token/password/foto privat tidak boleh masuk log atau endpoint publik.
- Uji locking/konkurensi memakai MySQL; SQLite tidak membuktikan perilaku locking MySQL.

## Berkas transfer

ShipX_Foundation.zip terakhir: https://chatgpt.com/library?file_id=libfile_555eaa0880808191b80e97f04086c85a&account_id=personal

Arsip tidak menyertakan .env, vendor, node_modules atau hasil build. Jika project lokal sudah disiapkan dan diubah pengguna, gunakan project tersebut; jangan ekstrak ulang di atasnya. Lockfile Flutter mungkin baru tersedia setelah pub get lokal; pertahankan file aktual.
