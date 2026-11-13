import 'package:latlong2/latlong.dart';

LatLng? tripPoint(Map<dynamic, dynamic>? address) {
  final latitude = num.tryParse('${address?['latitude']}');
  final longitude = num.tryParse('${address?['longitude']}');
  if (latitude == null ||
      longitude == null ||
      !latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180) {
    return null;
  }
  return LatLng(latitude.toDouble(), longitude.toDouble());
}

class TripNavigationTarget {
  const TripNavigationTarget({
    required this.id,
    required this.name,
    required this.address,
    required this.point,
    required this.mode,
    required this.guidance,
  });
  final String id, name, address, mode;
  final LatLng point;
  final bool guidance;

  static TripNavigationTarget? fromTrip(Map<String, dynamic> trip) {
    final status = trip['status'];
    if (![
      'assigned',
      'in_progress',
      'awaiting_reconciliation',
    ].contains(status)) {
      return null;
    }
    final mode = (trip['vehicle'] as Map?)?['travel_mode'];
    if (!['motorcycle', 'car'].contains(mode)) return null;
    final returning = status == 'awaiting_reconciliation';
    final stops = (trip['stops'] as List? ?? []).cast<Map<String, dynamic>>();
    final next = stops
        .where((stop) => !['delivered', 'failed'].contains(stop['status']))
        .firstOrNull;
    final address = returning
        ? trip['depot'] as Map?
        : next?['address'] as Map?;
    final point = tripPoint(address);
    if (point == null) return null;
    return TripNavigationTarget(
      id: returning ? 'depot' : '${next?['order_id'] ?? next?['sequence_no']}',
      name: '${returning ? (address?['name']) : (address?['recipient_name'])}',
      address: '${address?['address_text'] ?? ''}',
      point: point,
      mode: mode as String,
      guidance: status != 'assigned',
    );
  }
}
