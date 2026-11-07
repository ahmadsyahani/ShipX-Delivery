import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shipx/core/device_location.dart';
import 'package:shipx/delivery/address_form.dart';
import 'delivery_test.dart' show DeliverySession, depot;

class LocationPlatform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  int requests = 0, reads = 0;
  LocationSettings? settings;
  double latitude = -7.25, longitude = 112.75;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    reads++;
    settings = locationSettings;
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.utc(2026, 11, 7),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  late GeolocatorPlatform original;
  late LocationPlatform platform;
  setUp(() {
    original = GeolocatorPlatform.instance;
    platform = LocationPlatform();
    GeolocatorPlatform.instance = platform;
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  test(
    'one foreground location fix requests permission only when needed',
    () async {
      final point = await const DeviceLocation().locate();
      expect(point.latitude, -7.25);
      expect(point.longitude, 112.75);
      expect(platform.requests, 1);
      expect(platform.reads, 1);
      expect(platform.settings?.timeLimit, const Duration(seconds: 20));
      platform.permission = LocationPermission.whileInUse;
      await const DeviceLocation().locate();
      expect(platform.requests, 1);
    },
  );

  test(
    'disabled GPS and denied permissions do not attempt to read location',
    () async {
      platform.enabled = false;
      await expectLater(
        const DeviceLocation().locate(),
        throwsA(isA<LocationFailure>()),
      );
      expect(platform.requests, 0);
      expect(platform.reads, 0);
      platform.enabled = true;
      platform.requestedPermission = LocationPermission.denied;
      await expectLater(
        const DeviceLocation().locate(),
        throwsA(isA<LocationFailure>()),
      );
      expect(platform.reads, 0);
      platform.permission = LocationPermission.deniedForever;
      await expectLater(
        const DeviceLocation().locate(),
        throwsA(isA<LocationFailure>()),
      );
      expect(platform.requests, 1);
      expect(platform.reads, 0);
    },
  );

  test('invalid device coordinates are rejected', () async {
    platform.latitude = 100;
    await expectLater(
      const DeviceLocation().locate(),
      throwsA(isA<LocationFailure>()),
    );
  });

  testWidgets(
    'address form never requests GPS automatically and keeps map fallback on denial',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AddressFormPage(session: DeliverySession(), depot: depot()),
        ),
      );
      await tester.pumpAndSettle();
      expect(platform.reads, 0);
      expect(platform.requests, 0);
      expect(find.text('Latitude'), findsNothing);
      expect(find.text('Longitude'), findsNothing);
      platform.permission = LocationPermission.deniedForever;
      await tester.ensureVisible(find.text('Gunakan lokasi saya'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gunakan lokasi saya'));
      await tester.pumpAndSettle();
      expect(platform.reads, 0);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Pilih pin di peta'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.ensureVisible(
        find.text(
          'Izin lokasi belum diberikan. Izinkan melalui pengaturan perangkat atau pilih pin di peta.',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a completed address still requires a confirmed map point', (
    tester,
  ) async {
    final session = DeliverySession();
    await tester.pumpWidget(
      MaterialApp(
        home: AddressFormPage(session: session, depot: depot()),
      ),
    );
    await tester.pumpAndSettle();
    for (final entry in {
      'label': 'Rumah',
      'recipient_name': 'Penerima',
      'phone': '08123456789',
      'address_text': 'Jalan pengantaran',
    }.entries) {
      final field = find.byKey(ValueKey(entry.key));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    await tester.ensureVisible(find.text('Simpan alamat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan alamat'));
    await tester.pumpAndSettle();
    expect(session.saved, isNull);
    expect(
      find.text('Pilih titik pengantaran di peta terlebih dahulu.'),
      findsOneWidget,
    );
    expect(platform.reads, 0);
  });
}
