import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'core/auth_api.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.user,
    required this.openCatalog,
    required this.openOrders,
    required this.chooseDelivery,
  });
  final ShipXUser user;
  final void Function([String collection]) openCatalog;
  final VoidCallback openOrders, chooseDelivery;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
    children: [
      Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.local_mall_outlined,
              color: Colors.white,
              size: 58,
            ),
            const SizedBox(height: 28),
            const Text(
              'Kebutuhan harian,\nsampai di tujuan.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                height: 1.18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilih barangmu dan tentukan waktu pengantaran.',
              style: TextStyle(color: Colors.white, height: 1.6),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => openCatalog(),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Lihat katalog'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hai, ${user.name}!',
              style: const TextStyle(
                fontSize: 18,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mau pesan apa hari ini?',
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) {
                final stacked =
                    box.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.25;
                final width = stacked ? box.maxWidth : (box.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final shortcut in const [
                      (
                        collection: 'favorites',
                        label: 'Barang favorit',
                        icon: Icons.favorite_border,
                      ),
                      (
                        collection: 'frequent',
                        label: 'Sering dipesan',
                        icon: Icons.history,
                      ),
                    ])
                      SizedBox(
                        width: width,
                        child: OutlinedButton.icon(
                          onPressed: () => openCatalog(shortcut.collection),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryDark,
                            side: const BorderSide(color: AppColors.border),
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          icon: Icon(shortcut.icon, size: 18),
                          label: Text(
                            shortcut.label,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(
                Icons.local_shipping_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Atur pengiriman'),
              subtitle: const Text('Alamat dan jadwal pengantaran'),
              trailing: const Icon(Icons.chevron_right),
              onTap: chooseDelivery,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Riwayat pesanan'),
              subtitle: const Text('Lihat status dan rincian pesanan'),
              trailing: const Icon(Icons.chevron_right),
              onTap: openOrders,
            ),
          ],
        ),
      ),
    ],
  );
}
