# Navigasi lokal untuk demo ShipX

Pengguna memilih demo lokal setelah penyiapan billing Google tidak berhasil. Flutter memakai flutter_map/OpenStreetMap dan Laravel meminta rute ke Valhalla 3.9.1 pada 127.0.0.1:8002. Runtime Python 3.14.10 serta graph jalan berada di backend/work/routing-demo yang diabaikan Git.

## Menjalankan demo

1. Aktifkan MySQL melalui Laragon dan jalankan Laravel seperti biasa pada0.0.0.0:8000.
2. Dari root project, jalankan `./scripts/routing-demo/start.ps1`. Server routing berjalan di latar belakang pada laptop.
3. Hubungkan HP dan laptop ke Wi-Fi yang sama. APK lokal memakai API192.168.101.158:8000/api/v1 pada build yang diuji. Jika IP laptop berubah, bangun/pasang ulang dengan API_BASE_URL yang sesuai.
4. Login kurir, buka trip, tekan Peta tujuan lalu Lihat rute atau Mulai navigasi. Izinkan lokasi ketika diminta.

Assigned menampilkan pratinjau dari depot ke tujuan pertama. In_progress mengikuti GPS foreground, memperbarui belokan dan menghitung ulang setelah tiga posisi akurat berturut-turut keluar jalur. Jeda perhitungan ulang minimal 20 detik. Awaiting_reconciliation mengarahkan kembali ke depot. Tombol Kembali ke detail trip mengembalikan kurir ke alur pencatatan hasil, foto bukti dan COD yang dilakukan kurir.

Saat aplikasi ditinggalkan, navigasi aktif dijeda dan stream GPS dihentikan. Coba lagi memeriksa penugasan dan menghitung rute baru dari lokasi terbaru. Halaman memeriksa trip setiap 15 detik ketika terlihat/foreground dan menghapus data navigasi saat akses dicabut atau rute/tujuan berubah. Pembaruan progres dan rute ulang menggunakan posisi dengan akurasi maksimal 40 meter.

## Data dan cakupan

Graph demo memakai data OpenStreetMap yang diunduh melalui Overpass untuk area sekitar depot Surabaya, latitude -7.32 hingga -7.23 dan longitude 112.75 hingga 112.84. Titik awal serta tujuan harus berada dalam cakupan ini. Mesin mendukung mode motorcycle dan auto sesuai snapshot kendaraan. Estimasi memakai data jalan dan model kecepatan Valhalla. Ubin peta OpenStreetMap masih diambil melalui internet. Instruksi bahasa Indonesia dibentuk dari jenis manuver serta nama jalan hasil Valhalla.

Penyiapan pertama dijalankan dari root menggunakan `python scripts/routing-demo/prepare.py`. Script menyiapkan runtime khusus project dan graph area tersebut. Parameter `--bbox SOUTH WEST NORTH EAST` tersedia pada penyiapan pertama. Script memeriksa kecocokan cakupan ketika dijalankan kembali dengan graph yang tersedia.

Log routing berada di backend/work/routing-demo/server.log dan server-error.log. Health check tersedia pada http://127.0.0.1:8002/health. Server hanya menerima koneksi loopback. HP mengakses Laravel, lalu Laravel meneruskan permintaan rute setelah pemeriksaan role serta kepemilikan trip.

## Kontrak tambahan

POST /api/v1/courier/trips/{id}/navigation memakai bearer kurir aktif dan body latitude/longitude posisi awal. Tujuan pertama yang belum final atau depot saat kembali ditentukan server. Response data memuat provider, route_version_id, target_id/target, travel_mode, guidance, shape polyline6, distance_m, duration_seconds, maneuvers dan attribution. Navigation tidak mengubah route_version, jadwal pelanggan, matriks admin, stok atau status trip. Permintaan dibatasi30permenit. Tujuan di luar akses menghasilkan404, koordinat invalid422, mesin lokal mati503 ROUTING_OFFLINE dan rute di luar cakupan422 ROUTE_NOT_FOUND.
