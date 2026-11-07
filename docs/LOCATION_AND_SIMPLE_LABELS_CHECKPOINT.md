# Lokasi perangkat dan label sederhana — 7 November 2026

Pengguna meminta web/mobile tidak meminta latitude/longitude, memakai posisi perangkat, menghilangkan tampilan Asia/Jakarta, serta mengganti tampilan ukuran/satuan barang. Pengguna secara eksplisit memilih **semua barang tampil sebagai item/buah**; implementasi memakai label konsisten **item**.

## Perubahan

- Flutter form alamat tidak menampilkan input Latitude/Longitude. Gunakan lokasi saya meminta satu posisi foreground setelah tombol ditekan dan izin diberikan. Pin dibuka di peta untuk ditinjau; perubahan alamat baru dikirim setelah konfirmasi titik dan Simpan alamat.
- Pilih pin di peta tetap tersedia ketika GPS mati, izin ditolak, timeout atau pembacaan gagal. Peta juga memiliki tombol lokasi perangkat. Pin yang diklik pengguna membatalkan hasil GPS terlambat agar tidak tertimpa. Lokasi di luar layanan tidak bisa dikonfirmasi; server tetap memvalidasi cakupan.
- Android memakai geolocator14.1.2 dengan izin coarse/fine. Tidak meminta izin background, tidak membuat pelacakan langsung dan tidak mengambil lokasi saat membuka halaman. Build target tetap Android; uji GPS hardware/izin nyata membutuhkan pengguna menekan tombol dan mengizinkan di HP.
- Web depot memakai Leaflet1.9.4 + OpenStreetMap, tombol lokasi perangkat dan klik pin. Tombol titik tengah peta mendukung pemilihan setelah menggeser peta, termasuk lewat keyboard. Error izin/timeout tetap membolehkan pemilihan peta. Titik dan radius tetap dikirim dalam kontrak lama saat Simpan depot; tidak ada request lokasi otomatis.
- Jadwal menampilkan tanggal/jam tanpa nama zona IANA. Konversi waktu tetap mengikuti depot/snapshot order, bukan zona perangkat. Pengaturan wilayah depot memakai nama Indonesia bagian barat/tengah/timur; nilai internal zona waktu tidak diubah.
- Katalog, keranjang, pesanan, stok dan muatan memakai item. Nama produk tetap sesuai data admin, termasuk informasi yang memang bagian dari nama. Riwayat/unit_label database tidak ditulis ulang. Produk baru memiliki unit_label item; mengedit produk lama mempertahankan nilai tersimpan tetapi tampilan tetap item.
- Berat/dimensi/volume disembunyikan dari katalog/detail belanja, quote, receipt dan daftar muatan. Ringkasan trip admin menggunakan persentase beban/ruang, bukan angka gram/cm³. Ledger, reservasi dan pemeriksaan kapasitas dua dimensi tetap berjalan.
- Data kemasan produk berada di detail pengiriman admin, dengan input kg/cm yang dikonversi tepat ke gram/mm sebelum submit. Data ini tetap wajib untuk perencanaan, bukan diisi angka asumsi. Kendaraan memakai beban kg dan panjang/lebar/tinggi ruang barang cm; hasil perkalian dikirim sebagai cm³. Edit kendaraan memakai kapasitas tersimpan sampai admin memilih ukur ulang, tanpa mengarang dimensi lama. Satuan liter dan input volume langsung dihapus.

Tidak ada migration, perubahan .env/API key, reset atau perubahan data bisnis. Koordinat, zona dan berat/volume tetap menjadi data sistem sesuai kontrak API. Perubahan ini menyederhanakan cara memilih lokasi serta penyajiannya.

## Verifikasi

66 tes Flutter lolos, termasuk izin GPS hanya setelah tombol ditekan, GPS mati/izin ditolak tidak membaca posisi, posisi di luar rentang ditolak, fallback peta tetap aktif, dan alamat lengkap tanpa pin tidak dikirim. Preview 320px/teks1.5x, 390px dan 820px diperbarui. Analyzer bersih, APK debug berhasil dibuild dengan plugin GPS. Uji integrasi checkout diperbarui untuk memilih pin pada peta, tetapi skenario HP tersebut tidak dijalankan ulang dalam checkpoint ini.

Browser QA memakai database/storage sementara dan koordinat sintetis. Skenario memeriksa GPS browser yang diizinkan, ditolak dan fallback titik tengah, layout peta 320/390/1440, konversi produk1kg/10cm menjadi1000g/100mm, kendaraan80kg dan60x50x60cm menjadi80000g/180000cm³, version conflict, serta alur order/trip/hasil sebelumnya. Akun responsif dipisah agar suite tidak melampaui throttle login produksi. Batas login tidak dilonggarkan.

Verifikasi final satu suite bersih: **8 skenario browser lolos**. Percobaan awal tertahan oleh selector lama, notifikasi peta yang juga memakai role status, fixture produk bernama sama dari pengulangan, dan throttle akun QA; selector dan isolasi akun diperbaiki tanpa melonggarkan aturan produksi.

Build web berhasil, peringatan chunk besar yang sudah ada tetap muncul. Build Android memunculkan peringatan Java source/target8 dari dependency geolocator, tetapi build berhasil. Foto dan data uji hanya pada QA; server/database QA dibersihkan setelah pengujian.

HP sempat terdeteksi saat awal checkpoint tetapi sudah tidak terdeteksi ketika APK siap; APK ada di mobile/build/app/outputs/flutter-apk/app-debug.apk. Untuk USB gunakan adb reverse tcp:8000 tcp:8000 dan jalankan Flutter dengan API_BASE_URL=http://127.0.0.1:8000/api/v1. Setelah terpasang, pengguna perlu menekan Gunakan lokasi saya lalu mengizinkan lokasi; izin sistem tidak diberikan otomatis oleh agen.

Referensi dependency: [geolocator](https://pub.dev/packages/geolocator), [Leaflet](https://leafletjs.com/reference-1.9.4.html). Attribution OpenStreetMap tetap terlihat pada peta web/mobile. Tidak menambah reverse geocoding; nama penerima dan teks alamat tetap diisi pengguna.
