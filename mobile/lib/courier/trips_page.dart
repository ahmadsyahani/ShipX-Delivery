import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../core/auth_api.dart';
import '../core/auth_session.dart';
import '../commerce/order_refresh.dart';
import '../catalog_page.dart' show rupiah;
import '../delivery/delivery_page.dart' show slotDate, slotTime;
import 'trip_start_panel.dart';
import 'delivery_result_panel.dart';
import 'reconciliation_view.dart';
import 'trip_overview.dart';
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

  Widget _summary(Map<String, dynamic> t, {bool detail = false}) {
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
                  if (detail && t['estimated_return_at'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Estimasi manual kembali: ${_when(t['estimated_return_at'], tz)}',
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
            if (!detail)
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

  Widget _detail(Map<String, dynamic> t) {
    final tz = t['timezone'] as String;
    final depot = t['depot'] as Map<String, dynamic>;
    final stops = (t['stops'] as List).cast<Map<String, dynamic>>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TripOverview(trip: t, session: widget.session),
        const SizedBox(height: 14),
        _summary(t, detail: true),
        if (t['reconciliation'] != null) ...[
          const SizedBox(height: 14),
          ReconciliationView(
            summary: t['reconciliation'] as Map<String, dynamic>,
            timezone: tz,
          ),
        ],
        if (t['manifest'] != null && t['status'] != 'completed') ...[
          const SizedBox(height: 14),
          TripStartPanel(
            externalBusy: _fetching,
            session: widget.session,
            trip: t,
            onRefresh: () => _load(background: true),
            onBusyChanged: (value) => setState(() => _starting = value),
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warehouse_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dari ${depot['name']}\n${depot['address_text']}\nKembali ke depot setelah seluruh tujuan.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ...stops.map((s) {
          final address = s['address'] as Map<String, dynamic>;
          final items = (s['items'] as List).cast<Map<String, dynamic>>();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${s['sequence_no']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tujuan ${s['sequence_no']} · ${s['order_number']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textMain,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${address['recipient_name']} · ${address['phone']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address['address_text'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textBody,
                      ),
                    ),
                    if (address['directions'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.directions,
                                size: 14,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  address['directions'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Jendela: ${_when(s['window_start_at'], tz)} – ${_when(s['window_end_at'], tz)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (s['estimated_arrival_at'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Estimasi manual tiba: ${_when(s['estimated_arrival_at'], tz)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    const Divider(height: 24),
                    ...items.map(
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${i['quantity']} item · ${i['name']}${i['handling_notes'] == null ? '' : '\n${i['handling_notes']}'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textBody,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: CodTotal(amount: rupiah(s['total_rp'])),
                    ),
                    if (s['id'] != null)
                      DeliveryResultPanel(
                        key: ValueKey('result-${s['id']}'),
                        session: widget.session,
                        trip: t,
                        stop: s,
                        externalBusy: _fetching,
                        onRefresh: () => _load(background: true),
                        onBusyChanged: (busy) =>
                            setState(() => _starting = busy),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppPageIntro(
                  title: widget.id == null
                      ? 'Siap mengantar?'
                      : 'Detail perjalanan',
                  description: widget.id == null
                      ? 'Siapkan perjalanan dan lihat penugasanmu.'
                      : 'Periksa muatan, tujuan, dan jadwal perjalanan.',
                ),
              ),
              IconButton(
                onPressed: _fetching || _starting ? null : _load,
                tooltip: 'Perbarui tugas',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const InfoBanner(
            message:
                'Jadwal perjalanan menggunakan estimasi manual. Periksa muatan dan catat hasil pada setiap tujuan.',
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
            appBar: AppBar(title: const Text('Detail trip')),
            body: content,
          );
  }
}
