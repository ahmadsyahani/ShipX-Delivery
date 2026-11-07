# Hasil pengiriman, foto bukti dan COD

Checkpoint 6 November 2026 melanjutkan TRIP_DEPARTURES_CHECKPOINT.md. Source Flutter terbaru memakai tema dan komponen yang telah dirapikan pengguna. Migration `2026_11_06_000009_create_delivery_results` sudah Ran di MySQL lokal. Perubahan masih lokal di develop bersama checkpoint sebelumnya.

## Alur yang tersedia

Kurir membuka trip in_progress dan mencatat hasil sesuai urutan tujuan. Hanya tujuan pending pertama yang dapat diproses. Form berhasil membutuhkan foto bukti serta jumlah COD yang tepat sama dengan seluruh tagihan. Form gagal membutuhkan alasan dan mengirim COD nol. Catatan opsional maksimal 500 karakter. Foto gagal bersifat opsional. Seluruh item order diserahkan sekaligus atau seluruhnya gagal.

Foto dipilih dari kamera/galeri melalui image_picker, disalin ke application support untuk pemulihan permintaan, lalu diunggah sebelum hasil dicatat. Format server JPEG/PNG maksimal 2 MiB dengan dimensi maksimal 4096 × 4096. Kamera meminta ukuran maksimal 1600 × 1600 dan quality 80. Metadata unggahan berlaku 24 jam. Foto memakai nama UUID dan disk local privat. Server memeriksa isi/MIME/dimensi dan menyimpan checksum SHA-256.

Flutter menyimpan key unggahan, key hasil, payload dan referensi foto lokal sebelum request. Retry unggahan memakai key yang sama. Setelah unggahan berhasil, ID foto disimpan sebelum POST hasil. Timeout, gangguan jaringan, 5xx, 429 dan REQUEST_IN_PROGRESS mempertahankan permintaan. Konflik definitif mengharuskan refresh dan tinjauan ulang. Restore tidak otomatis mengirim. Ketika GET sudah menunjukkan hasil final, catatan lokal dibersihkan. Foto lokal dihapus setelah hasil terkonfirmasi. Gangguan penyimpanan memblokir pengiriman baru.

## Konsistensi stok dan uang

Pencatatan hasil memegang mutex depot yang sama dengan operasi sebelumnya, kemudian master kurir/kendaraan, account trip ID ascending, order dan trip. Server memeriksa kurir aktif pemilik trip, versi order/trip, keberangkatan, route/stops, urutan tujuan, claims, stok per SKU dan kepemilikan/expiry unggahan.

Berhasil membuat satu delivery_result, semua result_items dengan delivered_quantity sama dengan jumlah order, satu delivery ledger event unik per order, satu bukti foto dan satu payment_collection tunai sebesar total order. Saldo trip/available berkurang per SKU. Order menjadi delivered/paid dan closed_at terisi.

Gagal membuat hasil serta result_items dengan delivered_quantity nol. Order menjadi failed/unpaid dengan alasan. Saldo barang tetap di trip. Tidak ada collection atau transaksi keluar barang untuk kegagalan. Semua perubahan hasil, bukti, ledger, status dan COD berada dalam satu transaksi. UNIQUE order/stop/result/payment dan idempotency mencegah penggandaan.

Sesudah seluruh stops memiliki hasil, trip menjadi awaiting_reconciliation. actual_return_at tetap menunggu proses kembali ke depot. Claims order/kurir/kendaraan masih ditahan. Admin mengakses hasil dan COD melalui detail pesanan, tautan foto privat dan filter delivered/failed. Detail trip menampilkan status menunggu rekonsiliasi. Customer melihat status/alasan serta foto dan COD milik pesanan sendiri.

## Kontrak API tambahan

- `POST /api/v1/courier/trips/{id}/stops/{stop}/proofs` memakai bearer kurir aktif dan Idempotency-Key UUID, multipart field photo. Sukses mengembalikan data.id UUID unggahan serta expires_at ISO UTC. Replay key/foto/tujuan yang sama mengembalikan ID sama. Key dengan foto/tujuan berbeda atau unggahan expired ditolak 409.
- `POST /api/v1/courier/trips/{id}/stops/{stop}/result` memakai bearer kurir aktif dan Idempotency-Key UUID. JSON memuat trip_version, order_version, outcome delivered/failed, cash_received_rp, failure_reason, notes dan proof_upload_id. proof_upload_id wajib untuk delivered. cash_received_rp harus sama dengan tagihan untuk delivered dan nol untuk failed. Item quantities, actor dan payment status ditetapkan server. Response 200 memuat id hasil, order_id, outcome, trip_status serta versi baru. Validasi 422, konflik 409, resource di luar akses 404.
- `GET /api/v1/delivery-proofs/{proof}` memerlukan bearer aktif. Customer hanya untuk order sendiri, courier hanya untuk trip sendiri, admin dapat mengaudit. `GET /admin/delivery-proofs/{proof}` memakai session web admin aktif. Tidak ada URL publik. Response memakai MIME gambar, private/no-store dan nosniff.
- GET order menambah delivery_result untuk status final. GET courier trip mencakup awaiting_reconciliation. Stops memuat id, status, order_version, can_record_result dan result. can_record_result merupakan petunjuk UI, pemeriksaan POST tetap otoritatif.

## Penyimpanan dan pembersihan

Tabel baru delivery_proof_uploads, delivery_results, delivery_result_items, delivery_proofs dan payment_collections. Composite FK result order/stop memastikan hasil terikat tujuan yang sesuai. Bukti dan collection unik per hasil. Storage key tidak dikirim lewat resource API. Hasil final tidak memiliki endpoint edit/hapus.

Upload file berlangsung di luar transaksi database. Kegagalan metadata menghapus file milik request itu. `php artisan shipx:cleanup-delivery-proofs` menandai unggahan pending expired di bawah mutex depot, lalu menghapus file di luar transaksi. Bukti attached dipertahankan. File UUID tanpa metadata yang berumur lebih dari sehari juga dibersihkan. Command dijadwalkan harian dan mengikuti scheduler Laravel yang sudah dipakai proyek. Jalankan scheduler atau command manual di lingkungan lokal.

Default disk privat tetap mengikuti konfigurasi aplikasi. QA memberi LOCAL_PRIVATE_STORAGE_PATH hanya pada proses server QA agar file sintetis terpisah. Launcher QA membersihkan foto dalam root unik miliknya saat dihentikan. Tidak menulis konfigurasi tersebut ke .env pengguna.

## Verifikasi

Suite backend mencakup 6 skenario baru untuk transaksi hasil/COD multi-SKU, foto privat, kepemilikan, expiry, stok kurang, urutan tujuan dan pembersihan staging. Flutter mencakup pemulihan dua tahap unggahan/hasil, key yang tetap, kegagalan storage, form gagal sampai dialog konfirmasi, serta multipart HTTP dengan bearer dan byte foto. Seluruh 53 tes Flutter lolos, analyzer bersih. Build Vite/TypeScript dan APK debug berhasil. Gradle sempat menolak tiga entri cache immutable, percobaan karantina tertahan file lock, kemudian build ulang berhasil.

Suite backend akhir lolos 91 tes dengan 1432 assertions. Pemeriksaan akhir menemukan 0 database QA, 0 hasil/unggahan uji di database bisnis, dan hash .env identik. File foto QA dibersihkan oleh launcher. Foto draft lokal memakai nama unik agar dua layar tidak saling menimpa, dan dibersihkan saat diganti atau ditinggalkan sebelum submit. HP belum terdeteksi ADB untuk uji kamera fisik.

Seluruh 6 skenario browser lolos. Skenario keberangkatan sekarang diteruskan sampai unggahan foto, delivered + COD dengan replay, akses foto customer, failed tujuan terakhir, serta tampilan hasil admin desktop/390 px. Screenshot diperiksa.

`php scripts/verify-delivery-results-mysql.php` lolos dengan worker paralel pada database disposable. Pengujian mencakup delivered vs failed, delivered dengan key sama/berbeda, satu hasil/proof/COD/ledger, saldo per SKU dan claims sampai awaiting_reconciliation. Launcher juga menjalankan kembali race penugasan/start serta rollback/reapply migration pada database QA kosong.

Untuk browser gunakan `php scripts/serve-checkout-qa.php departures`, lalu `npm.cmd run test:e2e` di backend. Hentikan memakai `php scripts/serve-checkout-qa.php stop` agar database dan foto QA dibersihkan. `.env` dipertahankan dengan SHA-256 `DBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C`.

Uji kamera/pemilih foto pada HP fisik masih memerlukan perangkat tersambung. Rekonsiliasi barang kembali, barang rusak/karantina, penyetoran COD, penutupan trip dan pelepasan claims menjadi checkpoint berikutnya. Navigasi tujuan dan optimasi provider tetap mengikuti rencana selanjutnya.
