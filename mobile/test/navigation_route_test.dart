import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shipx/courier/navigation_route.dart';

Map<String, dynamic> routeJson() => {
  'shape': '???o}@o}@?',
  'target_id': '2',
  'route_version_id': '7',
  'duration_seconds': 120,
  'maneuvers': [
    {'type': 1, 'instruction': 'Lanjutkan', 'begin_shape_index': 0},
    {'type': 15, 'instruction': 'Belok kiri', 'begin_shape_index': 1},
    {'type': 4, 'instruction': 'Tiba di tujuan', 'begin_shape_index': 2},
  ],
};

void main() {
  test('Valhalla geometry uses six decimal places and projects progress', () {
    final route = NavigationRoute.fromJson(routeJson());
    expect(route.points, [
      const LatLng(0, 0),
      const LatLng(0, .001),
      const LatLng(.001, .001),
    ]);
    final progress = route.project(const LatLng(0, .0005));
    expect(progress.along, closeTo(55.6, 1));
    expect(progress.offRoute, closeTo(0, .1));
    expect(route.nextStep(progress.along).instruction, 'Belok kiri');
    expect(route.nextStep(170).instruction, 'Tiba di tujuan');
  });

  test('off-route distance and search limits prevent jumping far ahead', () {
    final route = NavigationRoute.fromJson(routeJson());
    expect(route.project(const LatLng(.001, 0)).offRoute, greaterThan(100));
    final limited = route.project(const LatLng(.001, .001), maximum: 100);
    expect(limited.along, lessThanOrEqualTo(100));
    expect(limited.offRoute, greaterThan(50));
  });

  test('malformed shapes and out-of-range maneuvers are rejected', () {
    expect(() => decodeRouteShape('o}'), throwsFormatException);
    expect(
      () => NavigationRoute.fromJson(
        routeJson()
          ..['maneuvers'] = [
            {'type': 4, 'instruction': 'Invalid', 'begin_shape_index': 500},
          ],
      ),
      throwsFormatException,
    );
  });
}
