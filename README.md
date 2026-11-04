# ShipX

Fondasi pemesanan dan pengantaran berbagai barang dari satu pusat pemenuhan: Flutter Android (customer/courier), Laravel API, React + Inertia + shadcn/ui + Tailwind CSS (admin), MySQL.

## Struktur

- `backend/`: Laravel; API di routes/api.php, web di routes/web.php. Controller/Request/Resource dibuat per fitur saat dibutuhkan; aturan lintas channel ditempatkan di service/action yang sama. Tidak memakai microservice atau repository generik pada fondasi.
- UI admin: `backend/resources/js/pages/Admin`, layout dan komponen React di `resources/js/layouts` dan `resources/js/components`; komponen shadcn asli ada di `components/ui`. Blade hanya root Inertia.
- `mobile/`: source Flutter awal; core konfigurasi/API, selanjutnya features/auth, addresses, orders, courier ditambahkan ketika fiturnya dikerjakan.
- `docs/`: PRD, ERD, kontrak API fase pertama, dan catatan setup.
- `scripts/`: penyelesaian scaffolding Android lokal.

## Status

Checkpoint terbaru: admin dapat mengonfirmasi/menolak pending dengan alasan, pencatatan keputusan dan reservasi stok yang konsisten. Flutter menampilkan status/alasan serta refresh manual dan pembaruan foreground. Migration order_decisions sudah Ran; 58 tes backend / 742 assertions, tes Flutter terbaru, browser desktop/mobile dan race keputusan MySQL lolos. Rincian: [keputusan admin](docs/ORDER_DECISIONS_CHECKPOINT.md). Pernyataan konfirmasi masih menyusul pada catatan checkpoint sebelumnya telah digantikan.

Autentikasi, katalog, depot, alamat/slot, stok, checkout COD serta keputusan admin tersedia. Admin React + Inertia mengelola stok beralasan dan mengonfirmasi/menolak pending; customer Flutter mempunyai keranjang, quote server, checkout, riwayat/detail, status terbaru dan pembatalan sebelum penugasan. Master kurir/kendaraan, penugasan trip dan pengantaran adalah tahap berikutnya. Catat stok nyata melalui `/admin/stock`; saldo awal produk nol. Detail terbaru: [keputusan admin](docs/ORDER_DECISIONS_CHECKPOINT.md), [migrasi shadcn](docs/ADMIN_UI_MIGRATION.md), [status setup](docs/SETUP_STATUS.md).

## Menjalankan backend

PHP 8.5.2 lokal; Laravel framework terkunci melalui composer.lock. Node untuk Vite/Tailwind. Dependensi tidak dibundel dalam arsip.

```powershell
cd backend
composer install
Copy-Item .env.example .env
php artisan key:generate
npm.cmd ci
npm.cmd run build
php artisan serve --host=127.0.0.1 --port=8000
```

Jangan menimpa .env yang sudah dikonfigurasi; Copy-Item hanya pada checkout baru. Untuk HP fisik, jalankan server development pada `--host=0.0.0.0` hanya di jaringan lokal tepercaya, lalu gunakan IP LAN laptop. Jangan expose server development ke internet.

`GET http://127.0.0.1:8000/api/v1/health` tidak memerlukan MySQL. Konfigurasi file session/cache memungkinkan pengecekan fondasi sebelum database siap. Aktifkan MySQL lewat Laragon, buat database kosong `shipx` dengan akun development yang sesuai, dan isi DB_USERNAME/DB_PASSWORD di .env. Jangan menaruh password nyata di .env.example.

Migration identitas user dan personal_access_tokens Sanctum sudah tersedia. Pada checkout yang sudah tersetup cukup `composer install` lalu `php artisan migrate`; jangan mengulang key:generate atau menimpa `.env`. Migration domain lain dibuat bertahap. Jangan jalankan migrate:fresh terhadap database yang sudah berisi data.

## Menjalankan Flutter

Flutter SDK harus writable oleh terminal pengguna. Jalankan dari PowerShell biasa jika SDK tidak bisa diakses oleh lingkungan otomatis.

```powershell
.\scripts\initialize-mobile.ps1
cd mobile
flutter analyze
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

10.0.2.2 adalah alamat host untuk Android Emulator standar. HP fisik memakai IP LAN laptop; keduanya harus satu jaringan. URL `localhost` di HP menunjuk HP, bukan laptop. Internet permission disiapkan script. HTTP cleartext hanya di manifest debug; produksi harus HTTPS. Jika memakai opsi --profile/release, backend harus memakai HTTPS yang dipercaya perangkat.

Sebelum distribusi nyata, ganti application ID sementara com.example.shipx dan siapkan signing sendiri. Jangan commit keystore atau API secret.

## Verifikasi

```powershell
cd backend
php artisan test
php artisan route:list --path=api
```

Checkpoint keputusan: 58 tes backend (742 assertions), suite Flutter dengan lima tes status baru, analyzer, TypeScript, build Vite/APK dan 2 skenario browser desktop/mobile lolos. Dari backend jalankan `npm.cmd run typecheck`; panduan browser QA ada di docs/ADMIN_UI_MIGRATION.md. Jalankan `flutter test` dari mobile. Tes MySQL terisolasi dari root: `php scripts/verify-checkout-mysql.php` dan `php scripts/verify-order-decisions-mysql.php`. Integration test HP auth/katalog sebelumnya lolos; checkout dan keputusan admin di HP belum selesai terkonfirmasi.

## Akun staf dan web admin

Jalankan `php artisan shipx:create-staff admin` atau `php artisan shipx:create-staff courier` dari backend hanya jika belum memiliki akun. Isi identitas dan password minimal 12 karakter secara interaktif. Admin masuk di `http://127.0.0.1:8000/admin/login`, lalu buka Produk, Stok atau Pesanan. Pesanan saat ini baca saja. Jalankan `php artisan schedule:work` pada terminal backend terpisah untuk expiry pending tiap menit; endpoint katalog/quote/order/stok juga membersihkan pending kedaluwarsa.

## Perubahan lingkup v0.2

Acuan aktif adalah docs/PRD_ShipX.md, docs/ERD_ShipX.md, dan docs/API_PHASE_1.md. Dokumen history menyimpan rancangan lama khusus galon, bukan aturan implementasi. Model MVP sementara tetap katalog barang satu operator/depot; layanan pickup paket bebas dari banyak pengirim perlu keputusan produk tersendiri. Database lokal baru bernama shipx; tidak ada database lama yang diganti atau dihapus.
