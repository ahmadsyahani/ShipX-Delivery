# Konfirmasi dan penolakan pesanan — 4 November 2026

Checkpoint setelah migrasi admin React/Inertia. Admin aktif sekarang dapat mengonfirmasi atau menolak pesanan pending; Flutter customer menampilkan hasil keputusan dan alasan penolakan. Penugasan kurir/kendaraan, trip, delivery, COD selesai dan rekonsiliasi tetap tahap berikutnya.

## Alur dan aturan

1. Customer checkout seperti sebelumnya, menghasilkan pending dan reservasi per item.
2. Admin membuka Pesanan → detail → Konfirmasi pesanan atau Tolak pesanan. Dialog meminta konfirmasi; penolakan wajib alasan maksimal 500 karakter yang terlihat pelanggan.
3. Konfirmasi menjadi confirmed dan mengisi confirmed_at; seluruh reservasi tetap active. Harga, alamat, jadwal dan item snapshot tidak diubah meskipun master berubah.
4. Penolakan menjadi rejected, mengisi closed_at/status_reason dan melepas reservasi active sekali. Tidak ada pengurangan stok fisik, ledger pengiriman atau tagihan yang dibayar.
5. Pending yang melewati deadline menjadi cancelled/PENDING_EXPIRED. Deadline diperiksa setelah menunggu lock, sehingga request yang dikirim sebelum deadline tetap ditolak bila baru memperoleh lock setelah deadline. Pelepasan expiry dan respons konflik disimpan bersama.
6. Hanya pending dapat diputuskan. Keputusan final tidak dapat ditimpa; customer masih boleh membatalkan confirmed sebelum penugasan memakai versi terbaru. Catatan keputusan admin tetap tersimpan setelah pembatalan customer.

Web POST `/admin/orders/{order}/confirm` menerima idempotency_key UUID dan lock_version. POST `/admin/orders/{order}/reject` menerima keduanya ditambah reason. Session web, CSRF dan admin aktif wajib; bearer admin saja tidak memberi akses. Actor/status/waktu ditetapkan server. Berhasil redirect ke detail terbaru; kegagalan bisnis ditampilkan sebagai halaman konflik 409. Scope idempotency per admin, jenis keputusan dan order; replay tidak membuat keputusan atau pelepasan stok kedua. Konflik payload/retensi memakai aturan idempotency 30 hari yang sudah ada.

Mutasi memakai mutex depot, inventory account ascending ID, lalu order. Versi/status/reservasi diperiksa di dalam transaksi. Konfirmasi ditolak bila reservasi hilang, tidak aktif, jumlah/produk/account berbeda, atau saldo tidak mendukung reservasi. Penolakan tetap dapat melepas reservasi yang ada untuk menutup order yang bermasalah. Error bisnis: STALE_VERSION, ORDER_NOT_PENDING, ORDER_EXPIRED, RESERVATION_CONFLICT; invariant database UNIQUE(order_id) mencegah dua catatan keputusan.

## Data dan API customer

Migration tambahan `2026_11_04_000005_create_order_decisions` sudah Ran pada MySQL utama. Tabel order_decisions menyimpan order_id unik, admin_id, decision confirmed/rejected, reason nullable, order_version dan decided_at. Jalur aplikasi hanya menambah catatan; tidak menyediakan edit/hapus. Ini catatan keputusan admin, bukan audit lengkap semua transisi order.

OrderResource menambahkan confirmed_at dan closed_at nullable ISO UTC. Status rejected dan status_reason dapat dibaca melalui GET orders/GET orders/{id} milik customer sendiri. Identitas admin/catatan internal decision tidak diberikan lewat API customer; di web admin hanya id/nama admin terkait yang dimuat.

Flutter menampilkan label Dikonfirmasi/Ditolak, waktu konfirmasi, alasan penolakan dan penjelasan tidak perlu membayar pesanan ditolak. Tombol pembatalan hanya untuk pending/confirmed. Ada tombol Perbarui status dan pull-to-refresh. Halaman pesanan memeriksa status tiap 15 detik saat route paling depan dan aplikasi foreground, serta saat aplikasi aktif kembali. Tidak ada WebSocket/push. Polling detail berhenti pada status final; polling ditunda selama request mutasi belum pasti/berjalan. Pada daftar yang sudah memuat halaman tambahan, pembaruan otomatis ditunda agar isi tidak tiba-tiba kembali ke halaman pertama; pengguna tetap dapat refresh manual. Kegagalan jaringan mempertahankan data terakhir dan menampilkan error.

## Bukti verifikasi

- Backend: **58 tes / 742 assertions lolos**, termasuk delapan tes baru untuk keputusan, replay, snapshot, expiry tepat waktu, validasi, CSRF/role, reservasi rusak dan pembatalan confirmed.
- Flutter: suite sebelumnya 34 tes ditambah lima tes status/polling/pagination; analyzer bersih. Status/alasan, polling foreground, route tertutup, resume, error offline dan halaman tambahan diverifikasi. APK debug berhasil dibangun untuk `http://127.0.0.1:8000/api/v1` melalui USB reverse.
- `php scripts/verify-order-decisions-mysql.php` **lolos**: dua worker nyata confirm versus reject, confirm versus cancel, serta dua keputusan yang tertahan depot lock sampai lewat expiry. Hanya satu transisi menang, catatan keputusan tidak ganda, reservasi sesuai status, ledger fisik tidak berubah. Database sementara otomatis dihapus.
- Dua skenario Playwright desktop/mobile **lolos**, termasuk dialog, alasan wajib, keputusan dari tab lama ditolak, hasil dikonfirmasi/ditolak terlihat melalui API customer, stock available tetap saat confirm dan pulih saat reject. Screenshot keputusan ditinjau. Server QA dan databasenya sudah dibersihkan.
- `.env` tetap identik SHA-256 `DBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C`. Tidak ada akun/produk/order fixture pada database utama. Pengujian Android fisik checkpoint ini belum dilakukan; APK baru belum dipasang ke HP.

## Cara mencoba dan kelanjutan

Gunakan akun customer untuk checkout barang dengan stok nyata dan slot belum cutoff. Di [admin lokal](http://127.0.0.1:8000/admin/orders), buka detail sebelum deadline lalu pilih keputusan. Flutter dengan build terbaru akan menampilkan perubahan saat refresh atau polling halaman pesanan. Jalankan `php artisan schedule:work` dari backend untuk expiry tanpa kunjungan halaman; endpoint terkait juga tetap membersihkan pending expired. Jangan mengulang setup atau menimpa .env.

Tahap berikut sesuai PRD: master kurir/kendaraan beserta kapasitas, penugasan trip manual dan pencegahan penugasan ganda, kemudian operasi kurir, hasil delivery/COD dan rekonsiliasi. Confirmed saat ini menahan stok sampai dibatalkan atau kelak diproses ke trip; belum berarti barang sudah diberangkatkan.
