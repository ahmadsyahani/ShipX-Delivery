# UI web dan Flutter — 7 November 2026

## Arah visual

Pengguna meminta perapian Flutter dan web admin, dengan font premium tetapi santai. Mengembangkan UI mobile pengguna yang sudah ada, mempertahankan alur transaksi dan state retry.

- Font: Plus Jakarta Sans. Body 400/500, label 600, judul 700/800. Bundel lokal tanpa runtime Google Fonts; web variable TTF, Flutter lima instance statis untuk pemilihan bobot lintas renderer.
- Palet: ocean teal `#087E8B`, deep teal `#05555E`, navy `#182E40`, mist `#F4F7FA`, aqua `#E6F4F4`, white `#FFFFFF`. Warna status tetap dibedakan secara semantik.
- Web: navigasi navy di kiri, area kerja terang rata kiri, pesanan pending sebagai prioritas, ringkasan trip memakai data confirmed yang sudah tersedia. Mobile web menggunakan drawer, form bertumpuk dan tabel scroll di dalam wadahnya.
- Flutter: header merek dan konteks tab, katalog dengan panel navy, daftar produk, navigasi bawah, kartu/form berwarna tenang. Konten RoleHome dibatasi 760 logical pixels pada tablet, tetap penuh pada HP.

```text
Desktop admin: [navigasi] [judul + aksi]
                         [pending] [produk] [slot]
                         [pesanan dikonfirmasi -> kelola trip]
                         [pesanan terbaru] [depot + persiapan]
HP Flutter:   [ShipX / tab] [keranjang]
              [isi halaman, scroll]
              [Katalog | Pengiriman | Keranjang | Akun]
```

Rancangan ditinjau terhadap kebutuhan operasional: tidak menambahkan metrik fiktif, dekorasi grafik, atau animasi masuk. Identitas utama ada pada tipografi dan navigasi; teal mobile pengguna dipertahankan.

## Perubahan dan bug layout

- Tema shadcn, sidebar/drawer, dashboard/login, heading, tombol/input/select lebih lega; fokus keyboard/reduced motion tetap tersedia.
- Heading nomor order/trip memakai pembungkusan kata panjang dan lebar yang benar. Masalah overflow ditemukan oleh browser pada 390px, kemudian diperbaiki.
- Flutter: font diterapkan ke tema, app bar, button, navigation label. Status badge, nama kendaraan, harga/satuan dan spesifikasi produk membungkus di layar kecil.
- Jadwal pengiriman memakai Wrap; judul dan pemilih tanggal sebelumnya melebar pada 390px dan 320px dengan teks 1.5x. Tidak ada perubahan pada tanggal, timezone, validasi, endpoint atau idempotency.
- Lisensi OFL disertakan pada aset Flutter, LicenseRegistry dan menu Lisensi aplikasi; salinan web ada di public/fonts/plus-jakarta-sans-OFL.txt.

Sumber font: [google/fonts — Plus Jakarta Sans](https://github.com/google/fonts/tree/main/ofl/plusjakartasans). Variable TTF SHA256 `89B3FB38AA0D275D7A731D0D817A4F1622B316B4D7FBDEDCF02EE9099FF68BC8`. Instance 400/500/600/700/800 dibuat dengan fontTools.varLib.instancer tanpa mengubah desain font. Tidak ada paket runtime baru.

## Verifikasi

Hasil akhir: **56 tes Flutter**, analyzer bersih, **7 skenario browser** (enam alur bisnis + satu responsif), TypeScript/build web dan APK debug berhasil. QA database tersisa **0**; hash .env identik dengan awal tugas. Enam skenario dan satu skenario responsif dijalankan terpisah agar pemeriksaan tambahan tidak mengubah fixture transaksi.

- Flutter: seluruh suite dan pemeriksaan layout font asli; 320x740 dengan teks 1.5x, 390x844, 820x1180. Login/validasi, katalog/detail, header/nav customer/kurir, pengiriman, keranjang dan akun. Preview opt-in lewat `--dart-define=SHIPX_UI_SCREENSHOTS=true`, tersimpan di mobile/build/ui-preview/ (ignored).
- Web: enam alur browser yang sudah ada ditambah satu skenario responsif 320/390/820/1440. Font benar-benar dimuat dari aset lokal, bukan hanya nama CSS. Screenshot tersimpan di backend/test-results/ (ignored).
- TypeScript, Vite build, Flutter analyzer dan APK debug diperiksa. Peringatan ukuran chunk Vite lama masih ada.
- QA menggunakan database dan storage sementara melalui scripts/serve-checkout-qa.php; tidak menambahkan fixture ke data bisnis. Tidak ada migration/setup ulang atau perubahan .env.
- HP tidak terdeteksi pada pemeriksaan ADB; preview merupakan render widget test/browser, belum bukti tampilan atau kamera pada HP fisik.

## Melihat hasil

Web: jalankan Laravel dari backend lalu buka http://127.0.0.1:8000/admin/login. Aset production sudah dibuild. Jika Vite dev server sedang dipakai, pastikan ia berjalan.

Flutter: font/aset baru membutuhkan restart penuh, bukan hanya hot reload. Dari mobile:

```powershell
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

APK debug ada di mobile/build/app/outputs/flutter-apk/app-debug.apk. API localhost pada HP membutuhkan USB/ADB reverse. Domain checkpoint tetap hasil pengiriman/foto/COD; rekonsiliasi dan penutupan trip belum dikerjakan oleh perubahan UI ini.
