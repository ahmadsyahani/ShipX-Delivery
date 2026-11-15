import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/auth_session.dart';
import '../commerce/shopping_state.dart' show PendingStore;
import 'trip_start_state.dart';

class TripStartPanel extends StatefulWidget {
  const TripStartPanel({
    super.key,
    required this.session,
    required this.trip,
    required this.onRefresh,
    required this.onBusyChanged,
    this.store,
    this.externalBusy = false,
  });
  final AuthSession session;
  final Map<String, dynamic> trip;
  final Future<void> Function() onRefresh;
  final ValueChanged<bool> onBusyChanged;
  final PendingStore? store;
  final bool externalBusy;

  @override
  State<TripStartPanel> createState() => _TripStartPanelState();
}

class _TripStartPanelState extends State<TripStartPanel> {
  late final TripStartState _start;
  bool _wasBusy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _start = TripStartState(
      session: widget.session,
      tripId: widget.trip['id'].toString(),
      store: widget.store,
    )..addListener(_changed);
    _start.restore().then((_) {
      if (mounted &&
          [
            'in_progress',
            'awaiting_reconciliation',
          ].contains(widget.trip['status'])) {
        _start.observeStarted();
      }
    });
  }

  void _changed() {
    if (!mounted) return;
    if (_wasBusy != _start.busy) {
      _wasBusy = _start.busy;
      widget.onBusyChanged(_wasBusy);
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant TripStartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip['lock_version'] != widget.trip['lock_version']) {
      _message = null;
    }
    if ([
      'in_progress',
      'awaiting_reconciliation',
    ].contains(widget.trip['status'])) {
      _start.observeStarted();
    }
  }

  @override
  void dispose() {
    _start.removeListener(_changed);
    _start.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.externalBusy || widget.trip['can_start'] != true) return;
    final trip = widget.trip;
    final manifest = (trip['manifest'] as List).cast<Map<String, dynamic>>();
    final payload = {
      'lock_version': trip['lock_version'],
      'route_version_id': trip['route_version_id'],
      'departure_review_id': trip['departure_review']['id'],
      'manifest': manifest
          .map(
            (r) => {'product_id': r['product_id'], 'quantity': r['quantity']},
          )
          .toList(),
    };
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mulai perjalanan?'),
        content: const Text(
          'Jumlah barang mengikuti manifest perjalanan. Saat trip dimulai, muatan dicatat ke trip dan pesanan siap diantar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Periksa lagi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Mulai trip sekarang'),
          ),
        ],
      ),
    );
    if (!mounted || yes != true) return;
    if (widget.externalBusy) {
      setState(
        () => _message =
            'Status sedang diperbarui. Coba konfirmasi kembali setelah selesai.',
      );
      return;
    }
    if (widget.trip['lock_version'] != trip['lock_version']) {
      setState(
        () => _message =
            'Rencana berubah. Tinjau manifest terbaru sebelum mulai.',
      );
      return;
    }
    await _start.submit(payload);
    if (mounted) await widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final rows = (trip['manifest'] as List).cast<Map<String, dynamic>>();
    final total = rows.fold<int>(
      0,
      (sum, row) => sum + (row['quantity'] as num).toInt(),
    );
    final locked =
        !_start.ready ||
        _start.busy ||
        _start.storageError ||
        _start.pending != null;
    final started = [
      'in_progress',
      'awaiting_reconciliation',
    ].contains(trip['status']);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            leading: Icon(
              started ? Icons.inventory_2_outlined : Icons.checklist_rounded,
              color: AppColors.primary,
            ),
            title: Text(
              'Muatan · $total item',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              started ? 'Sudah tercatat di trip' : 'Otomatis dari manifest',
              style: const TextStyle(fontSize: 12),
            ),
            children: rows
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${row['variants'][0]['name']}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${row['quantity']} item',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          if (!started) ...[
            if (trip['start_block_reason'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  trip['start_block_reason'],
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.warning,
                  ),
                ),
              ),
            if (_start.pending != null) ...[
              const Text(
                'Permintaan sebelumnya tersimpan. Periksa status trip sebelum mencoba kembali.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.warning,
                ),
              ),
              TextButton(
                onPressed: _start.busy || widget.externalBusy
                    ? null
                    : () async {
                        await _start.retry();
                        if (mounted) await widget.onRefresh();
                      },
                child: const Text('Coba lagi permintaan yang sama'),
              ),
            ] else
              FilledButton.icon(
                onPressed:
                    locked || widget.externalBusy || trip['can_start'] != true
                    ? null
                    : _submit,
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: Text(
                  _start.busy ? 'Memproses keberangkatan…' : 'Mulai trip',
                ),
              ),
          ],
          if (_start.message != null || _message != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _message ?? _start.message!,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          if (_start.storageError)
            TextButton(
              onPressed: _start.busy ? null : _start.restore,
              child: const Text('Periksa penyimpanan kembali'),
            ),
        ],
      ),
    );
  }
}
