# Master kurir/kendaraan dan uji HP — 4 November 2026

Status lanjutan: penugasan manual kini tersedia; baca [MANUAL_TRIPS_CHECKPOINT.md](MANUAL_TRIPS_CHECKPOINT.md). Pernyataan trip belum tersedia di bawah merupakan histori checkpoint armada.

Pekerjaan dilanjutkan pada branch `develop` yang awalnya bersih. Perubahan checkpoint ini masih lokal; tidak melakukan commit, merge, atau push. `.env` dipertahankan dengan SHA-256 `DBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C`.

## Fitur tersedia

Admin React/Inertia + shadcn memiliki menu Kurir dan Kendaraan, masing-masing daftar, pencarian, filter aktif/nonaktif, pagination, tambah dan edit dengan lock_version. Tidak ada hapus permanen, akun/password bawaan untuk bisnis, atau kendaraan contoh yang ditambahkan ke database utama. Routing trip dan penugasan belum dikerjakan.

Kurir memakai tabel users, role ditetapkan server menjadi courier. Admin mengisi nama, email, telepon, kata sandi minimal 12/maksimal 1024 karakter beserta konfirmasi, dan status akun. Email dinormalisasi lowercase/trim, unik terhadap semua akun (termasuk customer/admin). Edit kata sandi kosong mempertahankan hash lama. Mengubah email/kata sandi atau menonaktifkan akun mencabut semua token Sanctum kurir di transaksi yang sama; mengaktifkan kembali tidak memulihkan token lama. Perubahan nama/telepon saja mempertahankan token. Role tidak bisa diganti lewat form, dan URL kurir tidak dapat mengedit customer/admin. Hash/password/remember_token tidak dikirim melalui props React; kata sandi tidak di-flash setelah validasi gagal.

Kendaraan menyimpan depot_id=1, code, name, plate_number, travel_mode motorcycle/car, max_load_weight_g, max_load_volume_cm3, is_active dan lock_version. Kode uppercase/trim maksimal 64 karakter, karakter A–Z/0–9/titik/underscore/hyphen. Pelat uppercase tanpa spasi/hyphen, alfanumerik 3–16 karakter setelah normalisasi. Kode dan pelat masing-masing unik per depot melalui validasi dan constraint database. Berat integer 1–1.000.000.000 gram, volume integer 1–1.000.000.000.000 cm³; batas ini batas input teknis, kapasitas aman sebenarnya ditentukan operator. Jenis motor/mobil belum menghubungkan provider rute apa pun. Kendaraan baru nonaktif secara default pada form sampai diperiksa.

Migration `2026_11_04_000006_create_fleet_masters` sudah Ran: menambahkan users.lock_version default 0 serta tabel vehicles. Tidak ada reset database. Profil kurir versi lama dan kendaraan versi lama ditolak 409 tanpa menimpa perubahan lain. Jalur pengelolaan memakai session web + CSRF + admin aktif. Belum ada API mobile untuk daftar kendaraan/kurir; mobile kurir baru login/me/logout dan beranda akun, belum daftar trip.

## Bug checkout yang ditemukan saat uji HP

POST orders sebelumnya bisa menghasilkan lock_version=null karena Eloquent belum membaca default database setelah insert, walaupun GET order sudah menunjukkan 0. CheckoutService sekarang refresh order sebelum membentuk resource pertama, sehingga respons create dan replay berikutnya menyimpan versi integer 0. Tes regresi CheckoutTest menegaskan nilai ini. Tidak mengubah response idempotency historis atau mereset order pengguna.

Skrip integrasi juga dibenahi: operasi I/O langsung memakai tester.runAsync agar tidak menunggu tanpa frame sebelum UI pertama; admin QA menggunakan cookie session dan CSRF asli dalam memori untuk confirm/reject. Ini perbaikan harness pengujian. Guard `X-ShipX-QA` dan port QA tetap wajib sebelum aksi admin sintetis; tidak ada endpoint bypass auth ditambahkan pada aplikasi.

## Verifikasi

- Backend akhir: **67 tes / 1002 assertions lolos**. Sembilan tes master mencakup hash dan kerahasiaan password, validasi/duplikasi, versi lama, revokasi token, reset password/email, role/CSRF, normalisasi pelat, kapasitas dan filter. Tes Inertia meliputi empat route master baru, dan regresi checkout memeriksa versi respons pertama.
- TypeScript, build Vite dan analyzer Flutter lolos. Source produksi Flutter tidak berubah pada checkpoint ini; skrip integration test diperluas.
- **Empat skenario browser desktop/mobile lolos**: dua skenario admin sebelumnya dan dua fleet. Kurir baru dapat login via API; nonaktif/re-aktif tidak menghidupkan kembali token; konflik tab lama ditolak; kendaraan dapat dibuat/diubah, duplikasi pelat ditolak, dan form/tabel muat pada layar sempit. Screenshot kurir dan form kendaraan mobile ditinjau.
- **Integration test di HP I2405 (10DF5G08H70004U) lolos** menggunakan QA MySQL terisolasi: register customer, katalog dua SKU, alamat lewat koordinat manual, slot, quote Rp45.000, checkout, admin confirm melalui web session+CSRF, status Dikonfirmasi di Flutter, cancel confirmed, stok kembali, order kedua ditolak admin dan alasan terlihat, stok kembali, logout, login kurir, beranda sesuai role tanpa keranjang customer, logout akhir. Ini menggantikan status historis checkout/keputusan HP belum terkonfirmasi pada checkpoint lama. Tile peta online tidak diuji pada alur ini.
- Akun/token/pending QA berada pada database dan penyimpanan memori terpisah. Server QA dihentikan lewat command stop, databasenya dibersihkan, reverse 8001 dilepas. Reverse 8000 untuk API utama dipertahankan. Build aplikasi normal ditujukan ke `http://127.0.0.1:8000/api/v1`; tidak memakai test runner/akun QA untuk penggunaan berikutnya.
- Build normal sudah dipasang dan dibuka kembali; tampilan katalog utama di HP diverifikasi, sesi pengguna tetap tersedia. Helper Flutter non-resident yang tertahan menunggu debugger ditutup setelah aplikasi aktif; proses aplikasi Android tetap berjalan. Tidak ada fixture akun/kendaraan pada database utama.

## Cara mencoba dan tahap berikut

Buka `/admin/couriers` untuk akun kurir dan `/admin/vehicles` untuk kendaraan nyata. Isi kapasitas berat barang yang aman dan volume muat efektif setelah memperhitungkan perlengkapan. Kurir menggunakan email/password tersebut untuk login di Flutter. Sesi lama yang dicabut perlu login ulang.

Jangan membuat ulang database atau menimpa .env. Untuk checkout baru setelah pull, jalankan composer install, npm ci/build sesuai lockfile dan `php artisan migrate`; jangan migrate:fresh. Uji browser memakai server `php scripts/serve-checkout-qa.php` dan `npm.cmd run test:e2e` dari backend; hentikan server QA dengan `php scripts/serve-checkout-qa.php stop` setelah selesai. Uji HP: reverse port 8001 dan `flutter test integration_test/checkout_flow_test.dart -d <device>` terhadap QA, kemudian pasang kembali build main.dart untuk port 8000. Jangan jalankan test runner terhadap data bisnis.

Tahap berikut: trip manual yang memilih confirmed orders, kurir, kendaraan, waktu berangkat dan urutan tujuan; validasi kedua kapasitas dan larangan penugasan ganda. Saat trip tersedia, perubahan master yang memengaruhi penugasan aktif harus ditinjau sesuai aturan trip. Belum ada stock load, perjalanan kurir, delivery/COD atau rekonsiliasi pada master ini.
