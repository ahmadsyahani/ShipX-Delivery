import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/catalog/product_art.dart';

void main() {
  Widget view({String? photoUrl}) => MaterialApp(
    home: SizedBox(
      width: 100,
      height: 100,
      child: ProductArt(
        category: 'Minuman',
        productName: 'Air mineral',
        photoUrl: photoUrl,
        baseUrl: 'http://127.0.0.1:8000/api/v1',
      ),
    ),
  );

  testWidgets('products without a photo retain category icons', (tester) async {
    await tester.pumpWidget(view());
    expect(find.byIcon(Icons.local_drink_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('relative photo URLs use the connected API host', (tester) async {
    await tester.pumpWidget(view(photoUrl: '/product-photos/test.png'));
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      'http://127.0.0.1:8000/product-photos/test.png',
    );
    expect(image.semanticLabel, 'Foto Air mineral');
    final fallback = image.errorBuilder!(
      tester.element(find.byType(Image)),
      Exception('Connection unavailable'),
      StackTrace.current,
    );
    await tester.pumpWidget(MaterialApp(home: fallback));
    expect(find.byIcon(Icons.local_drink_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported photo URLs use the category icon', (tester) async {
    await tester.pumpWidget(view(photoUrl: 'file:///private/photo.png'));
    expect(find.byIcon(Icons.local_drink_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
