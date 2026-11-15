import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../commerce/shop_widgets.dart' show CodTotal;
import '../catalog_page.dart' show rupiah;
import 'trip_map_page.dart';
import '../core/auth_session.dart';
import '../core/app_widgets.dart';

/// Delivery progress follows the server's stop order and recorded outcomes.
class TripOverview extends StatelessWidget {
  const TripOverview({
    super.key,
    required this.trip,
    required this.session,
    this.content,
  });

  final Map<String, dynamic> trip;
  final AuthSession session;
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    final stops = (trip['stops'] as List? ?? []).cast<Map<String, dynamic>>();
    final finished = stops
        .where((stop) => ['delivered', 'failed'].contains(stop['status']))
        .length;
    final pending = stops.where(
      (stop) => !['delivered', 'failed'].contains(stop['status']),
    );
    final next = pending.firstOrNull;
    final address = next?['address'] as Map<String, dynamic>?;
    final returning = trip['status'] == 'awaiting_reconciliation';
    final completed = trip['status'] == 'completed';

    return Material(
      key: const ValueKey('courier-trip-overview'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: content == null
            ? const BorderSide(color: AppColors.border)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.primaryDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.route_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        content == null
                            ? 'Trip kamu'
                            : completed
                            ? 'Trip selesai'
                            : returning
                            ? 'Kembali ke depot'
                            : trip['status'] == 'in_progress'
                            ? 'Dalam perjalanan'
                            : 'Siap berangkat',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: content == null ? null : 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '$finished dari ${stops.length} tujuan ditangani',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: stops.isEmpty ? 0 : finished / stops.length,
                    minHeight: 6,
                    color: const Color(0xFFB9E4A6),
                    backgroundColor: Colors.white24,
                  ),
                ),
              ],
            ),
          ),
          if (content != null)
            ExpansionTileTheme(
              data: const ExpansionTileThemeData(
                shape: Border(),
                collapsedShape: Border(),
              ),
              child: content!,
            )
          else
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    completed
                        ? 'Rekonsiliasi sudah selesai'
                        : returning
                        ? 'Kembali ke depot'
                        : trip['status'] == 'assigned'
                        ? 'Tujuan pertama setelah berangkat'
                        : 'Tujuan berikutnya',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    returning || completed
                        ? '${(trip['depot'] as Map?)?['name'] ?? 'Depot'}'
                        : '${address?['recipient_name'] ?? 'Belum ada tujuan'}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    returning
                        ? 'Serahkan barang kembali dan uang COD kepada admin.'
                        : completed
                        ? 'Rincian penyerahan tersedia pada rekonsiliasi trip.'
                        : '${address?['address_text'] ?? 'Perbarui trip untuk melihat tujuan.'}',
                    style: const TextStyle(
                      color: AppColors.textBody,
                      height: 1.5,
                    ),
                  ),
                  if (!returning && !completed && next != null) ...[
                    const SizedBox(height: 10),
                    StatusBadge(
                      status: 'assigned',
                      text: next['delivery_type'] == 'express'
                          ? 'Express'
                          : 'Reguler',
                    ),
                    const SizedBox(height: 16),
                    CodTotal(amount: rupiah(next['total_rp'])),
                  ],
                  if (!completed) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                TripMapPage(trip: trip, session: session),
                          ),
                        ),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Peta tujuan'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
