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
  });
  final AuthSession session;
  final ShoppingState? shopping;
  final VoidCallback? openCart;
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
    return AppPanel(
      color: selected ? AppColors.primaryLighter : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionTitle(
            title: address['label'],
            icon: Icons.home_outlined,
            action: selected
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 22,
                  )
                : null,
          ),
          Text(
            address['recipient_name'],
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            address['phone'],
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Text(
            address['address_text'],
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textBody,
              height: 1.6,
            ),
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonal(
                onPressed: address['within_service_area'] == true && !_locked
                    ? () => _chooseAddress(address)
                    : null,
                child: Text(selected ? 'Dipilih' : 'Pilih alamat'),
              ),
              TextButton(
                onPressed: _locked ? null : () => _edit(address),
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: _locked ? null : () => _delete(address),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ],
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
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const AppPageIntro(
            title: 'Alamat & jadwal',
            description: 'Pilih tujuan, lalu tentukan waktu pengantaran.',
          ),
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionTitle(
                  title: _depot!['name'],
                  subtitle: 'Pengiriman dari depot',
                  icon: Icons.warehouse_outlined,
                ),
                AppAmountLine(
                  label: 'Ongkir per pesanan',
                  value: rupiah(_depot!['delivery_fee_rp']),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Alamat pengantaran',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.textMain,
                  ),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                onPressed: _locked ? null : () => _edit(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_addresses.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: const [
                    Icon(
                      Icons.pin_drop_outlined,
                      size: 40,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada alamat. Tambahkan penerima dan pin lokasi terlebih dahulu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          for (final a in _addresses)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _addressTile(a),
            ),
          if (_addressPage < _addressLast)
            Center(
              child: TextButton(
                onPressed: _addressMore ? null : _moreAddresses,
                child: Text(_addressMore ? 'Memuat...' : 'Muat alamat lainnya'),
              ),
            ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Jadwal pengiriman',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.textMain,
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(40, 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
                onPressed: _locked ? null : _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  '$_date · ${_depot!['timezone']}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_slotBusy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_slotError != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _slotError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => _loadSlots(),
                      child: const Text('Muat ulang slot'),
                    ),
                  ],
                ),
              ),
            )
          else if (_slots.where(_open).isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: const [
                    Icon(
                      Icons.schedule_outlined,
                      size: 40,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada slot terbuka untuk tanggal ini. Pilih tanggal lain atau muat ulang.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            for (final s in _slots.where(_open))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _slotTile(s),
              ),
          ],
          if (!_slotBusy && _slotError == null && _slotPage < _slotLast)
            Center(
              child: TextButton(
                onPressed: _slotMore ? null : () => _loadSlots(next: true),
                child: Text(_slotMore ? 'Memuat...' : 'Muat slot lainnya'),
              ),
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F4F4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedAddress != null && _selectedSlot != null
                        ? 'Alamat dan jadwal sudah dipilih. Pilihan ini belum membuat pesanan atau memesan stok.'
                        : 'Pilih alamat dan jadwal, lalu buka Keranjang untuk menghitung total dan membuat pesanan.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.openCart != null &&
              _selectedAddress != null &&
              _selectedSlot != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FilledButton.icon(
                onPressed: _locked ? null : widget.openCart,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Lanjut ke keranjang'),
              ),
            ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Muat ulang pengiriman'),
            ),
          ),
        ],
      ),
    );
  }
}
