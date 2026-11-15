import 'package:flutter/material.dart';
import '../catalog_page.dart' show rupiah;
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../core/auth_api.dart';
import '../core/auth_session.dart';
import '../commerce/order_refresh.dart';
import 'trips_page.dart';

class CourierSummaryPage extends StatefulWidget {
  const CourierSummaryPage({
    super.key,
    required this.session,
    required this.openTrips,
    this.active = true,
  });

  final AuthSession session;
  final VoidCallback openTrips;
  final bool active;

  @override
  State<CourierSummaryPage> createState() => _CourierSummaryPageState();
}

class _CourierSummaryPageState extends State<CourierSummaryPage>
    with OrderRefresh<CourierSummaryPage> {
  Map<String, dynamic>? _summary;
  bool _fetching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
    startOrderRefresh(() async {
      if (widget.active) await _load();
    });
  }

  @override
  void didUpdateWidget(covariant CourierSummaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  Future<void> _load() async {
    if (_fetching) return;
    setState(() {
      _fetching = true;
      _error = null;
    });
    try {
      final result = await widget.session.commerceRequest(
        'GET',
        '/courier/summary',
      );
      if (mounted) setState(() => _summary = result);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          if ([401, 403, 404].contains(error.status)) _summary = null;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Ringkasan belum dapat diperbarui. Periksa koneksi dan coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _openTrip(Map<String, dynamic> trip) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourierTripsPage(
          session: widget.session,
          id: trip['id'].toString(),
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _summary;
    final next = data?['next_trip'] as Map<String, dynamic>?;
    final total = data?['total_stops'] as int? ?? 0;
    final pending = data?['pending_stops'] as int? ?? 0;
    final delivered = data?['delivered_stops'] as int? ?? 0;
    final failed = data?['failed_stops'] as int? ?? 0;
    final updated = DateTime.tryParse('${data?['updated_at']}')?.toLocal();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Perjalananmu',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: _fetching ? null : _load,
                tooltip: 'Perbarui ringkasan',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            InfoBanner(message: _error!),
            if (data != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Menampilkan ringkasan terakhir.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            TextButton(
              onPressed: _fetching ? null : _load,
              child: const Text('Coba lagi'),
            ),
          ],
          if (data == null && _fetching)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (data != null) ...[
            AppPanel(
              color: AppColors.primaryDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${data['active_trips']} trip aktif',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${delivered + failed} dari $total tujuan ditangani',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: total == 0 ? 0 : (delivered + failed) / total,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFB9E4A6),
                    backgroundColor: Colors.white24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppPanel(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _metric(
                          'Tujuan tersisa',
                          '$pending',
                          Icons.route_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _metric(
                          'Terkirim',
                          '$delivered',
                          Icons.task_alt_outlined,
                        ),
                      ),
                    ],
                  ),
                  if (failed > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$failed tujuan gagal diantar',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'COD diterima',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rupiah(data['cod_collected_rp']),
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pada trip aktif, menunggu rekonsiliasi admin.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'COD tujuan tersisa',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rupiah(data['cod_remaining_rp']),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    next == null
                        ? 'Belum ada trip aktif'
                        : next['status'] == 'awaiting_reconciliation'
                        ? 'Saatnya kembali ke depot'
                        : 'Lanjutkan tugasmu',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    next == null
                        ? 'Penugasan dari admin akan muncul di menu Trip.'
                        : next['status'] == 'awaiting_reconciliation'
                        ? 'Serahkan barang kembali dan COD kepada admin untuk menyelesaikan trip.'
                        : '${next['trip_number']}',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textBody,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: next == null
                        ? widget.openTrips
                        : () => _openTrip(next),
                    icon: Icon(
                      next == null
                          ? Icons.route_outlined
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                    label: Text(
                      next == null
                          ? 'Lihat daftar trip'
                          : next['status'] == 'awaiting_reconciliation'
                          ? 'Lihat setoran & barang kembali'
                          : next['status'] == 'assigned'
                          ? 'Lihat persiapan trip'
                          : 'Lanjutkan pengantaran',
                    ),
                  ),
                ],
              ),
            ),
            if (updated != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Diperbarui ${updated.hour.toString().padLeft(2, '0')}.${updated.minute.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.primary, size: 20),
      const SizedBox(height: 8),
      Text(
        value,
        style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    ],
  );
}
