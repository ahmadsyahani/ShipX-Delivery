# Admin React + Inertia + shadcn/ui — 4 November 2026

Pembaruan setelah migrasi UI: admin sekarang bisa mengonfirmasi dan menolak pending. Lihat [ORDER_DECISIONS_CHECKPOINT.md](ORDER_DECISIONS_CHECKPOINT.md). Status baca-saja dan hasil tes pada dokumen ini adalah catatan checkpoint migrasi; hasil terbaru 58 tes backend / 742 assertions serta uji browser keputusan sudah lolos.

Pengguna menyetujui penggantian Blade admin menjadi React + Inertia dengan shadcn/ui asli. Keputusan ini menggantikan catatan sebelumnya yang menetapkan Blade tanpa React. Flutter tetap memakai API Sanctum yang sama.

## Implementasi

- React 19 + TypeScript, Inertia Laravel 2.0.28 dan adapter React 2.3.29, Tailwind CSS 4. Versi lengkap terkunci di composer.lock/package-lock.json; Laravel tetap 13.40.0.
- Komponen asli diambil dengan CLI resmi `shadcn@4.23.0 add`, style `new-york`: Button, Card, Input, Label, Badge, Table, Textarea, Separator, Sheet, DropdownMenu, Alert, Skeleton, NativeSelect, Switch. Source ada di `backend/resources/js/components/ui`; konfigurasi di components.json. Ini bukan tiruan komponen Blade.
- Root view Inertia hanya `resources/views/app.blade.php`; entry Vite `resources/js/app.tsx`. Halaman ada di `resources/js/pages/Admin`, layout sidebar/topbar responsif di `resources/js/layouts/admin-layout.tsx`. Template Blade admin lama sudah dihapus.
- Seluruh halaman aktif dipindahkan: login, ringkasan, produk/list/form, depot, slot/list/form, stok/list/mutasi/ledger, pesanan/list/detail, konflik versi, dan error navigasi.
- Tema ShipX terang dengan aksen teal, ikon Lucide, sidebar desktop, Sheet untuk navigasi mobile, dropdown akun, tabel dengan scroll horizontal dan pagination, empty state, filter, pesan berhasil serta error per isian.
- Dashboard memakai hitungan database sebenarnya dan pesanan terbaru; tidak ada statistik, produk atau pesanan bisnis contoh.

Autentikasi tetap session web + CSRF + role admin aktif. Identitas yang dibagikan ke React hanya id/name/email/role, tanpa hash password atau token. Login/logout membersihkan history Inertia, halaman admin memakai `Cache-Control: no-store, private`. Endpoint API tetap JSON dan tidak memakai middleware Inertia web. Error web melalui navigasi Inertia dirender sebagai halaman React; status HTTP tetap dipertahankan.

Form memakai `useForm` dan validasi Laravel. Konflik edit tetap 409, lalu pengguna memuat data terbaru. Mutasi stok tetap beralasan, transaksional dan idempoten. Setelah mutasi berhasil pada halaman yang sama, form mengadopsi key baru dari server; setelah depot disimpan, form mengadopsi lock_version baru. Ini mencegah mutasi berikutnya dianggap replay atau penyimpanan kedua dianggap versi lama. Waktu slot diedit dalam zona depot, bukan zona browser; nomor pesanan panjang dapat terbungkus pada layar sempit.

Tidak ada migration baru, reset database, penggantian .env, penggantian akun admin, maupun perubahan source Flutter untuk migrasi UI ini. Hash .env tetap `DBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C`.

## Menjalankan

Untuk workspace saat ini, aset production sudah dibangun. Aktifkan MySQL/Laragon dan server lokal, lalu buka `http://127.0.0.1:8000/admin/login` dengan akun admin yang sudah ada. Refresh penuh bila browser masih menampilkan aset lama.

Untuk checkout baru atau pemasangan dependensi sesuai lockfile:

```powershell
cd backend
composer install
npm.cmd ci
npm.cmd run build
php artisan serve --host=127.0.0.1 --port=8000
```

Untuk mengerjakan UI dengan hot reload, jalankan `npm.cmd run dev` di terminal backend lain. Scheduler `php artisan schedule:work` tetap diperlukan untuk expiry tiap menit. Jangan menjalankan ulang setup, key:generate, menyalin .env.example, atau migrate:fresh pada workspace yang sudah tersetup.

## Bukti uji

- `php artisan test`: **50 tes / 633 assertions lolos**. Termasuk regresi auth, katalog, delivery, checkout dan lima tes Inertia untuk props aman, navigasi JSON, asset version, validasi, logout/history, error web serta kontrak API.
- `npm.cmd run typecheck` dan `npm.cmd run build` lolos; pemeriksaan dependensi npm tidak menemukan vulnerability saat pemasangan akhir.
- `npm.cmd run test:e2e`: **2 skenario Chrome headless lolos**, desktop 1440×1000 dan mobile 390×844. Login gagal/berhasil, input tetap terisi saat validasi gagal, navigasi SPA tanpa reload dokumen, tambah/edit produk, konflik dua tab, dua mutasi stok berurutan (3 lalu 2 menghasilkan 5), dua simpan depot, form waktu slot, order melalui API customer, detail order di admin, refresh langsung, logout, guard halaman serta menu mobile. Tidak ada error runtime JavaScript pada skenario desktop.
- Screenshot dashboard desktop, stok, detail order dan produk mobile ditinjau. Pemeriksaan tambahan nomor pesanan panjang di mobile dilakukan setelah penyesuaian wrapping.
- Seluruh uji browser memakai database QA sementara di port 8001. Guard `X-ShipX-QA: isolated-checkout` wajib cocok sebelum test mengirim mutasi. Router QA juga mensyaratkan env khusus dan nama database QA yang valid. Akun admin fixture hanya dibuat pada database tersebut.
- Source Flutter tidak diubah pada migrasi ini; hasil 34 tes Flutter pada checkpoint sebelumnya tetap merupakan bukti tahap checkout, bukan tes ulang sesi migrasi web.

Untuk mengulang tes browser, jalankan dari root:

```powershell
php scripts/serve-checkout-qa.php
```

Di terminal kedua:

```powershell
cd backend
npm.cmd run test:e2e
```

Tes memakai Chrome yang sudah terpasang. Setelah selesai, dari root di terminal kedua jalankan:

```powershell
php scripts/serve-checkout-qa.php stop
```

Tunggu pesan `Isolated UI QA database removed.` pada server QA. Jangan hentikan paksa parent/terminal sebelum cleanup. Hasil screenshot/trace berada di backend/test-results dan diabaikan Git. Skrip lama `verify-catalog-http.py` yang membaca form Blade telah diganti pesan petunjuk agar tidak membuat fixture pada database utama.

## Batas fitur

Perubahan ini memigrasikan tampilan admin dan memperbaiki state formulir. Pesanan admin tetap baca saja; konfirmasi, dispatch, pengantaran dan pembayaran selesai belum diimplementasikan. Checkout Flutter di HP masih perlu konfirmasi pada checkpoint terpisah. Build Vite memberi peringatan bundle utama sekitar 613 kB (sekitar 203 kB gzip); halaman lain sudah dimuat sebagai chunk terpisah. SSR tidak diaktifkan sehingga Node hanya diperlukan untuk build/dev UI, bukan service SSR tambahan.
