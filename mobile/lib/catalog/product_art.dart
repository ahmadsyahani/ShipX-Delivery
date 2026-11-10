import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/api_config.dart';

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
  ProductKind.food => Icons.restaurant_outlined,
  ProductKind.care => Icons.sanitizer_outlined,
  ProductKind.parcel => Icons.inventory_2_outlined,
};

/// Product photo with a category icon while loading or unavailable.
class ProductArt extends StatelessWidget {
  const ProductArt({
    super.key,
    required this.category,
    this.transparent = false,
    this.photoUrl,
    this.productName,
    this.baseUrl = ApiConfig.baseUrl,
  });

  final String category;
  final bool transparent;
  final String? photoUrl, productName;
  final String baseUrl;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final extent = constraints.biggest.shortestSide;
      final iconSize = extent.isFinite ? (extent * .55).clamp(0.0, 68.0) : 48.0;
      final fallback = Semantics(
        image: true,
        label: 'Ikon kategori $category',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: transparent ? Colors.transparent : AppColors.primaryLighter,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Icon(
              categoryIcon(category),
              size: iconSize,
              color: AppColors.primary,
            ),
          ),
        ),
      );
      final reference = Uri.tryParse(photoUrl ?? '');
      final base = Uri.tryParse(baseUrl);
      if (photoUrl == null ||
          photoUrl!.trim().isEmpty ||
          reference == null ||
          base == null) {
        return fallback;
      }
      final source = base.resolveUri(reference);
      if (!['http', 'https'].contains(source.scheme)) {
        return fallback;
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          source.toString(),
          fit: BoxFit.contain,
          semanticLabel: 'Foto ${productName ?? category}',
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      );
    },
  );
}
