import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../core/auth_api.dart';
import '../core/device_location.dart';
import '../core/auth_session.dart';

class AddressFormPage extends StatefulWidget {
  const AddressFormPage({
    super.key,
    required this.session,
    required this.depot,
    this.address,
    this.location = const DeviceLocation(),
  });
  final AuthSession session;
  final DeviceLocation location;
  final Map<String, dynamic> depot;
  final Map<String, dynamic>? address;
  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  final _form = GlobalKey<FormState>();
  final _values = <String, String>{};
  late final TextEditingController _lat, _lng;
  bool _busy = false, _stale = false, _locating = false;
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

  Future<void> _pin({bool useDevice = false}) async {
    LatLng? devicePoint;
    if (useDevice) {
      setState(() {
        _locating = true;
        _error = null;
      });
      try {
        devicePoint = await widget.location.locate();
      } on LocationFailure catch (error) {
        if (mounted) setState(() => _error = error.message);
        return;
      } catch (_) {
        if (mounted) {
          setState(
            () => _error =
                'Lokasi belum dapat dibaca. Coba lagi atau pilih pin di peta.',
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _locating = false);
      }
      if (!mounted) return;
    }
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
          initial: devicePoint ?? (valid ? LatLng(lat, lng) : null),
          location: widget.location,
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
      setState(() => _error = 'Lengkapi isian wajib terlebih dahulu.');
      return;
    }
    final lat = double.tryParse(_lat.text), lng = double.tryParse(_lng.text);
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      setState(
        () => _error = 'Pilih titik pengantaran di peta terlebih dahulu.',
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
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(key),
      initialValue: widget.address?[key] as String?,
      enabled: !_busy,
      maxLength: max,
      maxLines: lines,
      keyboardType: key == 'phone' ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: AppColors.textMuted)
            : null,
      ),
      validator: (value) => !optional && (value == null || value.trim().isEmpty)
          ? '$label wajib diisi.'
          : null,
      onSaved: (value) => _values[key] = value?.trim() ?? '',
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.address == null ? 'Tambah alamat' : 'Edit alamat'),
    ),
    body: Form(
      key: _form,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppPageIntro(
              title: 'Ke mana barang diantar?',
              description:
                  'Lengkapi penerima dan alamat, lalu pastikan titik lokasinya.',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppSectionTitle(
                      title: 'Alamat penerima',
                      icon: Icons.person_pin_circle_outlined,
                    ),
                    _field(
                      'label',
                      'Label alamat',
                      80,
                      icon: Icons.bookmark_border_rounded,
                    ),
                    _field(
                      'recipient_name',
                      'Nama penerima',
                      160,
                      icon: Icons.person_outline,
                    ),
                    _field(
                      'phone',
                      'Nomor telepon',
                      30,
                      icon: Icons.phone_outlined,
                    ),
                    _field(
                      'address_text',
                      'Alamat lengkap',
                      2000,
                      lines: 3,
                      icon: Icons.home_outlined,
                    ),
                    const Divider(height: 24),
                    const AppSectionTitle(
                      title: 'Titik pengantaran',
                      icon: Icons.map_outlined,
                      subtitle: 'Gunakan lokasi perangkat atau pilih di peta',
                    ),
                    FilledButton.icon(
                      onPressed: _busy || _locating
                          ? null
                          : () => _pin(useDevice: true),
                      icon: const Icon(Icons.my_location_rounded),
                      label: Text(
                        _locating ? 'Mencari lokasi...' : 'Gunakan lokasi saya',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy || _locating ? null : () => _pin(),
                      icon: const Icon(Icons.pin_drop_outlined),
                      label: const Text('Pilih pin di peta'),
                    ),
                    if (_lat.text.isNotEmpty && _lng.text.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: InfoBanner(
                          message:
                              'Titik pengantaran sudah dipilih. Pastikan pin sesuai alamat penerima.',
                        ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Radius layanan: ${widget.depot['service_radius_m']} meter dari ${widget.depot['name']}. Titik harus berada dalam wilayah layanan.',
                              style: const TextStyle(
                                color: Color(0xFF657B83),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      'directions',
                      'Petunjuk lokasi',
                      1000,
                      optional: true,
                      lines: 2,
                      icon: Icons.directions_outlined,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    if (_stale)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Kembali dan muat ulang'),
                        ),
                      ),
                    FilledButton(
                      onPressed: _busy || _locating ? null : _save,
                      child: Text(_busy ? 'Menyimpan...' : 'Simpan alamat'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PinPicker extends StatefulWidget {
  final DeviceLocation location;
  const PinPicker({
    super.key,
    required this.depot,
    this.initial,
    this.location = const DeviceLocation(),
  });
  final Map<String, dynamic> depot;
  final LatLng? initial;
  @override
  State<PinPicker> createState() => _PinPickerState();
}

class _PinPickerState extends State<PinPicker> {
  late LatLng _center;
  LatLng? _pin;
  final _map = MapController();
  bool _locating = false;
  String? _locationError;
  int _locationGeneration = 0;
  @override
  void initState() {
    super.initState();
    _center = LatLng(
      (widget.depot['latitude'] as num).toDouble(),
      (widget.depot['longitude'] as num).toDouble(),
    );
    _pin = widget.initial;
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _useDeviceLocation() async {
    final generation = ++_locationGeneration;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final point = await widget.location.locate();
      if (!mounted || generation != _locationGeneration) return;
      setState(() => _pin = point);
      _map.move(point, 16);
    } on LocationFailure catch (error) {
      if (mounted && generation == _locationGeneration) {
        setState(() => _locationError = error.message);
      }
    } catch (_) {
      if (mounted && generation == _locationGeneration) {
        setState(
          () => _locationError =
              'Lokasi belum terbaca. Ketuk peta untuk memilih titik.',
        );
      }
    } finally {
      if (mounted && generation == _locationGeneration) {
        setState(() => _locating = false);
      }
    }
  }

  bool get _inside =>
      _pin != null &&
      const Distance().as(LengthUnit.Meter, _center, _pin!) <=
          (widget.depot['service_radius_m'] as num);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pilih titik pengantaran'),
      actions: [
        IconButton(
          tooltip: 'Gunakan lokasi saya',
          onPressed: _locating ? null : _useDeviceLocation,
          icon: const Icon(Icons.my_location_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.primaryLight,
          child: Row(
            children: const [
              Icon(
                Icons.touch_app_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ketuk peta untuk menaruh pin. Lingkaran menunjukkan wilayah layanan.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _pin ?? _center,
              initialZoom: 14,
              minZoom: 3,
              maxZoom: 19,
              onTap: (_, point) {
                _locationGeneration++;
                setState(() {
                  _pin = point;
                  _locating = false;
                  _locationError = null;
                });
              },
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
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.warehouse,
                        color: Color(0xFF087E8B),
                        size: 22,
                      ),
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              if (_locationError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InfoBanner(
                    message: _locationError!,
                    color: AppColors.error,
                    backgroundColor: AppColors.errorBg,
                  ),
                ),
              if (_pin != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _inside ? AppColors.successBg : AppColors.errorBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _inside
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          size: 18,
                          color: _inside ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _inside
                                ? 'Titik pengantaran berada dalam wilayah layanan.'
                                : 'Titik berada di luar wilayah layanan. Pilih titik lain.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _inside
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _inside
                        ? () => Navigator.pop(context, _pin)
                        : null,
                    child: const Text('Gunakan titik ini'),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
