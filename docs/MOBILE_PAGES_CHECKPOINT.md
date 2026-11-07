# Penyatuan seluruh tampilan mobile — 7 November 2026

Pengguna meminta Pengiriman, Keranjang, Akun dan halaman mobile lainnya didesain ulang mengikuti katalog yang telah disetujui. Web admin dan kontrak API tidak diubah oleh checkpoint ini.

## Arah desain dan cakupan

Palet putih #FFFFFF, mist #F4F7FA, ocean teal #087E8B, deep teal #05555E dan teks navy #182E40; Plus Jakarta Sans lokal dipertahankan. Area informasi memakai panel putih tanpa bayangan, judul ringkas, ikon bagian dan jarak antarbagian. Produk tetap memakai ilustrasi kemasan generik. Rancangan mengikuti pekerjaan pada setiap layar: Pengiriman memilih tujuan/waktu, Keranjang meninjau barang/tagihan, Akun membuka fungsi akun. Tidak menambahkan promosi, saldo, loyalty atau metrik buatan.

```text
Pengiriman: [intro] [depot + ongkir] [alamat] [tanggal + slot] [ke keranjang]
Keranjang:  [intro] [barang + jumlah] [tujuan/jadwal] [COD + quote + konfirmasi]
Akun:       [profil] [pesanan / alamat / trip] [sesi / lisensi / keluar]
Pesanan:    [status + nomor + total] -> [status] [tujuan/jadwal] [rincian + COD]
```

- Komponen bersama AppPanel, AppPageIntro, AppSectionTitle dan AppAmountLine dipakai lintas layar. AppPanel memakai Material agar ink/tap pada menu tetap terlihat; tes menemukan dekorasi Container yang menutupi ListTile dan hal tersebut diperbaiki.
- Pengiriman menampilkan depot/ongkir, kartu penerima, pemilihan slot dengan indikator terpilih dan lanjut ke keranjang setelah alamat+slot dipilih. Tombol ini hanya navigasi ke tab yang sudah ada, tidak membuat order/reservasi.
- Keranjang mengelompokkan barang, pengiriman dan pembayaran. Ilustrasi sama dengan katalog, kontrol jumlah dan hapus mempertahankan lock. Quote server, retry pending, periksa riwayat, persetujuan COD dan pemeriksaan fingerprint tetap utuh.
- AccountPage baru memisahkan profil dari daftar menu. Customer mempunyai Pesanan saya dan Alamat & jadwal, courier Trip saya; refresh sesi, lisensi dan logout tetap memakai callback yang sama. Tidak ada tombol ubah profil yang belum didukung API.
- Daftar pesanan memakai status, nomor dan total yang mudah dipindai. Detail memisahkan status, penerima/jadwal, rincian/COD, hasil/foto dan tindakan pembatalan. Nomor panjang membungkus; tidak menambahkan ETA atau status fiktif. Pembatalan tetap hanya pending/confirmed dan tunduk lock.
- Form alamat memakai bagian penerima dan titik pengantaran. Latitude/Longitude ditumpuk setelah preview teks1.5x menunjukkan label terpotong. Pin peta, validasi radius, field keys, version conflict dan API dipertahankan.
- Trip, pemeriksaan muatan, formulir hasil dan hasil pengiriman memakai judul/panel yang selaras. Dropdown hasil dapat melebar sesuai area tersedia. Aturan urutan, upload privat, COD, versi dan durable retry tidak berubah.
- Login, app bar, input, pemulihan sesi dan halaman cek koneksi mengikuti tema bersama. Halaman cek koneksi tetap hanya menghubungi server setelah tombol ditekan.

## Verifikasi

61 tes Flutter lolos dan analyzer bersih. Preview font asli mencakup 320x740/teks1.5x, 390x844 dan 820x1180. Skenario meliputi katalog+quick-add, pengiriman memilih alamat/slot lalu ke keranjang, quote COD dan membuka/membatalkan dialog konfirmasi, akun, daftar/detail pesanan dengan nomor/penerima/alamat panjang, serta form alamat. Tes checkout tetap membuktikan fingerprint berubah mencegah pesanan lama, dan stok server tidak cukup menonaktifkan konfirmasi. Test status/polling, logout/revocation, start trip, retry dan hasil kurir juga lolos.

Preview ignored tersedia di mobile/build/ui-preview/: pengiriman-390.png, pengiriman-selected-390.png, keranjang-390.png, checkout-390.png, akun-390.png, orders-390.png, order-detail-390.png, order-payment-390.png, address-form-390.png dan address-location-320.png. Semua memakai fixture lokal sintetis, bukan bukti data bisnis/perangkat fisik. Regenerasi melalui test/ui_layout_test.dart dengan --dart-define=SHIPX_UI_SCREENSHOTS=true.

Tidak ada migration, fixture database bisnis, setup ulang atau perubahan .env. Hash .env tetap identik. Suite backend tidak diulang karena perubahan ini hanya Flutter; hasil backend terakhir 92/1450 berada pada checkpoint menu sebelumnya.

APK debug menggunakan API_BASE_URL=http://127.0.0.1:8000/api/v1 untuk HP USB; pertahankan adb reverse tcp:8000 tcp:8000. Jalankan Flutter dengan define tersebut agar tidak kembali ke alamat default emulator.

APK akhir berhasil dibuild (38.7 detik), dipasang dengan adb install -r (Success) dan dibuka di HP I2405. Reverse8000 aktif. Tidak uninstall/clear app data. Interaksi manual pengguna pada HP dan kamera tidak diklaim sudah diuji oleh checkpoint ini.
