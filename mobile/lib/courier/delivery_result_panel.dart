import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../core/auth_session.dart';
import '../core/app_widgets.dart';
import '../commerce/shopping_state.dart' show PendingStore;
import '../catalog_page.dart' show rupiah;
import 'delivery_result_state.dart';
import 'delivery_result_view.dart';

class DeliveryResultPanel extends StatefulWidget {
  const DeliveryResultPanel({
    super.key,
    required this.session,
    required this.trip,
    required this.stop,
    required this.onRefresh,
    required this.onBusyChanged,
    this.externalBusy = false,
    this.store,
  });
  final AuthSession session;
  final Map<String, dynamic> trip, stop;
  final Future<void> Function() onRefresh;
  final ValueChanged<bool> onBusyChanged;
  final bool externalBusy;
  final PendingStore? store;
  @override
  State<DeliveryResultPanel> createState() => _DeliveryResultPanelState();
}

class _DeliveryResultPanelState extends State<DeliveryResultPanel> {
  late final DeliveryResultState _state;
  final _form = GlobalKey<FormState>();
  String _outcome = 'delivered', _cash = '', _reason = '', _notes = '';
  String? _photo, _message;
  bool _wasBusy = false, _picking = false;
  @override
  void initState() {
    super.initState();
    _state = DeliveryResultState(
      session: widget.session,
      tripId: widget.trip['id'].toString(),
      stopId: widget.stop['id'].toString(),
      store: widget.store,
    )..addListener(_changed);
    _restore();
  }

  Future<void> _restore() async {
    await _state.restore();
    if (!mounted) return;
    setState(() => _photo = _state.pending?['photo_path'] as String?);
    if (widget.stop['result'] != null) await _state.observeCompleted();
  }

  void _changed() {
    if (!mounted) return;
    if (_wasBusy != _state.busy) {
      _wasBusy = _state.busy;
      widget.onBusyChanged(_wasBusy);
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant DeliveryResultPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stop['result'] != null) _state.observeCompleted();
  }

  @override
  void dispose() {
    if (_state.pending == null) unawaited(_removeDraft(_photo));
    _state.removeListener(_changed);
    _state.dispose();
    super.dispose();
  }

  Future<void> _removeDraft(String? path) async {
    if (path == null) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      // A completed request or another cleanup may already have removed it.
    }
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _picking = true);
    widget.onBusyChanged(true);
    try {
      final picker = ImagePicker();
      final lost = await picker.retrieveLostData();
      final selected =
          lost.files?.firstOrNull ??
          await picker.pickImage(
            source: source,
            maxWidth: 1600,
            maxHeight: 1600,
            imageQuality: 80,
            requestFullMetadata: false,
          );
      if (selected == null) return;
      if (await selected.length() > 2 * 1024 * 1024) {
        throw const FormatException(
          'Foto maksimal 2 MB. Pilih foto yang lebih kecil.',
        );
      }
      final root = await getApplicationSupportDirectory();
      final file = File(
        '${root.path}/delivery-photos/${widget.session.user!.id}/${widget.stop['id']}-${const Uuid().v4()}.photo',
      );
      await file.parent.create(recursive: true);
      await File(selected.path).copy(file.path);
      if (mounted) {
        final previous = _photo;
        setState(() {
          _photo = file.path;
          _message = null;
        });
        await _removeDraft(previous);
      } else {
        await _removeDraft(file.path);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is FormatException
              ? error.message
              : 'Foto belum dapat dipilih. Periksa izin kamera atau pilih dari galeri.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _picking = false);
        widget.onBusyChanged(false);
      }
    }
  }

  Future<void> _submit() async {
    if (widget.externalBusy || !_form.currentState!.validate()) return;
    if (_outcome == 'delivered' && _photo == null) {
      setState(() => _message = 'Ambil atau pilih foto bukti terlebih dahulu.');
      return;
    }
    final version = widget.trip['lock_version'];
    final payload = {
      'trip_version': version,
      'order_version': widget.stop['order_version'],
      'outcome': _outcome,
      'cash_received_rp': _outcome == 'delivered' ? int.parse(_cash) : 0,
      'failure_reason': _outcome == 'failed' ? _reason.trim() : null,
      'notes': _notes.trim().isEmpty ? null : _notes.trim(),
      'proof_upload_id': null,
    };
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          _outcome == 'delivered'
              ? 'Simpan kiriman berhasil?'
              : 'Simpan kiriman gagal?',
        ),
        content: Text(
          _outcome == 'delivered'
              ? 'Seluruh barang sudah diserahkan dan COD ${rupiah(widget.stop['total_rp'])} sudah diterima. Hasil ini akan dicatat permanen.'
              : 'Barang tetap menjadi muatan trip. Pastikan tidak ada uang atau barang yang diserahkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Periksa lagi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Simpan hasil'),
          ),
        ],
      ),
    );
    if (!mounted || yes != true) return;
    if (widget.trip['lock_version'] != version || widget.externalBusy) {
      setState(
        () => _message = 'Tugas berubah. Perbarui dan periksa kembali hasil.',
      );
      return;
    }
    await _state.submit(payload, _photo);
    if (mounted) await widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stop['result'] != null) {
      return DeliveryResultView(
        session: widget.session,
        result: widget.stop['result'],
      );
    }
    if (widget.stop['can_record_result'] != true) {
      return const SizedBox.shrink();
    }
    final locked =
        !_state.ready ||
        _state.busy ||
        _state.pending != null ||
        _state.storageError ||
        _picking ||
        widget.externalBusy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionTitle(
              title: 'Catat hasil tujuan ini',
              icon: Icons.fact_check_outlined,
              subtitle: 'Hasil, bukti foto, dan penerimaan COD',
            ),
            const SizedBox(height: 12),
            if (_state.pending == null)
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _outcome,
                      decoration: const InputDecoration(
                        labelText: 'Hasil pengiriman',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'delivered',
                          child: Text('Berhasil diserahkan'),
                        ),
                        DropdownMenuItem(
                          value: 'failed',
                          child: Text('Gagal diantar'),
                        ),
                      ],
                      onChanged: locked
                          ? null
                          : (value) => setState(() => _outcome = value!),
                    ),
                    const SizedBox(height: 14),
                    if (_outcome == 'delivered')
                      TextFormField(
                        key: const ValueKey('delivery-cash'),
                        enabled: !locked,
                        decoration: InputDecoration(
                          labelText: 'COD diterima (Rp)',
                          helperText:
                              'Harus ${rupiah(widget.stop['total_rp'])}',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(16),
                        ],
                        onChanged: (value) => _cash = value,
                        validator: (value) =>
                            int.tryParse(value ?? '') == widget.stop['total_rp']
                            ? null
                            : 'Uang harus sesuai seluruh tagihan.',
                      ),
                    if (_outcome == 'failed')
                      TextFormField(
                        key: const ValueKey('delivery-failure-reason'),
                        enabled: !locked,
                        decoration: const InputDecoration(
                          labelText: 'Alasan gagal',
                        ),
                        maxLength: 500,
                        onChanged: (value) => _reason = value,
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Alasan gagal wajib diisi.'
                            : null,
                      ),
                    const SizedBox(height: 14),
                    TextFormField(
                      enabled: !locked,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (opsional)',
                      ),
                      maxLength: 500,
                      onChanged: (value) => _notes = value,
                    ),
                    if (_photo != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Image.file(
                          File(_photo!),
                          height: 150,
                          errorBuilder: (_, error, stack) => const Text(
                            'Foto lokal belum dapat dibuka. Pilih kembali.',
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: locked
                              ? null
                              : () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Ambil foto'),
                        ),
                        TextButton(
                          onPressed: locked
                              ? null
                              : () => _pick(ImageSource.gallery),
                          child: const Text('Pilih foto'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: locked ? null : _submit,
                      child: const Text('Tinjau hasil pengiriman'),
                    ),
                  ],
                ),
              ),
            if (_state.pending != null) ...[
              const Text(
                'Ada permintaan tersimpan untuk tujuan ini. Perbarui tugas atau lanjutkan permintaan yang sama.',
              ),
              if (!_state.needsReview)
                OutlinedButton(
                  onPressed:
                      _state.busy || _state.storageError || widget.externalBusy
                      ? null
                      : () async {
                          await _state.retry();
                          if (mounted) await widget.onRefresh();
                        },
                  child: Text(
                    _state.busy
                        ? 'Memproses…'
                        : 'Coba ulang permintaan yang sama',
                  ),
                ),
              if (_state.needsReview)
                TextButton(
                  onPressed: widget.externalBusy
                      ? null
                      : () async {
                          await widget.onRefresh();
                          if (mounted &&
                              widget.stop['can_record_result'] == true) {
                            await _state.reviewAgain();
                          }
                        },
                  child: const Text('Periksa ulang hasil'),
                ),
            ],
            if (_message != null || _state.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_message ?? _state.message!),
              ),
            if (_state.storageError)
              TextButton(
                onPressed: _state.busy ? null : _restore,
                child: const Text('Periksa penyimpanan kembali'),
              ),
          ],
        ),
      ),
    );
  }
}
