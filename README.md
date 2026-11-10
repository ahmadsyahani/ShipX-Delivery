# ShipX

**ShipX adalah aplikasi pemesanan dan pengantaran barang dari satu depot ke banyak pelanggan, dengan rencana rute pengiriman yang dioptimalkan.**

Pelanggan memesan beberapa barang lewat HP, admin mengelola stok dan menyusun trip, lalu kurir mengantar barang dan mencatat hasilnya. Seluruh pesanan dibayar tunai di tempat (COD).

> Model MVP saat ini adalah katalog barang milik **satu operator** yang diambil dari **satu depot**. Layanan kirim paket bebas dari banyak pengirim belum termasuk dan perlu keputusan produk tersendiri.

## Isi

- [Cara kerja singkat](#cara-kerja-singkat)
- [Siapa memakai apa](#siapa-memakai-apa)
- [Teknologi](#teknologi)
- [Struktur proyek](#struktur-proyek)
- [Status pengembangan](#status-pengembangan)
- [Menjalankan backend](#menjalankan-backend)
- [Menjalankan aplikasi Flutter](#menjalankan-aplikasi-flutter)
- [Akun staf dan web admin](#akun-staf-dan-web-admin)
- [Pengujian](#pengujian)
- [Dokumentasi](#dokumentasi)

## Cara kerja singkat

1. **Pelanggan** login, menyimpan alamat, memilih slot, lalu menyusun keranjang berisi beberapa barang. Harga dan total berat/volume dihitung oleh server.
2. **Pelanggan** checkout dengan COD. Stok langsung dicadangkan (reservation).
3. **Admin** mengonfirmasi atau menolak pesanan. Pesanan pending yang lewat batas waktu (awal 30 menit) dibatalkan otomatis.
4. **Admin** memilih pesanan, kendaraan, dan kurir untuk membuat trip, dengan batas kapasitas berat dan volume kendaraan.
5. **Kurir** memeriksa muatan, memulai trip, lalu mengantar sesuai urutan dan mencatat hasil serta foto bukti.
6. **Admin** merekonsiliasi barang yang kembali dan uang COD, lalu menutup trip.

Status pesanan: `pending` → `confirmed` → `assigned` → `out_for_delivery` → `delivered` / `failed`.

## Siapa memakai apa

| Peran | Platform | Yang bisa dilakukan |
| --- | --- | --- |
| Customer | Flutter Android | Kelola alamat, pesan barang, pantau status, batalkan sebelum penugasan |
| Courier | Flutter Android | Lihat trip sendiri, konfirmasi muatan, catat hasil dan COD |
| Admin | Web | Kelola produk, stok, pesanan, kendaraan, kurir, trip, dan rekonsiliasi |

## Teknologi

- **Mobile:** Flutter (Android)
- **Backend:** Laravel, REST API dengan Sanctum
- **Admin web:** React + Inertia + TypeScript + shadcn/ui + Tailwind CSS
- **Database:** MySQL

## Struktur proyek

| Folder | Isi |
| --- | --- |
| `backend/` | Laravel. API di `routes/api.php`, web di `routes/web.php`. Aturan bisnis lintas channel ada di service/action yang sama. |
| `backend/resources/js/` | UI admin: halaman di `pages/Admin`, layout di `layouts`, komponen di `components` (shadcn di `components/ui`). Blade hanya sebagai root Inertia. |
| `mobile/` | Aplikasi Flutter untuk customer dan kurir. |
| `docs/` | PRD, ERD, kontrak API, dan catatan checkpoint. |
| `scripts/` | Skrip penyelesaian scaffolding Android lokal. |

## Status pengembangan

Checkpoint terakhir 10 November 2026.

Sudah tersedia:

- [x] Autentikasi, katalog, depot, alamat, dan slot pengiriman
- [x] Stok dengan alasan perubahan, plus checkout COD
- [x] Keputusan admin (konfirmasi/tolak pesanan)
- [x] Master kurir dan kendaraan
- [x] Penugasan trip manual (urutan tujuan, kapasitas, penguncian eksklusif)
- [x] Konfirmasi muatan dan start trip
- [x] Hasil pengiriman berhasil/gagal, foto bukti privat, dan COD
- [x] Rekonsiliasi barang kembali dan uang, serta penutupan trip
- [x] Foto produk pada admin dan Flutter, dropdown kategori, serta SKU otomatis
- [x] Perapian katalog, keranjang, pengiriman, akun, dan tampilan kurir Flutter

Berikutnya:

- [ ] Rute dan ETA, lalu optimasi urutan pengiriman
- [ ] Pilot

Catatan: untuk saat ini kelayakan waktu jalan memakai durasi ruas yang diisi manual oleh admin, bukan routing provider atau lalu lintas langsung.

Rincian tiap tahap ada di dokumen checkpoint:

| Tahap | Dokumen |
| --- | --- |
| Rekonsiliasi dan penutupan trip | [RECONCILIATION_CHECKPOINT](docs/RECONCILIATION_CHECKPOINT.md) |
| Katalog dan checkout mobile | [MOBILE_STOREFRONT_CHECKPOINT](docs/MOBILE_STOREFRONT_CHECKPOINT.md) |
| Foto produk, kategori dan SKU | [API_PHASE_1](docs/API_PHASE_1.md) |
| Hasil kiriman, foto, COD | [DELIVERY_RESULTS_CHECKPOINT](docs/DELIVERY_RESULTS_CHECKPOINT.md) |
| Konfirmasi muatan dan start trip | [TRIP_DEPARTURES_CHECKPOINT](docs/TRIP_DEPARTURES_CHECKPOINT.md) |
| Penugasan trip manual | [MANUAL_TRIPS_CHECKPOINT](docs/MANUAL_TRIPS_CHECKPOINT.md) |
| Master armada | [FLEET_MASTERS_CHECKPOINT](docs/FLEET_MASTERS_CHECKPOINT.md) |
| Keputusan admin | [ORDER_DECISIONS_CHECKPOINT](docs/ORDER_DECISIONS_CHECKPOINT.md) |
| Status setup | [SETUP_STATUS](docs/SETUP_STATUS.md) |

## Menjalankan backend

**Kebutuhan:** PHP 8.5.2, Composer, Node.js (untuk Vite/Tailwind), MySQL (misalnya lewat Laragon).

```powershell
cd backend
composer install
Copy-Item .env.example .env
php artisan key:generate
npm.cmd ci
npm.cmd run build
php artisan serve --host=127.0.0.1 --port=8000
```

Cek server berjalan: `GET http://127.0.0.1:8000/api/v1/health` (tidak memerlukan MySQL).

Menyiapkan database:

1. Aktifkan MySQL, lalu buat database kosong bernama `shipx`.
2. Isi `DB_USERNAME` dan `DB_PASSWORD` di `.env`.
3. Jalankan `php artisan migrate`.

**Perhatian:**

- `Copy-Item .env.example .env` dan `key:generate` hanya untuk checkout baru. Jangan menimpa `.env` yang sudah dikonfigurasi.
- Jangan menjalankan `migrate:fresh` pada database yang sudah berisi data.
- Jangan menaruh password asli di `.env.example`.
- Untuk HP fisik, jalankan server dengan `--host=0.0.0.0` hanya di jaringan lokal tepercaya, lalu pakai IP LAN laptop. Jangan membuka server development ke internet.

## Menjalankan aplikasi Flutter

Flutter SDK harus bisa ditulis oleh terminal kamu. Jalankan dari PowerShell biasa jika SDK tidak bisa diakses oleh lingkungan otomatis.

```powershell
.\scripts\initialize-mobile.ps1
cd mobile
flutter analyze
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Alamat API tergantung perangkat:

| Perangkat | Alamat |
| --- | --- |
| Android Emulator | `10.0.2.2` |
| HP fisik | IP LAN laptop (satu jaringan). `localhost` di HP menunjuk ke HP itu sendiri, bukan laptop |

Catatan:

- HTTP cleartext hanya diizinkan di manifest debug. Produksi wajib HTTPS, dan mode `--profile`/release juga butuh backend HTTPS yang dipercaya perangkat.
- Sebelum distribusi nyata, ganti application ID sementara `com.example.shipx` dan siapkan signing sendiri. Jangan commit keystore atau API secret.

## Akun staf dan web admin

Buat akun hanya jika belum punya (jalankan dari folder `backend`):

```powershell
php artisan shipx:create-staff admin
php artisan shipx:create-staff courier
```

Isi identitas dan password (minimal 12 karakter) secara interaktif.

Admin masuk di `http://127.0.0.1:8000/admin/login`, lalu bisa membuka Produk, Stok, Pesanan, dan menu operasional lainnya. Catat stok awal lewat `/admin/stock` (saldo awal produk nol).

Jalankan scheduler di terminal backend terpisah agar pesanan pending kedaluwarsa tiap menit:

```powershell
php artisan schedule:work
```

## Pengujian

Dari folder `backend`:

```powershell
php artisan test
php artisan route:list --path=api
npm.cmd run typecheck
```

Dari folder `mobile`:

```powershell
flutter test
```

Dari root proyek (tes MySQL terisolasi):

```powershell
php scripts/verify-checkout-mysql.php
php scripts/verify-order-decisions-mysql.php
```

Tes di HP fisik: `mobile/integration_test/checkout_flow_test.dart` mencakup checkout, keputusan admin, pembatalan, dan login kurir dengan database QA terpisah. Setelah selesai, kembalikan aplikasi ke API utama. Panduan QA browser ada di `docs/ADMIN_UI_MIGRATION.md`.

## Dokumentasi

Acuan aktif ada di tiga dokumen berikut:

- [PRD_ShipX](docs/PRD_ShipX.md): tujuan, lingkup, dan alur bisnis
- [ERD_ShipX](docs/ERD_ShipX.md): rancangan database
- [API_PHASE_1](docs/API_PHASE_1.md): kontrak API fase pertama

Folder `docs/history` menyimpan rancangan lama khusus galon. Isinya hanya riwayat, bukan aturan implementasi.
