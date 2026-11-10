# Barang kembali, setoran COD dan penutupan trip

Checkpoint 8 November 2026 melanjutkan DELIVERY_RESULTS_CHECKPOINT.md. Perubahan lokal pada `develop`; belum commit/push dan tidak otomatis merge ke `main`.

## Operasi

Sesudah semua tujuan final, kurir membawa barang tersisa dan uang ke depot. Admin membuka trip `awaiting_reconciliation`, menghitung setiap SKU (termasuk saldo nol), mengisi jumlah layak jual/karantina dan uang yang benar-benar diterima, lalu menyatakan sudah menerima serta menyetujui hasil hitung. Angka aktual tidak dipraisi; nol harus diisi eksplisit. Dialog terakhir menegaskan pencatatan final.

Expected barang berasal dari saldo akun trip; expected COD dari payment_collections pada rute terpilih. Delivered telah mengurangi muatan, failed masih menyisakan barang. Selisih adalah actual minus expected, dihitung server per SKU/kondisi dan uang. Perubahan kondisi menjadi karantina juga wajib alasan per barang. Barang tambahan dari katalog depot, termasuk nonaktif, dapat dihitung dengan expected nol. Selisih uang wajib alasan sendiri. Admin penerima sekaligus menyetujui satu rekonsiliasi final; kurir tidak dapat menutup trip.

Satu transaksi mengosongkan saldo trip, menambah depot hanya sebanyak fisik yang diterima pada kondisi terpilih, mencatat ledger/receipt/items/audit, mengisi actual_return_at dengan waktu penerimaan admin, mengubah status menjadi completed, menaikkan versi dan melepas active_order_allocations/courier_trip_locks/vehicle_trip_locks. Selisih yang disetujui terekam sebagai perbedaan debit muatan dan kredit barang aktual. Barang hilang tidak dikreditkan, karantina tidak masuk stok siap dipesan. Collection dan hasil/status final order tidak ditulis ulang agar cocok dengan setoran.

Server memeriksa admin aktif, depot, versi, status, seluruh hasil/collection final, claims, SKU muatan lengkap, produk unik satu depot, angka nonnegatif dan alasan. Mutex depot mengikuti stok/start/hasil; idempotency membungkus claim/domain/respons atomik. Key/payload sama melakukan replay; key sama dengan payload berbeda konflik. Tidak ada endpoint edit/hapus rekonsiliasi atau membuka ulang completed. Koreksi berikutnya memerlukan proses audit terpisah.

## Kontrak web dan mobile

`POST /admin/trips/{trip}/reconcile`, session web + CSRF + admin aktif:

```json
{
  "idempotency_key": "UUID",
  "lock_version": 5,
  "actual_cash_rp": 48000,
  "discrepancy_reason": null,
  "received_and_approved": true,
  "items": [
    {
      "product_id": 1,
      "available_quantity": 2,
      "quarantine_quantity": 0,
      "discrepancy_reason": null
    }
  ]
}
```

Maksimal 500 SKU unik; jumlah masing-masing kondisi 0–1.000.000. Setoran 0–100.000.000.000.000 rupiah, mencakup total maksimum trip dari batas harga/pesanan saat ini dan masih dalam integer aman JavaScript. Alasan maksimal 500 karakter. Field expected_cash_rp/approved_by/status tidak boleh dipasok. Sukses redirect ke detail; konflik memakai halaman Conflict agar admin memuat ulang dan meninjau, tanpa silent retry dengan versi baru.

Detail admin menambah reconciliation (expected_cash_rp, items, record nullable), returnProducts hanya saat awaiting, serta filter completed. Receipt final menyimpan expected/actual/difference, alasan, admin/waktu dan dua kondisi per SKU.

`GET /api/v1/courier/trips` tetap menyediakan tugas aktif di data, ditambah recent_completed maksimal lima milik kurir sendiri, terbaru dahulu. Detail completed milik sendiri tetap dapat dibaca: menambah actual_return_at dan reconciliation saat awaiting/completed; can_start/can_record_result false sesudah selesai. Kurir lain 404; role lain/nonaktif ditolak. Flutter menampilkan tugas aktif diikuti riwayat singkat, petunjuk penyerahan saat awaiting dan bukti final setelah refresh/polling, tanpa tombol tutup trip.

## Skema dan uji

Migration `2026_11_07_000010_create_trip_reconciliations` sudah Ran di MySQL lokal. Tabel trip_reconciliations mempunyai trip UNIQUE, expected/actual cash, signed difference, reason, approved_by/at, inventory_transaction_id UNIQUE. reconciliation_items mempunyai FK receipt/product, state, expected/actual quantity, signed difference, reason, UNIQUE receipt/product/state. Tidak mereset DB atau mengubah .env/data bisnis.

- Backend: 100 tes / 1552 assertions lolos, termasuk replay/key conflict, role, stale, SKU tidak lengkap/duplikat/tidak dikenal, alasan/approval, barang tambahan/hilang/rusak, surplus/kekurangan uang, semua berhasil/gagal dan forced DB failure sesudah stok berubah yang harus rollback penuh. Setelah batas setoran diperluas, tes domain diulang.
- Flutter: 70 tes lolos dan analyzer bersih; receipt/polling dan font asli pada 320px (skala teks 1,5), 390px dan 820px. Screenshot build/ui-preview diabaikan Git.
- `php scripts/verify-reconciliation-mysql.php`: race key sama/berbeda dan admin berbeda lolos; satu receipt/ledger, pengembalian tepat sekali, saldo trip nol, COD dan claims benar. Mengulang race start/hasil dan rollback/reapply migration di DB disposable yang dihapus otomatis. Launcher lama diperbaiki agar bootstrap memakai nama Kernel lengkap.
- TypeScript/build web dan APK debug berhasil. Delapan skenario browser lolos pada fixture bersih, termasuk alur hasil pengiriman sampai rekonsiliasi rusak/selisih COD, receipt completed, stok katalog, konflik tab admin lama, filter completed dan screenshot 320/390/1440px. Timeout awal ditelusuri ke redirect yang sudah berhasil di server tetapi menunggu antrean server PHP QA; batas expect UI menjadi 15 detik tanpa mengubah aturan domain. Kontrak ID receipt string juga diuji terpisah (1 tes/17 assertions lolos).

APK memakai API_BASE_URL=http://127.0.0.1:8000/api/v1 untuk adb reverse. HP belum terdeteksi; pemasangan APK dan uji fisik belum dilakukan. Deployment publik tidak termasuk checkpoint ini. Navigasi/optimasi provider dan pilot menjadi tahap selanjutnya; fitur khusus jadwal ulang failed belum tersedia.

Pemeriksaan akhir: 0 database QA, 0 file foto UI QA dan 0 receipt uji di database bisnis. SHA-256 .env tetap DBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C. MySQL dinyalakan memakai executable/config/data Laragon yang sudah ada tanpa initialize/setup ulang. Server QA dihentikan; Laravel lokal disiapkan kembali pada port 8000 untuk peninjauan pengguna.
