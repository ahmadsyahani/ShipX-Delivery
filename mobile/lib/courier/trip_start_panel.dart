import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
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
  final _form = GlobalKey<FormState>();
  final Map<String, int> _counts = {};
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
      _counts.clear();
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
    if (widget.externalBusy) return;
    if (!_form.currentState!.validate()) return;
    final trip = widget.trip;
    final manifest = (trip['manifest'] as List).cast<Map<String, dynamic>>();
    final payload = {
      'lock_version': trip['lock_version'],
      'route_version_id': trip['route_version_id'],
      'departure_review_id': trip['departure_review']['id'],
      'manifest': manifest
          .map(
            (r) => {
              'product_id': r['product_id'],
              'quantity': _counts[r['product_id'].toString()],
            },
          )
          .toList(),
    };
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi muatan dan berangkat?'),
        content: const Text(
          'Pastikan seluruh SKU sudah dihitung dan dimuat sesuai manifest. Stok akan dipindahkan dari depot ke trip. Setelah berhasil, rencana dan pembatalan sebelum berangkat dikunci.',
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
        () => _message = 'Rencana berubah. Hitung dan tinjau muatan kembali.',
      );
      return;
    }
    await _start.submit(payload);
    if (mounted) await widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final rows = (t['manifest'] as List).cast<Map<String, dynamic>>();
    final locked =
        !_start.ready ||
        _start.busy ||
        _start.storageError ||
        _start.pending != null;

    final inProgress = [
      'in_progress',
      'awaiting_reconciliation',
    ].contains(t['status']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionTitle(
              title: inProgress
                  ? 'Muatan sudah diberangkatkan'
                  : 'Periksa muatan per SKU',
              subtitle: inProgress
                  ? 'Lanjutkan ke tujuan pengiriman'
                  : 'Cocokkan jumlah barang sebelum berangkat',
              icon: inProgress
                  ? Icons.task_alt_rounded
                  : Icons.checklist_rounded,
            ),
            const SizedBox(height: 12),
            if (inProgress) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Reservasi sudah dikonsumsi dan stok tercatat di trip. Catat hasil setiap tujuan. Setelah semua tujuan selesai, kembalikan barang tersisa dan setorkan COD ke admin.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...rows.map(
                (r) => Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${r['quantity']} unit · ${r['variants'][0]['name']}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'Masukkan jumlah fisik setelah menghitung setiap SKU. Jika berbeda, hubungi admin sebelum berangkat.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              if (t['start_block_reason'] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      t['start_block_reason'],
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Form(
                key: _form,
                child: Column(
                  children: rows
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: TextFormField(
                            key: ValueKey(
                              '${t['lock_version']}-${r['product_id']}',
                            ),
                            enabled: !locked,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: InputDecoration(
                              labelText:
                                  'Jumlah fisik · ${r['variants'][0]['name']}',
                              helperText:
                                  'Harus ${r['quantity']} unit · ID produk #${r['product_id']}',
                              prefixIcon: const Icon(
                                Icons.pin_outlined,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                            ),
                            validator: (value) =>
                                int.tryParse(value ?? '') == r['quantity']
                                ? null
                                : 'Jumlah harus sesuai manifest: ${r['quantity']}.',
                            onChanged: (value) =>
                                _counts[r['product_id'].toString()] =
                                    int.tryParse(value) ?? 0,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 18),
              if (_start.pending != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Permintaan sebelumnya tersimpan. Periksa status trip sebelum mengirim ulang; isi permintaan tetap sama.',
                    style: TextStyle(fontSize: 12, color: AppColors.warning),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed:
                      _start.busy || _start.storageError || widget.externalBusy
                      ? null
                      : () async {
                          await _start.retry();
                          if (mounted) await widget.onRefresh();
                        },
                  child: const Text('Coba ulang permintaan yang sama'),
                ),
              ] else
                FilledButton.icon(
                  onPressed:
                      locked || widget.externalBusy || t['can_start'] != true
                      ? null
                      : _submit,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: Text(
                    _start.busy
                        ? 'Memproses keberangkatan…'
                        : 'Konfirmasi muatan & mulai trip',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
            if (_start.message != null || _message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _message ?? _start.message!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (_start.storageError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: _start.busy ? null : _start.restore,
                  child: const Text('Periksa penyimpanan kembali'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
