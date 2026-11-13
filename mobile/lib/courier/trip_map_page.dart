import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/map_attribution.dart';
import '../core/app_theme.dart';
import '../core/device_location.dart';
import '../core/auth_session.dart';
import '../core/auth_api.dart';
import '../commerce/order_refresh.dart';
import 'trip_navigation_target.dart';
import 'trip_navigation_page.dart';
export 'trip_navigation_target.dart' show tripPoint;

/// Destination overview. Road guidance is supplied by the navigation provider.
class TripMapPage extends StatefulWidget {
  const TripMapPage({super.key, required this.trip, required this.session});
  final Map<String, dynamic> trip;
  final AuthSession session;

  @override
  State<TripMapPage> createState() => _TripMapPageState();
}

class _TripMapPageState extends State<TripMapPage>
    with OrderRefresh<TripMapPage> {
  final _map = MapController();
  LatLng? _location;
  bool _locating = false;
  String? _error;
  Map<String, dynamic>? _trip;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _refresh();
    startOrderRefresh(_refresh);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final response = await widget.session.commerceRequest(
        'GET',
        '/courier/trips/${widget.trip['id']}',
        envelope: true,
      );
      if (mounted) {
        setState(() {
          _trip = response['data'] as Map<String, dynamic>;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          if ([401, 403, 404].contains(error.status)) _trip = null;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Peta belum diperbarui. Periksa koneksi.');
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final point = await const DeviceLocation().locate();
      if (!mounted || _trip == null) return;
      setState(() => _location = point);
      _map.move(point, 16);
    } on LocationFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Lokasi belum terbaca. Coba lagi.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Widget _pin({String? number, bool depot = false, bool done = false}) =>
      Container(
        decoration: BoxDecoration(
          color: done ? AppColors.textMuted : AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        alignment: Alignment.center,
        child: depot
            ? const Icon(
                Icons.warehouse_outlined,
                color: Colors.white,
                size: 22,
              )
            : Text(
                number!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
      );

  @override
  Widget build(BuildContext context) {
    final target = _trip == null ? null : TripNavigationTarget.fromTrip(_trip!);
    final depot = tripPoint(_trip?['depot'] as Map?);
    final stops = (_trip?['stops'] as List? ?? []).cast<Map<String, dynamic>>();
    final points = <LatLng>[
      ?depot,
      for (final stop in stops)
        if (tripPoint(stop['address'] as Map?) case final LatLng point) point,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Peta tujuan')),
      body: points.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  _error ?? 'Titik pengiriman belum tersedia. Perbarui trip.',
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: AppColors.primaryDark,
                  child: const Text(
                    'Penanda mengikuti urutan trip. Buka rute untuk petunjuk perjalanan.',
                    style: TextStyle(color: Colors.white, height: 1.5),
                  ),
                ),
                Expanded(
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: points.first,
                      initialZoom: 14,
                      initialCameraFit: points.length > 1
                          ? CameraFit.bounds(
                              bounds: LatLngBounds.fromPoints(points),
                              padding: const EdgeInsets.all(48),
                              maxZoom: 16,
                            )
                          : null,
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
                      MarkerLayer(
                        markers: [
                          if (depot != null)
                            Marker(
                              point: depot,
                              width: 42,
                              height: 42,
                              child: Tooltip(
                                message: 'Depot',
                                child: _pin(depot: true),
                              ),
                            ),
                          for (final stop in stops)
                            if (tripPoint(stop['address'] as Map?)
                                case final LatLng point)
                              Marker(
                                point: point,
                                width: 38,
                                height: 38,
                                child: Tooltip(
                                  message:
                                      '${(stop['address'] as Map)['recipient_name']}',
                                  child: _pin(
                                    number: '${stop['sequence_no']}',
                                    done: [
                                      'delivered',
                                      'failed',
                                    ].contains(stop['status']),
                                  ),
                                ),
                              ),
                          if (_location != null)
                            Marker(
                              point: _location!,
                              width: 30,
                              height: 30,
                              child: const Icon(
                                Icons.my_location,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                        ],
                      ),
                      const MapAttribution(),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (target != null) ...[
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                final backToTrip = await Navigator.of(context)
                                    .push<bool>(
                                      MaterialPageRoute(
                                        builder: (_) => TripNavigationPage(
                                          session: widget.session,
                                          tripId: '${widget.trip['id']}',
                                        ),
                                      ),
                                    );
                                if (backToTrip == true && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              icon: const Icon(Icons.navigation_rounded),
                              label: Text(
                                target.guidance
                                    ? 'Mulai navigasi'
                                    : 'Lihat rute',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _locating ? null : _locate,
                            icon: const Icon(Icons.my_location),
                            label: Text(
                              _locating
                                  ? 'Membaca lokasi…'
                                  : 'Lihat posisi saya',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
