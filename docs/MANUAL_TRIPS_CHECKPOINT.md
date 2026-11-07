# Penugasan trip manual — 4 November 2026

**Lanjutan 5 November 2026:** [konfirmasi muatan dan start trip](TRIP_DEPARTURES_CHECKPOINT.md) sudah tersedia dengan tinjauan estimasi jalan manual yang dipilih pengguna. Batas “start/ETA manual belum tersedia” di bawah merupakan histori. Gunakan mode QA `departures` untuk seluruh browser suite terbaru, bukan hanya `trips`.

Checkpoint ini menggantikan status lama “trip belum tersedia”. Perubahan masih lokal di `develop`, bersama perubahan master armada sebelumnya; belum commit/push. Migration `2026_11_04_000007_create_manual_trips` sudah Ran di MySQL lokal tanpa reset atau seed data bisnis. `.env` dipertahankan.

## Cara mencoba

1. Pastikan depot dikonfigurasi, kurir/kendaraan aktif tersedia, dan ada pesanan **Dikonfirmasi** dengan jendela layanan mendatang.
2. Buka **Trip pengiriman → Buat trip** di admin. Pilih kurir, kendaraan, rencana keberangkatan dalam zona depot, serta 1–20 pesanan dari slot/gelombang yang sama.
3. Atur urutan memakai tombol naik/turun. Periksa berat gram, volume cm³, dimensi/penanganan dan jadwal. Simpan draft, tinjau detail, lalu **Tetapkan trip**.
4. Login Flutter sebagai kurir yang dipilih; tab **Trip** menampilkan penugasan dan detail tujuan. Customer melihat **Ditugaskan** dan tidak bisa membatalkan sendiri.
5. Sebelum berangkat, admin bisa **Buka ulang trip** atau **Batalkan trip**, dengan alasan. Orders kembali Dikonfirmasi dan armada dilepas. Pembatalan trip tidak membatalkan pesanan.

## Aturan dan transaksi

Draft belum mengunci pesanan/armada. Simpan/edit membuat route_version baru; versi sebelumnya tidak ditimpa. Penetapan memeriksa ulang versi trip/order/depot/kurir/kendaraan, status aktif, pesanan confirmed satu gelombang, departure di masa depan dan sebelum akhir jendela, kedua kapasitas kendaraan, reservasi tiap item dan kecukupan saldo depot. Master berubah mengharuskan edit/tinjau ulang draft. Perubahan product master tidak mengubah snapshot order.

Penetapan atomik membuat stops berurutan, claims unik pesanan/kurir/kendaraan dan mengubah orders confirmed → assigned. Draft lain dapat berbagi kandidat sebelum ditetapkan, tetapi penetapan yang berebut sumber daya ditolak. Master armada yang sedang ditugaskan tidak dapat diedit; buka ulang trip dahulu. Assigned customer order tidak dapat dibatalkan sampai admin melepas penugasan.

Buka ulang/batal hanya sebelum actual_departure_at dan pada status yang diizinkan. Stops lama ditandai voided dengan waktu/alasan, claims dilepas, orders kembali confirmed dengan versi baru. Buka ulang membuat route_version draft baru. Semua reservasi tetap active dan saldo/ledger fisik tidak berubah oleh aksi trip ini. Customer bisa membatalkan confirmed order kembali memakai versi terbaru.

Mutasi admin memakai session + CSRF + admin aktif, idempotency_key UUID serta lock_version untuk edit/transisi. Replay identik tidak menggandakan trip/stops/event; key dengan payload berbeda ditolak. Konflik melalui halaman Inertia dengan tautan muat data terbaru. Filter pesanan mendukung assigned; detail order menautkan trip aktif.

Mutasi memakai mutex depot yang sama dengan checkout/cancel/stock/keputusan, lalu row lock kurir/kendaraan, akun stok ID ascending jika validasi stok diperlukan, orders ID ascending, lalu trip. Pelepasan penugasan tidak mengubah stok. Tidak ada request provider/upload di dalam transaksi. Edit master memakai row lock dan pemeriksaan claim.

## Skema

Tabel baru: trips, route_versions, trip_stops, active_order_allocations, courier_trip_locks, vehicle_trip_locks, trip_events. Planned weight/volume terpisah dari loaded weight/volume (masih nol). Route menyimpan snapshot depot, armada, departure, pesanan dan urutan manual. Events append-only mencatat actor/action/reason/trip_version/waktu ISO UTC. Tidak ada endpoint hapus domain/history.

Composite FK menjaga selected route milik trip, stop milik route/trip, dan allocation terhubung ke order/trip/stop yang sesuai. UNIQUE claims menjaga satu alokasi aktif per order, kurir dan kendaraan. Constraints sudah diuji di MySQL; jangan mengganti dengan pemeriksaan UI saja.

## API dan Flutter

- `GET /api/v1/courier/trips`: bearer Sanctum untuk kurir aktif, hanya assigned trip miliknya. Tidak mengirim alamat penerima pada daftar. Maksimal satu trip aktif melalui courier lock; daftar ini bukan riwayat/pagination.
- `GET /api/v1/courier/trips/{id}`: detail assigned milik sendiri; snapshot depot/kendaraan, urutan, penerima/telepon/alamat, items/kemasan/penanganan, jendela dan tagihan COD. Kurir lain, draft, cancelled atau reopened menghasilkan 404; customer/admin bearer dan akun nonaktif ditolak 403.
- ID API string, waktu ISO UTC dan timezone depot; `feasibility_status=not_evaluated`, ETA null. Tidak mengirim customer_id atau email/versi master internal.
- Flutter kurir: tab Trip/Akun, refresh/retry dan polling 15 detik saat tab/rute terlihat dan foreground. Detail dihapus saat 404, jaringan gagal mempertahankan data terakhir dengan pesan error, 401/403 membersihkan sesi. Customer assigned tetap dipantau supaya reopen → confirmed terlihat kembali.

## Verifikasi

- **77 tes backend / 1187 assertions**, termasuk 10 skenario trip (kapasitas, snapshot, claims, versi/departure/master, reservasi, role/CSRF) lolos.
- TypeScript dan build Vite lolos. Warning bundle utama >500 kB tetap ada.
- **43 tes Flutter**, analyzer bersih dan build APK debug lolos. APK memakai `http://127.0.0.1:8000/api/v1` untuk ADB reverse.
- **5 skenario browser** seluruh admin/master/trip lolos. Trip diuji sampai pemilihan/urutan, penetapan, konflik tab lama, API kurir, reopen, edit dan cancel, termasuk viewport 390 px; screenshot diperiksa.
- `php scripts/verify-manual-trips-mysql.php` lolos: rollback/reapply migration pada QA kosong, workers paralel berebut order/kurir/kendaraan, same-key replay, reopen vs cancel, customer cancel vs assign; claims/reservasi/ledger dan composite route FK. Database dibuang otomatis.
- `php scripts/serve-checkout-qa.php trips` menyediakan fixture terpisah berheader guard; jalankan `npm.cmd run test:e2e` di backend. Admin QA trip terpisah menghindari suite melampaui 5 login/menit per akun/IP; batas produksi tidak dilonggarkan. Stop melalui `php scripts/serve-checkout-qa.php stop` agar DB sintetis dibersihkan.
- Bug waktu riwayat tanpa offset UTC dan label tombol draft yang keliru tampak sedang menyimpan saat pilihan belum lengkap telah diperbaiki.

HP tidak terdeteksi ADB pada checkpoint ini. APK terbaru belum dipasang; trip belum diuji pada perangkat fisik. Uji checkout HP pada checkpoint sebelumnya tetap merupakan bukti versi sebelumnya. `.env` SHA-256 tetap `DBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C`.

Server QA sudah dihentikan, fixture dibersihkan, dan pemeriksaan akhir menemukan 0 database `shipx_qa_*` tersisa. Layanan backend/MySQL pengguna tetap berjalan.

## Batas dan lanjutan

Ini **perencanaan/penugasan sebelum keberangkatan**. Kelayakan waktu tempuh jalan terhadap seluruh jendela belum dievaluasi. Tidak memakai jarak garis lurus sebagai pengganti jalan atau ETA palsu. Volume penjumlahan belum membuktikan susunan geometris muat; admin meninjau bentuk/penanganan.

Selanjutnya konfirmasi muatan per SKU dan start trip atomik (stok depot → akun trip, reservation consumed, order out_for_delivery), hasil delivered/failed, bukti, COD dan rekonsiliasi. Sebelum mengaktifkan start, tetapkan pemeriksaan kelayakan jadwal/perjalanan sesuai PRD; jangan menganggap snapshot manual not_evaluated sebagai rute layak. Setelah berangkat claims harus dilepas melalui lifecycle/reconciliation yang sesuai, bukan tombol batal sebelum berangkat.
