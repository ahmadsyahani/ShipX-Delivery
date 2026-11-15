# Handoff ShipX untuk Codex

## Uji GPS fisik ditunda pengguna — 15 November 2026

Pengguna memulai uji GPS, kemudian secara eksplisit memilih “Lanjutkan nanti”. Hentikan pemantauan GPS sampai pengguna melanjutkan. HP I2405 tersambung melalui192.168.101.183:41013; port ini adalah koneksi langsung, pairing tidak diperlukan. Aplikasi kurir merupakan clone Android user999, akun Prabo Who id2. Pemilih com.vivo.doubleinstance dapat muncul ketika membuka aplikasi. Laravel/routing/scheduler telah siap melalui start-demo.ps1.

Database awal tidak memiliki kendaraan, slot hari ini, pesanan atau trip aktif. Disiapkan customerid4 bernama UJI GPS15November, alamat uji dekat depot, kendaraanid1 kodeUJI-GPS-20261115 dan satu slot12.00–13.00. Tripid1 berangkat11.15 dan tripid2 berangkat11.22, masing-masing satu item productid1 dengan totalCODRp5.503. Keduanya dimulai dan ditandai delivered oleh pengguna melalui HP. Pengguna menyatakan ada penyerahan barang/uang, sehingga perlakukan hasil serta ledger tersebut sebagai data bisnis dan jangan mereset/kompensasi secara otomatis. Trip1 sudah completed setelah pengguna merekonsiliasi. Trip2 masih awaiting_reconciliation pada pemeriksaan terakhir, dengan COD yang perlu dicatat melalui rekonsiliasi biasa. Jangan mengisi uang aktual atau menyetujui penerimaan atas asumsi.

Server belum menerima POST location pada kedua percobaan. Sampel pelacakan0, admin/customer sempat waiting saat in_progress, lalu unavailable sesudah hasil final. Navigasi jalan dan foreground service Android terlihat aktif. Log menunjukkan sesi lokasi diakhiri lewat DELETE sebelum hasil delivered, sehingga uji60–90detik pada satu halaman navigasi belum teramati. Pengguna menyatakan sudah berjalan dengan navigasi terbuka, tetapi data server belum membuktikan tracking GPS, screen-lock atau pemulihan koneksi. Penyebab belum dipastikan dan tidak ada perubahan source aplikasi pada tahap ini.

Fixture serta observer lokal berada pada backend/work/gps-physical-20261115, diabaikan Git. state.json berisi trip2/order2/customer4/admin1/courier2, attempt-1-state.json mencatat trip1. samples.json dan attempt-1-samples.json kosong. prepare.php memakai alur quote/checkout/confirm/optimasi/assign/review biasa, observe.php memeriksa TripTracking admin/customer dan menghitung sampel tanpa mencetak koordinat. Melanjutkan perlu merekonsiliasi trip2 sesuai uang/barang aktual, kemudian menyiapkan satu trip baru dan membiarkan navigasi tetap terbuka hingga server menerima GPS sebelum langkah berjalan/layar terkunci/koneksi putus diuji. Source tetap develop, belum commit/push.

## Validasi dan launcher demo — 15 November 2026

Pengguna menyetujui penyempurnaan menjelang demo, kemudian memilih tes otomatis dahulu dan uji GPS fisik menyusul. Uji GPS bergerak, layar terkunci, koneksi terputus dan selisih ETA terhadap perjalanan nyata tetap belum dilakukan.

`scripts/start-demo.ps1` menambahkan satu perintah persiapan setelah MySQL aktif di Laragon. `scripts/check-demo.php` memeriksa koneksi, migration dan depot tanpa menjalankan setup ulang. Launcher memeriksa aset web/cakupan graph, memakai routing yang tersedia, menyiapkan Laravel pada0.0.0.0:8000 dan scheduler. Server utama sebelumnya hanya mendengarkan127.0.0.1, sehingga launcher memulai ulang proses milik project untuk akses HP. Mutex per workspace menserialisasi dua peluncuran bersamaan. Pengujian berulang dan paralel mempertahankan satu listener8000 serta satu scheduler. Kegagalan preflight diuji dengan nama database tidak tersedia pada environment subprocess, lalu konfigurasi asli diverifikasi kembali. Log berada pada storage/logs/demo-api*.log dan demo-scheduler*.log.

Benchmark menemukan matriks motor dari pin depot gagal dua arah meskipun route tunggal berhasil. Valhalla CostMatrix allow_second_pass sebelumnya false. Runtime serta generator config sekarang mengaktifkannya, dan regresi native motor/mobil lolos. Fingerprint dataset kini mencakup hash PBF serta script server, sehingga perubahan perilaku server memulai ulang proses milik project dan mengganti kunci cache matriks lama. Tidak ada perubahan koordinat/radius depot.

`scripts/verify-route-benchmark.php` membaca depot, memakai tujuan fiktif Surabaya serta matriks Valhalla aktif. Sepuluh tujuan Reguler menghasilkan estimasi perjalanan130menit menjadi89menit, pengurangan31,54%. Dua puluh tujuan termasuk4Express menghasilkan252menit menjadi158menit, pengurangan37,30%. Seluruh tujuan muncul sekali, jadwal layak, skor terpilih tidak memburuk dan route preview mencakup tujuan sampai kembali. Waktu optimizer pada run yang diamati sekitar0,2–0,4detik untuk10tujuan dan1,4–2,6detik untuk20tujuan. Angka tersebut merupakan hasil skenario simulasi, bukan penghematan atau waktu tiba yang terukur di jalan. Laporan JSON tersimpan di backend/work/demo-verification/route-benchmark.json, diabaikan Git dan dapat dibuat ulang.

144tes backend/2163assertions,114tes Flutter dan analyzer lolos. Tiga tes Python persiapan serta dua tes integrasi server native lolos. Browser QA MySQL dengan graph aktif lolos untuk checkout jalan, preview/apply optimasi, peta dan assignment serta API kurir. Script verify-reconciliation-mysql.php lolos untuk alur multi-SKU sampai completed, hasil delivered/failed, retry/race start/assignment/COD/rekonsiliasi, saldo ledger dan pelepasan claims. Semua database QA dibersihkan setelah uji. Panduan terkini ada di docs/DEMO_GUIDE.md, README dan status PRD diperbarui. .env SHA256 tetapDBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C. Source lokal develop, belum commit/push. APK yang terpasang tetap kompatibel karena perubahan tahap ini pada tooling/backend routing.

## Cakupan graph sesuai depot — 15 November 2026

Pengguna meminta perbaikan peringatan radius depot di luar peta sebelum demo. Depot utama berada pada-7.2771739,112.7921963 dengan radius10000meter, sedangkan graph lama bbox[-7.32,112.75,-7.23,112.84] hanya mencakup sebagian radius. prepare.py menambah --depot yang membaca konfigurasi depot dan membangun bbox seluruh radius dengan buffer jalan3km. Graph baru disimpan dalam datasets terpisah, active.json dipindahkan setelah build berhasil, dan runtime/server membaca graph aktif dengan kompatibilitas layout lama. start.ps1 memeriksa fingerprint dataset dan hanya menghentikan proses Python/server milik project ketika perlu memuat dataset baru. Menjalankan start ulang dengan dataset sama idempotent.

Graph utama baru berhasil dibangun pada backend/work/routing-demo/datasets/9fd8a489ebc27ad7, bbox[-7.394,112.674,-7.16,112.91], dataset_id a9cefff6243fd70b243ca691ebf27c3764d662e238237f7bf766544295c2cab9. Server8002 telah dimulai ulang dan controller status Laravel mengembalikan available=true serta service_area_covered=true. Rute motor dari depot ke-7.277,112.72 yang berada di luar bbox lama berhasil9,014km/726,321detik.144tes backend/2163assertions dan3tes Python lolos. Radius depot10000meter dipertahankan, .env memiliki hash sebelumnya. Graph diabaikan Git, laptop baru perlu menyiapkannya. Setelah perubahan lokasi/radius, jalankan python scripts/routing-demo/prepare.py --depot lalu scripts/routing-demo/start.ps1. Setelah restart laptop, start.ps1 mengaktifkan graph yang sudah tersedia. Uji tracking fisik tetap tertunda sesuai permintaan pengguna sebelumnya. Source lokal develop, belum commit/push.

## Monitor, laporan, notifikasi dan kontak — 14 November 2026

Pengguna meminta uji tracking fisik, monitor admin, dashboard/laporan, notifikasi dan tombol kontak. Uji fisik ditunda secara eksplisit oleh pengguna sampai besok karena belum ada trip berjalan. Jangan menandai perjalanan nyata atau layar terkunci sebagai terverifikasi. Langkah berikutnya adalah menyiapkan pesanan uji pada jadwal operasional, menetapkan trip ke akun kurir HP, mulai trip lalu membandingkan gerakan GPS pada customer/admin dan kondisi layar terkunci.

Migration000016 telah diterapkan pada MySQL shipx setelah pengguna menyalakan Laragon. Menambah notifications dan nomor depot opsional. OrderObserver/TripObserver membuat notifikasi database dalam transaksi domain, termasuk penetapan order yang sebelumnya memakai bulk update. API notifikasi milik akun sendiri memiliki pagination, unread count, tandai satu/semua dibaca. Flutter menambah bell, badge, inbox dan snackbar saat status baru tiba, polling15detik pada foreground. Push saat aplikasi ditutup belum diterapkan. Tombol kontak kurir membuka dialer untuk penerima serta depot. Admin perlu mengisi Telepon depot agar tombol depot muncul.

Web /admin/monitor memakai polling10detik, Leaflet, lokasi terkini/terakhir, progres serta tujuan selanjutnya. Validasi token/kurir/rute GPS tetap berlaku dan token/sessionGPS tidak diekspos. Dashboard menambah trip aktif, pesanan terlambat, gagal hari ini dan COD belum disetor, refresh15detik. /admin/reports menyediakan periode tanggal pengantaran maksimal366hari, status terkini, COD/setoran/selisih dan ekspor CSV yang melindungi formula spreadsheet.

143tes backend/2157assertions dan114tes Flutter lolos, analyzer bersih. Browser QA MySQL terisolasi lolos untuk dashboard, monitor kosong/assigned, laporan berisi pesanan/filter/CSV dan penyimpanan telepon depot pada1440/390/320px. Preview notifikasi dengan font asli320/390/820px lolos. Database QA dibersihkan. APK arm64 Wi-Fi dipasang melalui192.168.101.183:45451 dengan Success dan lastUpdateTime14November23:34:52, kemudian ShipX kurir dibuka. Hash APK build dan unduhan backend/public/build/shipx-wifi.apk identik81A8AD2B9934C74BB800234E0171A20C9CAC9881409D56FE50C0E9E84FFF5396. Uji fisik tetap tertunda sesuai pengguna. .env identik dengan SHA256DBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C. Source lokal develop, belum commit/push.

## Navigasi layar penuh dan pelacakan customer — 14 November 2026

Pengguna meminta UI navigasi kurir seperti referensi peta layar penuh serta customer bisa melacak posisi kurir. Navigasi kini memakai panel belokan mengambang, jarak belokan, panah arah gerak dengan peta mengikuti heading, sisa waktu/jarak/estimasi tiba dan panel penerima. NavigationPanels menjaga panel dapat digulir pada landscape/font besar. Order detail out_for_delivery menambah Lacak pengiriman, menampilkan kurir, tujuan pesanannya sendiri, waktu pembaruan dan ETA jalan ketika pesanan menjadi pending pertama.

DeviceLocation.watch memakai AndroidSettings dengan foreground notification, wake/Wi-Fi lock dan interval5detik. MainActivity meminta POST_NOTIFICATIONS melalui MethodChannel ketika navigasi dimulai, manifest menyertakan izin foreground service lokasi. Stream berlanjut saat app diminimalkan/layar mati, assignment dicek15detik juga pada background. Sesi berbagi hanya untuk in_progress, mengirim fix akurat≤40meter paling sering6detik. Keluar halaman, trip/route berubah atau akses dicabut menghentikan GPS dan sesi. Saat menuju depot GPS tetap untuk navigasi. Masa berlaku posisi serta UI stale menangani koneksi putus/proses Android berhenti. Uji GPS jalan nyata dan layar terkunci pada HP masih diperlukan.

TripTracking/TripTrackingController menambah POST+DELETE courier/trips/{id}/location dan GET orders/{id}/tracking. Posisi terakhir memakai cache persisten120detik, penanda sesi berhenti180detik, lock pertrip dan versi rute. Jam fix dibatasi2menit lampau/30detik mendatang. Fix lama diabaikan, stop sesi lama menjaga sesi baru. Token kurir harus tetap berlaku saat customer membaca, alokasi/order/kurir/rute diperiksa sebelum dan sesudah routing. Customer hanya melihat lokasi order out_for_delivery pada stop pending miliknya. Live60detik, stale hingga cacheexpired, kemudian waiting. Delivered/failed/revoked/unavailable membersihkan tampilan. ETA hanya untuk pending pertama dan routing yang berhasil. Skema bisnis memakai tabel yang tersedia. Konfigurasi cache utama file, .env SHA-256 tetapDBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C.

141tes backend/2042assertions dan110tes Flutter lolos. Analyzer bersih, APK arm64 dibangun dan merged manifest memverifikasi GeolocatorLocationService type location serta izin. Tes mencakup owner/role, sesi/urutan fix, kedaluwarsa, stop/replay, tokenlogout, hasil delivered, background lifecycle, polling customer dan data dicabut. Dua tes tracking/45assertions juga lolos pada MySQL dengan cache database pada database QA acak terisolasi, kemudian QA dihapus. UI320/390/820px dengan font asli diperiksa, landscape740×360/font1,5 lolos. APK Wi-Fi final dipasang melalui192.168.101.183:45451 dengan Success dan lastUpdateTime14November18:04:39. Hash APK build dan unduhan backend/public/build/shipx-wifi.apk cocok. Laravel8000 serta Valhalla8002 healthOK. Uji GPS fisik dan layar terkunci pada HP tetap perlu dilakukan pengguna pada trip in_progress.

## Menu Ringkasan kurir — 14 November 2026

Pengguna meminta tambahan menu yang membantu kurir. Dipilih Ringkasan dengan progres tujuan, sisa tujuan, terkirim/gagal, COD diterima, COD tujuan tersisa dan shortcut lanjut trip/setoran. Cakupan statistik adalah trip aktif milik kurir, mencakup awaiting_reconciliation. COD memakai ledger payment_collections dan trip completed keluar dari perhitungan sesudah rekonsiliasi. GET /api/v1/courier/summary memakai middleware kurir aktif serta transaksi baca, tanpa migration. Tab Trip/Ringkasan/Akun terhubung melalui RoleHome.

Polling hanya pada tab aktif/foreground15detik dan refresh setelah kembali dari detail. Offline mempertahankan data terakhir dengan pesan, pencabutan akses membersihkan data.139tes backend/1997assertions dan104tes Flutter lolos, analyzer bersih. Tes mencakup dua hasil pengiriman, COD, rekonsiliasi, kurir lain/customer/nonaktif, shortcut, empty state serta offline. Preview320/390/820px diperiksa dengan font asli. APK arm64 API Wi-Fi dipasang melalui192.168.101.183:45451 dengan Success dan lastUpdateTime14November17:21:56. APK unduhan lokal diperbarui. Pemeriksaan navigasi Ringkasan→detail→kembali lolos otomatis, verifikasi menu HP dilakukan pengguna saat membuka akun kurir.

## Penyelarasan jalan dan detail trip ringkas — 14 November 2026

Revisi visual lanjutan atas permintaan pengguna meminimalkan garis pada detail trip. Border luar kartu detail, garis bawaan bagian buka/tutup dan divider sebelum peta dihilangkan, dengan pemisahan melalui jarak. Preview320/390/820px diperiksa. Seluruh101tes Flutter dan analyzer lolos. APK pembaruan dipasang melalui Wi-Fi dengan Success dan lastUpdateTime14November17:05:40. APK unduhan lokal diperbarui.

Pengguna menyetujui pengerjaan berurutan dari audit web/mobile, kemudian meminta detail trip kurir diringkas, muatan otomatis dan tujuan digabung. Branch kerja develop, baseline89a29c4. Read-only audit awal menemukan hanya arsip README0001 untracked. File arsip dipertahankan.

RoadRouting kini menjadi layanan bersama untuk navigasi, ongkir, optimasi dan peta admin. Valhalla lokal menambah /matrix dan dataset_id SHA-256 PBF pada health. Mode ongkir awal dipilih motorcycle, radius layanan tetap garis lurus dan graph juga memvalidasi cakupan. Ongkir menggunakan jarak jalan, kesiapan Express menggunakan waktu persiapan ditambah durasi jalan. Quote/options/order menampilkan sumber serta waktu hitung, orders.delivery_estimate JSON nullable menyimpan snapshot. Kegagalan provider503 membatalkan klaim idempotency agar UUID dapat dicoba kembali. Perubahan alamat/depot selama perhitungan ditolak409. Migration000015 sudah diterapkan ke MySQL shipx sesudah pengguna secara eksplisit mengizinkan kolom tambahan dan menyalakan Laragon. .env SHA-256 tetapDBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C.

Optimasi admin default mengambil matriks seluruh arah dari Valhalla sesuai kendaraan, dengan pilihan input manual. Setiap ruas dibulatkan ke atas ke menit utuh agar cocok dengan kontrak tinjauan admin. Snapshot optimasi menyimpan road_source. Tinjauan yang sama dengan hasil provider memakai source provider_road_estimate, start tetap memvalidasi versi, manifest, jadwal dan expiry. Web menambah status/cakupan routing pada Depot serta peta loop depot–tujuan–depot dengan nomor, ETA dan perbandingan urutan awal. Peta hanya membaca data bisnis. Angka waktu dari peta dapat disalin ke tinjauan secara eksplisit. Flutter kurir menampilkan layanan Express/Reguler tiap tujuan. Sumber estimasi terlihat pada pengiriman, quote dan detail pesanan pelanggan.

Revisi UI kurir menggabungkan progres, info kendaraan, muatan, peta, tujuan dan pencatatan hasil dalam satu kartu. Info perjalanan serta daftar muatan berupa bagian yang dapat dibuka. Tujuan pending pertama terbuka otomatis, tujuan berikutnya menjadi aktif sesudah hasil dicatat. Jumlah SKU saat start diambil otomatis dari manifest terbaru, dengan konfirmasi Mulai trip. Pengguna meminta otomatisasi ini sehingga form hitung manual pada Flutter dihapus. Retry durable tetap mengirim payload/UUID tersimpan. Dokumen API/PRD/ERD/LOCAL_NAVIGATION_DEMO diperbarui.

138tes backend/1970assertions lolos, termasuk optimasi provider→apply→assignment→review→start→foto→dua hasil delivered/COD→rekonsiliasi completed. Tes memeriksa matriks asimetris, pembulatan, cache kendaraan, cakupan, unreachable, retry503 checkout dan perubahan alamat selama hitung. Browser MySQL QA terisolasi memverifikasi rute native nyata dengan dua alamat berbeda pada320/390/1440px, serta tiga regresi form kelompok/manual optimization/reopen/cancel. Database QA dihapus sesudah pengujian. TypeScript/build web lolos. Flutter final101tes/analyzer lolos, termasuk manifest otomatis dan polling receipt completed. Preview detail ringkas320/390/820px diperiksa dengan font nyata. Uji jalan fisik masih diperlukan untuk validasi GPS di jalan.

Laravel0.0.0.0:8000 dan routing127.0.0.1:8002 dinyalakan kembali. HP I2405 tersambung via192.168.101.183:45451. APK revisi detail trip ringkas dibangun arm64 dengan API Wi-Fi192.168.101.158:8000/api/v1, dipasang Success dengan lastUpdateTime14November16:54:33. APK unduhan lokal diperbarui. Sesudah dibuka kembali, UI hierarchy HP memverifikasi Detail trip, Siap berangkat, Muatan13item otomatis, Mulai trip, Peta tujuan, Tujuan pengantaran1 dan Total COD pada aplikasi user999. Tidak menekan start pada data bisnis pengguna. Belum ada commit/push pada pengerjaan ini.

## Navigasi Valhalla lokal untuk demo — 14 November 2026

Pengguna gagal menghubungkan billing Google dan memilih demo lokal, lalu menyetujui OpenStreetMap+Valhalla. Integrasi Google pada tahap sebelumnya diganti dengan rute lokal. Dependensi google_navigation_flutter, manifest key serta konfigurasi desugaring SDK dikembalikan ke baseline. Key lokal pengguna tetap berada di file yang diabaikan Git. Pengembangan tetap di develop.

Valhalla3.9.1 berjalan nativeWindows melalui Python3.14.10 embeddable, semuanya khusus project pada backend/work/routing-demo (ignored). Tidak memasang Docker/WSL atau mengubah Python sistem. Helper scripts/routing-demo/prepare.py memeriksa SHA-256 runtime resmi, mengunduh wheel, mengambil jalan/restriksi OSM melalui Overpass dan membangun graph area sekitar depot Surabaya(-7.32,112.75,-7.23,112.84). Overpass sempat502, retry berhasil. File PBF dibuat melalui staging. Graph dan health sudah terverifikasi, rute motor2.14km/335detik/12manuver berhasil melaluiHTTP lokal. Instruksi bahasa Indonesia dibentuk backend dari jenis manuver dan nama jalan. Server loopback127.0.0.1:8002 aktif, dapat dinyalakan ulang memakai scripts/routing-demo/start.ps1. Petunjuk di docs/LOCAL_NAVIGATION_DEMO.md.

POST /api/v1/courier/trips/{id}/navigation memvalidasi kurir aktif/pemilik trip/status/koordinat dan memilih pending pertama atau depot saat kembali dari snapshot server. Response polyline6, manuver, jarak/waktu, target dan route_version_id. Error mesin mati503, di luar cakupan422 dan akses404/403. Permintaan dibatasi30permenit. Navigasi merupakan operasi baca data bisnis, terpisah dari konfirmasi/start/hasil/COD/rekonsiliasi dan matriks jalan admin.

Flutter memakai peta OSM dengan garis jalan hijau, penanda depot/tujuan/belokan, pratinjau assigned dari depot dan GPS foreground pada in_progress/pulang. Progres diproyeksikan ke ruas jalan dengan batas pencarian agar persimpangan tidak melompati rute. Tiga posisi akurat yang keluar jalur memicu rute ulang, jeda minimal20detik. Lokasi buruk diabaikan untuk progres/reroute. Akses/tujuan/rute diperiksa setiap15detik pada layar aktif dan sekali lagi setelah perhitungan. Keluar app menjeda GPS. Tombol kembali mengembalikan kurir ke detailtrip. Hak akses dicabut menghapus tampilan peta dan menghentikan stream. MapAttribution responsif memperbaiki overflow copyright pada320px/teks1.5.

132tes backend/1895assertions dan100tes Flutter lolos, analyzer bersih. Tes GPS simulasi memverifikasi belokan/reroute/pencabutan akses dan pratinjau depot tidak membacaGPS. Layout320/390/820px dengan font nyata diperiksa. .env SHA-256 tetapDBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C. Belum ada commit/push. Uji jalan fisik belum dilakukan.

APK final berhasil dipasang melalui debug nirkabel192.168.101.183:45291 denganSuccess, lastUpdateTime14November00:19:52. APK publik lokal diperbarui. Pratinjau nyata HP pada trip assigned berhasil menghitung rute1.6km/estimasi4menit, menampilkan garis mengikuti jalan, mark belokan112m dan instruksi Belok kiri menuju Jalan Raya ITS. Screenshot mobile/build/ui-preview/local-route-device.png. Laravel→ValhallaHTTP juga diuji langsung dan mengembalikan rute2.14km/instruksiIndonesia. Profil kurir HP memakai aplikasi gandaVivo(user999), sehingga peluncuran ADB bisa masuk wrapper com.vivo.doubleinstance dan XMLsemantics terbatas. Pengguna membuka ShipX kurir langsung untuk verifikasi. Revisi terakhir memakai titikGPS sampai arah gerak valid tersedia, lalu panah mengikuti heading. Dua tes simulasi terkait lolos lagi. Routing server tetap aktif dan healthOK. File APK/XML/screenshot sementara di HP dibersihkan.

## Integrasi Google Navigation SDK — 13 November 2026

Pengguna menyimpan GOOGLE_MAPS_API_KEY pada mobile/android/local.properties. Keberadaan/nonempty diperiksa tanpa menampilkan nilai, Git mengabaikan file tersebut. Screenshot Cloud menunjukkan Android apps dan2API restrictions. Hak akses key/billing belum dapat dinyatakan berhasil sampai rute Google dimuat di HP.

Source menambah google_navigation_flutter0.12.1, membaca key melalui manifest placeholder dari local.properties, minSdk minimal24 dan core desugaring NIO2.1.5. Konfigurasi AGP9/Kotlin2.3/Gradle9.1 bawaan sudah sesuai. TripNavigationTarget memilih pending pertama (tanpa melompati pin invalid), travel_mode snapshot motorcycle/car, depot saat awaiting_reconciliation, serta menonaktifkan completed. Halaman Google terpisah dari overview OSM. Assigned memakai pratinjau rute, in_progress/pulang memakai guidance. Tidak menulis status order/start/hasil dan tidak mengganti matriks estimasi admin.

Layar Google memeriksa API sebelum dan sesudah routing, GPS eksplisit setelah tombol, ketentuan Google melalui dialog SDK, menunggu road-snapped location, native route/maneuver UI, pemeriksaan assignment foreground15detik dan cleanup saat keluar/background/perubahan tujuan/akses dicabut. Navigasi dijeda saat aplikasi ditinggalkan dan dapat dicoba lagi. Native SDK belum diuji jalan di HP.93tes Flutter lolos sebelum pemeriksaan akhir, build pertama native SDK masih berlangsung saat catatan ini ditambahkan.

Hasil lanjut:95tes Flutter dan analyzer akhir lolos. APK arm64 native SDK dibangun (build pertama413detik, berikutnya29detik), diverifikasi berisi kode Dart/native navigasi, dipasang melalui Wi-Fi denganSuccess dan lastUpdateTime13November23:17:15. APK unduhan lokal diperbarui. Pengguna menyetujui dialog ketentuan Google di HP. Pratinjau rute assigned masih mengembalikan NavigationRouteStatus.networkError. Koneksi HP viaDNS/ping serta HTTPS ke maps.googleapis.com, clients4.google.com, mobilemaps-pa.googleapis.com dan mapsmobilesdks-pa.googleapis.com berhasil. Nilai key di merged manifest cocok dengan local.properties dan formatnya sesuai, tanpa menampilkan nilai. Screenshot Cloud menunjukkan Maps SDK for Android +Navigation SDK sertaAndroid apps, awalanSHA-1 sesuai, package/SHA lengkap terpotong. Status billing belum dikonfirmasi dan sudah ditanyakan. Jangan menyebut navigasi Google berhasil sebelum rute nyata terkonfirmasi. Source lokal develop tanpa commit/push dan .env dipertahankan. Gambar peta OSM sebelumnya terverifikasi, petunjuk Google aktif di dalam halaman tersendiri.

## Redesign kurir dan persiapan navigasi — 13 November 2026

Pengguna memilih navigasi lengkap tetap di dalam ShipX. Google Cloud/billing/API key belum tersedia dan pengguna meminta panduan penyiapan. Panduan sudah diberikan untuk Navigation SDK Android, Maps SDK Android, pembatasan package com.example.shipx dan SHA-1 sertifikat debug lokal. Key diminta disimpan sebagai GOOGLE_MAPS_API_KEY di mobile/android/local.properties yang sudah diabaikan Git, tanpa dikirim ke chat. Integrasi Google Navigation SDK belum ditambahkan. Google Cloud dan aktivasi billing harus diselesaikan pengguna sebelum pengujian navigasi nyata. Jangan menyatakan peta tujuan sebagai navigasi lengkap.

Tampilan detail kurir menambah TripOverview hijau dengan progres hasil delivered/failed, penerima pending pertama sesuai urutan server, COD responsif dan tombol Peta tujuan. TripMapPage memakai flutter_map/OSM yang sudah tersedia, penanda depot/tujuan bernomor serta posisi foreground setelah tombol ditekan. Tidak menggambar garis jalan atau mengklaim petunjuk belokan. Koordinat invalid ditolak, halaman melakukan refresh foreground dan menghapus data trip pada401/403/404. Alur konfirmasi muatan/start/hasil/foto/COD/rekonsiliasi tetap memakai komponen yang ada. COD tiap tujuan memakai komponen responsif yang sama dengan customer.

90 tes Flutter lolos dan analyzer bersih. Pratinjau320/390/820px diperiksa, judul ringkasan dipendekkan menjadi Trip kamu agar tidak terpotong pada320px/teks1,5 serta tidak menggandakan label status Trip selesai. Tambahan tes memeriksa peta pada penugasan yang dicabut. APK arm64 API Wi-Fi dibangun dan pemasangan awal melalui192.168.101.183:44159 menghasilkanSuccess, lalu aplikasi dibuka ulang. Source lokal develop, .env identik. Pengujian navigasi jalan dan akun kurir di HP masih menunggu konfigurasi Google Cloud serta akun/trip kurir yang sesuai.

Verifikasi lanjutan pada HP menemukan akun kurir sudah terbuka dengan trip assigned. Screenshot courier-update-reopen.png memverifikasi ringkasan/progres/penerima/COD terbaru. Tombol Peta tujuan dibuka tanpa mengubah status bisnis, screenshot courier-map-device.png memverifikasi tile OSM, penanda depot dan tujuan1. Posisi GPS belum diminta. APK revisi final sesudah perbaikan label completed berhasil dipasang ulang (Success) dan dibuka. Seluruh90tes dan analyzer akhir lolos. Navigasi belokan tetap menunggu Google Cloud/API key.

## APK terbaru tersimpan setelah peluncuran ulang — 13 November 2026

Pengguna mendapati UI lama setelah menutup/membuka aplikasi. Perubahan sebelumnya baru dikirim lewat hot reload sedangkan APK terpasang masih build lama. APK debug terbaru dibangun khusus android-arm64 dengan API Wi-Fi192.168.101.158:8000/api/v1. Transfer streaming awal terputus saat HP offline. Setelah port berubah, ADB tersambung kembali ke I2405 pada192.168.101.183:44159, push APK160358001byte berhasil dan pm install -r menghasilkanSuccess. APK lokal publik backend/public/build/shipx-wifi.apk diperbarui.

Aplikasi di-force-stop lalu dibuka kembali tanpa Flutter attach/hot reload. Sesi customer pulih, Home dan katalog terbaru terlihat di screenshot HP, termasuk header toko/alamat, bintang sering dipesan, hati favorit dan pill horizontal. Isi APK juga memuat penanda terbaru cart-payment-summary dan order-cod-amount. lastUpdateTime perangkat terkonfirmasi13November2026. File APK sementara di perangkat dibersihkan. Saat pengguna membutuhkan pembaruan yang bertahan setelah aplikasi ditutup, build/install APK terbaru diperlukan. .env dan setup dipertahankan.

## Form trip berbasis jadwal pelanggan — 13 November 2026

Pengguna meminta Buat Trip mengikuti jadwal dan layanan yang sudah dipilih di mobile. Form sekarang memilih kelompok slot+snapshot window pelanggan, menampilkan pesanan yang sesuai serta badge Express/Reguler. Perubahan kelompok membersihkan pilihan lama. Tanggal berangkat otomatis/read-only dan field Waktu berangkat kurir berupa jam. Tanggal/jam lokal lengkap tetap dikirim dalam kontrak lama. ID plan lama dinormalisasi menjadi angka saat edit.

Preview optimasi menambah recommend_departure opsional, default API false dan UI true. Perencanaan awal memperhitungkan jam buka serta persiapan depot, lalu waktu jalan tujuan pertama dipakai menyarankan jam berangkat. Semua baseline/kandidat dibanding pada waktu saran yang sama. Waktu diterapkan bersama rute dari preview tersimpan, lalu divalidasi kembali saat save. Tidak mengubah jadwal atau jenis layanan snapshot pelanggan. 131tes backend/1877assertions, TypeScript/build web serta3skenario browser MySQL lolos. Browser menguji pergantian kelompok Reguler/Express, tanggal otomatis, pengosongan pilihan, rekomendasi/apply dan alur manual/reopen/cancel, dengan preview320/390/1440px. Source lokal develop. Tidak ada migration baru. QA dibersihkan sesudah pengujian.

## Optimasi trip dari matriks jalan — 13 November 2026

Pengguna menyetujui deadline-ordered cheapest feasible insertion +2-opt satu trip/satu slot, maksimum20pesanan. Provider belum dikonfigurasi sehingga matriks jalan lengkap dua arah diisi admin atau ditempel dari spreadsheet dengan sumber. Baseline urutan draft/FIFO dan kandidat memakai matriks sama, lalu dipilih menurut total waktu selesai Express, total perjalanan, waktu kembali. Semua kapasitas serta batas selesai layanan/operasional harus lolos. Express memakai deadline akhir slot. Heuristik dapat gagal menemukan rute yang sebenarnya ada, sehingga UI menyebut belum ditemukan rute layak. Waktu pulang dihitung terpisah dari batas selesai antar.

Admin Trip draft mempunyai panel input/komparasi/apply. Preview milik actor+trip+versi terikat hash snapshot danTTL30menit. Apply idempotent memvalidasi ulang data/depot/armada/reservasi dan append route_version dengan matriks/sumber/jadwal. Perubahan master/versi/expiry ditolak. Penetapan/tinjauan/start tetap alur yang tersedia, ruas terpilih mengisi tinjauan dan urutan sampai ke API kurir. Migration000014 sudah Ran. .env identik. Source lokal develop.

128tes backend/1825assertions sebelum penambahan lanjutan pada satu test integrasi, lalu test yang sama lolos sampai review/start/manifest/urutan API kurir. TypeScript/build web lolos. Browser QA MySQL lolos untuk input matriks, rekomendasi,apply,reload,assignment,prefill dan API kurir, dengan preview1440/390/320px. Database QA dibersihkan sesudah uji. Dokumen aktif API/PRD diperbarui.

## Jam operasional, Express dan Reguler — 13 November 2026

Pengguna menetapkan08–17Senin–Jumat dan09–16akhir pekan/libur nasional, memilih kalender nasional otomatis dan meminta ongkir/waktu dihitung dari jarak. DeliveryPolicy memvalidasi jam pada admin/API/quote/checkout. Kalender resmi Kemnaker2026/2027 berhasil disinkron17/18hari dengan fallback lokal, cuti bersama dikecualikan. Generator slot satu jam14hari berjalan harian dan tersedia melalui tombol admin.109slot baru disiapkan di database utama tanpa menimpa slot lama. Scheduler lokal aktif melalui artisan schedule:work.

Reguler memilih slot, Express otomatis memilih slot terdekat yang cukup waktu persiapannya pada tanggal terpilih. Ongkir dasar1km + tambahan per km berikutnya, Express tambahan persen. Default implementasi1000Rp/km tambahan,50%Express,30menit persiapan dan20km/jam, dapat diubah pada Depot. Jarak garis lurus diberi penjelasan estimasi. Jenis/jarak/ongkir disimpan di snapshot pesanan, terlihat di admin/mobile. Caller/retry lama tetap kompatibel. Detail kontrak di API_PHASE_1.md. Migration000013 telah Ran.

119tes backend/1766assertions,84tes Flutter, analyzer/TypeScript/build web lolos. Browser QA baru memverifikasi kalender/jam, generate14hari, harga Express MySQL, checkout dan detail admin pada390px. Pembaruan Flutter terkirim via hot reload15libraries/1,7detik. Source lokal develop. APK permanen belum dibangun ulang. .env dipertahankan. Kalender tahun berikutnya memerlukan penambahan URL pengumuman resmi pada config. Penugasan kurir tetap alur manual admin.

## Header toko dan pill katalog — 13 November 2026

Header katalog mengikuti referensi pengguna dengan app bar hijau gelap, kartu putih dua baris berisi nama toko/jarak dan alamat terdaftar. Nama serta koordinat toko dibaca dari delivery-settings; alamat yang dipilih di keranjang diprioritaskan, lalu satu alamat terdaftar jika hanya ada satu. Beberapa alamat memerlukan pilihan pengguna. Tampilan tidak memilih alamat atau jadwal checkout secara otomatis. Jarak Haversine ditandai perkiraan dan penjelasan garis lurus tersedia saat menekan toko. Tidak membaca GPS otomatis.

Kategori kini satu baris horizontal, dengan ikon bintang untuk Semua barang/Sering dipesan/Favorit dan tombol pencarian di kanan. Pencarian dibuka saat ditekan; pill tetap mengikuti gulir kategori. Header disembunyikan sementara saat keyboard tampil agar daftar tidak terjepit. 82 tes Flutter lolos, analyzer bersih; preview 320px/teks1,5, 390px dan820px diperiksa. Source lokal develop; tidak ada perubahan .env, data bisnis atau kontrak API. Debug nirkabel tersambung kembali ke I2405 di192.168.101.183:41697. Flutter attach dan hot restart berhasil; screenshot HP memverifikasi header hijau, nama Depot utama, jarak0,2km, alamat terdaftar dan satu baris pill. API health200. Pembaruan berjalan pada sesi debug tanpa memasang ulang APK; APK tersimpan belum dibangun ulang.

## Pill mengikuti gulir kategori — 13 November 2026

Katalog menampilkan bagian produk per kategori. Pill horizontal mengikuti kategori yang terlihat dan otomatis bergeser agar pilihan aktif masuk viewport. Menekan pill menggulir ke bagian tersebut, termasuk memuat halaman berikutnya jika diperlukan. Pencarian/collection baru membatalkan jump yang masih menunggu respons. API menambah grouped=1, mengurutkan kategori sebelum pagination dan menyediakan kategori sesuai hasil. Mode API biasa tetap tersedia. Judul Katalog menjadi18px.114 tes backend/1702 assertions dan79 tes Flutter lolos, analyzer bersih, preview320/390/820px dibuat. Perubahan tersedia sebagai source/preview lokal. APK untuk perubahan ini menunggu permintaan pemasangan pengguna.

## Home, katalog grid dan tema hijau — 13 November 2026

Pengguna memberi empat referensi Home, riwayat, detail dan katalog hijau. Mobile kini memakai hijau006241/dark004D35 dengan Plus Jakarta Sans. HomePage menampilkan sapaan dan pintasan katalog/favorit/sering dipesan/pengiriman/riwayat dengan identitas serta ikon ShipX. Katalog dibuka sebagai tampilan dalam tab Home sehingga navbar tetap Home, tombol kembali termasuk back Android mengembalikan Home. Navbar mempunyai Home/Pengiriman/Keranjang/Pesanan/Akun. Kategori menjadi chip horizontal. Produk memakai grid dua kolom, satu kolom pada layar sempit/font besar, dengan foto produk atau ikon, favorit dan quick-add. Halaman riwayat memakai kartu status/item/alamat/tagihan dan detail menampilkan hero status hijau serta section pengiriman, barang dan COD. Seluruh aksi memakai fitur dan data ShipX yang tersedia.

79 tes Flutter dan analyzer lolos. Preview Home/katalog/riwayat/detail pada320/390/820px diperiksa. Tes navigasi memeriksa katalog tetap memilih Home dan riwayat memilih Pesanan. APK debug API Wi-Fi192.168.101.158:8000/api/v1 berhasil dibangun dan dipasang melalui adb nirkabel I2405. Source lokal develop. Favorit serta aturan pesanan dari checkpoint sebelumnya dipertahankan.

## Kartu katalog, favorit dan sering dipesan — 13 November 2026

Setiap produk dibungkus kartu horizontal dengan tombol hati kanan atas dan plus32px kanan bawah yang tetap memiliki target sentuh berpadded. Pilihan Semua barang/Sering dipesan/Favorit ada di atas daftar, dapat digabungkan dengan kategori dan pencarian. Harga memakai baris tersendiri agar tetap terbaca pada layar320px/font1,5. Favorit disimpan per akun pada product_favorites, primary key user_id/product_id. PUT favorite menerima desired state boolean idempotent. Frequent diurutkan dari jumlah pesanan akun sendiri, mencakup pending/confirmed/assigned/out_for_delivery/delivered/failed dan mengecualikan cancelled/rejected. Kontrak lengkap di API_PHASE_1.md.

Migration000012 telah diterapkan.113 tes backend/1692 assertions,78 tes Flutter dan analyzer lolos. MySQL HTTP pada database QA disposable memverifikasi favorit berulang, hapus dan pagination frequent. Database QA dihapus. Preview320/390/820px diperiksa. Hot reload mengirim17 libraries dalam1,7detik ke I2405. Build terbaru kemudian berhasil dipasang dan dibuka otomatis melalui Wi-Fi agar UI ini tersedia pada peluncuran berikutnya. Flutter run aktif menggunakan koneksi192.168.101.183:41697 dan API192.168.101.158:8000/api/v1. Source lokal develop.

## Alignment tombol belanja dan koneksi Wi-Fi — 13 November 2026

Wireless debugging HP I2405 telah dipasangkan dengan laptop dan Flutter run berhasil dijalankan lewat Wi-Fi. Endpoint koneksi saat verifikasi192.168.101.183:41697, API tetap192.168.101.158:8000/api/v1. Port pairing ditemukan lewat adb mdns services. Hot reload tanpa perubahan source berhasil dalam581ms. Sesi sempat terputus ketika proses aplikasi berakhir, lalu dijalankan kembali dan hot reload diverifikasi. Untuk sesi pengembangan berikutnya periksa adb devices/mdns services karena alamat atau port perangkat dapat berubah.

Pengguna mengonfirmasi API health dan login APK melalui Wi-Fi berhasil. Build lokal memakai API_BASE_URL=http://192.168.101.158:8000/api/v1. HP dan laptop memakai Wi-Fi yang sama dengan Laravel/MySQL aktif. IP LAN perlu diperiksa lagi jika jaringan berubah. Pembuatan aturan firewall otomatis memerlukan administrator, sedangkan akses HP sudah dikonfirmasi berhasil. Tiga cache transform Gradle yang gagal diverifikasi telah dicadangkan dengan suffix .shipx-backup-20261113 setelah daemon dihentikan dan build ulang berhasil.

Pengguna kemudian meminta tombol Checkout dan Atur pengiriman dirapikan. ShopDock sekarang membagi kolom harga/tombol sama lebar, meratakan tombol ke margin kanan20px dan menempatkan ikon/teks di tengah. Layar sempit atau font besar memakai tombol selebar konten.76 tes Flutter dan analyzer lolos, termasuk regresi ukuran identik kedua CTA pada320/375/390/820px dengan skala teks1 dan1,5. Preview kedua layar diverifikasi. Source lokal develop, verifikasi tampilan HP menunggu pemasangan APK pembaruan.

## Integrasi seluruh checkpoint ke main — 10 November 2026

Pengguna meminta seluruh perubahan aplikasi digabungkan ke main. Paket ini mencakup rekonsiliasi trip dan receipt, perapian seluruh storefront Flutter, foto produk admin/mobile, dropdown kategori dan SKU otomatis. README diselaraskan dengan fitur yang tersedia. Catatan belum commit/push pada checkpoint sebelumnya merupakan histori. Identitas Git pengguna dan atribusi Claude pada commit README sebelumnya dipertahankan. Commit integrasi menyertakan atribusi Codex.

Verifikasi ulang mencakup 110 tes backend/1657 assertions,75 tes Flutter, analyzer, TypeScript/build web, serta race MySQL start/hasil/rekonsiliasi dan rollback/reapply migration. Delapan dari sembilan skenario browser lolos pada suite awal. Skenario trip mengalami timeout aset JavaScript di server QA lokal, kemudian lolos saat diulang tanpa perubahan source. Uji fisik HP untuk APK foto produk belum diulang. File patch README0001 merupakan salinan perubahan yang sudah tersimpan dalam riwayat dan dipertahankan sebagai arsip lokal. .env memiliki SHA256DBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C.

## Dropdown kategori dan SKU otomatis — 9 November 2026

Form produk admin memakai dropdown kategori umum serta kategori produk lama termasuk nonaktif, dengan pilihan tambah kategori baru. SKU create yang kosong dibuat server SHX- + ULID, input manual tetap tersedia. Edit tetap menampilkan kode tersimpan dan mewajibkan kode valid. 110 tes backend/1657 assertions, sembilan skenario browser dan TypeScript/build web lolos. Tidak ada migration. .env identik. Perubahan lokal develop.

## Foto produk admin dan Flutter — 9 November 2026

Admin tambah/edit produk memiliki upload satu foto opsional, preview, ganti dan hapus saat simpan. JPEG/PNG/WebP maksimal2MiB dan4096px. Migration000011 sudah Ran di MySQL. API menambah photo_url nullable relatif origin dan route foto katalog publik. Flutter ProductArt memakai host API aktif untuk foto katalog/detail/keranjang, serta fallback ikon kategori. File lama dihapus sesudah commit, file baru dibersihkan saat transaksi gagal dan konflik versi ditolak sebelum menulis file. Detail kontrak di API_PHASE_1.md bagian Foto produk.

108 tes backend/1616 assertions dan75 tes Flutter lolos, analyzer serta TypeScript bersih, build web/APK berhasil. Sembilan skenario browser lolos, termasuk unggah/ganti/hapus foto dan preview390px. HP belum terdeteksi sehingga APK baru belum dipasang. .env tetap identik SHA256DBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C. Produk bisnis belum diberi foto uji. Perubahan lokal develop.

## Ikon produk — 9 November 2026

Pengguna memilih ikon sederhana untuk produk. ProductArt sekarang memakai ikon Material outline sesuai kategori dengan warna teal dan ukuran responsif. Komponen ini dipakai pada katalog, keranjang, banner pengantaran dan keadaan kosong. Label aksesibilitas menjadi Ikon kategori. Catatan ilustrasi Canvas pada checkpoint sebelumnya merupakan histori.

18 tes katalog/keranjang/layout lolos, analyzer bersih dan APK berhasil dibangun. APK sudah diperbarui di HP I2405 melalui adb install -r dan ShipX dibuka. Reverse8000 aktif.

## Perapian layout Pengiriman — 9 November 2026

Halaman Pengiriman kini menempatkan alamat di atas, pemilih tanggal satu baris penuh dengan nama bulan Indonesia, kemudian jam yang tersedia. Informasi depot/ongkir diringkas di bawah. Tombol lanjut menetap dan aktif setelah alamat serta slot terpilih. Tampilan tanggal menggantikan kode zona waktu. 72 tes Flutter, analyzer dan build APK lolos. APK diperbarui melalui adb install -r di HP I2405 dan dibuka. Layout baru serta dialog tanggal sudah terlihat pada perangkat. Laravel/MySQL aktif dan reverse8000 tersedia saat verifikasi. Perubahan lokal develop.

## Belanja dan checkout dari referensi — 8 November 2026

Baca [MOBILE_STOREFRONT_CHECKPOINT.md](docs/MOBILE_STOREFRONT_CHECKPOINT.md). Referensi screenshot pengguna diterapkan pada katalog kategori vertikal, ringkasan pengiriman, ilustrasi transparan dan bar Checkout; keranjang memakai total/CTA menetap, alamat/jadwal lewat lembar bawah dengan pilihan sementara dan konfirmasi, Pengiriman/Akun diringankan. Quote/harga server, fingerprint, pending/idempotency, COD dan batas stok tetap berjalan. 72 tes Flutter, analyzer dan APK lolos; preview font asli 320px/teks1,5, 390px, 820px serta keyboard diverifikasi. HP belum tersambung saat APK siap, belum dipasang. .env identik, web/backend/data tidak diubah oleh UI ini. Rekonsiliasi sebelumnya tetap ada; seluruh pekerjaan masih lokal develop, belum commit/push/main. Koneksi HP terakhir sebelumnya sudah pulih setelah adb reverse dan pengguna mengonfirmasi bisa masuk; pemetaan perlu diulang saat kabel terputus.

## Rekonsiliasi dan penutupan trip — 8 November 2026

Baca [RECONCILIATION_CHECKPOINT.md](docs/RECONCILIATION_CHECKPOINT.md). Admin menerima barang layak jual/karantina per SKU dan setoran COD, menyetujui alasan selisih lalu menutup trip atomik dengan ledger/receipt/audit dan pelepasan claims. Migration 000010 sudah Ran tanpa reset/.env berubah. Flutter menampilkan penyerahan dan receipt final; API menambah recent_completed maksimal lima milik sendiri dan detail completed tetap tersedia. 100 backend/1552 assertions, 70 Flutter, delapan browser, analyzer, TypeScript/build/APK serta race MySQL rekonsiliasi lolos; kontrak ID receipt string diuji terpisah. Perubahan lokal develop belum commit/push. HP belum terdeteksi. Berikutnya navigasi/optimasi/pilot. User menanyakan hosting: Render Docker memungkinkan; InfinityFree gratis membatasi akses API Flutter. Belum meminta deployment; jangan mengubah .env produksi atau membuat layanan berbayar tanpa instruksi.

## Lokasi perangkat dan label item — 7 November 2026

Baca [LOCATION_AND_SIMPLE_LABELS_CHECKPOINT.md](docs/LOCATION_AND_SIMPLE_LABELS_CHECKPOINT.md). Pengguna memilih semua barang tampil sebagai item. Form alamat Flutter memakai GPS/peta tanpa input koordinat; geolocator14.1.2 dan izin foreground coarse/fine ditambahkan. Depot web memakai Leaflet1.9.4/pin/lokasi browser. Tidak ada pengambilan lokasi otomatis atau pelacakan background. Jadwal tidak menampilkan IANA; semua konversi zona depot tetap utuh. Ukuran teknis hilang dari layar utama, admin memakai detail kg/cm dan kapasitas kendaraan hasil ukuran ruang, lalu mengirim satuan API lama. Data bisnis, riwayat unit_label, .env dan kontrak tidak ditulis ulang. 66 tes Flutter dan analyzer lolos, build web/APK berhasil. HP sudah tidak terdeteksi saat APK siap; pemasangan GPS dan izin aktual menyusul.

## Seluruh tampilan mobile — 7 November 2026

APK akhir berhasil dipasang dan dibuka di HP I2405 dengan adb install -r, tanpa clear data; reverse port8000 aktif. Pengguna dapat meninjau tampilan pada aplikasi. Interaksi manual HP/kamera belum dikonfirmasi.

Baca [MOBILE_PAGES_CHECKPOINT.md](docs/MOBILE_PAGES_CHECKPOINT.md). Pengiriman, Keranjang, Akun (widget baru), pesanan/detail, form alamat, kurir/muatan/hasil, login dan cek koneksi diselaraskan dengan menu. Panel/intro/judul/jumlah pembayaran bersama tersedia. Pengiriman dapat menavigasi ke keranjang setelah memilih alamat/slot. Semua aturan API, checkout, fingerprint/idempotency, polling dan retry dipertahankan. 61 tes Flutter lolos, analyzer bersih; preview 320px/1.5x, 390px dan 820px meliputi checkout/dialog, alamat dan nomor pesanan panjang. Tidak mengubah backend/web admin/.env/data bisnis.

## Menu mobile kategori vertikal — 7 November 2026

Verifikasi: 61 tes Flutter, analyzer bersih, 92 backend/1450 assertions. APK debug dipasang dan dijalankan di HP I2405; pemetaan USB port8000 aktif. Preview widget test tersedia. Screenshot HP dilewati karena ShipX sudah bukan aplikasi foreground; interaksi manual kategori di HP belum dikonfirmasi. .env identik.

Pengguna menyetujui web admin, lalu meminta katalog mobile bergaya menu pemesanan TOMORO. Baca [MOBILE_MENU_CHECKPOINT.md](docs/MOBILE_MENU_CHECKPOINT.md). Header pencarian ringkas, rail kategori vertikal dan daftar produk bergulir terpisah, ilustrasi kemasan generik, quick-add dan bar keranjang. API katalog menambahkan categories lengkap dan filter category sebelum pagination; tidak ada migration/data bisnis/.env berubah. Font/palet sebelumnya dipakai; hero katalog navy besar telah diganti. Web admin tidak didesain ulang. USB HP menggunakan adb reverse8000 dan API_BASE_URL localhost, bukan default emulator.

## Checkpoint UI web dan Flutter — 7 November 2026

Baca [UI_REFRESH_CHECKPOINT.md](docs/UI_REFRESH_CHECKPOINT.md). Pengguna memilih perapian kedua UI. Plus Jakarta Sans dibundel lokal beserta OFL, tema teal/navy disatukan, dashboard/sidebar/login admin serta header/katalog/navigasi Flutter dirapikan. Heading ID panjang web, nama kendaraan/spesifikasi produk Flutter dan baris pemilih jadwal diperbaiki agar membungkus pada layar kecil. Perubahan ini hanya tampilan; checkpoint domain tetap hasil pengiriman di bawah. Tidak mengubah .env/setup/data bisnis. HP belum terdeteksi; verifikasi otomatis dan preview lokal tersedia.

## Checkpoint terbaru hasil pengiriman, foto dan COD

Verifikasi akhir checkpoint ini mencakup 91 tes backend / 1432 assertions, 53 tes Flutter dan 6 skenario browser. Uji race MySQL hasil lolos, migration 000009 Ran, dan 0 database QA serta 0 hasil/unggahan uji tertinggal di database bisnis. Foto server QA dibersihkan. Foto draft perangkat memakai nama unik dan cleanup sebelum submit, sementara permintaan belum pasti tetap disimpan untuk retry.

Baca [DELIVERY_RESULTS_CHECKPOINT.md](docs/DELIVERY_RESULTS_CHECKPOINT.md). Migration 000009 sudah Ran. Kurir mencatat hasil sesuai urutan, delivered seluruh order dengan foto privat dan COD tepat tagihan, atau failed beralasan/COD nol. Ledger trip keluar hanya untuk delivered, failed mempertahankan muatan. Hasil/proof/COD/version atomik dan idempotent. Semua tujuan selesai menjadi awaiting_reconciliation, claims tetap ditahan. Customer/admin dapat melihat hasil dan foto sesuai akses. Foto JPEG/PNG maksimal2MiB, staging24jam dan cleanup harian tersedia. Tema UI mobile pengguna dipakai. Tes Flutter53, browser6, analyzer/TypeScript/build/APK dan race MySQL hasil lolos. APK sempat tertahan cache Gradle, build ulang berhasil. .env utuh, perubahan masih lokal develop. Selanjutnya rekonsiliasi barang/uang dan penutupan trip. Uji kamera/foto HP fisik menyusul saat perangkat tersambung. Pernyataan hasil/COD belum tersedia di checkpoint lama merupakan histori.

## Checkpoint terbaru: konfirmasi muatan dan start trip — 5 November 2026

Baca [TRIP_DEPARTURES_CHECKPOINT.md](docs/TRIP_DEPARTURES_CHECKPOINT.md). Pengguna memilih estimasi waktu jalan manual dengan sumber + tinjauan admin untuk tahap ini, sehingga provider belum wajib. Admin mengisi semua ruas termasuk pulang, sumber, catatan dan penanganan; sistem menghitung tunggu/jendela/layanan. Review berlaku 24 jam, terikat versi dan diulang setelah replan. Flutter kurir menghitung semua SKU dan start dengan durable idempotency. Start menghitung ulang jadwal aktual, transfer ledger depot→trip, consume reservasi, orders out_for_delivery dan trip in_progress atomik; claims tetap ditahan, cancel/reopen sesudah start ditolak. Migration 000008 sudah Ran tanpa reset/.env berubah. 85 backend/1364 assertions, 48 Flutter, 6 browser, analyzer/build/APK dan race MySQL lolos. Perubahan lokal develop belum commit/push. HP tidak terdeteksi; APK belum dipasang. Berikutnya hasil delivered/failed, bukti, COD dan rekonsiliasi; tidak ada endpoint penyelesaian trip saat ini. Status “start belum tersedia” di checkpoint sebelumnya merupakan histori.

## Checkpoint terbaru: penugasan trip manual

Baca [MANUAL_TRIPS_CHECKPOINT.md](docs/MANUAL_TRIPS_CHECKPOINT.md). Admin dapat membuat/edit draft dan urutan manual, menetapkan, membuka ulang dan membatalkan sebelum berangkat. Validasi kapasitas dua dimensi, confirmed satu gelombang, versi/departure/reservasi dan claims pesanan/kurir/kendaraan atomik. Courier Flutter mempunyai tab Trip/Akun dan API assigned trip sendiri. Customer assigned tidak dapat cancel; reopen mengembalikan confirmed. Stok fisik belum dipindahkan. Migration 000007 sudah Ran, `.env` utuh, perubahan masih lokal develop bersama checkpoint armada. 77 tes backend/1187 assertions, 43 tes Flutter, 5 skenario browser, analyzer, TypeScript/build, APK dan race MySQL lolos. HP tidak terdeteksi; trip belum diuji langsung. Rute manual not_evaluated/ETA null. Berikutnya muatan/start, hasil/COD/rekonsiliasi dan kelayakan perjalanan. Jangan mengulang setup atau menganggap dispatch/optimasi aktif.

## Checkpoint terbaru: master kurir/kendaraan dan checkout HP lolos

Baca [FLEET_MASTERS_CHECKPOINT.md](docs/FLEET_MASTERS_CHECKPOINT.md). Menu admin Kurir/Kendaraan sudah tersedia (tambah/edit/filter/aktif/nonaktif, kapasitas dan konflik versi). Migration 000006 telah Ran; perubahan lokal pada develop, belum commit/push. Kata sandi/email/nonaktif kurir mencabut token. 67 tes backend / 1002 assertions, TypeScript/build, analyzer dan empat skenario browser lolos. Uji HP I2405 terisolasi kini **lolos** dari checkout multi-SKU sampai konfirmasi, pembatalan, penolakan/alasan dan login kurir; akun/pending asli tidak disentuh. Bug respons checkout lock_version null diperbaiki menjadi 0. QA database bersih dan reverse QA dilepas. .env tetap identik. Selanjutnya trip manual; dispatch/delivery/COD/rekonsiliasi belum tersedia. Status lama uji checkout HP belum selesai sudah digantikan.

## Checkpoint terbaru: keputusan admin dan status Flutter

Baca [ORDER_DECISIONS_CHECKPOINT.md](docs/ORDER_DECISIONS_CHECKPOINT.md). Admin kini dapat confirm/reject pending dengan dialog, alasan wajib untuk penolakan, lock_version dan idempotency; hanya admin web aktif + CSRF. Konfirmasi mempertahankan reservasi, penolakan menjadi rejected dan melepas sekali; deadline dicek sesudah lock. Migration order_decisions telah Ran tanpa reset/.env berubah. Flutter menampilkan status/alasan, refresh manual dan polling foreground 15 detik. 58 tes backend / 742 assertions, tes Flutter status, analyzer, build APK/Vite, dua skenario browser dan race MySQL keputusan lolos. Tidak ada QA DB tertinggal. APK belum dipasang ke HP. Selanjutnya master kurir/kendaraan dan trip manual; penugasan/delivery/COD/rekonsiliasi belum tersedia. Pernyataan admin baca-saja atau konfirmasi belum tersedia di checkpoint lama adalah histori.

## Checkpoint terbaru: admin React + Inertia + shadcn/ui asli

Pengguna menyetujui migrasi framework web. Baca [ADMIN_UI_MIGRATION.md](docs/ADMIN_UI_MIGRATION.md) terlebih dahulu. Semua halaman admin aktif sekarang React + TypeScript melalui Inertia, komponen shadcn asli diambil dari CLI resmi; Blade hanya root view Inertia. 50 tes backend / 633 assertions, TypeScript, build Vite dan 2 skenario browser desktop/mobile lolos. API Flutter, aturan domain dan .env dipertahankan; tidak ada migration/reset. Konflik versi, CSRF, role, mutasi stok berulang dan lock_version depot telah diverifikasi. Konfirmasi/dispatch pesanan tetap belum tersedia. Status dan keputusan Blade tanpa React di bagian historis di bawah sudah digantikan.

## Checkpoint terbaru: stok dan checkout, 4 November 2026

Baca [checkpoint stok/checkout](docs/CHECKOUT_CHECKPOINT.md) terlebih dahulu. Stok admin, keranjang Flutter, quote, checkout COD atomik, reservasi, riwayat dan pembatalan sudah diimplementasikan. Migration inventory/orders sudah Ran. Verifikasi ulang: 45 tes backend / 359 assertions, 31 tes Flutter + 3 tes layar checkout, analyzer dan race MySQL lolos; `.env` tetap identik. Uji checkout HP belum selesai terkonfirmasi dan pengguna memilih tes otomatis dahulu. Konfirmasi/dispatch admin belum tersedia. Catatan di bawah yang menyebut stok/order belum tersedia merupakan histori.

## Pembaruan terkini — depot, alamat dan slot, 4 November 2026

Fitur tahap ini tersedia: admin mengatur `/admin/depot` dan CRUD tanpa hapus `/admin/slots`; Flutter customer mempunyai tab Pengiriman untuk alamat/penerima, pin OSM atau koordinat manual, edit/nonaktif alamat, pilihan alamat dan slot menurut tanggal lokal depot. Endpoint customer baru: GET delivery-settings, GET delivery-slots, GET/POST addresses, PATCH/DELETE addresses/{id}. Semua auth/role enforced server, ID alamat user lain 404, radius dihitung Haversine, update/delete alamat memakai lock_version, dan slot disaring tepat cutoff.

Migration `2026_11_04_000003_create_delivery_settings_addresses_slots` telah Ran di MySQL. Tidak mengubah `.env`, akun atau produk pengguna. Depot sebenarnya belum dikonfigurasi: pengguna perlu mengisi lokasi/radius/ongkir di menu Depot sebelum alamat/slot bisa dipakai; jangan memasang koordinat contoh sebagai data bisnis. Waktu slot dari zona depot dikonversi UTC, service_date tetap lokal, timezone dikunci setelah slot pertama dibuat.

QA: 32 test backend/255 assertions, 19 test Flutter, analyzer bersih, APK debug berhasil. Script `php scripts/verify-delivery-mysql.php` memakai request API-kernel pada MySQL asli dalam transaksi yang di-rollback, lolos tanpa menyimpan fixture. Form panjang diperbaiki agar semua kolom tervalidasi, termasuk setelah scroll. Pemilihan alamat/slot hanya state layar, bertahan antar-tab, belum reservation/order. Uji lengkap dengan lokasi depot asli dan tile online di HP masih perlu konfirmasi pengguna. Lihat docs/SETUP_STATUS.md dan API_PHASE_1.md untuk kontrak/batasan.

Lanjut berikutnya: selesaikan uji pengguna setelah depot dan slot diisi, lalu fondasi ledger stok → keranjang → quote/checkout atomik. Domain stok/order belum diimplementasikan pada checkpoint ini.

## Verifikasi terbaru — katalog di HP, 4 November 2026

Pengguna telah membuat admin dan satu produk aktif `Air Mineral`. Katalog API sesuai dengan database. Integration test terbaru di HP I2405 sudah **lolos**: koneksi health, register sementara, pencarian produk pengguna, buka/tutup detail, validasi/pemulihan sesi, logout dan login ulang. Selector test dibedakan antara EditableText pencarian dan Text label produk. Akun/token uji dibersihkan; produk pengguna tidak dimodifikasi. ADB reverse 8000 aktif, API_BASE_URL pada build HP memakai `http://127.0.0.1:8000/api/v1`.

Status bagian berikut yang menyebut uji katalog HP tertunda adalah histori; checkpoint tersebut sudah selesai. Browser/web belum diverifikasi visual melalui otomasi. Pengguna dapat mendaftar akun customer sendiri lewat aplikasi; jangan memakai admin untuk menguji katalog customer. Langkah pengembangan berikut tetap konfigurasi depot, alamat/slot dan stok sebelum checkout.

## Pembaruan terakhir — tampilan admin dan katalog, 4 November 2026

Admin Laravel sekarang memiliki tampilan login, ringkasan, daftar/filter produk, tambah/edit dan kontrol aktif/nonaktif dengan Blade+Tailwind. Flutter memiliki tampilan auth baru serta tab Katalog/Akun untuk customer, pencarian, pagination, detail, refresh, retry dan kondisi kosong. Endpoint katalog bearer khusus customer aktif sudah tersedia. Courier/admin tetap hanya halaman akun pada mobile.

Migration `2026_11_04_000002_create_catalog_tables` sudah Ran di MySQL. Depot utama hanya identitas katalog; konfigurasi lokasi/cakupan/ongkir menyusul sebelum checkout. Produk menyimpan harga, satuan, berat, dimensi, volume hitungan server, status dan lock_version. SKU unik per depot. PUT/PATCH menolak edit versi lama. Produk nonaktif disaring API. Stok, keranjang, checkout dan pengantaran belum tersedia.

Verifikasi terbaru: 21 test backend (151 assertions), 11 test Flutter, analyze bersih, aset Vite dan APK debug berhasil. Uji HTTP+MySQL via `scripts/verify-catalog-http.py` lolos dari admin create hingga katalog/nonaktif/konflik versi; fixture dibersihkan. `.env` tetap utuh. Pengguna memilih uji otomatis dahulu karena HP belum tersambung. **UI katalog terbaru belum diuji langsung di HP; preview Chrome juga belum terverifikasi karena akses UI timeout.** Hasil integration test Android pada checkpoint auth berikut ini tetap merupakan histori.

Server saat pengujian: `http://127.0.0.1:8000`; admin login di `/admin/login`. Akun admin dibuat interaktif dengan command staf yang sudah ada, tanpa password bawaan. Detail cara mencoba dan batasan di docs/SETUP_STATUS.md. Lanjutkan pengecekan UI pada HP/browser ketika tersedia, kemudian konfigurasi depot, alamat/slot dan fondasi stok sebelum checkout.

## Pembaruan terbaru — 4 November 2026, checkpoint auth selesai

Bagian ini mengoreksi status historis pada bagian bawah handoff. Workspace aktual: `C:/Users/Ahmad Syahani/Desktop/shipx`; tidak ditemukan AGENTS.md yang berlaku maupun metadata Git, sehingga diff commit tidak tersedia. `.env` dipertahankan dengan hash identik.

- Backend/MySQL sudah terverifikasi; migration tambahan phone/role/is_active serta Sanctum personal_access_tokens sudah Ran. Laravel tetap versi terkunci 13.40.0; Sanctum 4.3.3 ditambahkan.
- Register customer, login, me dan logout token sekarang tersedia sesuai API_PHASE_1. Token 30 hari, role/aktivasi ditetapkan server, validasi/rate limit tersedia. Akun nonaktif ditolak pada login dan akses terlindungi. Public register tidak membuat courier/admin.
- Admin Blade: `/admin/login`, `/admin`, `/admin/logout`, session+CSRF dan middleware admin aktif. Halaman baru fondasi akses, belum modul bisnis. Buat akun admin/courier secara interaktif melalui `php artisan shipx:create-staff admin` atau `courier`; tidak ada akun bawaan.
- Flutter: login/register, secure token storage, validasi/pemulihan sesi, logout, beranda sesuai role dan akses halaman cek koneksi. Modul customer/courier masih placeholder yang menyatakan fitur belum tersedia.
- Flutter analyze bersih, 5 test unit/widget lolos, build APK debug berhasil. Integration test di HP Android I2405 melalui USB berhasil membuktikan health → register → me → restore secure token → logout → login → logout dengan Laravel/MySQL. Akun smoke dibersihkan setelah pengujian.
- Koneksi HP memakai `adb reverse tcp:8000 tcp:8000` dan `--dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1`; perlu USB/ADB reverse tetap aktif. Source tetap default emulator 10.0.2.2. Bukan bukti koneksi Wi-Fi.
- Detail bukti, cara run/test dan batasan ada di docs/SETUP_STATUS.md. Tahap berikutnya: master SKU → alamat/slot → quote/checkout/reservation multi-SKU; jangan mengulang setup/auth yang sudah berhasil.

Catatan status di bawah yang menyebut Flutter/auth belum dibuat adalah riwayat sebelum pembaruan ini.

## Tujuan dan cara kerja

Lanjutkan project ShipX dari source lokal pengguna. Baca dokumen dan source aktual sebelum mengubahnya. Jangan mengulang setup yang sudah berhasil. Bekerja bertahap dengan checkpoint yang bisa diuji. Pengguna memakai Windows, Laragon, VS Code dan PowerShell, dengan gaya komunikasi santai bahasa Indonesia. Pengguna ingin proyek cukup dalam secara teknis tetapi menghindari kompleksitas yang tidak dibutuhkan.

Jangan menganggap chat ini otomatis tersedia di sesi Codex baru. File ini adalah ringkasan keputusan dan progres; source lokal serta hasil pemeriksaan terbaru menjadi acuan implementasi.

## Keputusan yang disetujui

- Nama: ShipX, sebelumnya AntarGalon. Layanan tidak dibatasi ke galon; mendukung berbagai barang.
- Mobile: Flutter + Dart, target awal Android; satu aplikasi dengan tampilan customer/courier sesuai role.
- Backend: Laravel REST API; autentikasi direncanakan Laravel Sanctum.
- Web: admin Laravel + React + Inertia + TypeScript + Tailwind CSS + shadcn/ui asli (keputusan pengguna terbaru, 4 November 2026). Blade hanya menjadi root view Inertia.
- Database: MySQL; nama database lokal shipx.
- Source fondasi memakai skeleton Laravel 13.0.0; composer.lock pada saat dibuat mengunci framework 13.40.0. Periksa composer.lock aktual; jangan downgrade/upgrade tanpa kebutuhan. PHP yang terdeteksi saat setup 8.5.2.
- Tidak perlu microservices, repository generik, atau Redis untuk fondasi. Laravel queue/scheduler dengan driver database cukup ketika dibutuhkan.

## Lingkup produk aktif v0.2

Default rancangan sementara adalah katalog multi-produk milik satu operator dengan satu pusat pemenuhan/depot. Semua barang diambil dari depot sebelum perjalanan, lalu diantar ke beberapa pelanggan, dan kurir kembali ke depot.

Pengguna telah meminta dukungan barang lain dan nama ShipX. Pengguna BELUM secara eksplisit memilih model jasa pickup paket bebas dari alamat banyak pengirim. Jangan menambahkan model pickup-delivery marketplace secara diam-diam. Jika konteks implementasi menuntut perubahan model ini, jelaskan konsekuensinya dan kumpulkan keputusan terlebih dahulu.

- Customer: login, alamat + pin, keranjang multi-SKU, slot pengiriman, checkout, status dan pembatalan.
- Admin: produk, stok, pesanan, kendaraan/kurir, perencanaan rute, penugasan, rekonsiliasi.
- Courier: perjalanan sendiri, daftar tujuan, navigasi ke tujuan berikutnya, hasil pengiriman, foto bukti dan COD.
- Order dapat berisi beberapa SKU; kuantitas bilangan bulat dan satu unit jual dasar per SKU.
- Snapshot harga, nama/unit produk, berat/volume/dimensi, alamat dan jendela disimpan pada order.
- Kapasitas kendaraan divalidasi dengan total berat gram DAN volume kemasan cm³, bukan jumlah galon.
- Penjumlahan volume tidak menjamin barang secara geometris muat; admin meninjau bentuk/penanganan.
- Penukaran wadah 1:1 tidak berlaku pada alur umum. Deposit/wadah tukar/refill adalah fitur khusus di luar MVP generik, bukan fitur yang tetap diasumsikan berjalan.
- Pembayaran COD tunai seluruh tagihan; ongkir tetap per order pada MVP.
- Delivered seluruh order atau failed seluruh order. Tidak ada partial delivery.
- Jadwal per gelombang; tidak menyisipkan pesanan setelah kurir berangkat.
- Satu kendaraan/kurir per trip; belum mengoptimalkan pembagian banyak kendaraan sekaligus.
- Live tracking, payment gateway, multi-depot, langganan dan prediksi kebutuhan belum termasuk MVP.

## Optimasi rute

Fitur unggulan: menyusun urutan pengantaran berdasarkan estimasi waktu perjalanan jalan raya, kapasitas, jendela layanan dan durasi layanan. Navigasi ruas berikutnya dapat dibuka melalui Google Maps.

Rancangan awal: provider matriks waktu/jarak (kandidat Google Routes API), lalu algoritma sendiri nearest neighbor + 2-opt dalam Laravel. Integrasi provider belum dibuat; periksa dukungan mode kendaraan, tarif, kuota dan ketentuan penyimpanan data sebelum implementasi.

Bandingkan baseline urutan order masuk dengan kandidat menggunakan input/matriks sama. Periksa jendela layanan, waktu tunggu dan perjalanan pulang. Matriks bisa asimetris; hitung ulang biaya arah tiap ruas. Jika kandidat lebih buruk dan baseline layak, gunakan baseline. Jika tidak ditemukan solusi layak, tampilkan konflik; heuristik tidak membuktikan optimum global atau infeasibility matematis.

## Dokumen dan struktur

Folder project: shipx, lokasi absolut pada mesin pengguna belum dikonfirmasi. Pernah disarankan C:/laragon/www/shipx; jangan menganggap lokasi itu pasti benar. Mulai dari cwd Codex dan cari AGENTS.md yang berlaku.

- backend/: Laravel, routes/api.php, routes/web.php, resources, tests.
- mobile/: source Flutter, lib/core/api_config.dart, lib/core/health_api.dart, lib/main.dart, test/widget_test.dart.
- scripts/initialize-mobile.ps1: generate platform Android bila belum ada, set INTERNET permission dan debug-only cleartext, lalu flutter pub get.
- docs/PRD_ShipX.md: PRD aktif v0.2.
- docs/ERD_ShipX.md: ERD aktif v0.2.
- docs/API_PHASE_1.md: kontrak fase 1 aktif v0.2; membedakan rencana dan endpoint tersedia.
- docs/SETUP_STATUS.md: hasil pemeriksaan historis saat otomatisasi awal; progres pengguna di bawah lebih baru.
- docs/history/: rancangan khusus galon lama. Jangan mengimplementasikan domain galon dari folder ini sebagai aturan ShipX.

## Status terakhir yang telah dikonfirmasi pengguna

1. Pengguna mengikuti setup backend dan mengatakan berhasil tanpa error. Langkah checkpoint tersebut: composer install, .env, key:generate, health test dan membuka endpoint health. Verifikasi ulang secukupnya dari project aktual, jangan menganggap semua detail hasil sudah diamati asisten.
2. Pengguna mengikuti setup MySQL database shipx, konfigurasi .env, config:clear, migrate, migrate:status dan mengatakan semuanya berjalan baik.
3. Instruksi terakhir diberikan untuk koneksi Flutter: initialize-mobile.ps1, flutter analyze/test/devices, kemudian flutter run. Pengguna BELUM mengonfirmasi hasil langkah Flutter; ini checkpoint berikutnya.
4. Login, role, endpoint order, dashboard admin, migration domain, stok dan algoritma routing BELUM diimplementasikan oleh asisten dalam source fondasi yang diserahkan.
5. Migration yang telah dijalankan pengguna adalah migration bawaan Laravel; jangan menganggap seluruh ERD sudah menjadi tabel.

Saat setup otomatis awal, MySQL tidak aktif dan PHP/Flutter terhalang izin cache. Pengguna kemudian berhasil menjalankan backend/MySQL dari terminal lokal. Jangan menyajikan kendala backend lama sebagai masalah yang masih pasti terjadi. Cache Flutter masih perlu dibuktikan dari hasil lokal.

## Endpoint yang sudah dibuat

GET /api/v1/health, publik, tanpa kebutuhan database:

```json
{"data":{"service":"shipx-api","status":"ok","api_version":"v1"}}
```

Test backend: tests/Feature/ApiHealthTest.php. Flutter memeriksa kontrak health yang sama lewat tombol Periksa koneksi. Ini belum login atau bukti koneksi DB.

Default API_BASE_URL Flutter: http://10.0.2.2:8000/api/v1 untuk Android Emulator standar. HP fisik menggunakan IP LAN laptop pada jaringan yang sama. localhost pada HP bukan laptop. Gunakan --dart-define=API_BASE_URL=...; HTTP hanya debug, produksi HTTPS.

## Urutan kerja berikutnya

1. Baca AGENTS.md, dokumen aktif dan source aktual; periksa git status serta perubahan pengguna. Jangan menimpa .env, kredensial atau pekerjaan pengguna.
2. Pastikan baseline backend tetap lolos, cek migration status tanpa migrate:fresh. Verifikasi Flutter analyze/test dan koneksi HP/emulator ke /health. Pilih perangkat yang tersedia; jangan mengklaim APK berhasil sebelum build/run sungguh lulus.
3. Jika baseline siap, implementasi autentikasi: Sanctum, register customer, login, me, logout token; role customer/courier/admin dan is_active di server. Akun admin/kurir tidak dapat dibuat lewat register publik.
4. Web admin memakai session, CSRF dan middleware/policy admin, bukan bearer token yang ditanam di Blade.
5. Buat layar login/register Flutter serta secure token storage dan navigasi role. Uji token invalid/logout, role escalation dan akun nonaktif. Jangan hanya menyembunyikan menu.
6. Berikutnya master SKU → alamat/slot → quote/checkout/reservation multi-SKU → web antrean order → operasi pengiriman manual → optimasi.

## Invariant penting

- Harga dan total berat/volume dihitung server, tidak dipercaya dari client.
- Satu checkout multi-SKU atomik: jika stok satu item gagal, semuanya rollback.
- Reservation terpisah dari saldo fisik; seluruh account terkait dikunci dalam urutan konsisten.
- Jangan mengedit saldo tanpa ledger. Stock state aktif tersedia/karantina, bukan full/empty versi galon.
- Satu order/kurir/kendaraan tidak boleh punya dua alokasi aktif; ERD menggunakan tabel claims/locks dengan PK unik.
- Hasil delivery, item results, ledger dan COD ditulis satu transaksi dan aman dari request berulang.
- Rekonsiliasi stok per SKU/kondisi, bukan total campuran satuan semua barang; selisih butuh alasan/persetujuan.
- Token/password/foto privat tidak boleh masuk log atau endpoint publik.
- Uji locking/konkurensi memakai MySQL; SQLite tidak membuktikan perilaku locking MySQL.

## Berkas transfer

ShipX_Foundation.zip terakhir: https://chatgpt.com/library?file_id=libfile_555eaa0880808191b80e97f04086c85a&account_id=personal

Arsip tidak menyertakan .env, vendor, node_modules atau hasil build. Jika project lokal sudah disiapkan dan diubah pengguna, gunakan project tersebut; jangan ekstrak ulang di atasnya. Lockfile Flutter mungkin baru tersedia setelah pub get lokal; pertahankan file aktual.
