import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../core/contact_button.dart';
import '../core/auth_api.dart';
import '../core/auth_session.dart';
import '../commerce/order_refresh.dart';
import '../catalog_page.dart' show rupiah;
import '../delivery/delivery_page.dart' show slotDate, slotTime;
import 'trip_start_panel.dart';
import 'delivery_result_panel.dart';
import 'reconciliation_view.dart';
import 'trip_overview.dart';
import 'trip_map_page.dart';
import '../commerce/shop_widgets.dart' show CodTotal;

class CourierTripsPage extends StatefulWidget {
  const CourierTripsPage({
    super.key,
    required this.session,
    this.active = true,
    this.id,
  });
  final AuthSession session;
  final bool active;
  final String? id;

  @override
  State<CourierTripsPage> createState() => _CourierTripsPageState();
}

class _CourierTripsPageState extends State<CourierTripsPage>
    with OrderRefresh<CourierTripsPage> {
  List<Map<String, dynamic>> _trips = [];
  Map<String, dynamic>? _trip;
  bool _fetching = false, _loading = true;
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    startOrderRefresh(() async {
      if (widget.active) await _load(background: true);
    });
  }

  @override
  void didUpdateWidget(covariant CourierTripsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load(background: true);
  }

  Future<void> _load({bool background = false}) async {
    if (_fetching || _starting) return;
    _fetching = true;
    setState(() {
      _error = null;
      if (!background) _loading = true;
    });
    try {
      final r = await widget.session.commerceRequest(
        'GET',
        '/courier/trips${widget.id == null ? '' : '/${widget.id}'}',
        envelope: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (widget.id == null) {
          _trips = [
            ...(r['data'] as List).cast<Map<String, dynamic>>(),
            ...(r['recent_completed'] as List? ?? [])
                .cast<Map<String, dynamic>>(),
          ];
        } else {
          _trip = r['data'] as Map<String, dynamic>;
        }
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          if ([401, 403, 404].contains(e.status)) {
            _trip = null;
            _trips = [];
          }
          _error = e.status == 404
              ? 'Penugasan sudah dibuka ulang, dibatalkan, atau tidak lagi tersedia untuk Anda.'
              : e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Belum dapat memperbarui tugas. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  String _when(dynamic value, String timezone) =>
      '${slotDate(value as String, timezone)} ${slotTime(value, timezone)}';
  Widget _summary(Map<String, dynamic> t) {
    final v = t['vehicle'] as Map<String, dynamic>;
    final tz = t['timezone'] as String;
    final inProgress = [
      'in_progress',
      'awaiting_reconciliation',
    ].contains(t['status']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBadge(
                  status: t['status'] == 'completed'
                      ? 'delivered'
                      : inProgress
                      ? 'in_progress'
                      : 'assigned',
                  text: t['status'] == 'completed'
                      ? 'Trip selesai'
                      : t['status'] == 'awaiting_reconciliation'
                      ? 'Menunggu rekonsiliasi'
                      : inProgress
                      ? 'Dalam perjalanan'
                      : 'Ditetapkan · belum berangkat',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              t['trip_number'],
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.two_wheeler,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${v['plate_number']} · ${v['name']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Rencana: ${_when(t['planned_departure_at'], tz)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textBody,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (t['actual_departure_at'] != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Berangkat: ${_when(t['actual_departure_at'], tz)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (t['estimated_return_at'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Estimasi rencana kembali: ${_when(t['estimated_return_at'], tz)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${t['total_stops']} tujuan',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(40, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourierTripsPage(
                          session: widget.session,
                          id: t['id'].toString(),
                        ),
                      ),
                    );
                    if (mounted) _load(background: true);
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text(
                    'Lihat tujuan',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(Map<String, dynamic> trip) {
    final timezone = trip['timezone'] as String;
    final depot = trip['depot'] as Map<String, dynamic>;
    final vehicle = trip['vehicle'] as Map<String, dynamic>;
    final stops = (trip['stops'] as List).cast<Map<String, dynamic>>();
    final next = stops
        .where((stop) => !['delivered', 'failed'].contains(stop['status']))
        .firstOrNull;
    final completed = trip['status'] == 'completed';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TripOverview(
          trip: trip,
          session: widget.session,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 18),
                title: Text(
                  '${vehicle['plate_number']} · ${vehicle['name']}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Berangkat ${_when(trip['planned_departure_at'], timezone)}',
                  style: const TextStyle(fontSize: 12),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${trip['trip_number']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Depot ${depot['name']} · ${depot['address_text']}',
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                  ContactButton(
                    phone: depot['phone'] as String?,
                    label: 'Hubungi depot',
                  ),
                  if (trip['estimated_return_at'] != null)
                    Text(
                      'Estimasi kembali ${_when(trip['estimated_return_at'], timezone)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
              if (trip['manifest'] != null && !completed)
                TripStartPanel(
                  externalBusy: _fetching,
                  session: widget.session,
                  trip: trip,
                  onRefresh: () => _load(background: true),
                  onBusyChanged: (value) => setState(() => _starting = value),
                ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!completed) ...[
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TripMapPage(
                              trip: trip,
                              session: widget.session,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: Text(
                          trip['status'] == 'awaiting_reconciliation'
                              ? 'Rute kembali ke depot'
                              : 'Peta tujuan',
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      'Tujuan pengantaran · ${stops.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              ...stops.map(
                (stop) => _stop(trip, stop, expanded: identical(stop, next)),
              ),
            ],
          ),
        ),
        if (trip['reconciliation'] != null) ...[
          const SizedBox(height: 14),
          ReconciliationView(
            summary: trip['reconciliation'] as Map<String, dynamic>,
            timezone: timezone,
          ),
        ],
      ],
    );
  }

  Widget _stop(
    Map<String, dynamic> trip,
    Map<String, dynamic> stop, {
    required bool expanded,
  }) {
    final address = stop['address'] as Map<String, dynamic>;
    final items = (stop['items'] as List).cast<Map<String, dynamic>>();
    final timezone = trip['timezone'] as String;
    final finished = ['delivered', 'failed'].contains(stop['status']);
    return ExpansionTile(
      key: ValueKey(
        'trip-${trip['id']}-stop-${stop['id'] ?? stop['sequence_no']}-active-$expanded',
      ),
      initiallyExpanded: expanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 18),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: finished
            ? AppColors.background
            : AppColors.primaryLight,
        child: Text(
          '${stop['sequence_no']}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
      title: Text(
        '${address['recipient_name']}',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Wrap(
          spacing: 6,
          runSpacing: 5,
          children: [
            StatusBadge(
              status: 'assigned',
              text: stop['delivery_type'] == 'express' ? 'Express' : 'Reguler',
            ),
            if (finished)
              StatusBadge(
                status: stop['status'],
                text: stop['status'] == 'delivered'
                    ? 'Terkirim'
                    : 'Gagal diantar',
              ),
          ],
        ),
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${address['recipient_name']} · ${address['phone']}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            Text(
              '${address['address_text']}',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            if (address['directions'] != null &&
                '${address['directions']}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${address['directions']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '${_when(stop['window_start_at'], timezone)} – ${slotTime(stop['window_end_at'], timezone)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: ContactButton(
                phone: address['phone'] as String?,
                label: 'Hubungi penerima',
              ),
            ),
            if (stop['estimated_arrival_at'] != null)
              Text(
                'Estimasi tiba ${_when(stop['estimated_arrival_at'], timezone)}',
                style: const TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '${item['quantity']} item · ${item['name']}${item['handling_notes'] == null ? '' : '\n${item['handling_notes']}'}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: CodTotal(amount: rupiah(stop['total_rp'])),
            ),
            Text(
              '${stop['order_number']}',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
            if (stop['id'] != null)
              DeliveryResultPanel(
                key: ValueKey('result-${stop['id']}'),
                session: widget.session,
                trip: trip,
                stop: stop,
                externalBusy: _fetching,
                onRefresh: () => _load(background: true),
                onBusyChanged: (busy) => setState(() => _starting = busy),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (widget.id == null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppPageIntro(
                    title: 'Siap mengantar?',
                    description: 'Siapkan perjalanan dan lihat penugasanmu.',
                  ),
                ),
                IconButton(
                  onPressed: _fetching || _starting ? null : _load,
                  tooltip: 'Perbarui tugas',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          if (widget.id == null)
            const InfoBanner(
              message:
                  'Jadwal perjalanan mengikuti rencana yang ditinjau admin. Muatan mengikuti manifest. Catat hasil pada setiap tujuan.',
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            ),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (widget.id != null && _trip != null) ...[
            const SizedBox(height: 14),
            _detail(_trip!),
          ] else if (widget.id == null) ...[
            const SizedBox(height: 14),
            ..._trips.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _summary(t),
              ),
            ),
            if (_trips.isEmpty && _error == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: const [
                        Icon(
                          Icons.route_outlined,
                          size: 48,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Belum ada trip yang ditugaskan.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tarik untuk memperbarui setelah admin menetapkan trip.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
    return widget.id == null
        ? content
        : Scaffold(
            appBar: AppBar(
              title: const Text('Detail trip'),
              actions: [
                IconButton(
                  onPressed: _fetching || _starting ? null : _load,
                  tooltip: 'Perbarui tugas',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            body: content,
          );
  }
}
