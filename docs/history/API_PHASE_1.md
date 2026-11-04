> HISTORIS v0.1 — aturan khusus galon dalam dokumen ini sudah digantikan oleh PRD_ShipX.md, ERD_ShipX.md, dan API_PHASE_1.md aktif. Jangan implementasikan aturan lama.

# Kontrak API fase 1 — ShipX

Versi rancangan 0.1, 4 November 2026. Acuan PRD dan ERD di folder ini.

## Status implementasi

Hanya GET /api/v1/health yang dibuat pada setup fondasi. Seluruh endpoint bisnis di bawah adalah kontrak yang harus diimplementasikan bertahap, bukan daftar fitur yang sudah berjalan. Auth memakai Sanctum setelah dipasang pada tahap implementasi autentikasi. Web admin memakai session + CSRF Laravel dan memanggil service bisnis yang sama; tidak menyimpan bearer token dalam Blade.

## Konvensi

- Base path `/api/v1`; Accept: application/json; request JSON kecuali upload bukti di fase pengiriman.
- ID numerik dikirim sebagai string agar aman di berbagai client. Rupiah dan kuantitas integer; timestamp ISO 8601 UTC; koordinat angka desimal. Data null dikirim eksplisit.
- Endpoint privat: Authorization: Bearer <token>. Jangan menaruh token di URL atau log; Flutter memakai secure storage saat auth dibuat.
- Response tunggal: `{ "data": { ... } }`; daftar memiliki `data`, `meta` dan `links`.
- Pagination `page=1&per_page=20`; maksimum per_page=100. Urutan default ditentukan tiap resource; tidak menerima sort kolom SQL bebas.
- Error validasi HTTP 422 mengikuti bentuk `{ "message": "...", "errors": { "field": ["..."] } }`.
- Error bisnis `{ "message": "...", "code": "OUT_OF_STOCK" }`; kode stabil, teks boleh berubah.
- 401 belum login/token invalid; 403 role atau akun tidak aktif; 404 resource tidak ada atau milik pengguna lain; 409 konflik status/versi/idempotency/stok; 429 rate limit. Flutter tidak mengasumsikan semua error non-200 memiliki data.
- Password dan token tidak termasuk response profil. Bukti dan kontak pelanggan lain tidak bocor lewat endpoint umum.

## Daftar endpoint

| Method/path | Akses | Hasil sukses | Status pengerjaan |
| --- | --- | --- | --- |
| GET /health | Publik | 200 identitas API, tidak menguji DB | Dibuat pada fondasi |
| POST /auth/register | Publik | 201 user customer + token | Rencana tahap auth |
| POST /auth/login | Publik | 200 user + token | Rencana tahap auth |
| DELETE /auth/token | Terautentikasi | 204 cabut token saat ini | Rencana tahap auth |
| GET /me | Terautentikasi | 200 user sendiri | Rencana tahap auth |
| GET /catalog | Customer | 200 depot + produk aktif dan aturan penukaran | Rencana tahap master |
| GET /delivery-slots?date=2026-11-05 | Customer | 200 slot aktif belum cutoff | Rencana tahap master |
| GET /addresses | Customer | 200 alamat aktif sendiri | Rencana tahap alamat |
| POST /addresses | Customer | 201 alamat baru | Rencana tahap alamat |
| PATCH /addresses/{id} | Customer pemilik | 200 alamat diperbarui | Rencana tahap alamat |
| DELETE /addresses/{id} | Customer pemilik | 204 nonaktifkan alamat | Rencana tahap alamat |
| POST /order-quotes | Customer | 200 estimasi harga, tanpa reservasi | Rencana tahap pemesanan |
| POST /orders | Customer | 201 order pending + reservasi | Rencana tahap pemesanan |
| GET /orders | Customer | 200 daftar pesanan sendiri terbaru dulu | Rencana tahap pemesanan |
| GET /orders/{id} | Customer pemilik | 200 detail snapshot dan status | Rencana tahap pemesanan |
| POST /orders/{id}/cancel | Customer pemilik | 200 status cancelled | Rencana tahap pemesanan |

Kurir boleh login dan GET /me; endpoint tugas kurir belum termasuk fase 1. Register selalu membuat customer, field role dari client dilarang. Akun kurir/admin dibuat lewat jalur admin terotorisasi, bukan self-registration.

## Health yang tersedia

```json
{"data":{"service":"shipx-api","status":"ok","api_version":"v1"}}
```

Health hanya membuktikan Laravel dan routing hidup. Tidak membuktikan MySQL, autentikasi, stok, atau routing provider sehat.

## Auth yang direncanakan

POST /auth/register menerima name (maks 100), email (normalisasi lowercase/trim, unik, maks 254), phone (string maks 30), password (min 12), password_confirmation, device_name (maks 100). POST /auth/login menerima email, password, device_name. Rate limit keduanya dan gunakan pesan login generik agar tidak membocorkan keberadaan akun.

```json
{
  "data": {
    "user": {"id":"1","name":"Pelanggan Contoh","email":"contoh@example.test","phone":"081234567890","role":"customer"},
    "token":"<token-sekali-ditampilkan>",
    "token_type":"Bearer",
    "expires_at":"2026-12-04T00:00:00Z"
  }
}
```

Default masa berlaku token rancangan: 30 hari, dapat dikonfigurasi; expiration harus ditegakkan server. MVP belum memblokir checkout berdasarkan verifikasi email karena alur verifikasi belum dibangun. Keputusan ini harus ditinjau sebelum pilot publik. Logout mencabut token saat ini saja.

## Alamat

```json
{
  "label":"Rumah",
  "recipient_name":"Pelanggan Contoh",
  "phone":"081234567890",
  "address_text":"Alamat contoh Surabaya",
  "latitude":-7.2575,
  "longitude":112.7521,
  "directions":"Pagar hijau"
}
```

Server memvalidasi rentang koordinat dan radius depot. Radius menggunakan jarak geodesik sebagai aturan area layanan, bukan pengganti jarak jalan untuk optimasi rute. Pin dalam radius belum menjamin jalan dapat dijangkau; admin tetap memeriksa saat perencanaan. Input di luar wilayah → 422 pada latitude/longitude. PATCH hanya menerima field yang diizinkan; user_id dilarang. DELETE menonaktifkan, tidak mengubah snapshot order lama.

## Quote dan checkout

Keduanya menerima payload yang sama; hanya POST /orders mewajibkan Idempotency-Key dan expected_total_rp.

```json
{
  "address_id":"12",
  "delivery_slot_id":"4",
  "items":[{"product_id":"1","quantity":2}],
  "exchange_confirmed":true,
  "expected_total_rp":17000
}
```

MVP hanya menerima satu item untuk produk aktif depot. Batas quantity awal 1–20; admin tetap memeriksa kapasitas kendaraan, dan batas dapat direvisi sebelum pilot. Tidak menerima unit_price, total, status, customer_id atau alamat snapshot dari client.

Contoh quote: harga refill Rp7.000 × 2 + ongkir Rp3.000 = Rp17.000. Angka ini contoh, bukan tarif depot yang sudah disepakati.

```json
{
  "data": {
    "items":[{"product_id":"1","quantity":2,"unit_price_rp":7000,"line_total_rp":14000}],
    "subtotal_rp":14000,
    "delivery_fee_rp":3000,
    "total_rp":17000,
    "exchange_required_units":2,
    "stock_available_now":true,
    "reserves_stock":false
  }
}
```

Quote adalah estimasi saat diminta. Checkout menghitung ulang harga, slot dan stok dalam transaksi; expected_total berbeda → 409 PRICE_CHANGED, minta pengguna meninjau quote baru. Field expected_total_rp pada quote opsional dan diabaikan untuk hitungan harga.

Checkout sukses:

```json
{
  "data": {
    "id":"101",
    "order_number":"AG-20261105-EXAMPLE",
    "status":"pending",
    "payment_status":"unpaid",
    "lock_version":1,
    "items":[{"product_id":"1","product_name":"Galon isi ulang","quantity":2,"unit_price_rp":7000,"line_total_rp":14000}],
    "subtotal_rp":14000,
    "delivery_fee_rp":3000,
    "total_rp":17000,
    "exchange_required_units":2,
    "address":{"recipient_name":"Pelanggan Contoh","phone":"081234567890","address_text":"Alamat contoh Surabaya","latitude":-7.2575,"longitude":112.7521,"directions":"Pagar hijau"},
    "window_start_at":"2026-11-05T02:00:00Z",
    "window_end_at":"2026-11-05T05:00:00Z",
    "pending_expires_at":"2026-11-05T01:30:00Z",
    "estimated_arrival_at":null,
    "created_at":"2026-11-05T01:00:00Z"
  }
}
```

Pending berarti menunggu konfirmasi admin, belum janji pengiriman final. Sisa stok bukan angka publik yang dijamin tetap; server bisa menolak checkout dengan OUT_OF_STOCK. Slot cutoff terlewati → SLOT_CLOSED. Produk nonaktif atau payload tidak sah → 422. Reservation pending dilepas setelah kedaluwarsa atau pembatalan sesuai PRD.

Detail order mengikuti resource yang sama, ditambah status_reason, cancelled_at dan closed_at nullable. ETA baru tersedia setelah penugasan dan tidak menyertakan alamat/nama pelanggan sebelumnya atau berikutnya.

## Pembatalan dan idempotency

POST /orders/{id}/cancel: `{ "lock_version":1, "reason":"Tidak jadi membutuhkan" }`. Reason maks 500; hanya pending/confirmed. Versi lama → 409 STALE_VERSION; status tak boleh dibatalkan → 409 ORDER_NOT_CANCELLABLE. Periksa kembali status sambil mengunci stok dan order; jangan bergantung pada status yang terakhir dilihat HP.

Untuk POST /orders dan POST /orders/{id}/cancel kirim header `Idempotency-Key: <UUID>`.

- Key discope per user dan operation (cancel mencakup ID order). Flutter membuat key sekali untuk satu aksi dan menyimpannya sampai respons pasti diperoleh.
- Retry payload sama mengembalikan status HTTP dan body hasil pertama, bukan transaksi baru. Response replay dapat diberi header Idempotency-Replayed: true.
- Key sama dengan payload berbeda → 409 IDEMPOTENCY_CONFLICT; request masih diproses → 409 REQUEST_IN_PROGRESS, retry key yang sama dengan backoff.
- Validasi shape dapat dilakukan sebelum menyimpan key; respons bisnis final disimpan. Error server yang rollback tidak boleh menyimpan keberhasilan palsu.
- Retensi rancangan 30 hari. Setelah retensi, jangan otomatis retry aksi lama dari antrean HP; refresh daftar/detail dan minta konfirmasi pengguna sebelum aksi baru. Timeout tidak berarti checkout gagal.
- Field expires_at di idempotency_records menentukan kebijakan retensi; UNIQUE constraints domain tetap melindungi hasil pengiriman dan ledger pada fase berikutnya.

## Pagination contoh

```json
{
  "data":[],
  "meta":{"current_page":1,"per_page":20,"last_page":1,"total":0},
  "links":{"next":null,"prev":null}
}
```

GET /orders boleh filter status dari domain resmi; alamat diurutkan id terbaru. Delivery-slots hanya tanggal lokal depot hari ini atau mendatang; date format YYYY-MM-DD, masa pencarian maksimal 7 hari ke depan untuk MVP.

## Batas implementasi pertama

Urutan: health → Sanctum/register/login/me → master depot/product → alamat → slot → checkout + reservation → daftar/detail → pembatalan → login web admin dan antrean order. Login web memakai session, middleware auth/admin dan CSRF, bukan endpoint register publik. Fase sesudahnya baru penugasan, ledger pengiriman, COD dan optimasi.

Kriteria lulus fase pemesanan: login customer/courier tidak melompati role, akses data pengguna lain ditolak, harga dihitung server, snapshot tidak berubah, stok terakhir aman terhadap request bersamaan, retry tidak menggandakan order, pembatalan melepas reservation sekali. Uji konkurensi harus menggunakan MySQL, bukan menganggap hasil SQLite membuktikan perilaku locking MySQL.
