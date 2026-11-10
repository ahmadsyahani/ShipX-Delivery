# Kontrak API ShipX — fase 1 v0.2

## Kategori dan SKU admin — 9 November 2026

Form tambah/edit produk menerima props categories berisi pilihan umum dan seluruh kategori unik produk depot1, termasuk produk nonaktif. Dropdown menyediakan tambah kategori baru dengan validasi string maksimal80. Kategori tersimpan tetap dikirim melalui field category pada kontrak lama.

Pada POST /admin/products, sku yang tidak dikirim, null atau kosong dibuat server sebagai SHX- diikuti ULID26karakter. Unique constraint depot/SKU tetap berlaku. Kode manual tetap didukung dan dinormalisasi uppercase/trim. PUT update tetap mewajibkan sku valid agar edit metadata mempertahankan kode barang. Tidak ada migration untuk perubahan ini.

## Foto produk — 9 November 2026

Admin dapat mengunggah satu foto opsional saat tambah/edit produk melalui field multipart `photo`. JPEG, PNG atau WebP maksimal 2 MiB dan 4096 × 4096 piksel. Edit multipart memakai POST dengan `_method=put` dan `lock_version`. `remove_photo=true` menghapus foto saat simpan, bersamaan dengan unggahan ditolak. `photo_path` dan `photo_url` merupakan field keluaran yang tidak boleh dikirim sebagai input. Konflik versi diperiksa sebelum menyimpan file. File lama dihapus sesudah transaksi berhasil dan file baru dibersihkan jika transaksi gagal.

Katalog menambah `photo_url` berupa path relatif terhadap origin server, misalnya `/product-photos/{uuid}.png`, atau null untuk produk tanpa foto. Flutter menyelesaikan URL dengan host API aktif dan menampilkan foto di katalog, detail serta keranjang, dengan ikon kategori saat foto kosong, sedang dimuat atau gagal. GET `/product-photos/{file}` bersifat publik untuk foto katalog yang masih direferensikan produk depot1. Nama file acak, MIME ditetapkan dari format tervalidasi dan respons memakai nosniff. File disimpan pada disk local di `product-photos`, sehingga hosting perlu penyimpanan persisten.

Checkpoint aktif 8 November 2026: POST /admin/trips/{trip}/reconcile (session/CSRF/admin aktif, UUID idempotency, lock_version, actual_cash_rp, discrepancy_reason nullable, received_and_approved=true, items lengkap [{product_id,available_quantity,quarantine_quantity,discrepancy_reason}]). Expected dan selisih dihitung server, alasan wajib jika beda per SKU/kondisi atau uang. Menutup awaiting_reconciliation menjadi completed dengan ledger/receipt/audit dan pelepasan claims atomik. GET courier/trips mempertahankan data aktif dan menambah recent_completed maksimal lima milik sendiri; GET detail juga mengizinkan completed milik sendiri, menambah actual_return_at dan reconciliation pada awaiting/completed. can_start/can_record_result false setelah selesai. Lihat RECONCILIATION_CHECKPOINT.md untuk payload/batas/replay. Pernyataan rekonsiliasi belum ada di bawah merupakan histori.

Acuan PRD_ShipX.md dan ERD_ShipX.md. Health, auth, katalog, depot, alamat, slot, quote, checkout, daftar/detail/cancel order sudah diimplementasikan. Detail bukti uji dan batasannya ada di SETUP_STATUS.md.

## Konvensi

Checkpoint 6 November 2026 menambahkan hasil/foto/COD. Courier POST trips/{id}/stops/{stop}/proofs menerima multipart photo JPEG/PNG ≤2MiB dengan Idempotency-Key, mengembalikan UUID unggahan dan expiry24jam. Courier POST trips/{id}/stops/{stop}/result menerima trip_version/order_version/outcome/cash_received_rp/failure_reason/notes/proof_upload_id, memakai Idempotency-Key. Delivered wajib foto dan COD seluruh tagihan, failed wajib alasan dan COD nol. Kuantitas ditetapkan server, sesuai urutan tujuan. Hasil/proof/ledger/COD atomik, seluruh stops selesai membuat awaiting_reconciliation dengan claims tetap ditahan. GET delivery-proofs/{id} bearer aktif memeriksa kepemilikan order/trip atau admin, web admin punya route foto privat sendiri. GET order menambah delivery_result dan GET courier stops menambah metadata status/versi/hasil. Detail ada di DELIVERY_RESULTS_CHECKPOINT.md.

Checkpoint 5 November 2026 menggantikan batas start lama: admin `POST /admin/trips/{id}/departure-review` menerima idempotency_key/lock_version, leg_minutes per ruas termasuk kembali (tujuan+1; integer 0–1440), source_reference/reason wajib max500 dan handling_checked=true. Session+CSRF+admin aktif. Tinjauan terikat route/trip/master versions, berlaku24 jam dan bukan provider/optimasi. Kurir `POST /api/v1/courier/trips/{id}/start` memakai bearer, header Idempotency-Key UUID, lock_version, route_version_id, departure_review_id dan manifest `[{product_id,quantity}]` seluruh SKU. Start due, review/jadwal aktual, kapasitas, claims dan reservasi divalidasi sebelum ledger transfer depot→trip serta reservation consumed/orders out_for_delivery/trip in_progress. Replay tidak menggandakan. GET courier kini mencakup assigned/in_progress; detail menambah manifest/review/can_start/start_block_reason/loaded totals/actual_departure_at dan estimasi manual jadwal. can_start hanya petunjuk UI; POST tetap otoritatif. Sumber/jadwal manual dibedakan dengan feasibility_status=feasible_manual; tidak ada ETA provider. Lihat TRIP_DEPARTURES_CHECKPOINT.md untuk payload/batas. Hasil/COD/rekonsiliasi belum tersedia.

Checkpoint trip manual sudah aktif; lihat MANUAL_TRIPS_CHECKPOINT.md. Web admin `/admin/trips` menyediakan GET index/create/show/edit, POST store, PUT update dan POST `{id}/assign|reopen|cancel` dengan session+CSRF+admin aktif. Plan: idempotency_key UUID, courier_id, vehicle_id, departure_local `YYYY-MM-DDTHH:mm` dalam timezone depot, orders berurutan `[{id,lock_version}]` 1–20; update menambah lock_version trip. Aksi memakai idempotency_key/lock_version; reopen/cancel wajib reason maksimal 500. Konflik bisnis 409 melalui Inertia. Kapasitas/snapshot/claims server, tanpa perubahan stok fisik; route feasibility not_evaluated/ETA null. Master armada dengan claim aktif tidak dapat diedit sebelum reopen.

API kurir aktif: `GET /api/v1/courier/trips` hanya assigned milik sendiri (maksimal satu aktif; `{data:[]}`, tanpa pagination/riwayat/alamat penerima); `GET /api/v1/courier/trips/{id}` detail dengan ordered stops/snapshot alamat/penerima/items/jendela/tagihan. ID string dan waktu ISO UTC. Role lain/nonaktif 403, trip di luar akses atau yang dibuka ulang 404. Daftar memuat id/trip_number/status/lock_version/planned_departure_at/timezone/vehicle/total_stops/planned_weight_g/planned_volume_cm3/feasibility_status/estimated_arrival_at; detail menambah depot/route_version/stops. Tidak ada endpoint start, hasil, pembayaran atau rekonsiliasi tahap ini. Pernyataan kurir baru login/me pada bagian fase sebelumnya merupakan histori.

Web admin telah dimigrasikan ke React + Inertia + shadcn/ui asli pada 4 November 2026. Akses web tetap session+CSRF dan role admin aktif; sebutan admin Blade pada catatan historis berarti stack sebelum migrasi. API mobile dan payload bisnis tetap sama. Lihat ADMIN_UI_MIGRATION.md.

Base /api/v1; JSON; bearer Sanctum untuk mobile, session+CSRF untuk admin Blade. ID string, rupiah integer, berat gram, volume cm³, waktu ISO UTC. Response `{data: ...}`; daftar ditambah meta/links pagination. Per_page default 20 maksimal 100. Error validasi 422 memakai message/errors; bisnis 409 memakai message/code. 401 token invalid; 403 role/akun; 404 resource tidak ada/milik user lain; 429 rate limit.

## Endpoint

| Method/path | Fungsi |
| --- | --- |
| GET /health | Publik; data.service=shipx-api, status=ok, api_version=v1; tidak memeriksa DB |
| POST /auth/register | Buat customer, bukan role pilihan client |
| POST /auth/login | Email/password/device_name → user + bearer token |
| DELETE /auth/token | Cabut token sekarang, 204 |
| GET /me | Profil sendiri tanpa password/token tersimpan |
| GET /catalog | Customer aktif; depot dan SKU aktif dengan metadata kemasan; belum menjamin stok atau menerima pesanan |
| GET /delivery-slots?date=YYYY-MM-DD | Slot belum cutoff pada tanggal lokal depot |
| GET /delivery-settings | Customer aktif; konfigurasi wilayah, ongkir, zona waktu dan waktu server |
| GET/POST /addresses | Daftar/buat alamat sendiri |
| PATCH/DELETE /addresses/{id} | Edit/nonaktifkan alamat sendiri |
| POST /order-quotes | Hitung harga/berat/volume, tanpa reservation |
| POST /orders | Checkout multi-SKU atomik, status pending, 201 |
| GET /orders | Pesanan sendiri, terbaru dulu |
| GET /orders/{id} | Detail snapshot sendiri |
| POST /orders/{id}/cancel | Batalkan pending/confirmed dengan lock_version |

### Keputusan admin yang tersedia

Jalur web session+CSRF khusus admin aktif: POST `/admin/orders/{order}/confirm` menerima idempotency_key UUID dan lock_version; POST `/admin/orders/{order}/reject` menambahkan reason wajib 1–500 karakter setelah trim. Actor, status dan waktu tidak boleh dipilih client. Berhasil redirect ke detail terbaru; konflik bisnis 409 ditampilkan melalui halaman Inertia. Ini bukan endpoint bearer mobile.

Hanya pending sebelum pending_expires_at dapat diputuskan. Konfirmasi menjadi confirmed dan mengisi confirmed_at, tanpa mengurangi fisik atau melepas reservasi. Penolakan menjadi rejected, mengisi closed_at/status_reason dan melepas reservasi active sekali. Status final tidak dapat diputuskan ulang. Catatan order_decisions dengan UNIQUE(order_id) menyimpan admin, waktu, jenis keputusan, alasan dan versi hasil secara atomik. Idempotency memakai scope admin+jenis keputusan+order dan retensi 30 hari yang sama; key sama/payload sama tidak membuat keputusan kedua.

Versi/status/reservasi dan deadline diperiksa setelah lock depot → account ascending → order. Jika deadline terlewati ketika menunggu lock, order menjadi cancelled/PENDING_EXPIRED dan respons ORDER_EXPIRED 409 disimpan bersama pelepasan reservasi. Konflik lain: STALE_VERSION, ORDER_NOT_PENDING, RESERVATION_CONFLICT. Tidak ada perubahan snapshot harga/alamat/jadwal saat konfirmasi. Confirmed masih dapat dibatalkan customer memakai versi terbaru sebelum assignment.

GET orders/detail customer sekarang dapat menghasilkan confirmed/rejected dan menambahkan confirmed_at serta closed_at nullable ISO UTC. Alasan penolakan terlihat customer; identitas admin dan relasi order_decisions tidak dikirim ke API customer. Flutter menampilkan status/alasan dan refresh manual/polling foreground 15 detik; ini bukan push notification. Detail/batas polling dan bukti uji di ORDER_DECISIONS_CHECKPOINT.md.

## Payload checkout

### Master kurir dan kendaraan (web admin)

Session web+CSRF dan admin aktif diperlukan untuk GET index/create/edit serta POST create/PUT-PATCH update `/admin/couriers` dan `/admin/vehicles`. Tidak ada delete atau endpoint bearer mobile master. Daftar memakai q max100, status active/inactive, page>=1, pagination20. Edit wajib lock_version; versi lama409 tanpa overwrite. Lihat FLEET_MASTERS_CHECKPOINT.md.

Kurir menerima name/email max255, phone wajib max30, is_active boolean; password create wajib min12/max1024 dan confirmed, edit kosong mempertahankan password lama. Email lowercase/trim unik terhadap semua users. Role ditetapkan courier oleh server; URL kurir tidak dapat mengedit admin/customer. Perubahan email/password atau nonaktif mencabut token Sanctum, reaktif tidak mengembalikan token lama. Props admin hanya id/name/email/phone/is_active/lock_version, tanpa hash/token/password.

Kendaraan menerima code uppercase/trim max64 dengan karakter SKU ASCII, name max160, plate_number alfanumerik 3–16 setelah uppercase dan menghapus spasi/hyphen; code dan plate unik per depot. travel_mode motorcycle/car; max_load_weight_g integer 1–10^9, max_load_volume_cm3 integer 1–10^12, is_active boolean. Depot ID1 ditetapkan server. Batas input teknis bukan rekomendasi kapasitas kendaraan tertentu. Belum ada penugasan/trip/routing pada master.

Perbaikan respons checkout: POST orders kini selalu membaca default DB sebelum resource dibuat; lock_version awal integer0, bukan null. Status dan API lainnya tetap mengikuti kontrak order di bawah.

### Katalog yang sudah tersedia

`GET /api/v1/catalog` memakai bearer customer aktif. Courier/admin menerima 403; pengelolaan admin melalui web session. Query `q` opsional maksimal 100 karakter (nama, kategori, SKU), `category` opsional maksimal 80 karakter untuk kecocokan kategori penuh sesuai collation database, `page` minimal 1, `per_page` default 20 maksimal 100. Filter kategori dan pencarian digabungkan sebelum pagination. Urutan nama lalu ID. Respons `{data:[...],links:{...},meta:{...},depot:{id,name},categories:[string,...]}`. `categories` berisi kategori unik seluruh SKU aktif depot utama, diurutkan nama dan tidak dipotong oleh halaman/filter pencarian/kategori. Filter kategori kosong berarti semua; kategori tidak ditemukan menghasilkan data kosong. Tambahan ini mendukung tab vertikal Flutter tanpa menebak kategori dari halaman pertama.

Item katalog: id string, sku, name, category, unit_label, unit_price_rp integer, shipping_weight_g, shipping_volume_cm3, length_mm, width_mm, height_mm, handling_notes nullable. Produk nonaktif selalu dikecualikan. Flutter menampilkan detail dari item yang dimuat, pencarian, pagination, retry dan refresh; data katalog dapat berubah dan nantinya harus divalidasi ulang saat checkout.

Admin web `/admin/products` mendukung daftar, pencarian nama/SKU, filter aktif/nonaktif, tambah dan edit. SKU dinormalisasi uppercase dan unik per depot. Harga 1–1.000.000.000 rupiah; berat 1–1.000.000 gram; setiap dimensi 1–10.000 mm. Volume dihitung server sebagai `ceil(panjang × lebar × tinggi / 1000)` cm³. Client tidak boleh memilih depot atau volume. Status nonaktif tetap menyimpan produk; belum ada hapus permanen. Update PUT/PATCH wajib lock_version; versi lama menerima halaman 409 dengan tautan muat ulang. Update berhasil menaikkan versi.

Depot utama (ID 1) dikonfigurasi lewat menu Depot. Lokasi, cakupan layanan dan ongkir harus lengkap sebelum checkout. Katalog kini memuat available_quantity integer: saldo depot/available dikurangi reservation aktif. Produk baru mulai dengan saldo nol, bukan stok fiktif. Flutter dapat menambahkan barang ke keranjang dari detail katalog.

### Checkout yang tersedia

```json
{
  "address_id":"12",
  "delivery_slot_id":"4",
  "items":[{"product_id":"1","quantity":2},{"product_id":"2","quantity":1}],
  "expected_total_rp":45000
}
```

Quote memakai payload sama tanpa expected_total_rp. Maksimal awal 20 SKU unik, quantity per item 1–20, ditinjau saat pilot. Product duplikat ditolak 422; stok salah satu SKU kurang menolak seluruh checkout. Tidak ada exchange_confirmed atau exchange_required_units. Server menghitung seluruh harga dan metadata pengiriman. Produk dinonaktifkan/tidak punya metadata valid ditolak 422. Address di luar wilayah ditolak 422, slot lewat cutoff → 409 SLOT_CLOSED, stok kurang → 409 OUT_OF_STOCK, harga berbeda → 409 PRICE_CHANGED.

Contoh quote dua SKU: 2 × Rp15.000 + 1 × Rp12.000 + ongkir Rp3.000 = Rp45.000. Nilai hanya contoh. Response memuat item(product_id,quantity,unit_price_rp,line_total_rp,unit_weight_g,unit_volume_cm3), subtotal_rp, delivery_fee_rp, total_rp, total_weight_g, total_volume_cm3, stock_available_now, reserves_stock=false. Checkout menghitung ulang dan menyimpan snapshot; quote tidak menjamin stok.

Response order: id, order_number berprefix SX, status, payment_status, lock_version, items termasuk snapshot nama/unit/harga/berat/volume/dimensi, total, address snapshot, window_start_at/end_at, pending_expires_at, estimated_arrival_at nullable, created_at. Jangan mengekspos alamat penerima lain. Edit master tidak mengubah order lama.

### Stok, reservation dan order

Semua endpoint order/quote memakai bearer customer aktif. POST order-quotes mengembalikan 200 `{data:quote}` dan tidak membuat reservation. Quote menambahkan nama, satuan, dimensi, handling_notes dan available_quantity per item. Jika stok kurang, quote tetap 200 dengan stock_available_now=false; checkout menolak seluruh transaksi dengan 409 OUT_OF_STOCK. Semua angka dihitung dari master server. Order berhasil: 201 `{data:order}`, status pending, payment_status unpaid, pembayaran COD tunai. Order number `SX-YYYYMMDD-ULID`. Total rupiah/berat/volume tersimpan sebagai integer 64 bit.

Alamat wajib aktif dan milik customer (ID user lain 404), berada dalam radius terkini (422), depot lengkap (409 DELIVERY_NOT_CONFIGURED), slot milik depot/aktif/belum cutoff (409 SLOT_CLOSED), dan produk aktif dengan metadata valid (422). expected_total_rp wajib pada checkout dan dibandingkan dengan perhitungan ulang; perubahan harga/ongkir menghasilkan 409 PRICE_CHANGED. Items duplikat ditolak; urutan item dinormalisasi berdasarkan product_id. Payload item hanya product_id/quantity; harga per item dari client ditolak.

Saldo fisik tetap ketika order dibuat; reservation active ditulis per order_item dalam transaksi yang sama dengan order dan snapshot. Pending_expires_at adalah nilai paling awal antara sekarang + TTL depot dan cutoff slot. Pending yang habis TTL menjadi cancelled dengan status_reason=PENDING_EXPIRED dan reservation dilepas sekali. Ini bukan mutasi fisik sehingga tidak membuat entry ledger pengiriman. Semua operasi stok memakai mutex depot tunggal, lalu account di-lock ascending ID; perubahan order setelah lock account. Desain ini sengaja menyerialkan mutasi depot pada skala MVP, belum klaim throughput tinggi.

POST /orders dan POST /orders/{id}/cancel mewajibkan Idempotency-Key UUID. Scope user+operation (cancel termasuk ID order), hash dari payload tervalidasi yang dinormalisasi. Claim, perubahan domain dan response tersimpan commit dalam transaksi yang sama. Retry request berhasil mengembalikan status/body awal (201 untuk create, 200 untuk cancel); kegagalan bisnis 409/422/404 juga disimpan. Key sama dengan payload berbeda 409 IDEMPOTENCY_CONFLICT. Lock timeout/deadlock yang belum selesai 409 REQUEST_IN_PROGRESS; retry dengan key yang sama. Record lewat 30 hari ditolak 409 IDEMPOTENCY_EXPIRED; periksa order sebelum memulai key baru. Belum ada penghapusan otomatis record idempotency.

Cancel menerima lock_version integer dan reason wajib maksimal 500. Hanya pending/confirmed dapat dibatalkan. Versi berubah 409 STALE_VERSION; status tidak sesuai 409 ORDER_NOT_CANCELLABLE. Response cancel 200 berisi order snapshot, status cancelled dan versi bertambah. Reservation dilepas hanya yang active; saldo fisik dan ledger stok tidak berubah. GET orders hanya milik sendiri, newest ID first, pagination default 20/maks 100. GET orders/{id} user lain 404. Resource menyertakan timezone snapshot, address{recipient_name,phone,address_text,latitude,longitude,directions}, item snapshot, totals, reason, deadline dan ETA null.

Admin `/admin/stock` melihat saldo per SKU: fisik tersedia, reserved, siap dipesan, karantina. POST `/admin/stock/{product}` menerima UUID idempotency_key, stock_state available/quarantine, quantity_delta signed nonzero ±1.000.000, reason wajib maks 500. Entry ledger dan balance berubah atomik; saldo akhir tidak boleh negatif/kurang dari reservation (409 STOCK_CONFLICT). Mutasi positif pertama opening, berikutnya adjustment. `/admin/orders` dan detail mendukung antrean/filter pending, confirmed, rejected, cancelled serta konfirmasi/penolakan pending. Penugasan, delivery dan rekonsiliasi belum tersedia.

`php artisan shipx:expire-orders` memproses expiry; scheduler menjalankannya tiap menit ketika Laravel scheduler aktif. Untuk development gunakan `php artisan schedule:work`. Katalog, quote, checkout, daftar/detail order dan admin stok/order juga menjalankan cleanup due secara bertahap sampai selesai, sehingga tidak bergantung hanya pada UI HP untuk melepas reservation.

Flutter menyimpan keranjang dan pilihan alamat/slot dalam memori sesi. Sebelum create/cancel, pending payload+UUID ditulis ke secure storage per user. Timeout/5xx/REQUEST_IN_PROGRESS mempertahankan permintaan dan mengunci perubahan keranjang sampai hasil dipastikan melalui retry identik. Respons bisnis final membersihkan pending; stok/harga dapat diperiksa ulang sebelum percobaan baru. Pending lebih dari 30 hari memerlukan pemeriksaan riwayat dan konfirmasi pengguna sebelum ditutup. Cart kosong setelah create berhasil; order tetap dapat dilihat lewat Pesanan saya. Logout/401 menghapus halaman privat dari stack navigasi; pending milik user tetap dapat dipulihkan setelah login kembali.

## Depot, alamat, dan slot yang tersedia

Semua endpoint delivery/address memerlukan bearer **customer aktif**. Admin mengelola `/admin/depot` (GET/PUT) dan `/admin/slots` (index/create/store/edit/update) melalui session+CSRF. Tidak ada koordinat atau ongkir contoh yang otomatis dipasang pada depot pengguna. Sebelum depot lengkap, GET delivery-settings mengembalikan configured=false; POST/PATCH alamat menerima 409 `DELIVERY_NOT_CONFIGURED`, dan daftar slot kosong.

`GET /delivery-settings`: `{data:{id,name,configured,address_text,latitude,longitude,timezone,service_radius_m,delivery_fee_rp,today,server_time}}`. Koordinat angka atau null; today adalah tanggal lokal depot; server_time ISO UTC. Zona waktu yang didukung saat ini Asia/Jakarta, Asia/Makassar, Asia/Jayapura. Radius 1–200.000 meter, ongkir integer 0–1.000.000.000 rupiah. Admin juga menyimpan pending_ttl_minutes (1–1440, default 30) dan default_service_seconds (1–7200, default 300) untuk fase checkout/routing. PUT depot wajib lock_version; konflik versi menerima halaman 409. Zona waktu tidak dapat diubah setelah slot pernah dibuat agar service_date tidak berubah makna.

Alamat: POST menerima label (maks 80), recipient_name (160), phone (30), address_text (2000), latitude [-90,90], longitude [-180,180], directions nullable (1000). Kolom selain directions wajib. Koordinat dibulatkan tujuh desimal sebelum pemeriksaan radius dan penyimpanan. user_id dan is_active dilarang dari client. Jarak dihitung Haversine dengan radius bumi 6.371.008,8 meter; tepat batas diterima, di luar radius ditolak 422 pada latitude. Radius adalah jarak geodesik, bukan estimasi ruas jalan.

POST 201 / PATCH 200 mengembalikan `{data:{id,label,recipient_name,phone,address_text,latitude,longitude,directions,lock_version,within_service_area}}`. ID string. PATCH mendukung perubahan parsial dan wajib lock_version; DELETE wajib lock_version pada body, menonaktifkan alamat dan mengembalikan 204. Versi tidak sesuai: 409 `STALE_VERSION`. DELETE ulang alamat sendiri yang telah nonaktif tetap 204. PATCH alamat nonaktif atau akses ID user lain menerima 404. GET addresses hanya alamat aktif milik sendiri dengan pagination default 20, per_page maksimal 100; tiap alamat dihitung ulang within_service_area terhadap konfigurasi depot terbaru. Perubahan radius/titik depot tidak menghapus alamat lama.

GET delivery-slots mewajibkan date format YYYY-MM-DD sesuai zona waktu depot, page minimal 1, per_page default 20 maksimal 100. Respons `{data:[{id,service_date,window_start_at,window_end_at,cutoff_at}],meta,links,timezone,server_time}`. Semua timestamp UTC; yang tampil hanya slot aktif pada service_date tersebut, cutoff_at > waktu server, dan window_start_at > waktu server. Tepat cutoff sudah ditutup.

Admin memasukkan service_date, start_time/end_time (HH:mm), cutoff_local (YYYY-MM-DDTHH:mm), is_active, serta lock_version untuk update PUT/PATCH. Semua input waktu ditafsirkan dalam zona depot lalu disimpan UTC. Akhir harus setelah awal pada hari yang sama; cutoff <= awal. Slot aktif belum cutoff dan maksimal 365 hari ke depan. Rentang sama per depot ditolak walaupun slot lama nonaktif; edit slot lama. Slot lewat cutoff boleh dinonaktifkan. Belum ada kuota kapasitas slot atau reservation.

Flutter menyimpan pilihan alamat/slot hanya pada layar pengiriman selama sesi aplikasi; pindah tab mempertahankan pilihan, refresh menghapus pilihan slot, logout menghapus state layar. Pilihan slot kedaluwarsa dibersihkan menggunakan waktu server + waktu monotonic perangkat. Checkout berikutnya harus memvalidasi ulang status slot, cakupan alamat, harga dan stok. Peta pin memakai flutter_map/OpenStreetMap dan atribusi; input koordinat manual tetap tersedia jika tile tidak termuat.

## Identitas dan keamanan

Status implementasi auth: register mengembalikan 201; login 200; me 200; logout token saat ini 204. Register dan login mengembalikan `{data:{user:{id,name,email,phone,role},token,token_type,expires_at}}`; me mengembalikan `{data:{id,name,email,phone,role}}`. ID berupa string. Token berlaku 30 hari, dicabut per perangkat saat logout. Mobile menggunakan bearer saja; session admin tidak diterima sebagai autentikasi API.

Validasi: name/email maksimal 255, phone maksimal 30, device_name maksimal 100, password minimal 12 saat register (maksimal 1024). Password salah/email tidak dikenal mengembalikan 422 dengan pesan sama; kredensial benar pada akun nonaktif mengembalikan 403. Akun yang kemudian dinonaktifkan juga menerima 403 pada endpoint terlindungi. Login dibatasi 5 percobaan/menit per email+IP dan 30/menit per IP; register 5/menit per IP. Atribut role/is_active tidak boleh hadir pada request publik. Endpoint bisnis fase berikutnya wajib memakai auth dan pembatasan role server sesuai pemilik operasi.

Web admin: GET/POST `/admin/login`, GET `/admin`, POST `/admin/logout` dan resource `/admin/products`; menggunakan session web, rotasi session, CSRF dan role admin aktif. Akun staf dibuat operator melalui `php artisan shipx:create-staff admin` atau `courier` dengan password interaktif; tidak ada akun/password bawaan. Pengelolaan produk tersedia; order dan operasi pengiriman menyusul.

Register menerima name,email,phone,password(min 12),password_confirmation,device_name. Email dinormalisasi, login dibatasi rate dan pesan generik; role/is_active dilarang dari client. Response auth memuat user(id,name,email,phone,role), token, token_type=Bearer, expires_at (default rancangan 30 hari, ditegakkan server). Akun kurir/admin dibuat oleh jalur admin. Tahap awal email verification belum memblokir checkout; tinjau sebelum pilot publik.

Alamat: label,recipient_name,phone,address_text,latitude,longitude,directions nullable. Kepemilikan diverifikasi server; source_address_id hanya asal snapshot. Radius geodesik untuk wilayah, matriks jalan untuk optimasi; keduanya berbeda fungsi.

POST /orders dan cancel mewajibkan Idempotency-Key UUID. Key sama+payload sama mengembalikan response awal; payload beda → IDEMPOTENCY_CONFLICT; sedang berjalan → REQUEST_IN_PROGRESS. Key cancel discope ke ID order; simpan key di HP sampai hasil jelas. Retensi rancangan 30 hari, jangan replay aksi lama setelah retensi tanpa memeriksa order dan konfirmasi baru. Timeout bukan bukti gagal. Cancel menerima lock_version dan reason maks 500; konflik versi → STALE_VERSION, status tidak sesuai → ORDER_NOT_CANCELLABLE.

## Fase berikutnya

Auth → katalog multi-SKU → alamat/slot → quote/checkout/reservation → daftar/detail/cancel → web admin. Kurir baru login/me pada fase ini; endpoint trip, hasil, COD, reconciliation per SKU dan optimasi dirancang setelah fondasi stabil. Uji race stok memakai MySQL.
