import 'package:flutter/material.dart';

enum ProductKind { drink, food, care, parcel }

ProductKind productKind(String category) {
  final value = category.toLowerCase();
  if (['minuman', 'drink', 'air', 'kopi', 'susu'].any(value.contains)) {
    return ProductKind.drink;
  }
  if (['makanan', 'food', 'snack', 'roti'].any(value.contains)) {
    return ProductKind.food;
  }
  if (['sabun', 'bersih', 'care', 'deterjen'].any(value.contains)) {
    return ProductKind.care;
  }
  return ProductKind.parcel;
}

IconData categoryIcon(String category) => switch (productKind(category)) {
  ProductKind.drink => Icons.local_drink_outlined,
  ProductKind.food => Icons.bakery_dining_outlined,
  ProductKind.care => Icons.sanitizer_outlined,
  ProductKind.parcel => Icons.inventory_2_outlined,
};

/// Neutral packaging artwork until the catalog supports real product photos.
class ProductArt extends StatelessWidget {
  const ProductArt({super.key, required this.category});
  final String category;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Ilustrasi kemasan kategori $category',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(painter: _PackagingPainter(productKind(category))),
    ),
  );
}

class _PackagingPainter extends CustomPainter {
  _PackagingPainter(this.kind);
  final ProductKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final background = switch (kind) {
      ProductKind.drink => const Color(0xFFEAF5F6),
      ProductKind.food => const Color(0xFFFFF3DD),
      ProductKind.care => const Color(0xFFF3EEF8),
      ProductKind.parcel => const Color(0xFFF3F0E9),
    };
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    canvas.save();
    // A square composition remains undistorted in both compact and wide tiles.
    final scale = size.shortestSide / 128;
    canvas.translate(
      (size.width - 128 * scale) / 2,
      (size.height - 128 * scale) / 2,
    );
    canvas.scale(scale);
    void rounded(Rect rect, Color color, [double radius = 8]) =>
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius)),
          Paint()..color = color,
        );
    canvas.drawOval(
      const Rect.fromLTWH(28, 108, 72, 9),
      Paint()..color = const Color(0x14182E40),
    );
    switch (kind) {
      case ProductKind.drink:
        final bottle = Path()
          ..moveTo(49, 29)
          ..lineTo(79, 29)
          ..lineTo(79, 39)
          ..quadraticBezierTo(91, 47, 91, 59)
          ..lineTo(91, 101)
          ..quadraticBezierTo(91, 111, 81, 111)
          ..lineTo(47, 111)
          ..quadraticBezierTo(37, 111, 37, 101)
          ..lineTo(37, 59)
          ..quadraticBezierTo(37, 47, 49, 39)
          ..close();
        canvas.drawPath(bottle, Paint()..color = const Color(0xFFA2D9DF));
        rounded(
          const Rect.fromLTWH(47, 17, 34, 15),
          const Color(0xFF087E8B),
          4,
        );
        rounded(const Rect.fromLTWH(37, 61, 54, 31), Colors.white, 3);
        rounded(const Rect.fromLTWH(45, 47, 5, 48), const Color(0x55FFFFFF), 3);
        canvas.drawPath(
          Path()
            ..moveTo(64, 67)
            ..quadraticBezierTo(49, 82, 64, 85)
            ..quadraticBezierTo(79, 82, 64, 67),
          Paint()..color = const Color(0xFF087E8B),
        );
      case ProductKind.food:
        final bag = Path()
          ..moveTo(38, 30)
          ..lineTo(90, 30)
          ..lineTo(97, 109)
          ..lineTo(31, 109)
          ..close();
        canvas.drawPath(bag, Paint()..color = const Color(0xFFE9BB73));
        rounded(
          const Rect.fromLTWH(37, 23, 54, 12),
          const Color(0xFFC88E43),
          3,
        );
        rounded(
          const Rect.fromLTWH(43, 58, 42, 33),
          const Color(0xFFFFFBF1),
          4,
        );
        canvas.drawOval(
          const Rect.fromLTWH(50, 68, 28, 14),
          Paint()..color = const Color(0xFFC88E43),
        );
        canvas.drawLine(
          const Offset(57, 69),
          const Offset(54, 77),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2,
        );
        canvas.drawLine(
          const Offset(67, 69),
          const Offset(64, 77),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2,
        );
      case ProductKind.care:
        rounded(
          const Rect.fromLTWH(38, 44, 54, 67),
          const Color(0xFFB3A0CB),
          13,
        );
        rounded(
          const Rect.fromLTWH(55, 30, 20, 18),
          const Color(0xFF827096),
          3,
        );
        rounded(
          const Rect.fromLTWH(54, 20, 37, 10),
          const Color(0xFF827096),
          3,
        );
        rounded(
          const Rect.fromLTWH(43, 68, 44, 28),
          const Color(0xFFFCF9FF),
          4,
        );
        rounded(const Rect.fromLTWH(60, 73, 8, 18), const Color(0xFFB3A0CB), 2);
        rounded(const Rect.fromLTWH(55, 78, 18, 8), const Color(0xFFB3A0CB), 2);
      case ProductKind.parcel:
        rounded(
          const Rect.fromLTWH(25, 45, 78, 64),
          const Color(0xFFCCA36C),
          5,
        );
        final top = Path()
          ..moveTo(25, 45)
          ..lineTo(45, 25)
          ..lineTo(91, 25)
          ..lineTo(103, 45)
          ..close();
        canvas.drawPath(top, Paint()..color = const Color(0xFFE6C69B));
        rounded(
          const Rect.fromLTWH(57, 45, 16, 64),
          const Color(0xFFEAD3B3),
          0,
        );
        rounded(
          const Rect.fromLTWH(33, 67, 20, 22),
          const Color(0xFFFAF6EF),
          3,
        );
        canvas.drawLine(
          const Offset(37, 74),
          const Offset(48, 74),
          Paint()
            ..color = const Color(0xFFCCA36C)
            ..strokeWidth = 2,
        );
        canvas.drawLine(
          const Offset(37, 80),
          const Offset(45, 80),
          Paint()
            ..color = const Color(0xFFCCA36C)
            ..strokeWidth = 2,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PackagingPainter oldDelegate) => oldDelegate.kind != kind;
}
