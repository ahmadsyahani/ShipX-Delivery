# Kontrak API ShipX — fase 1 v0.2

Acuan PRD_ShipX.md dan ERD_ShipX.md. Health, auth, katalog, depot, alamat, slot, quote, checkout, daftar/detail/cancel order sudah diimplementasikan. Detail bukti uji dan batasannya ada di SETUP_STATUS.md.

## Konvensi

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

### Katalog yang sudah tersedia

`GET /api/v1/catalog` memakai bearer customer aktif. Courier/admin menerima 403; pengelolaan admin melalui web session. Query `q` opsional maksimal 100 karakter (nama, kategori, SKU), `page` minimal 1, `per_page` default 20 maksimal 100. Urutan nama lalu ID. Respons `{data:[...],links:{...},meta:{...},depot:{id,name}}`.

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
