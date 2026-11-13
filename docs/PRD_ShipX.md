# PRD — ShipX

Checkpoint 14 November 2026 menambah navigasi demo lokal OpenStreetMap/Valhalla. Pratinjau assigned dimulai dari depot, perjalanan aktif menggunakan GPS foreground dengan instruksi belokan dan perhitungan ulang rute. Graph mencakup area sekitar depot Surabaya. Pencatatan hasil, foto, COD serta rekonsiliasi tetap melalui alur operasional kurir/admin. Rincian serta cara menjalankan tersedia di LOCAL_NAVIGATION_DEMO.md.

Checkpoint aktif 8 November 2026: barang kembali layak jual/karantina per SKU, setoran COD, alasan/persetujuan selisih dan penutupan trip sudah diimplementasikan. Receipt/ledger/audit/status completed/pelepasan claims atomik; Flutter menampilkan penyerahan dan receipt milik sendiri. Lihat RECONCILIATION_CHECKPOINT.md. Pernyataan rekonsiliasi belum tersedia di checkpoint lama di bawah adalah histori. Navigasi/optimasi provider dan pilot menjadi tahap berikutnya.

Versi 0.2 · 4 November 2026 · menggantikan lingkup khusus galon v0.1.

## Konsep dan batas produk

Checkpoint aktif 6 November 2026 sudah mencakup hasil delivered/failed, foto bukti privat, COD tepat seluruh tagihan dan ledger pengiriman atomik. Hasil dicatat sesuai urutan tujuan, seluruh item atau gagal seluruhnya. Flutter memakai desain mobile terbaru pengguna. Setelah seluruh tujuan selesai, trip menunggu rekonsiliasi dan armada tetap terikat. Tahap berikutnya rekonsiliasi barang kembali/uang serta penutupan trip, kemudian navigasi/optimasi dan pilot. Lihat DELIVERY_RESULTS_CHECKPOINT.md. Catatan tahap sebelumnya di bawah merupakan histori.

Keputusan pengguna 5 November 2026: untuk tahap operasi manual, pemeriksaan jalan memakai durasi tiap ruas yang dimasukkan admin beserta sumber dan tinjauan penanganan, sebelum provider routing tersedia. Sistem menghitung waktu tunggu, jendela mulai layanan, durasi layanan dan pulang, lalu memeriksa ulang dari keberangkatan aktual. Statusnya feasible_manual, tidak diklaim sebagai matriks provider/optimasi/live traffic. Konfirmasi semua SKU dan start atomik telah tersedia; ledger depot→trip/reservation consumed/orders out_for_delivery, claims tetap ditahan. Lihat TRIP_DEPARTURES_CHECKPOINT.md. Bagian rancangan matriks/provider tetap tujuan tahap optimasi, bukan alasan mengganti data jalan dengan garis lurus. Pernyataan “start belum ada” di checkpoint lama sudah digantikan; hasil/COD/rekonsiliasi belum tersedia.

Checkpoint aktif: penugasan manual sebelum berangkat sudah tersedia (draft/edit urutan, assign, reopen/cancel beralasan, claims eksklusif, kapasitas, reservasi, versi dan akses trip sendiri pada Flutter kurir). Migration 000007 sudah Ran. Kelayakan waktu jalan belum dihitung; rute manual not_evaluated dan ETA null, tidak ada start/dispatch atau perpindahan stok pada checkpoint ini. Berikutnya konfirmasi muatan/start atomik, operasi hasil/COD dan rekonsiliasi, dengan pemeriksaan kelayakan sebelum start diaktifkan. Lihat MANUAL_TRIPS_CHECKPOINT.md. Status “berikutnya trip manual” di bagian historis di bawah telah digantikan.

ShipX adalah aplikasi pemesanan dan pengantaran berbagai barang dengan optimasi urutan pengiriman. Pelanggan dan kurir memakai Flutter Android; admin mengelola katalog, stok, pesanan, kendaraan, rute, serta rekonsiliasi melalui Laravel + React + Inertia + TypeScript + shadcn/ui + Tailwind. Backend Laravel REST API + Sanctum, database MySQL. Migrasi web dari Blade disetujui pengguna dan selesai pada 4 November 2026; rincian di ADMIN_UI_MIGRATION.md.

Keputusan eksplisit pengguna: nama ShipX dan dukungan barang selain galon. Default rancangan sementara: barang berasal dari katalog milik satu operator dan diambil di satu depot sebelum keberangkatan. Ini melanjutkan alur yang sudah dirancang, dengan kategori barang diperluas. Apabila maksud produk adalah jasa kirim paket bebas dari alamat pengirim ke penerima, diperlukan perluasan pickup/delivery berpasangan; model itu belum diasumsikan sebagai keputusan pengguna.

Contoh kategori awal: air minum kemasan dan kebutuhan rumah kemasan. Admin mengaktifkan SKU yang ukuran, bobot dan penanganannya sudah diketahui. Dukungan berbagai barang tidak berarti semua barang otomatis cocok untuk kendaraan atau layanan yang tersedia.

## Tujuan

- Memesan beberapa SKU dari HP dan memantau pengirimannya.
- Merencanakan urutan tujuan yang efisien dengan batas kapasitas dan waktu.
- Menjaga konsistensi stok per SKU, barang yang kembali, dan uang COD.
- Membuktikan manfaat optimasi melalui pembanding baseline dengan input yang sama.

Indikator pilot: pesanan sukses/gagal, ketepatan jendela layanan, selisih stok per SKU, selisih COD, estimasi penghematan rute, dan selisih ETA dengan aktual. Target awal uji algoritma 10–20 tujuan per trip; target kinerja harus dibuktikan, bukan dianggap telah tercapai.

## Role

| Role | Hak utama |
| --- | --- |
| Customer | Kelola alamat, pilih barang/jumlah, pesan, lihat status sendiri, batalkan sebelum penugasan |
| Courier | Lihat trip sendiri, konfirmasi muatan, buka navigasi, catat hasil dan COD |
| Admin | Katalog/stok/slot, konfirmasi, perencanaan rute, penugasan, rekonsiliasi |

## Lingkup MVP

- Satu pusat pemenuhan dan satu lokasi pickup awal per trip.
- Banyak SKU, satu unit jual dasar per SKU, kuantitas bulat; belum ada konversi dus/botol atau penjualan pecahan berat.
- Satu order dapat berisi beberapa SKU dan memiliki satu tujuan serta satu jendela layanan.
- Berat pengiriman per unit dalam gram; volume kemasan per unit dalam cm³. Keduanya wajib diketahui untuk SKU yang dapat dikirim. Admin memverifikasi kecocokan fisik barang.
- Kendaraan memiliki batas beban aman (gram) dan volume muat efektif (cm³), disalin ke trip.
- Satu kurir/kendaraan per trip; belum ada optimasi pembagian armada serentak.
- Pembayaran COD seluruh tagihan; harga tiap SKU + ongkir tetap per order.
- Penyerahan seluruh order atau gagal seluruhnya; barang gagal kembali ke depot.
- Jadwal per gelombang; tidak menambah order setelah berangkat.
- Bukti serah terima privat dan pencatatan alasan gagal.

Penukaran wadah bukan syarat checkout umum. Pembelian barang dengan wadah tukar, deposit, reverse pickup, dan pengembalian wadah belum diaktifkan dalam MVP generik; perlu modul khusus bila diprioritaskan kemudian. Dengan demikian galon dapat menjadi SKU penjualan biasa, tetapi skema refill tukar wadah lama tidak dianggap tetap didukung.

## Alur bisnis

1. Pelanggan login, menyimpan alamat/pin dan memilih slot.
2. Pelanggan menyusun keranjang multi-SKU; server menghitung harga serta total berat/volume dari data master.
3. Checkout menyimpan snapshot barang, harga, dimensi pengiriman, alamat dan jendela; reservation dibuat per item secara atomik.
4. Admin mengonfirmasi order; pending yang lewat TTL konfigurasi (awal 30 menit) dibatalkan dan reservation dilepas sekali.
5. Admin memilih kumpulan confirmed orders, kendaraan, kurir, serta keberangkatan. Sistem memvalidasi kapasitas dan menghitung rute.
6. Admin menyetujui rencana; kurir mengecek jumlah tiap SKU dan memulai trip. Stock depot dipindah ke account trip, reservation dikonsumsi.
7. Delivered: seluruh jumlah tiap SKU diserahkan, tagihan dibayar, bukti dicatat. Failed: tidak ada barang diserahkan atau uang diterima, barang tetap menjadi muatan trip.
8. Admin menerima kembali barang tersisa, memeriksa rusak/karantina per SKU, merekonsiliasi COD, dan menutup trip.

## Status dan konsistensi

Order: pending → confirmed → assigned → out_for_delivery → delivered/failed. Pending dapat rejected/cancelled; confirmed dapat cancelled. Assigned hanya dibuka ulang admin sebelum berangkat dan harus dihitung ulang. Status final immutable; jadwal ulang failed membuat order baru setelah trip asal direkonsiliasi.

Trip: draft → assigned → in_progress → awaiting_reconciliation → completed; sebelum berangkat boleh cancelled. Seluruh transisi, stok dan uang divalidasi server. Pengiriman ulang request tidak menggandakan order, hasil, ledger atau COD. Harga tidak boleh diubah kurir di lapangan.

Stok tersedia per SKU = balance depot/available − reservation aktif SKU tersebut. Seluruh account item dalam satu checkout dikunci dengan urutan ID konsisten; bila salah satu stok tidak cukup, seluruh checkout rollback. Tidak ada stok negatif.

## Kapasitas dan optimasi

`berat order = Σ(quantity × unit_shipping_weight_g_snapshot)`  
`volume order = Σ(quantity × unit_shipping_volume_cm3_snapshot)`

Kedua total gabungan order trip wajib <= snapshot kapasitas kendaraan. Volume adalah pendekatan penjumlahan kemasan, bukan bukti susunan tiga dimensi muat. Admin wajib meninjau bentuk, dimensi terpanjang, barang rapuh, dan aturan penanganan. Barang yang butuh penanganan di luar kemampuan operator tidak diterima otomatis.

MVP delivery-only: muatan awal tertinggi; keberhasilan mengurangi berat/volume dan kegagalan mempertahankan muatan. Tidak ada asumsi total wadah tetap atau perhitungan kapasitas hanya berdasarkan jumlah barang.

Keputusan13November2026, optimasi satu trip/satu slot memakai deadline-ordered cheapest feasible insertion +2-opt. Matriks waktu jalan manual lengkap beserta sumber ditinjau admin. Baseline urutan draft, FIFO dan kandidat dibanding dari input sama. Semua batas kapasitas serta selesai layanan dalam window dan jam operasional wajib terpenuhi. Skor mengutamakan total waktu selesai Express sejak keberangkatan, lalu total waktu jalan termasuk pulang dan waktu kembali. Express memakai deadline akhir slot pesanan. Prioritas Express dapat menambah total waktu jalan, sehingga admin melihat kedua metrik sebelum menerapkan. Matriks asimetris dihitung sesuai arah tiap ruas. Kandidat heuristik belum menjamin optimum global. Integrasi provider matriks tetap menjadi tahap berikutnya.

Jika data jalan tidak lengkap atau tidak ditemukan rute layak, admin menerima konflik dan memecah gelombang/mengubah rencana. Jangan menggantinya diam-diam dengan jarak garis lurus. ETA hanya estimasi. Kebijakan penyimpanan data dan biaya provider diperiksa sebelum integrasi.

## Acceptance criteria utama

1. Keranjang dua SKU menghitung harga/berat/volume di server, menyalin snapshot, dan membuat reservation semua-atau-tidak-sama-sekali.
2. Produk tanpa metadata pengiriman valid tidak dapat checkout.
3. Dua pembeli stok terakhir: maksimal satu berhasil; cancellation/expiry melepas reservation sekali.
4. Total berat atau volume melewati kendaraan: penugasan/keberangkatan ditolak.
5. Order, kurir dan kendaraan tidak punya dua penugasan aktif.
6. Retry delivery menghasilkan satu hasil, ledger dan COD; delivered wajib sama jumlah per SKU dengan order.
7. Failed tidak memindahkan barang keluar trip dan tidak menghasilkan COD.
8. Rekonsiliasi menghitung stok tersedia/karantina per SKU, expected/actual/selisih dan COD; selisih wajib alasan/persetujuan.
9. Edit master harga, berat, volume atau alamat tidak mengubah snapshot order lama.
10. Akses antar-user/kurir ditolak dan API umum tidak membocorkan data penerima lain.

## Tahapan dan status

Fondasi → auth/role → master SKU dan alamat/slot → checkout multi-SKU/stok → operasi pengiriman manual → optimasi → pilot. Ledger stok, keranjang, quote, checkout COD, keputusan admin serta riwayat/detail/pembatalan customer tersedia. Master kurir dan kendaraan sudah dapat dikelola admin, dengan kapasitas berat/volume, status aktif/nonaktif, konflik versi dan pencabutan token kurir saat kredensial berubah. Uji HP checkout multi-SKU, konfirmasi, penolakan/alasan, pembatalan dan login kurir sudah lolos. Tahap berikutnya: penugasan trip manual, operasi pengiriman dan rekonsiliasi. Lihat FLEET_MASTERS_CHECKPOINT.md dan SETUP_STATUS.md untuk bukti uji. Optimasi dilakukan setelah fondasi operasi pengiriman stabil.

Live tracking, langganan, payment gateway, multi-depot, pickup bebas, partial delivery, return setelah delivered, cold-chain dan dangerous goods berada di luar MVP ini. Tidak ada komitmen mendukungnya hanya dengan mengganti nama aplikasi.
