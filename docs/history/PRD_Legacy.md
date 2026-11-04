> HISTORIS v0.1 — aturan khusus galon dalam dokumen ini sudah digantikan oleh PRD_ShipX.md, ERD_ShipX.md, dan API_PHASE_1.md aktif. Jangan implementasikan aturan lama.

# PRD — ShipX

Versi: 0.1 — rancangan MVP untuk ditinjau  
Tanggal: 4 November 2026  
Nama produk: sementara, dapat diganti  
Platform: Flutter Android untuk pelanggan/kurir; web Laravel Blade + Tailwind CSS untuk admin.

## 1. Ringkasan produk

ShipX adalah sistem pemesanan dan pengiriman galon untuk satu depot. Pelanggan memesan melalui HP, admin mengelompokkan pesanan ke dalam gelombang perjalanan, dan kurir mengikuti urutan tujuan yang dioptimalkan berdasarkan estimasi waktu perjalanan jalan raya.

Nilai utama: mempermudah pemesanan berulang, membantu admin menyusun perjalanan yang layak, serta mencatat galon penuh, wadah kosong, dan uang COD secara konsisten.

Sistem menyarankan rute efisien berdasarkan data dan batasan yang tersedia. Sistem tidak menjanjikan rute tercepat secara mutlak maupun waktu tiba yang pasti.

## 2. Masalah dan hipotesis

- Pesanan melalui chat mudah terlewat, alamat harus ditanyakan ulang, dan status sulit dipantau.
- Urutan pengantaran disusun berdasarkan kebiasaan, belum dibandingkan secara terukur.
- Catatan galon penuh, wadah kosong, dan penerimaan COD berpotensi berbeda antara depot dan kurir.
- Pelanggan dapat tidak berada di tempat sehingga pesanan gagal dan barang kembali.

Hipotesis yang perlu diuji: pelanggan bersedia menggunakan aplikasi untuk pemesanan berulang; admin terbantu oleh pengelompokan gelombang; optimasi memberikan penghematan estimasi dibanding urutan pesanan masuk.

Validasi awal: wawancara satu pemilik depot, satu kurir, dan sekitar lima pelanggan rutin. Catat alur penukaran, kapasitas kendaraan sebenarnya, jam layanan, dan kebiasaan pembayaran. Angka operasional pada dokumen ini adalah default rancangan, bukan hasil observasi.

## 3. Tujuan dan ukuran keberhasilan

| Tujuan | Ukuran MVP |
| --- | --- |
| Pesanan dapat diselesaikan dari awal sampai akhir | Pemesanan, perencanaan, keberangkatan, hasil pengantaran, dan penutupan perjalanan berjalan dalam pilot |
| Stok dan uang dapat direkonsiliasi | Seluruh perjalanan ditutup dengan catatan selisih nol atau selisih yang dijelaskan dan disetujui admin |
| Rute layak | Tidak ada pelanggaran kapasitas dan tidak ada pesanan dialokasikan ke dua perjalanan aktif |
| Manfaat optimasi terukur | Bandingkan estimasi waktu/jarak sebelum dan sesudah pada input identik; tampilkan hasil termasuk ketika tidak ada penghematan |
| Estimasi tidak menyesatkan | Catat waktu aktual dan selisih ETA; pisahkan waktu berkendara dan waktu layanan |

Target uji teknis: 10–20 tujuan per perjalanan; perhitungan heuristik lokal selesai dalam 5 detik pada lingkungan uji yang didokumentasikan, di luar latensi penyedia matriks. Target ini perlu dibuktikan melalui pengujian.

## 4. Pengguna dan hak akses

| Role | Kewenangan |
| --- | --- |
| Pelanggan | Registrasi, kelola alamat sendiri, memesan, melihat pesanan sendiri, membatalkan sebelum penugasan |
| Kurir | Akun dibuat admin; melihat perjalanan yang ditugaskan, membuka navigasi, mencatat hasil kunjungan, bukti dan COD |
| Admin | Kelola depot/produk/stok/kurir, konfirmasi pesanan, rencanakan dan tetapkan rute, rekonsiliasi, lihat laporan |

Satu aplikasi Flutter memakai navigasi sesuai role. Role kurir/admin tidak dapat dipilih melalui registrasi publik. Menyembunyikan tombol tidak menggantikan validasi izin di server.

## 5. Keputusan lingkup MVP

| Aspek | Keputusan awal |
| --- | --- |
| Wilayah | Satu depot dengan radius layanan yang diatur admin |
| Produk | Satu jenis galon isi ulang dengan wadah yang diterima depot |
| Skema penjualan | Tukar 1 wadah kosong yang layak dengan 1 galon penuh |
| Pembayaran | COD tunai, tarif per galon dan ongkir tetap yang ditampilkan sebelum pesan |
| Armada | Satu kendaraan/kurir per perjalanan; perjalanan berbeda dapat memakai kurir berbeda |
| Penjadwalan | Gelombang pengiriman; pelanggan memilih salah satu jendela layanan yang disediakan |
| Pengambilan depot | Seluruh muatan perjalanan diambil di depot sebelum keberangkatan |
| Penyerahan | Pesanan diserahkan seluruhnya atau gagal seluruhnya |
| Rute | Start depot → beberapa pelanggan → kembali ke depot |
| Koneksi | Pemesanan dan konfirmasi hasil membutuhkan koneksi; draf hasil boleh tersimpan lokal |

Di luar MVP: pembelian wadah baru, deposit/utang wadah, produk lain, langganan otomatis, payment gateway, live tracking, optimasi pembagian banyak kendaraan sekaligus, pesanan baru masuk ke rute berjalan, perpanjangan otomatis, dan prediksi kebutuhan pelanggan.

## 6. Alur utama

1. Pelanggan mendaftar menggunakan email/password, menambahkan alamat teks, pin koordinat, nomor kontak, dan petunjuk lokasi.
2. Pelanggan memilih jumlah galon, menyetujui penukaran wadah 1:1, memilih jendela layanan, dan melihat total harga.
3. Server memvalidasi wilayah, stok yang dapat dijanjikan, serta menyimpan snapshot harga/alamat. Pesanan masuk sebagai pending.
4. Admin mengonfirmasi pesanan dan mengelompokkan pesanan dengan jendela yang kompatibel. Pending sudah menahan stok sampai dikonfirmasi, ditolak, atau dibatalkan.
5. Admin memilih kurir, kapasitas kendaraan, waktu berangkat, dan durasi layanan per tujuan. Sistem menghitung baseline serta rute usulan.
6. Admin meninjau kelayakan, menetapkan rute, dan menyiapkan muatan. Kurir memverifikasi jumlah muatan sebelum berangkat.
7. Setelah keberangkatan, anggota pesanan dan urutan rute dikunci. Kurir menjalankan kunjungan sesuai rencana.
8. Di tujuan, kurir memeriksa wadah, menerima COD, menyerahkan galon, lalu mengirim hasil dan bukti penerimaan.
9. Untuk kegagalan, kurir memilih alasan dan catatan. Tidak ada retry dalam perjalanan yang sama pada MVP.
10. Kurir kembali ke depot; admin menghitung galon penuh tersisa, wadah kosong, dan uang. Perjalanan ditutup setelah rekonsiliasi.

## 7. Kebutuhan fungsional dan acceptance criteria

| ID | Kebutuhan P0 | Kriteria penerimaan |
| --- | --- | --- |
| AUTH-01 | Login dan role | Token dapat dicabut; pelanggan tidak dapat mengakses pesanan orang lain atau endpoint kurir/admin |
| ADR-01 | Alamat dan pin | Koordinat wajib, pin dalam wilayah layanan, alamat disalin ke pesanan sehingga edit alamat tidak mengubah pesanan lama |
| ORD-01 | Pemesanan | Jumlah bilangan bulat positif; harga dihitung server; stok tidak dapat dipesan melebihi ketersediaan |
| ORD-02 | Pembatalan | Pelanggan boleh membatalkan pending/confirmed; assigned hanya dapat dibatalkan admin setelah rute dibuka ulang; out_for_delivery tidak dapat dibatalkan |
| ORD-03 | Jendela layanan | Admin mengatur slot dan cutoff; slot yang sudah lewat cutoff tidak dapat dipilih |
| INV-01 | Reservasi stok | Dua request bersamaan untuk stok terakhir menghasilkan maksimal satu reservasi sah |
| RTE-01 | Pembuatan rute | Hanya confirmed yang belum dialokasikan dapat dipilih; jumlah muatan tidak melewati kapasitas |
| RTE-02 | Optimasi dan pembanding | Tampilkan urutan baseline/usulan, durasi, jarak, ETA, asumsi durasi layanan, dan waktu data diambil |
| RTE-03 | Penugasan | Kurir tidak memiliki dua perjalanan assigned/in_progress bersamaan; perubahan rencana membatalkan versi penugasan sebelumnya |
| RTE-04 | Ketidaklayakan | Pin tak terjangkau, data matriks tidak lengkap, atau jendela tak terpenuhi ditampilkan; rute tidak dapat diberangkatkan sebagai rute layak |
| CRR-01 | Mulai perjalanan | Kurir mengonfirmasi muatan; reservasi dialihkan ke stok kendaraan tepat satu kali |
| CRR-02 | Hasil kunjungan | Delivered memerlukan jumlah tukar sama dengan pesanan, COD sesuai tagihan, serta bukti foto barang/serah terima tanpa kewajiban memfoto wajah |
| CRR-03 | Pengiriman gagal | Alasan wajib: pelanggan tidak ada, wadah tidak sesuai/kurang, pembayaran gagal, alamat tak ditemukan, atau kendala akses |
| CRR-04 | Pengiriman ulang request | Idempotency key yang sama tidak membuat hasil, mutasi stok, atau penerimaan uang ganda |
| REC-01 | Rekonsiliasi | Admin membandingkan catatan dengan jumlah fisik dan uang; selisih wajib dijelaskan; koreksi melalui entri penyesuaian |
| REP-01 | Laporan | Admin melihat pesanan, hasil perjalanan, pergerakan stok, COD, dan perbandingan rute |

## 8. Status dan aturan perubahan

Pesanan:

`pending → confirmed → assigned → out_for_delivery → delivered / failed`

- pending dapat menjadi rejected atau cancelled; confirmed dapat menjadi cancelled.
- assigned dapat kembali ke confirmed hanya oleh admin sebelum keberangkatan melalui pembatalan penugasan dan kalkulasi ulang rute.
- delivered/failed/rejected/cancelled bersifat final. Jadwal ulang failed membuat pesanan baru dengan referensi ke pesanan sebelumnya, setelah stok direkonsiliasi.
- Penyelesaian pesanan dan status pembayaran disimpan terpisah. Pembayaran memiliki status unpaid/collected/reconciled.

Perjalanan:

`draft → assigned → in_progress → awaiting_reconciliation → completed`

- draft/assigned dapat cancelled sebelum berangkat dan melepas alokasi pesanan.
- Saat semua stop final atau admin menghentikan perjalanan karena kendala, perjalanan menuju awaiting_reconciliation. Stop tersisa ditandai failed dengan alasan yang sesuai.
- completed hanya oleh admin setelah barang dan COD diperiksa. Riwayat tidak dihapus.
- Perubahan status di luar jalur ditolak server dan dicatat sebagai error yang dapat dipahami pengguna.

## 9. Stok, wadah, dan COD

### 9.1 Lokasi dan reservasi

Pisahkan stok fisik penuh di depot, stok penuh di kendaraan, wadah kosong di depot, dan wadah kosong di kendaraan. Reservasi bukan pengurangan stok fisik.

`stok dapat dijanjikan = stok penuh depot − reservasi pesanan yang belum dimuat`

Reservasi dibuat secara atomik saat pesanan pending diterima server. Pending yang tidak dikonfirmasi dalam waktu konfigurasi (default 30 menit) dibatalkan sistem; stok dilepas sekali. Konfirmasi dan proses kedaluwarsa harus aman saat berjalan bersamaan.

### 9.2 Pergerakan

- Berangkat membawa N: stok penuh depot turun N; penuh kendaraan naik N; reservasi N diselesaikan.
- Berhasil mengantar q: penuh kendaraan turun q; kosong kendaraan naik q; COD tercatat q × harga snapshot + ongkir pesanan.
- Gagal: tidak ada penyerahan, penukaran atau COD; galon penuh tetap di kendaraan.
- Kembali: seluruh galon penuh tersisa dan kosong dipindahkan ke depot berdasarkan hitungan aktual, dengan selisih dicatat terpisah.
- Pengisian galon di depot dicatat manual admin sebagai perubahan kosong menjadi penuh; pencatatan stok awal dan penerimaan wadah juga diaudit.

Barang rusak/bocor dikarantina melalui penyesuaian admin dengan alasan, bukan dianggap delivered. Tidak ada stok negatif atau pengeditan saldo tanpa mutasi.

### 9.3 Kapasitas

Karena setiap penyerahan ditukar 1:1, total wadah di kendaraan tetap sepanjang pengantaran berhasil. Kapasitas MVP memakai jumlah wadah aman yang ditentukan depot. Pemeriksaan awal N ≤ kapasitas tetap wajib. Jika kelak mendukung pengambilan kosong tambahan, ukuran produk lain, atau pembelian tanpa tukar, model kapasitas harus diperluas per tahap perjalanan dan memperhitungkan berat/volume.

### 9.4 Aturan pengecualian

Jika wadah kurang/tidak layak, pelanggan tidak membayar sesuai tagihan, atau tidak dapat menerima, pengiriman gagal seluruhnya. Kurir tidak mengubah harga atau membuat utang di lapangan. Admin dapat membuat pesanan baru setelah penyelesaian perjalanan. Aturan ini harus jelas sebelum checkout.

## 10. Optimasi rute

### Input

- Koordinat depot dan alamat snapshot pesanan.
- Matriks waktu serta jarak berdasarkan jaringan jalan dan jenis kendaraan yang didukung penyedia.
- Waktu keberangkatan, jendela layanan, jumlah wadah, kapasitas kendaraan, dan durasi layanan per tujuan (default 5 menit, dapat diatur).
- Seluruh perjalanan menyertakan perjalanan kembali ke depot.

### Algoritma MVP

1. Validasi matriks lengkap, stok, kapasitas, serta kompatibilitas jendela layanan.
2. Buat baseline urutan pesanan masuk menggunakan matriks yang sama.
3. Susun kandidat nearest neighbor berdasarkan waktu perjalanan; tangani waktu tunggu dan batas akhir jendela.
4. Perbaiki urutan dengan 2-opt; setiap kandidat diperiksa ulang terhadap seluruh jendela layanan.
5. Matriks dapat asimetris karena jalan satu arah: hitung ulang biaya seluruh kandidat, jangan memakai rumus pertukaran yang menganggap A→B sama dengan B→A.
6. Bandingkan kandidat layak dan baseline layak; gunakan yang terbaik. Jika tidak menemukan kandidat layak, tampilkan konflik dan minta admin memecah gelombang atau mengubah waktu.
7. Simpan snapshot rute, parameter, waktu perhitungan, dan versi; admin dapat mengubah urutan sebelum berangkat lalu menghitung ulang kelayakan.

Tujuan: meminimalkan estimasi durasi total perjalanan, termasuk layanan dan waktu tunggu, dengan kapasitas serta jendela layanan sebagai batas wajib. Heuristik tidak menjamin optimum global; kegagalan menemukan rute juga tidak membuktikan tidak ada solusi.

ETA setiap stop dihitung dari keberangkatan, waktu perjalanan, waktu tunggu, dan layanan stop sebelumnya. Jendela layanan ditafsirkan sebagai rentang mulai pelayanan. ETA ditampilkan sebagai estimasi, bukan janji pasti.

Jika penyedia tidak mendukung mode kendaraan yang digunakan, admin harus mendapat peringatan; rute yang mengandung akses kendaraan tidak sesuai tidak boleh dianggap siap berangkat tanpa peninjauan. Jangan mengganti matriks gagal dengan jarak garis lurus secara diam-diam.

### Pembuktian hasil

- Ukur penghematan estimasi: `(durasi baseline − durasi usulan) / durasi baseline × 100%` jika baseline layak dan durasinya positif.
- Bila baseline tidak layak, tampilkan konflik, bukan persentase perbandingan yang menyesatkan.
- Gunakan skenario jalan satu arah, koordinat duplikat, jendela sempit, satu tujuan, dan tujuan tidak terjangkau.
- Pisahkan penghematan estimasi dengan perubahan waktu aktual yang turut dipengaruhi lalu lintas dan pelanggan.

## 11. Layar utama

Pelanggan: login/registrasi; beranda produk; alamat dan pin; checkout; daftar/detail pesanan; profil. Halaman detail menampilkan urutan status dan ETA setelah penugasan, tanpa membuka data pelanggan lain.

Kurir: perjalanan aktif; daftar tujuan; detail tujuan dengan kontak dan petunjuk; tombol buka navigasi; hasil pengantaran; ringkasan muatan/COD; riwayat perjalanan sendiri.

Admin: ringkasan operasional; antrean pesanan; produk/tarif; stok dan mutasi; alamat di peta; perencana rute dengan pembanding; penugasan; rekonsiliasi; laporan; pengaturan depot/slot/kurir.

## 12. Rancangan teknis awal

- Mobile: Flutter + Dart, REST JSON. Satu aplikasi dengan akses sesuai role.
- Backend: Laravel + Sanctum; versi framework dipilih dan dikunci saat setup, bukan mengikuti latest otomatis.
- Web: Blade + Tailwind CSS; JavaScript seperlunya untuk peta dan interaksi formulir.
- Database: MySQL; transaksi dan locking untuk stok, penugasan, serta finalisasi.
- Queue/scheduler: job optimasi, notifikasi, dan kedaluwarsa pending. Driver database cukup untuk MVP; Redis belum wajib.
- Peta/routing: integrasi provider melalui adapter; kandidat awal Google Routes API untuk matriks, navigasi melalui Google Maps. Verifikasi dukungan kendaraan, ketentuan penggunaan/penyimpanan data, kuota, dan tarif sebelum implementasi.
- Optimasi: service dalam Laravel untuk nearest neighbor + 2-opt; tidak perlu microservice untuk lingkup awal.
- Penyimpanan: token di secure storage; bukti foto privat dengan akses terotorisasi; secret API server tidak ditanam di aplikasi.
- Notifikasi: status dalam aplikasi sebagai kebutuhan wajib; push notification dapat ditambahkan setelah alur inti stabil.

Referensi teknis resmi: https://developers.google.com/maps/documentation/routes dan https://developers.google.com/maps/documentation/route-optimization/overview. PRD memilih heuristik sendiri untuk nilai pembelajaran; penggunaan layanan optimasi penuh adalah alternatif, bukan dependensi wajib.

## 13. Entitas data konseptual

| Entitas | Isi pokok |
| --- | --- |
| users / addresses | Role, akun, kontak, alamat dan koordinat |
| depots / products / delivery_slots | Lokasi depot, konfigurasi tarif, slot dan cutoff |
| orders / order_items | Snapshot harga/alamat, jendela, jumlah, status dan total |
| stock_reservations / inventory_movements | Reservasi, jenis/lokasi stok, mutasi bertanda dan referensi transaksi |
| vehicles / courier_assignments | Kapasitas dan penugasan kurir |
| trips / trip_stops / route_versions | Jadwal, snapshot rute, urutan, ETA dan metrik |
| delivery_attempts / delivery_proofs | Hasil final, jumlah, alasan gagal, bukti dan waktu aktual |
| payment_collections / trip_reconciliations | COD per pesanan, setoran, hitungan fisik dan selisih |
| audit_logs / idempotency_records | Pelaku perubahan dan pencegahan transaksi ganda |

Ini rancangan konseptual; ERD, indeks, constraint, serta kontrak endpoint dibuat pada tahap desain implementasi.

## 14. Persyaratan kualitas dan operasional

- Semua endpoint memeriksa kepemilikan/role; kurir hanya melihat data perjalanan yang ditugaskan.
- Request mutasi penting memakai idempotency key dan validasi versi untuk menolak update dari layar lama.
- Update hasil pengantaran menyimpan status, stok dan uang dalam satu transaksi; notifikasi diproses setelah commit.
- Gunakan HTTPS, pembatasan percobaan login, validasi file upload, dan pencatatan error yang tidak memuat token.
- Alamat dan bukti tidak dibuka publik. Catatan penting tidak dihapus; koreksi menyimpan pelaku dan alasan.
- Gangguan jaringan menampilkan status belum terkirim. Draf lokal tidak boleh ditampilkan sebagai hasil final sebelum server mengonfirmasi.
- Gangguan routing tidak menghapus pesanan; admin dapat mencoba ulang. Rute manual hanya dapat disetujui setelah validasi operasional, dengan alasan dan tanpa klaim telah dioptimalkan.
- Mata uang disimpan sebagai integer rupiah. Waktu disimpan UTC dan ditampilkan menurut zona depot (default Asia/Jakarta).
- Tetapkan batas kuota dan anggaran API; jangan menghitung ulang matriks setiap pelanggan membuka halaman.
- Backup database dan prosedur pemulihan diuji sebelum pilot operasional.

## 15. Skenario penerimaan kritis

1. Dua pelanggan memesan stok terakhir bersamaan: hanya satu reservasi berhasil.
2. Admin mengonfirmasi pesanan tepat saat job kedaluwarsa berjalan: hanya satu status final sah dan reservasi konsisten.
3. Dua admin menugaskan pesanan sama: pesanan hanya masuk satu perjalanan aktif.
4. Jumlah muatan melebihi kapasitas: keberangkatan ditolak.
5. Kurir menekan selesai dua kali atau retry setelah timeout: stok dan COD hanya berubah sekali.
6. Pelanggan tidak punya wadah sesuai jumlah: pengiriman gagal, stok kendaraan tetap penuh dan COD nol.
7. Sebagian stop gagal: muatan sisa kembali dan seluruh pergerakan dapat direkonsiliasi.
8. Alamat pelanggan diedit: alamat pesanan yang telah dibuat tidak berubah.
9. Matriks asimetris: nilai rute dihitung sesuai arah tiap ruas.
10. Jendela tidak dapat dipenuhi atau lokasi tak terjangkau: admin melihat alasan; sistem tidak menyembunyikan konflik.
11. Kurir mencoba mengakses trip kurir lain: ditolak server.
12. Hasil optimasi tidak lebih baik: baseline layak dipertahankan dan penghematan tidak dibuat-buat.

## 16. Tahap implementasi

| Tahap | Hasil yang harus bisa didemokan |
| --- | --- |
| 1 — Fondasi | Login role, pengaturan depot, produk, alamat, stok awal |
| 2 — Pemesanan | Checkout, snapshot harga, reservasi stok, konfirmasi dan pembatalan |
| 3 — Pengiriman manual | Trip, muatan, tugas kurir, bukti, COD, kegagalan dan rekonsiliasi |
| 4 — Optimasi | Matriks jalan, baseline, nearest neighbor, 2-opt, validasi kapasitas/jendela |
| 5 — Pilot | Uji kasus kritis, observasi penggunaan, bandingkan estimasi dengan aktual |

Optimasi dibangun setelah alur pengiriman manual terbukti konsisten agar kesalahan stok dan status tidak bercampur dengan kesalahan algoritma.

## 17. Keputusan yang perlu dikonfirmasi sebelum pilot

- Apakah depot nyata menerapkan tukar 1:1 dan menerima seluruh jenis wadah yang dimaksud?
- Berapa kapasitas aman kendaraan dan durasi layanan realistis per rumah?
- Berapa radius, jendela layanan, cutoff, ongkir, dan jam operasional?
- Apakah pelanggan bersedia memakai email untuk MVP atau login nomor HP perlu diprioritaskan?
- Apakah penyedia matriks mendukung kendaraan dan wilayah depot, dengan biaya yang dapat diterima?

Sampai ada hasil validasi, implementasi mengikuti default MVP pada dokumen ini. Perubahan pada deposit wadah, pembayaran parsial, atau pengiriman sebagian harus memperbarui aturan stok dan uang terlebih dahulu.
