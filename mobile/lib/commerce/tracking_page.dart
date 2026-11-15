import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/app_theme.dart';
import '../core/auth_api.dart';
import '../core/auth_session.dart';
import '../core/map_attribution.dart';
import '../core/navigation_panels.dart';
import '../courier/navigation_route.dart';
import '../courier/trip_navigation_target.dart' show tripPoint;
import 'order_refresh.dart';

class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({
    super.key,
    required this.session,
    required this.orderId,
    this.tileProvider,
    this.clock,
  });
  final AuthSession session;
  final String orderId;
  final TileProvider? tileProvider;
  final DateTime Function()? clock;

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage>
    with OrderRefresh<OrderTrackingPage> {
  final _map = MapController();
  Map<String, dynamic>? _data;
  List<LatLng> _road = [];
  bool _busy = false, _mapReady = false, _following = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    startOrderRefresh(_load, interval: const Duration(seconds: 10));
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final data = await widget.session.commerceRequest(
        'GET',
        '/orders/${widget.orderId}/tracking',
      );
      final road = data['route'] == null
          ? <LatLng>[]
          : decodeRouteShape(data['route']['shape']);
      if (!mounted) return;
      setState(() {
        _data = data;
        _road = road;
        _error = null;
        if (data['location'] == null) _mapReady = false;
      });
      _fit();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          if ([401, 403, 404].contains(error.status)) {
            _data = null;
            _road = [];
            _mapReady = false;
          }
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Koneksi terputus. Lokasi belum dapat diperbarui.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fit() {
    if (!_mapReady || !_following) return;
    final courier = tripPoint(_data?['location'] as Map?);
    final destination = tripPoint(_data?['destination'] as Map?);
    if (courier == null || destination == null) return;
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([courier, destination, ..._road]),
        padding: EdgeInsets.fromLTRB(
          40,
          MediaQuery.sizeOf(context).height * .12,
          40,
          MediaQuery.sizeOf(context).height * .30,
        ),
        maxZoom: 17,
      ),
    );
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = _data?['location'] as Map?;
    final point = tripPoint(location);
    final destination = tripPoint(_data?['destination'] as Map?);
    final recorded = DateTime.tryParse('${location?['recorded_at']}');
    final stale =
        _error != null ||
        _data?['status'] != 'live' ||
        recorded == null ||
        (widget.clock?.call() ?? DateTime.now()).toUtc().difference(
              recorded.toUtc(),
            ) >
            const Duration(seconds: 60);
    final route = !stale ? (_data?['route'] as Map?) : null;
    final minutes = route == null
        ? null
        : ((route['duration_seconds'] as num) / 60).ceil();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lacak pengiriman'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            tooltip: 'Perbarui posisi kurir',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: point == null || destination == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_busy)
                      const CircularProgressIndicator()
                    else
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 48,
                        color: AppColors.primary,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _error ??
                          (_data?['status'] == 'unavailable'
                              ? 'Pelacakan sudah berakhir atau pengiriman belum dimulai.'
                              : 'Menunggu lokasi kurir. Lokasi akan tampil saat kurir menyalakan navigasi.'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 16,
                    onMapReady: () {
                      _mapReady = true;
                      _fit();
                    },
                    onPositionChanged: (_, gesture) {
                      if (gesture) _following = false;
                    },
                  ),
                  children: [
                    TileLayer(
                      tileProvider: widget.tileProvider,
                      urlTemplate: const String.fromEnvironment(
                        'MAP_TILE_URL',
                        defaultValue:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      userAgentPackageName: 'com.example.shipx',
                      panBuffer: 0,
                    ),
                    if (!stale && _road.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _road,
                            color: AppColors.primary,
                            strokeWidth: 5,
                            borderColor: Colors.white,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 48,
                          height: 48,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delivery_dining_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                        Marker(
                          point: destination,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_on,
                            size: 44,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                NavigationPanels(
                  header: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Material(
                      color: stale
                          ? AppColors.warningBg
                          : AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              stale ? Icons.schedule : Icons.gps_fixed_rounded,
                              color: stale ? AppColors.warning : Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                stale
                                    ? 'Lokasi terakhir · menunggu pembaruan'
                                    : 'Posisi kurir diperbarui',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: stale
                                      ? AppColors.warning
                                      : Colors.white,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                _following = true;
                                _fit();
                              },
                              tooltip: 'Lihat kurir dan tujuan',
                              icon: Icon(
                                Icons.center_focus_strong,
                                color: stale ? AppColors.warning : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  footer: Material(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            minutes == null
                                ? 'Pengiriman sedang berlangsung'
                                : 'Sekitar ${minutes < 1 ? 1 : minutes} menit lagi',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_data!['destination']['address_text']}',
                            style: const TextStyle(fontSize: 13, height: 1.5),
                          ),
                          if (_data?['is_next_stop'] == false)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Kurir sedang menyelesaikan pengantaran sebelumnya.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          if (recorded != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Lokasi diperbarui ${recorded.toLocal().hour.toString().padLeft(2, '0')}.${recorded.toLocal().minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          const MapAttribution(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
