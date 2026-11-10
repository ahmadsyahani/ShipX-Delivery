import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../core/auth_api.dart';
import '../core/auth_session.dart';
import '../catalog_page.dart' show rupiah;
import 'address_form.dart';
import '../commerce/shopping_state.dart';

DateTime slotLocal(String value, String timezone) {
  final utc = DateTime.parse(value).toUtc();
  final hour = switch (timezone) {
    'Asia/Jayapura' => 9,
    'Asia/Makassar' => 8,
    _ => 7,
  };
  final local = utc.add(Duration(hours: hour));
  return local;
}

String slotTime(String value, String timezone) {
  final local = slotLocal(value, timezone);
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String slotDate(String value, String timezone) {
  final local = slotLocal(value, timezone);
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({
    super.key,
    required this.session,
    this.shopping,
    this.openCart,
    this.continueLabel = 'Lanjut ke keranjang',
  });
  final AuthSession session;
  final ShoppingState? shopping;
  final VoidCallback? openCart;
  final String continueLabel;
  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  Map<String, dynamic>? _depot;
  final List<Map<String, dynamic>> _addresses = [], _slots = [];
  String? _selectedAddress, _selectedSlot, _date, _error, _slotError;
  bool _busy = true, _slotBusy = false, _addressMore = false, _slotMore = false;
  int _addressPage = 0,
      _addressLast = 1,
      _slotPage = 0,
      _slotLast = 1,
      _generation = 0;
  int _loadSequence = 0;
  DateTime _serverTime = DateTime.now().toUtc();
  final Stopwatch _elapsed = Stopwatch()..start();
  Timer? _timer;
  DateTime get _now => _serverTime.add(_elapsed.elapsed);
  bool _open(Map<String, dynamic> s) =>
      DateTime.parse(s['cutoff_at']).isAfter(_now) &&
      DateTime.parse(s['window_start_at']).isAfter(_now);
  bool get _locked => widget.shopping?.locked ?? false;

  void _chooseAddress(Map<String, dynamic> value) {
    if (_locked) return;
    setState(() => _selectedAddress = value['id']);
    widget.shopping?.chooseAddress(value);
  }

  void _chooseSlot(Map<String, dynamic> value) {
    if (_locked) return;
    setState(() => _selectedSlot = _open(value) ? value['id'] : null);
    widget.shopping?.chooseSlot(
      _selectedSlot == null
          ? null
          : {...value, 'timezone': _depot!['timezone']},
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.shopping?.address?['id'];
    _selectedSlot = widget.shopping?.slot?['id'];
    _date = widget.shopping?.slot?['service_date'];
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final selected = widget.shopping?.slot;
      if (!_locked &&
          selected != null &&
          !DateTime.parse(selected['cutoff_at']).isAfter(_now)) {
        widget.shopping!.chooseSlot(null);
      }
      if (_slots.any((slot) => !_open(slot))) {
        setState(() {
          _slots.removeWhere((slot) => !_open(slot));
          if (!_slots.any((slot) => slot['id'] == _selectedSlot)) {
            _selectedSlot = null;
            widget.shopping?.chooseSlot(null);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsed.stop();
    super.dispose();
  }

  void _clock(String value) {
    _serverTime = DateTime.parse(value).toUtc();
    _elapsed.reset();
  }

  Future<void> _load() async {
    final previousSlot = widget.shopping?.slot;
    ++_generation;
    final sequence = ++_loadSequence;
    setState(() {
      _addressMore = false;
      _slotMore = false;
      _slotBusy = false;
      _busy = true;
      _error = null;
      _selectedSlot = null;
    });
    try {
      final results = await Future.wait([
        widget.session.deliveryRequest('GET', '/delivery-settings'),
        widget.session.deliveryRequest(
          'GET',
          '/addresses?per_page=20',
          envelope: true,
        ),
      ]);
      if (!mounted || sequence != _loadSequence) return;
      setState(() {
        _depot = results[0];
        _clock(_depot!['server_time']);
        if (_date == null || _date!.compareTo(_depot!['today'] as String) < 0) {
          _date = _depot!['today'];
        }
        _addresses
          ..clear()
          ..addAll((results[1]['data'] as List).cast<Map<String, dynamic>>());
        _addressPage = results[1]['meta']['current_page'];
        _addressLast = results[1]['meta']['last_page'];
        if (!_addresses.any(
          (a) =>
              a['id'] == _selectedAddress && a['within_service_area'] == true,
        )) {
          _selectedAddress = null;
        }
      });
      if (widget.shopping != null && !_locked) {
        final matches = _addresses.where(
          (a) =>
              a['id'] == _selectedAddress && a['within_service_area'] == true,
        );
        widget.shopping!.chooseAddress(matches.isEmpty ? null : matches.first);
        widget.shopping!.chooseSlot(null);
      }
      if (_depot!['configured'] == true) {
        await _loadSlots();
        if (!mounted || sequence != _loadSequence) return;
        if (previousSlot != null && _selectedAddress != null && !_locked) {
          final matches = _slots.where(
            (slot) => slot['id'] == previousSlot['id'] && _open(slot),
          );
          if (matches.isNotEmpty) _chooseSlot(matches.first);
        }
      }
    } catch (_) {
      if (mounted && sequence == _loadSequence) {
        setState(
          () => _error =
              'Data pengiriman belum dapat dimuat. Periksa koneksi dan coba lagi.',
        );
      }
    } finally {
      if (mounted && sequence == _loadSequence) setState(() => _busy = false);
    }
  }

  Future<void> _moreAddresses() async {
    if (_addressMore) return;
    final sequence = _loadSequence;
    setState(() => _addressMore = true);
    try {
      final r = await widget.session.deliveryRequest(
        'GET',
        '/addresses?page=${_addressPage + 1}&per_page=20',
        envelope: true,
      );
      if (mounted && sequence == _loadSequence) {
        setState(() {
          _addresses.addAll((r['data'] as List).cast<Map<String, dynamic>>());
          _addressPage = r['meta']['current_page'];
          _addressLast = r['meta']['last_page'];
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alamat lainnya belum dapat dimuat. Coba lagi.'),
          ),
        );
      }
    } finally {
      if (mounted && sequence == _loadSequence) {
        setState(() => _addressMore = false);
      }
    }
  }

  Future<void> _loadSlots({bool next = false}) async {
    if (next && (_slotBusy || _slotMore)) return;
    final generation = ++_generation;
    setState(() {
      _slotError = null;
      if (next) {
        _slotMore = true;
      } else {
        _slotBusy = true;
        _selectedSlot = null;
        widget.shopping?.chooseSlot(null);
        _slots.clear();
      }
    });
    try {
      final r = await widget.session.deliveryRequest(
        'GET',
        '/delivery-slots?date=$_date&page=${next ? _slotPage + 1 : 1}&per_page=20',
        envelope: true,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _clock(r['server_time']);
        _slots.addAll((r['data'] as List).cast<Map<String, dynamic>>());
        _slotPage = r['meta']['current_page'];
        _slotLast = r['meta']['last_page'];
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _slotError = 'Slot belum dapat dimuat. Coba lagi.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _slotBusy = false;
          _slotMore = false;
        });
      }
    }
  }

  Future<void> _edit([Map<String, dynamic>? address]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressFormPage(
          session: widget.session,
          depot: _depot!,
          address: address,
        ),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _delete(Map<String, dynamic> address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus alamat?'),
        content: Text(
          'Alamat ${address['label']} akan dinonaktifkan dari daftar Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.session.deliveryRequest(
        'DELETE',
        '/addresses/${address['id']}',
        body: {'lock_version': '${address['lock_version']}'},
      );
      if (mounted) await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Alamat belum dapat dihapus. Periksa koneksi lalu coba lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final first = DateTime.parse(_depot!['today']);
    final initial = DateTime.parse(_date!);
    final chosen = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
    );
    if (chosen != null && mounted) {
      setState(
        () => _date =
            '${chosen.year}-${chosen.month.toString().padLeft(2, '0')}-${chosen.day.toString().padLeft(2, '0')}',
      );
      await _loadSlots();
    }
  }

  Widget _addressTile(Map<String, dynamic> address) {
    final selected = _selectedAddress == address['id'];
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 21,
                    color: selected ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address['label'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        address['address_text'],
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: AppColors.textBody,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${address['recipient_name']} · ${address['phone']}',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (address['within_service_area'] != true)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: InfoBanner(
                  message: 'Di luar wilayah layanan saat ini. Edit pin alamat.',
                  color: AppColors.error,
                  backgroundColor: AppColors.errorBg,
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: _locked ? null : () => _delete(address),
                  child: const Text(
                    'Hapus',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: _locked ? null : () => _edit(address),
                  child: const Text('Edit'),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size(48, 40),
                  ),
                  onPressed: address['within_service_area'] == true && !_locked
                      ? () => _chooseAddress(address)
                      : null,
                  child: Text(selected ? 'Dipilih' : 'Pilih alamat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotTile(Map<String, dynamic> slot) {
    final selected = _selectedSlot == slot['id'];
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _locked ? null : () => _chooseSlot(slot),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${slotTime(slot['window_start_at'], _depot!['timezone'])}\u2013${slotTime(slot['window_end_at'], _depot!['timezone'])}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Batas pesan ${slotDate(slot['cutoff_at'], _depot!['timezone'])} ${slotTime(slot['cutoff_at'], _depot!['timezone'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textBody,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_depot?['configured'] != true) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.warehouse_outlined,
                        size: 56,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Wilayah pengiriman sedang disiapkan',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMain,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Admin perlu melengkapi lokasi dan radius depot. Setelah siap, Anda bisa menambahkan alamat dan memilih jadwal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Periksa kembali'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    final complete = _selectedAddress != null && _selectedSlot != null;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                const Text(
                  'Mau diantar ke mana?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pilih alamat dan waktu pengantaranmu.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Alamat tujuan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _locked ? null : () => _edit(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Tambah'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_addresses.isEmpty)
                  const AppPanel(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.add_location_alt_outlined,
                          size: 25,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Belum ada alamat. Tambahkan penerima dan pin lokasi terlebih dahulu.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final address in _addresses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _addressTile(address),
                  ),
                if (_addressPage < _addressLast)
                  TextButton(
                    onPressed: _addressMore ? null : _moreAddresses,
                    child: Text(
                      _addressMore ? 'Memuat...' : 'Muat alamat lainnya',
                    ),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Jadwal pengiriman',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pilih tanggal, lalu jam yang tersedia.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  button: true,
                  label: 'Pilih tanggal pengiriman',
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _locked ? null : _pickDate,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLighter,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.calendar_today_outlined,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tanggal pengantaran',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _dateLabel(),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 22,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_slotBusy)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_slotError != null)
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _slotError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _loadSlots(),
                          child: const Text('Muat ulang slot'),
                        ),
                      ],
                    ),
                  )
                else if (_slots.where(_open).isEmpty)
                  AppPanel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Belum ada slot terbuka untuk tanggal ini. Pilih tanggal lain atau muat ulang.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _locked ? null : _pickDate,
                            child: const Text('Pilih tanggal lain'),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final slot in _slots.where(_open))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _slotTile(slot),
                  ),
                if (_slotPage < _slotLast)
                  TextButton(
                    onPressed: _slotMore ? null : () => _loadSlots(next: true),
                    child: Text(
                      _slotMore ? 'Memuat...' : 'Muat jadwal lainnya',
                    ),
                  ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warehouse_outlined,
                        size: 19,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dikirim dari ${_depot!['name']}',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: AppColors.textBody,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ongkir per pesanan ${rupiah(_depot!['delivery_fee_rp'])}',
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
                ),
                if (complete)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'Alamat dan jadwal sudah dipilih.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Muat ulang pengiriman'),
                ),
              ],
            ),
          ),
        ),
        if (widget.openCart != null)
          Material(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.borderLight)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!complete)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _selectedAddress == null
                              ? 'Pilih alamat pengiriman terlebih dahulu.'
                              : 'Pilih jam pengantaran untuk melanjutkan.',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    FilledButton(
                      key: const ValueKey('delivery-continue'),
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      onPressed: complete && !_locked ? widget.openCart : null,
                      child: Text(
                        widget.continueLabel,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _dateLabel() {
    final date = DateTime.tryParse(_date ?? '');
    if (date == null) return 'Pilih tanggal';
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
