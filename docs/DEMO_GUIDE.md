# Panduan demo ShipX

## Status verifikasi 15 November 2026

Alur checkout multi-SKU, penetapan trip, keberangkatan, hasil berhasil/gagal, COD, pengembalian barang dan rekonsiliasi telah diuji pada database MySQL QA terisolasi. Uji paralel memeriksa retry, konflik penugasan, satu hasil/ledger/COD, pengembalian tepat satu kali serta pelepasan armada sesudah rekonsiliasi. Database QA dihapus setelah pengujian.

Benchmark menggunakan tujuan fiktif di Surabaya serta matriks Valhalla aktif. Hasilnya adalah estimasi model jalan pada jadwal simulasi. Waktu perjalanan fisik, ketepatan ETA dan perilaku GPS saat layar terkunci masih menunggu uji lapangan pengguna.

| Skenario | Perjalanan baseline | Perjalanan terpilih | Pengurangan estimasi |
| --- | --- | --- | --- |
| 10 tujuan Reguler | 130 menit | 89 menit | 31,54% |
| 20 tujuan, termasuk 4 Express | 252 menit | 158 menit | 37,30% |

Rute terpilih mencakup setiap tujuan sekali, memenuhi jendela layanan, dan mempunyai pratinjau jalan sampai kembali ke depot. Skor algoritma mengutamakan waktu penyelesaian Express, kemudian waktu perjalanan dan waktu kembali. Hasil pengurangan waktu dapat berubah mengikuti fixture, graph serta lokasi depot. Laporan mesin tersimpan di `backend/work/demo-verification/route-benchmark.json` sesudah benchmark dijalankan.

## Menyiapkan laptop

1. Aktifkan MySQL melalui Laragon.
2. Dari folder utama project jalankan perintah berikut.

```powershell
.\scripts\start-demo.ps1
```

Launcher memeriksa koneksi database, migration yang sudah diterapkan, konfigurasi depot, aset web dan cakupan peta. Routing, Laravel pada `0.0.0.0:8000`, serta scheduler berjalan di latar belakang. Server Laravel milik project yang masih terikat ke localhost dimulai ulang agar bisa diakses HP. Menjalankan launcher berulang memakai layanan yang tersedia. Dua peluncuran bersamaan diserialisasi dengan mutex per workspace. Log berada pada `backend/storage/logs/demo-api*.log`, `demo-scheduler*.log` dan `backend/work/routing-demo/server*.log`.

Web admin tersedia di `http://127.0.0.1:8000/admin`. Launcher mencetak alamat API Wi-Fi laptop. Sambungkan HP ke Wi-Fi yang sama dan cocokkan alamat API dengan APK. Build APK lokal terakhir memakai `http://192.168.101.158:8000/api/v1`. Uji alamat health dari browser HP sebelum membuka ShipX. Izin firewall Windows untuk jaringan lokal diperlukan jika akses HP terhalang.

Jika lokasi atau radius depot berubah, perluas graph terlebih dahulu, kemudian ulangi launcher.

```powershell
python scripts/routing-demo/prepare.py --depot
.\scripts\start-demo.ps1
```

Penyiapan graph memerlukan internet. Radius depot ditambah buffer jalan 3 km. Graph baru diaktifkan setelah pembangunan berhasil. Dataset ID mencakup data OSM serta versi script server agar cache dan proses aktif mengikuti perubahan perilaku routing. Ubin peta OpenStreetMap juga memerlukan internet saat demo.

## Skenario demonstrasi

1. Admin memeriksa depot, nomor telepon, stok, kurir dan kapasitas kendaraan. Siapkan jadwal 14 hari jika slot yang diperlukan belum tersedia.
2. Customer menyimpan alamat dalam wilayah layanan, memilih dua SKU, layanan Express/Reguler, jadwal serta membuat pesanan. Catat nomor pesanan dan total COD.
3. Admin mengonfirmasi pesanan, membuat draft trip untuk jadwal tersebut, menghitung rekomendasi jalan dan membandingkan rute awal dengan hasil optimasi.
4. Admin menerapkan rute, menetapkan kurir/kendaraan dan meninjau keberangkatan serta penanganan barang.
5. Kurir membuka trip saat rencana keberangkatan berlaku, mengonfirmasi muatan dan memulai trip. Senin–Jumat beroperasi 08.00–17.00. Sabtu, Minggu serta libur nasional beroperasi 09.00–16.00.
6. Kurir membuka navigasi, mengizinkan lokasi presisi/notifikasi, kemudian customer membuka Lacak pengiriman dan admin membuka Monitor kurir.
7. Selesaikan satu tujuan dengan foto bukti serta COD sesuai tagihan. Catat tujuan lainnya sebagai gagal dengan alasan untuk menunjukkan alur barang kembali.
8. Admin menerima barang kembali, mengisi jumlah layak jual/karantina dan uang aktual, menyetujui rekonsiliasi, lalu memeriksa trip completed serta laporan/CSV.
9. Periksa notifikasi customer/kurir dan tombol Hubungi penerima/Hubungi depot. Nomor depot diisi melalui pengaturan admin. Kotak masuk diperbarui selama aplikasi aktif.

## Uji tracking fisik yang masih menunggu

- Gunakan trip in_progress dan biarkan halaman navigasi kurir terbuka. Keluar halaman tersebut mengakhiri sesi berbagi lokasi.
- Berjalan beberapa puluh meter dalam jangkauan Wi-Fi laptop. Bandingkan pergerakan titik pada Monitor admin atau perangkat customer.
- Matikan layar HP selama sekitar satu menit, lalu periksa apakah waktu pembaruan GPS terus berubah.
- Putuskan Wi-Fi HP sementara. Posisi lama ditandai sesudah 60 detik dan cache berakhir setelah 120 detik. Sambungkan kembali dan periksa pembaruan lokasi.
- Catat waktu, hasil tiap langkah, model HP dan selisih ETA terhadap waktu tiba. Pengujian ini memerlukan tindakan fisik pengguna.

## Mengulang pemeriksaan otomatis

Jalankan dari folder utama. Launcher perlu berhasil sebelum benchmark jalan.

```powershell
php scripts/verify-reconciliation-mysql.php
php scripts/verify-route-benchmark.php
python scripts/routing-demo/test_prepare.py
python scripts/routing-demo/test_server.py
```

Script rekonsiliasi memakai database QA acak yang dibersihkan otomatis. Benchmark hanya membaca konfigurasi depot dan menghitung tujuan fiktif. Pengujian server Python memakai koordinat regresi Surabaya sehingga graph aktif harus mencakup fixture tersebut. Pengujian aplikasi lengkap tersedia melalui `php artisan test` dari backend dan `flutter test` dari mobile.
