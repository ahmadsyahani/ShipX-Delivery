# Belanja dan checkout mengikuti referensi pengguna

Checkpoint 8 November 2026. Pengguna memberikan dua screenshot aplikasi TOMORO: menu dengan kategori vertikal dan checkout berisi alamat/barang/tagihan serta CTA menetap. Cakupan Flutter; web admin, backend, data bisnis, kontrak API dan .env tidak diubah oleh pekerjaan UI ini. Perubahan rekonsiliasi sebelumnya tetap dipertahankan di develop, belum commit/push.

## Tampilan

- Palet putih #FFFFFF, abu ringan #F5F7F8, teal #087E8B, deep teal #05555E, mint #E8F4F1 dan teks navy #182E40. Plus Jakarta Sans lokal tetap dipakai. App bar lebih ringkas, navigasi pelanggan tanpa bidang indikator besar, judul dan panel tidak diulang sebagai pengantar panjang.
- Katalog mempunyai ringkasan tujuan/jadwal yang bisa ditekan, pencarian berbentuk pil, kategori kiri dengan indikator aktif dan area scroll terpisah, serta daftar barang putih dengan ilustrasi kemasan dan tombol tambah bulat. Banner pengantaran tidak mengklaim promo; disembunyikan ketika teks dibesarkan agar produk mendapat ruang. Rail diperlebar pada teks besar. Tidak menambahkan pickup, voucher, poin, diskon, foto merek atau janji ETA.
- ProductArt dapat memakai latar transparan agar ilustrasi menyatu dengan daftar. Ini tetap ilustrasi kategori, bukan foto produk sebenarnya; field foto produk belum ada di backend.
- Bar keranjang menetap menunjukkan jumlah item, subtotal pilihan dan Checkout. Ketika keyboard pencarian terbuka, bar disembunyikan agar katalog tidak terjepit; jumlah keranjang tetap ada pada ikon app bar. Visibilitas keyboard dibaca dari konteks RoleHome di luar Scaffold karena body menghapus viewInsets.
- Checkout menyusun tujuan/jadwal, barang dan kontrol jumlah/hapus, pembayaran tunai dan ringkasan biaya. Total serta tombol Hitung total/Pesan sekarang menetap di bawah, dengan tata letak bertumpuk pada layar sempit atau teks besar. Sebelum quote, label adalah subtotal sementara dan ongkir belum dianggap final. Setelah quote valid, harga baris memakai item quote server dan total mencakup ongkir. Dialog konfirmasi COD tetap wajib.
- Pengiriman memakai kartu alamat ringkas dengan radio/outline pilihan, aksi pilih/edit/hapus dan tombol lanjut menetap setelah alamat+slot dipilih. Akun memakai profil lebih ringan serta kelompok aktivitas/pengaturan dengan ikon kecil; fungsi role, sesi, lisensi dan logout tetap sama.

## Pemilihan pengiriman dan konsistensi

Komponen DeliverySummary, ShopDock dan ShopHeading ada di commerce/shop_widgets.dart. Katalog dan keranjang membuka lembar bawah DeliveryPage melalui RoleHome. Lembar memakai ShoppingState sementara tanpa restore/write ke secure storage. Pilihan alamat/slot baru diterapkan ke keranjang setelah Gunakan alamat & jadwal; menutup lembar mempertahankan pilihan asli. Membuat/mengedit alamat tetap merupakan tindakan simpan API yang eksplisit, bukan dibatalkan oleh penutupan lembar.

DeliveryPage menginisialisasi pilihan yang sudah ada lalu memvalidasi ulang alamat/cakupan dan slot yang masih terbuka dari respons server. Slot lama hanya dipilih kembali jika tersedia pada daftar tanggal yang dimuat; jika tidak ditemukan, pengguna harus memilih ulang. Tab Pengiriman hanya dipasang saat aktif, sehingga tidak ada instance tersembunyi yang mereset pilihan saat lembar bawah sedang digunakan. Timer cutoff dan generation guard tetap aktif.

Tidak mengubah endpoint, payload, auth, quote fingerprint, idempotency, reservasi, batas jumlah, stok server atau durable retry. Saat keranjang/jadwal berubah selama dialog, total lama ditolak; quote baru tetap diperlukan. Pending/busy/storage error memblokir perubahan dan pemesanan. Tidak ada order dibuat hanya karena membuka/menutup lembar atau memilih jadwal.

## Verifikasi dan artefak

- 72 tes Flutter lolos: 70 regresi diperbarui untuk label/layout baru, ditambah harga quote server vs perkiraan katalog/CTA tetap terlihat dan lembar pilihan yang tidak menerapkan perubahan sebelum konfirmasi, mempertahankan pilihan valid saat dibuka ulang serta diblokir oleh pending request.
- Preview font asli pada 320px/skala teks1,5, 390px dan 820px; skenario keyboard 280px pada layar kecil juga lolos tanpa overflow. Quote/konfirmasi, hasil/trip/rekonsiliasi, pemulihan sesi, GPS manual dan alur pesanan lama ikut lolos.
- Analyzer bersih, git diff --check bersih, APK debug berhasil dibangun dengan API_BASE_URL=http://127.0.0.1:8000/api/v1. HP belum terdeteksi saat APK siap; belum memasang APK ini atau mengklaim uji interaksi fisik.
- APK: mobile/build/app/outputs/flutter-apk/app-debug.apk. Preview: mobile/build/ui-preview/customer-390.png, customer-cart-390.png, checkout-390.png, pengiriman-390.png dan akun-390.png. Semuanya ignored; preview memakai fixture sintetis. Regenerasi melalui flutter test --dart-define=SHIPX_UI_SCREENSHOTS=true.
- Log ignored: build/storefront-tests-verified.log, storefront-analyze-verified.log dan storefront-apk.log. Suite backend/browser tidak diulang karena pekerjaan ini hanya Flutter; hasil 100 backend dan 8 browser dari checkpoint rekonsiliasi tetap historinya sendiri.

.env tetap mempunyai SHA-256 DBE59869C14B1BC0436EA8085AA62B37D8860FB6395E8995AF0C37D81CA7D24C. Tidak ada setup ulang, migration atau fixture bisnis baru. Untuk memasang ke HP lokal gunakan adb install -r tanpa uninstall/clear data, aktifkan adb reverse tcp:8000 tcp:8000 dan pastikan Laravel/MySQL aktif. Deployment publik belum dilakukan.
