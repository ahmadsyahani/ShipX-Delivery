import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../core/auth_api.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({
    super.key,
    required this.user,
    required this.busy,
    required this.refresh,
    required this.logout,
    this.orders,
    this.delivery,
    this.trips,
    this.error,
  });
  final ShipXUser user;
  final bool busy;
  final VoidCallback refresh, logout;
  final VoidCallback? orders, delivery, trips;
  final String? error;

  Widget _item(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? onTap, {
    bool destructive = false,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
    leading: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: destructive ? const Color(0xFFFFF1EF) : const Color(0xFFF0F7F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: destructive ? AppColors.error : AppColors.primaryDark,
        size: 21,
      ),
    ),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: destructive ? AppColors.error : AppColors.textMain,
      ),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
          height: 1.5,
        ),
      ),
    ),
    trailing: const Icon(
      Icons.chevron_right_rounded,
      size: 20,
      color: AppColors.textMuted,
    ),
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFFDDEFE9),
                  child: Text(
                    user.name.isEmpty
                        ? 'U'
                        : user.name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Senang ketemu kamu,',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 23,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                child: Text(
                  switch (user.role) {
                    'courier' => 'Kurir ShipX',
                    'admin' => 'Administrator',
                    _ => 'Pelanggan ShipX',
                  },
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      if (orders != null ||
          delivery != null ||
          trips != null ||
          user.role == 'admin') ...[
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            'Aktivitasmu',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        AppPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (orders != null)
                _item(
                  'Pesanan saya',
                  'Status dan riwayat pembelian',
                  Icons.receipt_long_outlined,
                  orders,
                ),
              if (delivery != null) ...[
                const Divider(
                  height: 1,
                  indent: 76,
                  color: AppColors.borderLight,
                ),
                _item(
                  'Alamat & jadwal',
                  'Atur tujuan dan waktu pengantaran',
                  Icons.location_on_outlined,
                  delivery,
                ),
              ],
              if (trips != null)
                _item(
                  'Trip saya',
                  'Tujuan, muatan, dan hasil pengiriman',
                  Icons.route_outlined,
                  trips,
                ),
              if (user.role == 'admin')
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Kelola operasional melalui web admin ShipX.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
      const Padding(
        padding: EdgeInsets.only(left: 8, bottom: 12),
        child: Text(
          'Pengaturan akun',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      AppPanel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _item(
              'Periksa sesi',
              busy ? 'Sedang memeriksa...' : 'Pastikan akses akun masih aktif',
              Icons.sync_rounded,
              busy ? null : refresh,
            ),
            const Divider(height: 1, indent: 76, color: AppColors.borderLight),
            _item(
              'Lisensi aplikasi',
              'Informasi pustaka dan font',
              Icons.info_outline_rounded,
              () => showLicensePage(context: context, applicationName: 'ShipX'),
            ),
            const Divider(height: 1, indent: 76, color: AppColors.borderLight),
            _item(
              'Keluar',
              'Akhiri sesi pada perangkat ini',
              Icons.logout_rounded,
              busy ? null : logout,
              destructive: true,
            ),
          ],
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: InfoBanner(
            message: error!,
            color: AppColors.error,
            backgroundColor: AppColors.errorBg,
          ),
        ),
      const SizedBox(height: 30),
      const Center(
        child: Text(
          'ShipX. Barang sampai, urusan beres.',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ),
    ],
  );
}
