# Checkpoint stok dan checkout — 4 November 2026

Checkpoint terbaru sesudah dokumen ini: [konfirmasi/penolakan admin dan status Flutter](ORDER_DECISIONS_CHECKPOINT.md). Status baca-saja admin pada batas tahap lama di bawah sudah digantikan.

Pembaruan sesudah checkpoint ini: web admin sudah memakai React + Inertia + shadcn/ui asli; lihat [ADMIN_UI_MIGRATION.md](ADMIN_UI_MIGRATION.md). Aturan stok/checkout dan API Flutter tetap sama. Angka tes di bawah merupakan bukti checkpoint sebelumnya; hasil migrasi web terbaru 50 tes backend / 633 assertions dan uji browser desktop/mobile.

Status ini menggantikan catatan checkpoint delivery/katalog sebelumnya. Migration `2026_11_04_000004_create_inventory_and_orders` sudah Ran di MySQL utama tanpa reset data. `.env` tetap identik: SHA-256 `DBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C`.

## Fitur tersedia

- Admin `/admin/stock`: saldo fisik, reservasi, tersedia untuk dijual, karantina, mutasi beralasan dan ledger per SKU. Produk baru/existing dimulai dari nol sampai pengguna mencatat stok nyata; tidak ada stok contoh pada database bisnis.
- Admin `/admin/orders`: daftar dan detail snapshot pesanan, saat ini baca saja.
- Flutter customer: keranjang, alamat/slot bersama tab Pengiriman, quote server, konfirmasi COD, checkout, riwayat/detail dan pembatalan pesanan sendiri.
- API customer: POST `/order-quotes`, POST/GET `/orders`, GET `/orders/{id}`, POST `/orders/{id}/cancel`. Rincian payload/konflik ada di API_PHASE_1.md.
- Checkout multi-SKU atomik, harga dan cakupan diperiksa ulang; reservasi tidak mengurangi stok fisik. Pembatalan/expiry melepas reservasi sekali. Saldo tidak boleh kurang dari reservasi aktif.
- UUID dan payload request disimpan aman sebelum dikirim. Timeout/restart mengulang request yang sama; kegagalan bisnis final tetap bisa direplay. Key kedaluwarsa 30 hari meminta pemeriksaan riwayat sebelum request baru. Keranjang biasa masih hanya di memori.

## Verifikasi sesi lanjutan

- Backend: **45 tes, 359 assertions lolos**, memakai SQLite pengujian terpisah.
- Flutter: **31 tes lolos**, ditambah **3 tes layar checkout lolos** (konfirmasi wajib, perubahan keranjang saat dialog menolak quote lama, stok habis menonaktifkan checkout). Analyzer bersih.
- `php scripts/verify-checkout-mysql.php` **lolos** pada database QA MySQL sementara: dua pembeli/satu unit menghasilkan satu pesanan; replay tidak duplikat, multi-SKU rollback utuh, cancel dan expiry melepas stok, saldo sesuai ledger. Database QA otomatis dihapus; database utama tidak direset.
- Migration status, jadwal expiry setiap menit dan kompilasi Blade berhasil diperiksa.
- Build aset Vite admin dan APK debug Android terbaru berhasil. APK ada di `mobile/build/app/outputs/flutter-apk/app-debug.apk`, memakai API utama port 8000 untuk sambungan USB reverse. Penghentian server QA melalui command `stop` berhasil diuji dan database QA dihapus.
- Uji Android checkout end-to-end **belum terkonfirmasi selesai**. Sesi pengujian sebelumnya terputus; selector navigasi/tab dan scroll detail diperbaiki. Pengguna memilih tes otomatis dahulu, HP menyusul. Jangan mengklaim checkout sudah lolos di HP. Tile peta online/visual web juga belum diverifikasi ulang.

## Menjalankan dan mencoba

1. Aktifkan MySQL di Laragon. Dari backend jalankan `php artisan serve --host=127.0.0.1 --port=8000`; server utama telah dijalankan kembali pada sesi ini.
2. Scheduler development `php artisan schedule:work` telah dijalankan pada sesi ini untuk expiry setiap menit; jalankan ulang dari backend setelah proses/terminal ditutup. Endpoint katalog/quote/order/stok juga membersihkan order lewat batas waktu. Tidak ada Windows service/task yang dipasang.
3. Masuk admin, isi depot sebenarnya dan slot dengan cutoff mendatang bila belum tersedia. Buka Stok, catat jumlah nyata dengan alasan. Jangan menambahkan stok fiktif untuk mencoba aplikasi utama.
4. Di Flutter customer, tambah barang → pilih alamat dan slot → Keranjang → Hitung total terbaru → konfirmasi pesanan COD. Lihat daftar/detail melalui Pesanan saya; uji pembatalan bila diperlukan.
5. APK debug untuk USB memakai `API_BASE_URL=http://127.0.0.1:8000/api/v1`; sambungkan HP, jalankan `adb reverse tcp:8000 tcp:8000`, lalu `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1`. HP belum dipasang ulang pada sesi lanjutan ini.

QA Android terisolasi: jalankan `php scripts/serve-checkout-qa.php`, reverse port 8001, lalu dari mobile `flutter test integration_test/checkout_flow_test.dart -d <device-id>`. Server membuat database QA tersendiri dan dua produk synthetic, test memakai penyimpanan memori sehingga sesi/pending asli aman. Setelah selesai, dari terminal root lain jalankan `php scripts/serve-checkout-qa.php stop` dan tunggu pesan `Isolated UI QA database removed.`; hapus reverse port 8001 saja. Jangan menghentikan server utama port 8000 atau menjalankan test ini terhadap data bisnis. Satu database fixture yang tertinggal dari sesi sebelumnya telah diperiksa identitas depot dan seluruh produknya, lalu dihapus tanpa menyentuh database utama.

## Batas tahap ini dan langkah berikut

Admin belum dapat mengonfirmasi, dispatch, atau menyelesaikan pesanan. Order dibuat pending dan kedaluwarsa menjadi cancelled. Belum ada pengantaran, pembayaran selesai, optimasi rute maupun pengurangan fisik saat serah barang. Lanjutkan uji HP, kemudian implementasi konfirmasi admin dan pengantaran manual sesuai kontrak. Penyempurnaan UI menyeluruh belum termasuk checkpoint ini.
