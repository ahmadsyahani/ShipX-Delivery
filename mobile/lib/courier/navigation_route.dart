import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class NavigationStep {
  const NavigationStep({
    required this.type,
    required this.instruction,
    required this.beginIndex,
  });
  final int type, beginIndex;
  final String instruction;
}

class NavigationProgress {
  const NavigationProgress({required this.along, required this.offRoute});
  final double along, offRoute;
}

class NavigationRoute {
  NavigationRoute.fromJson(Map<String, dynamic> json)
    : points = decodeRouteShape(json['shape'] as String),
      targetId = '${json['target_id']}',
      version = '${json['route_version_id']}',
      durationSeconds = (json['duration_seconds'] as num).toDouble() {
    if (points.length < 2 || !durationSeconds.isFinite || durationSeconds < 0) {
      throw const FormatException('Invalid navigation route');
    }
    distances = [0];
    for (var i = 1; i < points.length; i++) {
      distances.add(
        distances.last +
            const Distance().as(LengthUnit.Meter, points[i - 1], points[i]),
      );
    }
    steps = (json['maneuvers'] as List).map((value) {
      final index = value['begin_shape_index'] as int;
      if (index < 0 || index >= points.length) {
        throw const FormatException('Invalid maneuver index');
      }
      return NavigationStep(
        type: value['type'] as int,
        instruction: value['instruction'] as String,
        beginIndex: index,
      );
    }).toList();
    if (steps.isEmpty) throw const FormatException('Missing maneuvers');
  }

  final List<LatLng> points;
  late final List<double> distances;
  late final List<NavigationStep> steps;
  final String targetId, version;
  final double durationSeconds;
  double get length => distances.last;

  NavigationProgress project(
    LatLng position, {
    double minimum = 0,
    double maximum = double.infinity,
  }) {
    var nearest = double.infinity;
    var along = minimum.clamp(0.0, length).toDouble();
    final longitudeScale = 111320 * math.cos(position.latitude * math.pi / 180);
    for (var i = 0; i < points.length - 1; i++) {
      if (distances[i + 1] < minimum || distances[i] > maximum) continue;
      final x = (points[i].longitude - position.longitude) * longitudeScale;
      final y = (points[i].latitude - position.latitude) * 111320;
      final dx =
          (points[i + 1].longitude - points[i].longitude) * longitudeScale;
      final dy = (points[i + 1].latitude - points[i].latitude) * 111320;
      final denominator = dx * dx + dy * dy;
      final ratio = denominator == 0
          ? 0.0
          : (-(x * dx + y * dy) / denominator).clamp(0.0, 1.0);
      final distance = math.sqrt(
        math.pow(x + ratio * dx, 2) + math.pow(y + ratio * dy, 2),
      );
      final candidate =
          distances[i] + (distances[i + 1] - distances[i]) * ratio;
      if (candidate < minimum || candidate > maximum) continue;
      if (distance < nearest) {
        nearest = distance;
        along = candidate;
      }
    }
    return NavigationProgress(along: along, offRoute: nearest);
  }

  NavigationStep nextStep(double along) => steps.firstWhere(
    (step) => distances[step.beginIndex] > along + 8,
    orElse: () => steps.last,
  );
}

List<LatLng> decodeRouteShape(String encoded) {
  var index = 0, latitude = 0, longitude = 0;
  int component() {
    var result = 0, shift = 0;
    while (true) {
      if (index >= encoded.length || shift > 30) {
        throw const FormatException('Invalid route geometry');
      }
      final value = encoded.codeUnitAt(index++) - 63;
      if (value < 0 || value > 63) {
        throw const FormatException('Invalid route geometry');
      }
      result |= (value & 31) << shift;
      shift += 5;
      if (value < 32) break;
    }
    return result.isOdd ? ~(result >> 1) : result >> 1;
  }

  final points = <LatLng>[];
  while (index < encoded.length) {
    latitude += component();
    longitude += component();
    if (latitude.abs() > 90000000 ||
        longitude.abs() > 180000000 ||
        points.length >= 100000) {
      throw const FormatException('Invalid route geometry');
    }
    points.add(LatLng(latitude / 1e6, longitude / 1e6));
  }
  return points;
}
