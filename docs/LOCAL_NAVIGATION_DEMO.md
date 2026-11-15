# Navigasi lokal untuk demo ShipX

Pengguna memilih demo lokal setelah penyiapan billing Google tidak berhasil. Flutter memakai flutter_map/OpenStreetMap dan Laravel meminta rute ke Valhalla 3.9.1 pada 127.0.0.1:8002. Runtime Python 3.14.10 serta graph jalan berada di backend/work/routing-demo yang diabaikan Git.

## Menjalankan demo

1. Aktifkan MySQL melalui Laragon dan jalankan Laravel seperti biasa pada0.0.0.0:8000.
2. Dari root project, jalankan `./scripts/routing-demo/start.ps1`. Server routing berjalan di latar belakang pada laptop.
3. Hubungkan HP dan laptop ke Wi-Fi yang sama. APK lokal memakai API192.168.101.158:8000/api/v1 pada build yang diuji. Jika IP laptop berubah, bangun/pasang ulang dengan API_BASE_URL yang sesuai.
4. Login kurir, buka trip, tekan Peta tujuan lalu Lihat rute atau Mulai navigasi. Izinkan lokasi ketika diminta.

Assigned menampilkan pratinjau dari depot ke tujuan pertama. In_progress mengikuti GPS foreground, memperbarui belokan dan menghitung ulang setelah tiga posisi akurat berturut-turut keluar jalur. Jeda perhitungan ulang minimal 20 detik. Awaiting_reconciliation mengarahkan kembali ke depot. Tombol Kembali ke detail trip mengembalikan kurir ke alur pencatatan hasil, foto bukti dan COD yang dilakukan kurir.

Navigasi kurir kini memakai peta layar penuh, panel belokan mengambang, jarak belokan, panah posisi mengikuti arah gerak, estimasi tiba serta panel penerima. Panel dapat digulir pada landscape dan ukuran font besar. Android memulai foreground service lokasi ketika navigasi dibuka pada layar aktif dan meminta izin notifikasi padaAndroid13+. Stream tetap berjalan saat aplikasi diminimalkan atau layar dimatikan. Keluar dari halaman navigasi menghentikan stream dan berbagi lokasi. Trip/rute/akses diperiksa setiap15detik, termasuk saat navigasi aktif di latar belakang. Fix akurat maksimal40meter dipakai untuk progres, rute ulang dan berbagi posisi. Koneksi terputus diberi pesan dan dicoba kembali, pencabutan akses mengakhiri sesi.

Kurir memulai trip, membuka Peta tujuan lalu Mulai navigasi untuk membagikan lokasi pengiriman. Customer membuka detail pesanan out_for_delivery lalu Lacak pengiriman. Lokasi dikirim maksimal sekali6detik dan dibaca customer setiap10detik saat halaman terbuka. Fix60detik diberi label lama, cache terakhir berakhir120detik. ETA jalan tersedia ketika pesanan merupakan tujuan pending pertama. Layanan routing harus aktif untuk ETA. Titik tujuan customer berasal dari alamat snapshot pesanan. Penayangan posisi kurir mengikuti kepemilikan pesanan, alokasi, rute dan token kurir yang masih berlaku. Data posisi terakhir memakai cache persisten yang tersedia, konfigurasi lokal memakai file.

Rujukan implementasi Android tersedia pada [aturan memulai foreground service](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start) dan [geolocator](https://pub.dev/packages/geolocator). Build manifest menyertakan FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION serta POST_NOTIFICATIONS. Uji jalan dan layar terkunci pada HP nyata perlu dilakukan untuk memverifikasi kebijakan baterai perangkat.

## Data dan cakupan

Graph demo memakai data OpenStreetMap yang diunduh melalui Overpass. Cakupan aktif dapat diperiksa melalui `/health` pada port8002. Titik awal serta tujuan harus berada dalam cakupan tersebut. Mesin mendukung mode motorcycle dan auto sesuai snapshot kendaraan. Estimasi memakai data jalan dan model kecepatan Valhalla. Ubin peta OpenStreetMap masih diambil melalui internet. Instruksi bahasa Indonesia dibentuk dari jenis manuver serta nama jalan hasil Valhalla.

Setelah depot dikonfigurasi, jalankan `python scripts/routing-demo/prepare.py --depot` dari root. Script membaca lokasi/radius depot tanpa mengubahnya dan menambahkan buffer jalan3km. MySQL perlu aktif ketika membaca depot. Perubahan lokasi atau radius depot dapat diselaraskan dengan mengulang perintah ini, kemudian menjalankan `./scripts/routing-demo/start.ps1`.

Parameter `--bbox SOUTH WEST NORTH EAST` tetap tersedia untuk area khusus. Tanpa parameter, area awal adalah latitude-7.32hingga-7.23 dan longitude112.75hingga112.84. Runtime berada pada folder yang sama, sedangkan graph area baru dibangun di subfolder datasets terpisah. `active.json` baru diganti setelah pembangunan berhasil. Graph sebelumnya tetap tersimpan. Script start memeriksa fingerprint dataset dan memulai ulang proses routing milik project ketika dataset berubah. Proses lain pada port8002 menghasilkan pesan konflik. File graph serta pointer aktif diabaikan Git, sehingga penyiapan diperlukan pada laptop lain.

Log routing berada di backend/work/routing-demo/server.log dan server-error.log. Health check tersedia pada http://127.0.0.1:8002/health. Server hanya menerima koneksi loopback. HP mengakses Laravel, lalu Laravel meneruskan permintaan rute setelah pemeriksaan role serta kepemilikan trip.

## Kontrak tambahan

Mesin yang sama kini melayani ongkir dan waktu siap Express, matriks optimasi serta pratinjau jalan admin. Jalankan server routing sebelum mencoba checkout. Halaman Depot menyediakan status mesin dan pemeriksaan apakah seluruh radius layanan tercakup bbox graph. Alamat harus lolos radius depot, cakupan graph serta ketersediaan jalan. Quote gagal503 ketika mesin mati dan bisa dicoba kembali setelah server aktif. Mode ongkir awal memakai motor, sementara trip/navigasi mengikuti kendaraan yang ditugaskan. Durasi memakai model kecepatan pada data jalan statis.

Server lokal mempunyai POST /matrix untuk matriks seluruh arah hingga21 titik dan POST /route hingga22 titik, termasuk depot kembali. GET /health menyertakan bbox dan dataset_id dari fingerprint PBF serta script server. Laravel menyimpan hasil per kombinasi dataset, titik, kendaraan dan endpoint selama30menit, dengan pemeriksaan health berumur5detik. Dataset atau perilaku server baru membentuk kunci cache baru. Durasi optimasi dibulatkan ke atas ke menit per ruas untuk menyesuaikan kontrak tinjauan admin. Nilai ringkasan peta menyajikan durasi perjalanan sebelum pembulatan per ruas. Instruksi tes browser baru menggunakan `php scripts/serve-checkout-qa.php roads` dari root lalu `npx playwright test road-planning.spec.ts` dari backend. Mode `trips` mempertahankan fixture ongkir lama untuk tes input matriks manual. Database QA terisolasi dibersihkan melalui `php scripts/serve-checkout-qa.php stop`.

CostMatrix memakai `allow_second_pass=true` agar endpoint depot yang tersedia melalui route API juga dapat dijangkau matriks. Regresi diuji dua arah untuk motor dan mobil. Pengaturan ini mengikuti opsi [konfigurasi Valhalla](https://github.com/valhalla/valhalla/blob/3.9.1/scripts/valhalla_build_config). Panduan menjalankan seluruh layanan dan skenario uji terdapat di [DEMO_GUIDE.md](DEMO_GUIDE.md).

POST /api/v1/courier/trips/{id}/navigation memakai bearer kurir aktif dan body latitude/longitude posisi awal. Tujuan pertama yang belum final atau depot saat kembali ditentukan server. Response data memuat provider, road_source, route_version_id, target_id/target, travel_mode, guidance, shape polyline6, distance_m, duration_seconds, maneuvers dan attribution. Permintaan dibatasi30permenit. Tujuan di luar akses menghasilkan404, koordinat invalid422, mesin lokal mati503 ROUTING_OFFLINE, lokasi di luar bbox422 ROUTING_OUTSIDE_AREA dan jalan tidak ditemukan422 ROUTE_NOT_FOUND.
