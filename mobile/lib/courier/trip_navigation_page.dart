import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/map_attribution.dart';
import '../core/app_theme.dart';
import '../core/auth_api.dart';
import '../core/auth_session.dart';
import '../core/device_location.dart';
import '../commerce/order_refresh.dart';
import 'trip_navigation_target.dart';
import 'navigation_route.dart';

class TripNavigationPage extends StatefulWidget {
  const TripNavigationPage({
    super.key,
    required this.session,
    required this.tripId,
    this.location = const DeviceLocation(),
    this.tileProvider,
    this.clock,
  });
  final AuthSession session;
  final String tripId;
  final DeviceLocation location;
  final TileProvider? tileProvider;
  final DateTime Function()? clock;

  @override
  State<TripNavigationPage> createState() => _TripNavigationPageState();
}

class _TripNavigationPageState extends State<TripNavigationPage>
    with OrderRefresh<TripNavigationPage> {
  final _map = MapController();
  TripNavigationTarget? _target;
  NavigationRoute? _route;
  LatLng? _position;
  StreamSubscription<Position>? _location;
  AppLifecycleListener? _lifecycle;
  bool _busy = true, _rerouting = false, _checking = false, _mapReady = false;
  bool _following = true;
  int _generation = 0, _offRouteFixes = 0;
  double _along = 0;
  double? _heading;
  DateTime? _lastRouting;
  String? _error, _notice;
  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _initialize();
    startOrderRefresh(_checkAssignment);
    _lifecycle = AppLifecycleListener(
      onPause: () {
        if (_target?.guidance != true || !mounted) return;
        _invalidate(
          'Navigasi dijeda saat ShipX ditinggalkan. Tekan Coba lagi untuk melanjutkan.',
        );
      },
    );
  }

  bool _current(int generation) => mounted && generation == _generation;

  Future<Map<String, dynamic>> _readTrip() async {
    final response = await widget.session.commerceRequest(
      'GET',
      '/courier/trips/${widget.tripId}',
      envelope: true,
    );
    return response['data'] as Map<String, dynamic>;
  }

  bool _sameTarget(TripNavigationTarget a, TripNavigationTarget b) =>
      a.id == b.id &&
      a.point == b.point &&
      a.mode == b.mode &&
      a.guidance == b.guidance;

  Future<void> _initialize() async {
    final generation = ++_generation;
    await _location?.cancel();
    _location = null;
    if (!_current(generation)) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _route = null;
      _mapReady = false;
      _along = 0;
      _heading = null;
    });
    try {
      final trip = await _readTrip();
      if (!_current(generation)) return;
      final target = TripNavigationTarget.fromTrip(trip);
      if (target == null) {
        throw const LocationFailure(
          'Tujuan atau jenis kendaraan belum tersedia untuk navigasi. Perbarui trip.',
        );
      }
      _target = target;
      final point = target.guidance
          ? await widget.location.locate()
          : tripPoint(trip['depot'] as Map?);
      if (point == null) {
        throw const LocationFailure(
          'Titik depot belum tersedia untuk pratinjau rute.',
        );
      }
      if (!_current(generation)) return;
      _position = point;
      await _requestRoute(point, generation);
      if (!_current(generation)) return;
      if (target.guidance) {
        _location = widget.location.watch().listen(
          _positionChanged,
          onError: (_) {
            if (mounted) {
              _invalidate(
                'Posisi GPS terputus. Aktifkan lokasi lalu coba lagi.',
              );
            }
          },
        );
      }
    } on ApiException catch (error) {
      if (_current(generation)) setState(() => _error = error.message);
    } on LocationFailure catch (error) {
      if (_current(generation)) setState(() => _error = error.message);
    } catch (_) {
      if (_current(generation)) {
        setState(
          () => _error =
              'Rute demo belum dapat dimuat. Periksa koneksi ke laptop lalu coba lagi.',
        );
      }
    } finally {
      if (_current(generation)) setState(() => _busy = false);
    }
  }

  Future<void> _requestRoute(LatLng origin, int generation) async {
    _lastRouting = _now;
    final response = await widget.session.commerceRequest(
      'POST',
      '/courier/trips/${widget.tripId}/navigation',
      body: {'latitude': origin.latitude, 'longitude': origin.longitude},
    );
    if (!_current(generation)) return;
    final route = NavigationRoute.fromJson(response);
    final trip = await _readTrip();
    if (!_current(generation)) return;
    final target = TripNavigationTarget.fromTrip(trip);
    if (target == null ||
        _target == null ||
        !_sameTarget(_target!, target) ||
        route.targetId != target.id ||
        route.version != '${trip['route_version_id']}') {
      throw const LocationFailure(
        'Tujuan trip berubah. Kembali ke detail trip untuk memperbarui tujuan.',
      );
    }
    setState(() {
      _route = route;
      _along = 0;
      _offRouteFixes = 0;
      _notice = null;
    });
    _fitMap();
  }

  void _fitMap() {
    if (!_mapReady || _route == null) return;
    if (_target?.guidance == true && _position != null) {
      _map.move(_position!, 17);
    } else {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(_route!.points),
          padding: const EdgeInsets.all(48),
          maxZoom: 17,
        ),
      );
    }
  }

  void _positionChanged(Position fix) {
    if (!mounted ||
        _route == null ||
        _error != null ||
        _target?.guidance != true) {
      return;
    }
    if (!fix.latitude.isFinite ||
        !fix.longitude.isFinite ||
        !fix.accuracy.isFinite ||
        fix.accuracy < 0 ||
        fix.latitude.abs() > 90 ||
        fix.longitude.abs() > 180) {
      return;
    }
    final point = LatLng(fix.latitude, fix.longitude);
    if (fix.accuracy > 40) {
      setState(
        () =>
            _notice = 'Akurasi GPS rendah. Menunggu posisi yang lebih akurat.',
      );
      return;
    }
    final progress = _route!.project(
      point,
      minimum: math.max(0, _along - 30),
      maximum: _along + 250,
    );
    final offRoute = progress.offRoute > math.max(50, fix.accuracy * 2);
    setState(() {
      _position = point;
      if (fix.heading.isFinite && fix.heading >= 0 && fix.speed > 0.5) {
        _heading = fix.heading;
      }
      if (!offRoute) _along = math.max(_along, progress.along);
      _offRouteFixes = offRoute ? _offRouteFixes + 1 : 0;
      _notice = offRoute ? 'Posisi keluar jalur rute.' : null;
    });
    if (_mapReady && _following) _map.move(point, _map.camera.zoom);
    final canRetry =
        _lastRouting == null ||
        _now.difference(_lastRouting!) >= const Duration(seconds: 20);
    if (_offRouteFixes >= 3 && !_rerouting && canRetry) {
      unawaited(_reroute(point));
    }
  }

  Future<void> _reroute(LatLng origin) async {
    final generation = _generation;
    setState(() => _rerouting = true);
    try {
      await _requestRoute(origin, generation);
    } on ApiException catch (error) {
      if (_current(generation)) {
        if ([401, 403, 404, 409].contains(error.status)) {
          _invalidate(error.message);
        } else {
          setState(
            () =>
                _notice = '${error.message} Rute sebelumnya masih ditampilkan.',
          );
        }
      }
    } on LocationFailure catch (error) {
      if (_current(generation)) _invalidate(error.message);
    } catch (_) {
      if (_current(generation)) {
        setState(
          () => _notice =
              'Rute belum diperbarui. Rute sebelumnya masih ditampilkan.',
        );
      }
    } finally {
      if (_current(generation)) setState(() => _rerouting = false);
    }
  }

  Future<void> _checkAssignment() async {
    if (_busy || _error != null || _checking) return;
    _checking = true;
    final generation = _generation;
    try {
      final trip = await _readTrip();
      if (!_current(generation) || _target == null) return;
      final target = TripNavigationTarget.fromTrip(trip);
      if (target == null ||
          !_sameTarget(_target!, target) ||
          _route?.version != '${trip['route_version_id']}') {
        _invalidate(
          'Tujuan trip berubah. Kembali ke detail trip untuk memperbarui tujuan.',
        );
      }
    } on ApiException catch (error) {
      if (_current(generation)) _invalidate(error.message);
    } catch (_) {
      if (_current(generation)) {
        _invalidate(
          'Penugasan belum dapat diperiksa. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      _checking = false;
    }
  }

  void _invalidate(String message) {
    _generation++;
    unawaited(_location?.cancel());
    _location = null;
    setState(() {
      _error = message;
      _route = null;
      _mapReady = false;
      _target = null;
      _busy = false;
      _rerouting = false;
    });
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_location?.cancel());
    _lifecycle?.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final step = route?.nextStep(_along);
    final remaining = route == null
        ? 0.0
        : math.max(0.0, route.length - _along);
    final near =
        _target != null &&
        _position != null &&
        remaining < 25 &&
        const Distance().as(LengthUnit.Meter, _position!, _target!.point) < 35;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _target?.guidance == true ? 'Navigasi kurir' : 'Pratinjau rute',
        ),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.route_outlined,
                      color: AppColors.primary,
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _initialize,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            )
          : _busy || route == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Menyiapkan rute demo…'),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppColors.primaryDark,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(
                        near
                            ? Icons.location_on
                            : navigationTurnIcon(step!.type),
                        color: Colors.white,
                        size: 36,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _rerouting
                                  ? 'Menghitung ulang rute…'
                                  : near
                                  ? 'Anda dekat tujuan'
                                  : step!.instruction,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              near
                                  ? _target!.name
                                  : '${navigationDistance(math.max(0, route.distances[step!.beginIndex] - _along))} lagi',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            if (_target?.guidance != true)
                              const Text(
                                'Pratinjau dari depot',
                                style: TextStyle(color: Colors.white70),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_notice != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    color: AppColors.warningBg,
                    child: Text(
                      _notice!,
                      style: const TextStyle(color: AppColors.textBody),
                    ),
                  ),
                Expanded(
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: _position!,
                      initialZoom: 16,
                      onMapReady: () {
                        _mapReady = true;
                        _fitMap();
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
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: route.points,
                            strokeWidth: 6,
                            color: AppColors.primary,
                            borderStrokeWidth: 2,
                            borderColor: Colors.white,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _target!.point,
                            width: 44,
                            height: 44,
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.primaryDark,
                              size: 44,
                            ),
                          ),
                          Marker(
                            point: route.points[step!.beginIndex],
                            width: 26,
                            height: 26,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                          Marker(
                            point: _position!,
                            width: 48,
                            height: 48,
                            child: Transform.rotate(
                              angle: (_heading ?? 0) * math.pi / 180,
                              child: Icon(
                                _target!.guidance
                                    ? (_heading == null
                                          ? Icons.my_location
                                          : Icons.navigation_rounded)
                                    : Icons.warehouse_outlined,
                                color: AppColors.primary,
                                size: 42,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const MapAttribution(),
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: FloatingActionButton.small(
                            heroTag: null,
                            tooltip: _target!.guidance
                                ? 'Ikuti posisi saya'
                                : 'Lihat seluruh rute',
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            elevation: 2,
                            shape: const CircleBorder(),
                            onPressed: () {
                              _following = true;
                              _fitMap();
                            },
                            child: Icon(
                              _target!.guidance
                                  ? Icons.my_location
                                  : Icons.zoom_out_map,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _target!.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${navigationDistance(remaining)} • Estimasi ${math.max(1, (route.durationSeconds * (route.length == 0 ? 0 : remaining / route.length) / 60).ceil())} menit',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Kembali ke detail trip'),
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

String navigationDistance(double meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km'
    : '${meters.round()} m';

IconData navigationTurnIcon(int type) => switch (type) {
  9 || 23 => Icons.turn_slight_right_rounded,
  10 || 18 || 20 => Icons.turn_right_rounded,
  11 => Icons.turn_sharp_right_rounded,
  16 || 24 => Icons.turn_slight_left_rounded,
  15 || 19 || 21 => Icons.turn_left_rounded,
  14 => Icons.turn_sharp_left_rounded,
  12 => Icons.u_turn_right_rounded,
  13 => Icons.u_turn_left_rounded,
  25 || 37 || 38 => Icons.merge_rounded,
  26 || 27 => Icons.roundabout_left_rounded,
  4 || 5 || 6 => Icons.location_on,
  _ => Icons.straight_rounded,
};
