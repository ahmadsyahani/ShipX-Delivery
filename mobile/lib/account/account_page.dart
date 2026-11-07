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
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    leading: Icon(
      icon,
      color: destructive ? AppColors.error : AppColors.primary,
      size: 23,
    ),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: destructive ? AppColors.error : AppColors.textMain,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.textMuted,
        height: 1.5,
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
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    children: [
      const AppPageIntro(
        title: 'Akun kamu',
        description: 'Pesanan, pengiriman, dan akses akun dalam satu tempat.',
      ),
      AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    user.name.isEmpty
                        ? 'U'
                        : user.name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 23,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${user.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 5),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                switch (user.role) {
                  'courier' => 'Kurir ShipX',
                  'admin' => 'Administrator',
                  _ => 'Pelanggan ShipX',
                },
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
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
              const Divider(height: 1, indent: 56),
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
                padding: EdgeInsets.all(18),
                child: Text(
                  'Kelola operasional melalui web admin ShipX.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const AppSectionTitle(title: 'Pengaturan akun', icon: Icons.tune_rounded),
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
            const Divider(height: 1, indent: 56),
            _item(
              'Lisensi aplikasi',
              'Informasi pustaka dan font',
              Icons.info_outline_rounded,
              () => showLicensePage(context: context, applicationName: 'ShipX'),
            ),
            const Divider(height: 1, indent: 56),
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
      const SizedBox(height: 28),
      const Center(
        child: Text(
          'ShipX. Barang sampai, urusan beres.',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ),
    ],
  );
}
