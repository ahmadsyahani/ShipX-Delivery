# Konfirmasi muatan dan start trip — 5 November 2026

Pembaruan13November2026, jadwal memeriksa selesai layanan <=akhir slot dan jam tutup, serta keberangkatan dalam jam operasional. Rute draft bisa dioptimasi dengan matriks jalan manual lengkap. Ruas rute terpilih mengisi form tinjauan, lalu admin meninjau penanganan seperti biasa. Rincian di API_PHASE_1.md bagian Optimasi satu trip. Catatan lama di bawah yang memakai batas mulai layanan mencerminkan checkpoint sebelumnya.

Checkpoint ini melanjutkan MANUAL_TRIPS_CHECKPOINT.md. Pengguna secara eksplisit memilih **estimasi waktu jalan manual dengan sumber dan tinjauan admin** untuk tahap ini. Ini perubahan kebijakan sementara dari prasyarat provider pada rancangan awal; tidak ada integrasi provider, matriks otomatis, optimasi atau estimasi garis lurus yang disisipkan.

Migration `2026_11_04_000008_create_trip_departures` sudah Ran di MySQL lokal, tanpa reset atau fixture bisnis. Perubahan masih lokal pada `develop` bersama checkpoint sebelumnya; belum commit/push. `.env` tetap SHA-256 `DBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C`.

## Cara mencoba

1. Siapkan trip assigned seperti checkpoint manual sebelumnya. Rencana keberangkatan harus mendatang ketika draft dibuat.
2. Pada detail trip admin, isi **Tinjau keberangkatan**: menit setiap ruas jalan (depot → tujuan, antar-tujuan, tujuan terakhir → depot), sumber estimasi sesuai mode kendaraan, catatan, serta konfirmasi bentuk/dimensi/penanganan barang.
3. Simpan tinjauan. Tinjauan hanya dibuat dalam 24 jam sebelum rencana dan berlaku 24 jam setelah ditinjau. Rencana/versi master yang berubah memerlukan perencanaan/tinjauan ulang. Tinjauan baru menambah versi trip; yang lama tetap tersimpan.
4. Di Flutter kurir, buka detail trip dan masukkan jumlah fisik **setiap SKU** sesuai manifest. Tunggu waktu rencana berangkat. Tombol start tersedia setelah ada tinjauan yang berlaku dan pemeriksaan jadwal berhasil.
5. Tekan **Konfirmasi muatan & mulai trip**, periksa dialog, lalu konfirmasi. Jika jumlah tidak cocok, jangan mengubah pesanan dari kurir; hubungi admin sebelum berangkat.

Sistem menambahkan durasi setiap ruas, menunggu hingga window_start jika tiba lebih awal, memeriksa **mulai layanan <= window_end**, menambahkan default_service_seconds snapshot dan perjalanan pulang. Tidak ada batas jam pulang depot yang dikonfigurasi; waktu pulang ditampilkan sebagai estimasi. Saat start, seluruh jadwal dihitung ulang dari waktu server aktual. Jika sudah terlambat atau tinjauan kedaluwarsa, start ditolak dan stok tidak berpindah.

## Transaksi keberangkatan

Start hanya oleh kurir aktif pemilik trip. Server memeriksa versi trip/rute/tinjauan, identitas/status/versi depot/armada, claims eksklusif, urutan stops, orders assigned dengan versi yang sesuai, manifest snapshot, kapasitas berat DAN volume, reservasi lengkap dan kecukupan saldo depot termasuk reservasi order lain.

Dalam satu transaksi:

- Satu transaksi ledger `kind=load`, event_key unik `trip-load:{id}`.
- Untuk setiap SKU: depot/available −q, trip/available +q. Account trip memiliki trip_id dan owner_key `trip:{id}`; quarantine disiapkan bersaldo nol.
- Reservasi item menjadi consumed dengan consumed_at. Reservasi pesanan lain tetap active. Stok tersedia depot (`balance − active reservations`) tidak berubah akibat pemuatan yang sudah direservasi.
- Orders menjadi out_for_delivery dengan versi baru; payment_status tetap unpaid.
- Trip menjadi in_progress, actual_departure_at server, loaded_weight_g/loaded_volume_cm3 dan versi baru. Receipt manifest/jadwal aktual serta audit actor/waktu disimpan.
- Claims pesanan/kurir/kendaraan tetap ditahan. Reopen/cancel/edit/review sebelum berangkat ditolak sesudah start. Pelepasan claims menunggu lifecycle/rekonsiliasi berikutnya.

Mutex depot tetap sama dengan checkout/cancel/stock/penugasan; kurir/kendaraan di-lock, semua account ID ascending, lalu orders ID ascending dan trip. Pembuatan account baru berada dalam transaksi yang sama. Satu SKU gagal menyebabkan rollback seluruh muatan, account baru, reservasi, status dan ledger. UNIQUE receipt per trip serta event_key melengkapi idempotency.

## Web, API dan Flutter

Admin menampilkan manifest per SKU dengan rincian snapshot kemasan/order, form sumber/waktu jalan, estimasi tunggu/layanan/pulang, waktu berangkat aktual dan muatan. Filter trips menerima in_progress; orders menerima out_for_delivery. Halaman in_progress tidak menampilkan tombol sebelum keberangkatan.

`POST /admin/trips/{id}/departure-review` memakai session+CSRF+admin aktif. Payload: idempotency_key UUID, lock_version, leg_minutes berurutan (jumlah tujuan + 1, tiap ruas integer 0–1440), source_reference/reason wajib maksimal 500, handling_checked=true. Ruas nol hanya untuk estimasi operator, misalnya lokasi berimpit; sistem tidak mengisinya otomatis. Tidak ada input actor/status/sumber provider dari client. Review disimpan append-only, terikat trip/route/version dan versi master.

`POST /api/v1/courier/trips/{id}/start` memakai bearer kurir aktif dan header `Idempotency-Key: UUID`. Contoh body:

```json
{
  "lock_version": 2,
  "route_version_id": "1",
  "departure_review_id": "1",
  "manifest": [
    {"product_id": "1", "quantity": 4},
    {"product_id": "2", "quantity": 2}
  ]
}
```

Manifest harus tepat semua SKU, tanpa kurang/lebih/duplikat/substitusi; ID/jumlah dinormalisasi dan diurutkan untuk idempotency. Actor, status dan actual_departure_at ditetapkan server. Sukses 200 dengan data id/status/lock_version/actual_departure_at. Replay key/payload identik mengembalikan hasil yang sama; key berbeda setelah start tidak membuat pemuatan lagi. 422 validasi, 409 konflik, 401/403 auth/role, 404 di luar akses. Jika admin lebih dulu reopen/cancel saat race, start bisa 404 karena trip tidak lagi berada dalam akses operasional kurir.

GET courier trips/detail kini mencakup assigned dan in_progress milik sendiri. Detail menambah manifest, route_version_id, departure_review, can_start/start_block_reason (petunjuk UI, bukan pengganti validasi server), waktu aktual, loaded totals, ETA tujuan dan estimasi kembali. `feasibility_status=feasible_manual` menunjuk hasil tinjauan, bukan provider/live traffic; expires_at dan sumber ditampilkan. Route_versions awal tetap immutable not_evaluated; tinjauan disimpan terpisah. Setelah start, jadwal berasal dari receipt keberangkatan aktual. Daftar tetap tanpa alamat penerima. Customer melihat Dalam pengantaran, tidak dapat cancel; ETA customer masih nullable/belum ditampilkan.

Flutter menyimpan UUID/payload sebelum POST dalam secure storage terpisah per kurir/trip. Timeout, 5xx, 429 atau REQUEST_IN_PROGRESS mempertahankan permintaan untuk retry **key dan payload sama**. Konflik definitif memerlukan refresh/tinjauan baru. Restore tidak otomatis mengirim. GET in_progress membersihkan catatan lokal yang belum pasti tanpa memulai lagi. Gangguan penyimpanan memblokir POST. Polling tidak menimpa proses start; dialog memeriksa perubahan versi sebelum submit.

## Skema dan bukti uji

Migration menambah inventory_accounts.trip_id, inventory_transactions.trip_id, tabel trip_departure_reviews dan trip_load_confirmations. Composite FK memastikan review/load terkait trip dan route yang sesuai; receipt PK trip_id dan inventory_transaction_id UNIQUE. Ownership account juga divalidasi service. Review menyimpan sumber manual, durasi, schedule/master snapshots, handling_checked, actor, alasan dan expiry; receipt menyimpan manifest, review/rute/transaksi dan jadwal aktual.

- **85 tes backend / 1364 assertions** lolos, termasuk 8 skenario keberangkatan: jadwal lengkap/tunggu/pulang, versi/idempotency, semua SKU, stok/reservasi/capacity rollback, akses/CSRF, expiry dan invalidasi setelah reassign.
- **48 tes Flutter**, analyzer tanpa temuan, TypeScript/build Vite dan APK debug lolos. APK memakai localhost:8000 untuk ADB reverse. Warning bundle Vite utama >500 kB tetap ada.
- **6 skenario browser** lolos pada database QA bersih: tinjauan tidak layak, tab admin lama, manifest dua SKU, start/replay, stok tersedia tetap, status customer dan UI in_progress desktop/390 px. Screenshot diperiksa.
- `php scripts/verify-trip-departures-mysql.php` lolos: migration rollback/reapply pada QA kosong, seluruh race penugasan lama, start/start dengan key berbeda/sama, start/reopen dan start/cancel. Memeriksa satu load receipt/transaksi, saldo multi-SKU sesuai ledger, konservasi transfer internal dan claims. Database dibuang otomatis.

Untuk seluruh browser suite, jalankan `php scripts/serve-checkout-qa.php departures`, lalu `npm.cmd run test:e2e` dari backend. Mode ini mencakup fixture checkout/armada/trip/keberangkatan dengan akun sintetis terpisah; header X-ShipX-QA wajib sebelum mutasi browser. Fixture keberangkatan berjalan sebelum tes admin yang mengubah versi depot, karena perubahan tersebut memang mewajibkan replan di aplikasi. Clock hanya dimundurkan saat membuat fixture assigned agar rencana sudah due ketika server QA mulai; bukan bypass auth/aturan waktu pada aplikasi. Hentikan dengan `php scripts/serve-checkout-qa.php stop` agar database dibersihkan.

HP belum terdeteksi ADB; APK terbaru belum dipasang atau diuji pada perangkat fisik. Tidak ada fixture bisnis atau akun bawaan ditambahkan ke database utama. Lanjutan: hasil delivered/failed seluruh order, bukti, pencatatan COD dan rekonsiliasi barang/uang sebelum trip dapat ditutup. Jangan melepas claims atau mengedit saldo trip untuk menyimulasikan penyelesaian.

Pemeriksaan akhir: server QA dihentikan, 0 database shipx_qa_* tersisa, 0 receipt pemuatan uji pada database bisnis, dan hash .env tetap identik. MySQL pengguna dibiarkan aktif; server HTTP localhost:8000 tidak terdeteksi pada pemeriksaan sesi ini. Jalankan server backend yang biasa dipakai sebelum mencoba APK; build localhost untuk HP memerlukan ADB reverse tcp:8000 tcp:8000.
