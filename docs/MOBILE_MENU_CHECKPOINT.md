# Menu mobile kategori vertikal — 7 November 2026

Pengguna menyetujui web admin dan meminta katalog mobile mengikuti pola aplikasi pemesanan TOMORO: tab kategori vertikal yang bisa digulir. Web admin dipertahankan. Backend hanya mendapat tambahan kontrak katalog untuk mendukung kategori lengkap, tanpa migration atau perubahan data bisnis.

## Desain

Mengganti panel sambutan besar dengan menu yang langsung menampilkan produk. Header depot/COD dan pencarian ringkas tetap terlihat; rail kategori di kiri dan produk di kanan memiliki scroll controller terpisah. Kategori aktif memakai bidang putih dan indikator teal di kiri, bukan hanya perbedaan warna teks. Memakai Plus Jakarta Sans dan palet ShipX yang telah disetujui: teal #087E8B, navy #182E40, mist #F4F7FA, rail #EEF2F5, white #FFFFFF.

```text
[ShipX / Katalog]                  [tas]
[Depot]                      [Bayar COD]
[Cari produk atau kategori             ]
[Semua    ][Semua produk       refresh ]
[Minuman  ][ilustrasi | nama             ]
[Makanan  ][          | harga    tambah ]
[...      ][produk berikutnya           ]
[scroll   ][scroll produk               ]
[           Lihat keranjang             ] jika berisi
[Katalog | Pengiriman | Keranjang | Akun]
```

Produk belum memiliki field foto. ProductArt menggambar ilustrasi kemasan generik dengan Flutter Canvas, berbeda menurut kategori minuman/makanan/kebersihan/paket, dengan label aksesibilitas “Ilustrasi kemasan kategori ...”. Tidak menganggap ilustrasi sebagai foto barang sebenarnya dan tidak menambahkan foto atau aset merek TOMORO. Referensi pola: [aplikasi TOMORO di Google Play](https://play.google.com/store/apps/details?id=com.tomoro.indonesia.android).

Pada area produk sempit atau skala teks >1.25, ilustrasi berada di atas teks agar nama/harga/tombol tetap terbaca. Detail produk, spesifikasi pengiriman, harga/stock server dan alur COD tetap tersedia. Tombol tambah mematuhi stok tersedia serta lock pending/storage/busy. Kuantitas langsung terlihat pada gambar dan bar keranjang; notifikasi sukses quick-add dihilangkan karena menutupi CTA, kesalahan tetap ditampilkan.

## Data dan state

- GET catalog menerima category, menggabungkannya dengan q sebelum pagination, dan mengembalikan daftar categories seluruh produk aktif depot utama. Produk nonaktif/depot lain tidak membentuk kategori.
- Memilih kategori menghapus pencarian dan kembali ke halaman pertama. Pencarian baru mencakup semua kategori. Pagination dan retry mempertahankan kategori/query yang dipakai. Respons lama dibuang menggunakan generation yang sudah ada.
- Jika kategori aktif hilang pada refresh, pilihan kembali ke Semua dan data dimuat ulang. Error halaman lanjutan mempertahankan produk yang sudah terlihat dan menawarkan retry halaman yang sama.
- Pemilihan kategori dan tambah barang hanya memutasi state lokal; order tetap dibuat melalui quote/checkout yang sudah ada. Tidak ada perubahan autentikasi, versi order, idempotency, reservasi atau ledger.
- Saat memeriksa keranjang berisi pada 320px/skala teks1.5 ditemukan judul+badge melebar; baris tersebut kini Wrap.

## Verifikasi dan cara mencoba

Hasil akhir: **61 tes Flutter**, analyzer bersih; **92 tes backend / 1450 assertions**. APK debug berhasil dibuild, dipasang dan dijalankan di HP I2405 melalui USB dengan API_BASE_URL localhost dan reverse8000. Kamera/hasil pengiriman tidak diuji ulang oleh tugas katalog ini. .env memiliki hash identik dengan awal tugas; tidak ada fixture bisnis atau migration baru.

Tes backend mencakup seluruh kategori di luar halaman pertama, filter sebelum pagination, q+category, kategori kosong/tidak ditemukan, validasi dan pengecualian produk nonaktif/depot lain. Flutter memeriksa query encoding, kategori+paging, respons terlambat, scroll rail independen, quick-add, stok habis serta lock pending. Preview font asli mencakup 320px/1.5x, 390px dan 820px, termasuk keranjang berisi.

Preview ignored: mobile/build/ui-preview/customer-390.png dan customer-cart-390.png. Jalankan test/ui_layout_test.dart dengan --dart-define=SHIPX_UI_SCREENSHOTS=true untuk membuat ulang.

HP USB memerlukan `adb reverse tcp:8000 tcp:8000`, lalu dari mobile jalankan `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1`. `flutter run` tanpa define memakai alamat emulator 10.0.2.2. Jangan mengubah default emulator atau .env untuk menyelesaikan konfigurasi USB.
