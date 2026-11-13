import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/auth_session.dart';

/// Straight-line distance between saved pins, never a road-distance estimate.
String? catalogDistance(
  Map<String, dynamic>? store,
  Map<String, dynamic>? address,
) {
  double? coordinate(Map<String, dynamic>? value, String key, double limit) {
    final number = double.tryParse('${value?[key]}');
    return number != null && number.isFinite && number.abs() <= limit
        ? number
        : null;
  }

  final lat1 = coordinate(store, 'latitude', 90);
  final lon1 = coordinate(store, 'longitude', 180);
  final lat2 = coordinate(address, 'latitude', 90);
  final lon2 = coordinate(address, 'longitude', 180);
  if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;
  final radians = math.pi / 180;
  final a =
      math.pow(math.sin((lat2 - lat1) * radians / 2), 2) +
      math.cos(lat1 * radians) *
          math.cos(lat2 * radians) *
          math.pow(math.sin((lon2 - lon1) * radians / 2), 2);
  final km = 6371.0088 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

class CatalogLocationHeader extends StatefulWidget {
  const CatalogLocationHeader({
    super.key,
    required this.session,
    this.storeName,
    this.address,
    this.onChooseAddress,
  });
  final AuthSession session;
  final String? storeName;
  final Map<String, dynamic>? address;
  final VoidCallback? onChooseAddress;

  @override
  State<CatalogLocationHeader> createState() => _CatalogLocationHeaderState();
}

class _CatalogLocationHeaderState extends State<CatalogLocationHeader> {
  Map<String, dynamic>? _store, _registeredAddress;
  bool _loading = true, _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final values = await Future.wait([
        widget.session.deliveryRequest('GET', '/delivery-settings'),
        widget.session.deliveryRequest(
          'GET',
          '/addresses?per_page=2',
          envelope: true,
        ),
      ]);
      if (!mounted) return;
      final addresses = (values[1]['data'] as List)
          .cast<Map<String, dynamic>>();
      setState(() {
        _store = values[0];
        // With several saved addresses, let the customer choose the destination.
        _registeredAddress = addresses.length == 1 ? addresses.single : null;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = widget.address ?? _registeredAddress;
    final distance = catalogDistance(_store, address);
    final name = _store?['name'] as String? ?? widget.storeName ?? 'Toko ShipX';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryDark,
            AppColors.primaryDark,
            Colors.white,
            Colors.white,
          ],
          stops: [0, .48, .48, 1],
        ),
      ),
      child: Material(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _row(
              icon: Icons.storefront_rounded,
              title: name,
              subtitle: distance != null
                  ? '$distance · perkiraan'
                  : _loading
                  ? 'Memuat lokasi toko…'
                  : _failed
                  ? 'Muat ulang lokasi toko'
                  : address == null
                  ? 'Pilih alamat untuk melihat jarak'
                  : 'Jarak belum tersedia',
              onTap: _failed
                  ? _load
                  : () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (context) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _store?['address_text'] as String? ??
                                    'Alamat toko belum tersedia.',
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Jarak merupakan perkiraan garis lurus dari toko ke alamat pengiriman, bukan jarak tempuh jalan.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 76, right: 18),
              child: Divider(height: 1, color: AppColors.border),
            ),
            _row(
              icon: Icons.location_on_rounded,
              title: 'Lokasimu saat ini',
              subtitle:
                  address?['address_text'] as String? ??
                  (_loading
                      ? 'Memuat alamat terdaftar…'
                      : 'Pilih alamat terdaftar'),
              onTap: widget.onChooseAddress,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primaryLighter,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.textMain,
            ),
          ],
        ],
      ),
    ),
  );
}
