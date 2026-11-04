import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/auth_api.dart';
import '../core/auth_session.dart';

class AddressFormPage extends StatefulWidget {
  const AddressFormPage({
    super.key,
    required this.session,
    required this.depot,
    this.address,
  });
  final AuthSession session;
  final Map<String, dynamic> depot;
  final Map<String, dynamic>? address;
  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  final _form = GlobalKey<FormState>();
  final _values = <String, String>{};
  late final TextEditingController _lat, _lng;
  bool _busy = false, _stale = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _lat = TextEditingController(
      text: widget.address?['latitude']?.toString() ?? '',
    );
    _lng = TextEditingController(
      text: widget.address?['longitude']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _pin() async {
    final lat = double.tryParse(_lat.text.replaceAll(',', '.')),
        lng = double.tryParse(_lng.text.replaceAll(',', '.'));
    final valid =
        lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180;
    final pin = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => PinPicker(
          depot: widget.depot,
          initial: valid ? LatLng(lat, lng) : null,
        ),
      ),
    );
    if (pin != null && mounted) {
      setState(() {
        _lat.text = pin.latitude.toStringAsFixed(7);
        _lng.text = pin.longitude.toStringAsFixed(7);
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      setState(
        () => _error = 'Lengkapi isian wajib dan periksa koordinat alamat.',
      );
      return;
    }
    _form.currentState!.save();
    setState(() {
      _busy = true;
      _error = null;
      _stale = false;
    });
    try {
      final existing = widget.address;
      await widget.session.deliveryRequest(
        existing == null ? 'POST' : 'PATCH',
        existing == null ? '/addresses' : '/addresses/${existing['id']}',
        body: {
          ..._values,
          'latitude': _lat.text.trim().replaceAll(',', '.'),
          'longitude': _lng.text.trim().replaceAll(',', '.'),
          if (existing != null) 'lock_version': '${existing['lock_version']}',
        },
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _stale = error.status == 409;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Alamat belum tersimpan. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String key,
    String label,
    int max, {
    bool optional = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(key),
      initialValue: widget.address?[key] as String?,
      enabled: !_busy,
      maxLength: max,
      maxLines: lines,
      keyboardType: key == 'phone' ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: (value) => !optional && (value == null || value.trim().isEmpty)
          ? '$label wajib diisi.'
          : null,
      onSaved: (value) => _values[key] = value?.trim() ?? '',
    ),
  );
  Widget _coordinate(
    TextEditingController controller,
    String label,
    double bound,
  ) => TextFormField(
    controller: controller,
    enabled: !_busy,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final v = double.tryParse((value ?? '').replaceAll(',', '.'));
      return v == null || !v.isFinite || v.abs() > bound
          ? 'Isi $label yang valid.'
          : null;
    },
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.address == null ? 'Tambah alamat' : 'Edit alamat'),
    ),
    body: Form(
      key: _form,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ke mana barang diantar?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Isi penerima, alamat lengkap, dan titik lokasi yang tepat.',
            ),
            const SizedBox(height: 24),
            _field('label', 'Label alamat', 80),
            _field('recipient_name', 'Nama penerima', 160),
            _field('phone', 'Nomor telepon', 30),
            _field('address_text', 'Alamat lengkap', 2000, lines: 3),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pin,
              icon: const Icon(Icons.pin_drop_outlined),
              label: const Text('Pilih pin di peta'),
            ),
            const SizedBox(height: 16),
            _coordinate(_lat, 'Latitude', 90),
            const SizedBox(height: 16),
            _coordinate(_lng, 'Longitude', 180),
            const SizedBox(height: 12),
            Text(
              'Radius layanan: ${widget.depot['service_radius_m']} meter dari ${widget.depot['name']}. Titik harus berada dalam wilayah layanan.',
              style: const TextStyle(color: Color(0xFF657B83)),
            ),
            const SizedBox(height: 20),
            _field(
              'directions',
              'Petunjuk tambahan (opsional)',
              1000,
              optional: true,
              lines: 2,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_stale)
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Kembali dan muat ulang'),
              ),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Menyimpan...' : 'Simpan alamat'),
            ),
          ],
        ),
      ),
    ),
  );
}

class PinPicker extends StatefulWidget {
  const PinPicker({super.key, required this.depot, this.initial});
  final Map<String, dynamic> depot;
  final LatLng? initial;
  @override
  State<PinPicker> createState() => _PinPickerState();
}

class _PinPickerState extends State<PinPicker> {
  late LatLng _center;
  LatLng? _pin;
  @override
  void initState() {
    super.initState();
    _center = LatLng(
      (widget.depot['latitude'] as num).toDouble(),
      (widget.depot['longitude'] as num).toDouble(),
    );
    _pin = widget.initial;
  }

  bool get _inside =>
      _pin != null &&
      const Distance().as(LengthUnit.Meter, _center, _pin!) <=
          (widget.depot['service_radius_m'] as num);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pilih titik pengantaran')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Ketuk peta untuk menaruh pin. Lingkaran menunjukkan wilayah layanan.',
          ),
        ),
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _pin ?? _center,
              initialZoom: 14,
              minZoom: 3,
              maxZoom: 19,
              onTap: (_, point) => setState(() => _pin = point),
            ),
            children: [
              TileLayer(
                urlTemplate: const String.fromEnvironment(
                  'MAP_TILE_URL',
                  defaultValue:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                userAgentPackageName: 'com.example.shipx',
                panBuffer: 0,
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _center,
                    radius: (widget.depot['service_radius_m'] as num)
                        .toDouble(),
                    useRadiusInMeter: true,
                    color: const Color(0x18087E8B),
                    borderColor: const Color(0xFF087E8B),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    child: const Icon(
                      Icons.warehouse,
                      color: Color(0xFF087E8B),
                    ),
                  ),
                  if (_pin != null)
                    Marker(
                      point: _pin!,
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: Icon(
                        Icons.location_pin,
                        color: _inside ? Colors.red : Colors.grey,
                        size: 44,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://www.openstreetmap.org/copyright'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('© OpenStreetMap contributors'),
        ),
        if (_pin != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _inside
                  ? '${_pin!.latitude.toStringAsFixed(7)}, ${_pin!.longitude.toStringAsFixed(7)}'
                  : 'Titik berada di luar wilayah layanan. Pilih titik lain.',
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _inside ? () => Navigator.pop(context, _pin) : null,
                child: const Text('Gunakan titik ini'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
