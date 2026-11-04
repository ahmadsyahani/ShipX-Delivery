import 'dart:async';
import 'package:flutter/material.dart';
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
  const DeliveryPage({super.key, required this.session, this.shopping});
  final AuthSession session;
  final ShoppingState? shopping;
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
      if (_depot!['configured'] == true) await _loadSlots();
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

  @override
  Widget build(BuildContext context) {
    if (_busy) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }
    if (_depot?['configured'] != true) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.warehouse_outlined, size: 56),
            const SizedBox(height: 20),
            Text(
              'Wilayah pengiriman sedang disiapkan',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Admin perlu melengkapi lokasi dan radius depot. Setelah siap, Anda bisa menambahkan alamat dan memilih jadwal.',
            ),
            TextButton(onPressed: _load, child: const Text('Periksa kembali')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        children: [
          Text(
            'Alamat & jadwal',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${_depot!['name']} · Ongkir ${rupiah(_depot!['delivery_fee_rp'])}',
            style: const TextStyle(color: Color(0xFF657B83)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Alamat pengantaran',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: _locked ? null : () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
              ),
            ],
          ),
          if (_addresses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Belum ada alamat. Tambahkan penerima dan pin lokasi terlebih dahulu.',
              ),
            ),
          for (final a in _addresses)
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a['label'],
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (_selectedAddress == a['id'])
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF087E8B),
                          ),
                      ],
                    ),
                    Text('${a['recipient_name']} · ${a['phone']}'),
                    Text(a['address_text']),
                    if (a['within_service_area'] != true)
                      const Text(
                        'Di luar wilayah layanan saat ini. Edit pin alamat.',
                        style: TextStyle(color: Colors.red),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed:
                              a['within_service_area'] == true && !_locked
                              ? () => _chooseAddress(a)
                              : null,
                          child: Text(
                            _selectedAddress == a['id']
                                ? 'Dipilih'
                                : 'Pilih alamat',
                          ),
                        ),
                        TextButton(
                          onPressed: _locked ? null : () => _edit(a),
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          onPressed: _locked ? null : () => _delete(a),
                          child: const Text('Hapus'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_addressPage < _addressLast)
            TextButton(
              onPressed: _addressMore ? null : _moreAddresses,
              child: Text(_addressMore ? 'Memuat...' : 'Muat alamat lainnya'),
            ),
          const SizedBox(height: 24),
          Text(
            'Jadwal pengiriman',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          TextButton.icon(
            onPressed: _locked ? null : _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('$_date · ${_depot!['timezone']}'),
          ),
          if (_slotBusy)
            const Center(child: CircularProgressIndicator())
          else if (_slotError != null)
            Column(
              children: [
                Text(_slotError!),
                TextButton(
                  onPressed: () => _loadSlots(),
                  child: const Text('Muat ulang slot'),
                ),
              ],
            )
          else if (_slots.where(_open).isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Belum ada slot terbuka untuk tanggal ini. Pilih tanggal lain atau muat ulang.',
              ),
            )
          else ...[
            for (final s in _slots.where(_open))
              Card(
                color: Colors.white,
                child: ListTile(
                  selected: _selectedSlot == s['id'],
                  leading: Icon(
                    _selectedSlot == s['id']
                        ? Icons.check_circle
                        : Icons.schedule,
                    color: const Color(0xFF087E8B),
                  ),
                  title: Text(
                    '${slotTime(s['window_start_at'], _depot!['timezone'])}–${slotTime(s['window_end_at'], _depot!['timezone'])}',
                  ),
                  subtitle: Text(
                    'Batas pesan ${slotDate(s['cutoff_at'], _depot!['timezone'])} ${slotTime(s['cutoff_at'], _depot!['timezone'])}',
                  ),
                  onTap: _locked ? null : () => _chooseSlot(s),
                ),
              ),
          ],
          if (!_slotBusy && _slotError == null && _slotPage < _slotLast)
            TextButton(
              onPressed: _slotMore ? null : () => _loadSlots(next: true),
              child: Text(_slotMore ? 'Memuat...' : 'Muat slot lainnya'),
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F4F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _selectedAddress != null && _selectedSlot != null
                  ? 'Alamat dan jadwal sudah dipilih. Pilihan ini belum membuat pesanan atau memesan stok.'
                  : 'Pilih alamat dan jadwal, lalu buka Keranjang untuk menghitung total dan membuat pesanan.',
            ),
          ),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Muat ulang pengiriman'),
          ),
        ],
      ),
    );
  }
}
