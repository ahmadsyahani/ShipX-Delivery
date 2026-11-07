import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'core/auth_session.dart';
import 'commerce/shopping_state.dart';
import 'catalog/product_art.dart';

String rupiah(int amount) =>
    'Rp${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')}';

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    super.key,
    required this.session,
    this.shopping,
    this.openCart,
  });
  final AuthSession session;
  final ShoppingState? shopping;
  final VoidCallback? openCart;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _search = TextEditingController();
  final _productScroll = ScrollController();
  final _categoryScroll = ScrollController();
  final List<Map<String, dynamic>> _products = [];
  List<String> _categories = [];
  String? _category;
  String _query = '', _depot = 'Depot utama';
  String? _error;
  bool _loading = true, _more = false;
  bool _retryNext = false;
  int _page = 0, _lastPage = 1, _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _productScroll.dispose();
    _categoryScroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool next = false}) async {
    if (next && (_loading || _more)) return;
    final generation = ++_generation;
    setState(() {
      _retryNext = next;
      _error = null;
      if (next) {
        _more = true;
      } else {
        _loading = true;
        _more = false;
      }
    });
    try {
      final result = await widget.session.catalog(
        query: _query,
        category: _category,
        page: next ? _page + 1 : 1,
      );
      if (!mounted || generation != _generation) return;
      final products = (result['data'] as List).cast<Map<String, dynamic>>();
      final categories = result['categories'] is List
          ? (result['categories'] as List).cast<String>()
          : {
              ..._categories,
              ...products.map((p) => p['category'] as String),
            }.toList();
      if (result['categories'] is List &&
          _category != null &&
          !categories.contains(_category)) {
        _category = null;
        await _load();
        return;
      }
      setState(() {
        _categories = categories;
        if (!next) _products.clear();
        _products.addAll(products);
        _page = result['meta']['current_page'] as int;
        _lastPage = result['meta']['last_page'] as int;
        _depot = result['depot']['name'] as String;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'Katalog belum dapat dimuat. Periksa koneksi, lalu coba lagi.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _more = false;
        });
      }
    }
  }

  IconData _iconForCategory(String? category) {
    final cat = (category ?? '').toLowerCase();
    if (cat.contains('minuman') ||
        cat.contains('drink') ||
        cat.contains('air')) {
      return Icons.local_drink_outlined;
    }
    if (cat.contains('makanan') ||
        cat.contains('food') ||
        cat.contains('snack')) {
      return Icons.restaurant_outlined;
    }
    if (cat.contains('sabun') ||
        cat.contains('bersih') ||
        cat.contains('care')) {
      return Icons.sanitizer_outlined;
    }
    return Icons.inventory_2_outlined;
  }

  void _detail(Map<String, dynamic> p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _iconForCategory(p['category'] as String?),
                      size: 32,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLighter,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            p['category'] ?? '',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p['name'],
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textMain,
                                fontSize: 20,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${rupiah(p['unit_price_rp'])} / item',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      (p['available_quantity'] as int? ?? 0) > 0
                          ? 'Stok: ${p['available_quantity']}'
                          : 'Stok habis',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: (p['available_quantity'] as int? ?? 0) > 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              if (p['handling_notes'] != null) ...[
                const SizedBox(height: 16),
                Text(
                  p['handling_notes'],
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.textBody,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Stok diperiksa kembali saat checkout. Bayar tunai saat barang diterima.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              if (widget.shopping != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        (p['available_quantity'] as int? ?? 0) <= 0 ||
                            widget.shopping!.locked
                        ? null
                        : () {
                            final error = widget.shopping!.add(p);
                            if (error != null) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(error)));
                              return;
                            }
                            Navigator.pop(context);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Barang ditambahkan ke keranjang.',
                                ),
                                action: widget.openCart == null
                                    ? null
                                    : SnackBarAction(
                                        label: 'Keranjang',
                                        onPressed: widget.openCart!,
                                      ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(
                      (p['available_quantity'] as int? ?? 0) > 0
                          ? 'Tambah ke keranjang'
                          : 'Stok habis',
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup detail'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _searchProducts(String value) {
    _query = value.trim();
    _category = null;
    if (_productScroll.hasClients) _productScroll.jumpTo(0);
    _load();
  }

  void _selectCategory(String? value) {
    if (_category == value) return;
    _category = value;
    _query = '';
    _search.clear();
    if (_productScroll.hasClients) _productScroll.jumpTo(0);
    _load();
  }

  void _add(Map<String, dynamic> product) {
    final error = widget.shopping!.add(product);
    // The quantity badge and cart bar confirm success without covering the CTA.
    if (error == null) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) => widget.shopping == null
      ? _menu(context)
      : ListenableBuilder(
          listenable: widget.shopping!,
          builder: (context, _) => _menu(context),
        );

  Widget _menu(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _depot,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Bayar COD',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                maxLength: 100,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari produk atau kategori',
                  counterText: '',
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 21),
                  suffixIcon: IconButton(
                    tooltip: 'Cari',
                    onPressed: () => _searchProducts(_search.text),
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                onSubmitted: _searchProducts,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.borderLight),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: compact ? 78 : 88,
                child: ColoredBox(
                  color: const Color(0xFFEEF2F5),
                  child: Scrollbar(
                    controller: _categoryScroll,
                    child: ListView(
                      key: const ValueKey('catalog-categories'),
                      controller: _categoryScroll,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _categoryTab(null, 'Semua', Icons.grid_view_rounded),
                        for (final category in _categories)
                          _categoryTab(
                            category,
                            category,
                            categoryIcon(category),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 6, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _query.isNotEmpty
                                    ? 'Hasil pencarian'
                                    : _category ?? 'Semua produk',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Muat ulang',
                              onPressed: _loading ? null : () => _load(),
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 20,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => _load(),
                          child: ListView(
                            key: const ValueKey('catalog-products'),
                            controller: _productScroll,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                            children: [
                              if (_loading)
                                const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (_error != null && !_retryNext)
                                _message(
                                  Icons.cloud_off_outlined,
                                  'Koneksi belum tersedia',
                                  _error!,
                                  action: () => _load(),
                                  actionText: 'Coba lagi',
                                )
                              else if (_products.isEmpty)
                                _message(
                                  Icons.inventory_2_outlined,
                                  _query.isEmpty && _category == null
                                      ? 'Katalog sedang disiapkan'
                                      : 'Produk tidak ditemukan',
                                  _query.isEmpty && _category == null
                                      ? 'Tarik layar untuk memuat ulang.'
                                      : 'Coba kategori atau kata pencarian lain.',
                                  action: _query.isEmpty && _category == null
                                      ? null
                                      : () {
                                          _search.clear();
                                          _searchProducts('');
                                        },
                                  actionText: 'Lihat semua produk',
                                )
                              else ...[
                                for (final product in _products)
                                  _productTile(product),
                                if (_error != null)
                                  _message(
                                    Icons.wifi_off_rounded,
                                    'Belum dapat memuat lagi',
                                    _error!,
                                    action: () => _load(next: true),
                                    actionText: 'Coba lagi',
                                  )
                                else if (_page < _lastPage)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: OutlinedButton(
                                      onPressed: _more
                                          ? null
                                          : () => _load(next: true),
                                      child: Text(
                                        _more
                                            ? 'Memuat...'
                                            : 'Muat produk lainnya',
                                      ),
                                    ),
                                  ),
                                const Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: Text(
                                    'Harga dan stok diperiksa kembali saat checkout.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.6,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.shopping != null &&
            widget.shopping!.count > 0 &&
            widget.openCart != null)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.openCart,
              icon: const Icon(Icons.shopping_bag_outlined, size: 20),
              label: Text('Lihat keranjang (${widget.shopping!.count} barang)'),
            ),
          ),
      ],
    );
  }

  Widget _categoryTab(String? value, String label, IconData icon) {
    final active = _category == value;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? Colors.white : Colors.transparent,
        child: InkWell(
          key: ValueKey('category-${value ?? 'all'}'),
          onTap: () => _selectCategory(value),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: active ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 23,
                  color: active ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(height: 9),
                Text(
                  label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    color: active ? AppColors.primaryDark : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _productTile(Map<String, dynamic> product) {
    final available = (product['available_quantity'] as int? ?? 0) > 0;
    final quantity =
        widget.shopping?.lines[product['id']]?['quantity'] as int? ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => _detail(product),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 225 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.25;
                final artwork = Stack(
                  children: [
                    SizedBox(
                      width: stacked ? double.infinity : 84,
                      height: stacked ? 120 : 96,
                      child: ProductArt(
                        category: product['category'] as String,
                      ),
                    ),
                    if (quantity > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Semantics(
                          label: '$quantity di keranjang',
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              '$quantity',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
                final info = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'],
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'per item',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (!available)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Stok habis',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Text(
                          rupiah(product['unit_price_rp']),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        if (widget.shopping != null)
                          IconButton.filled(
                            tooltip: 'Tambah ${product['name']}',
                            onPressed: available && !widget.shopping!.locked
                                ? () => _add(product)
                                : null,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(44, 44),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 22),
                          ),
                      ],
                    ),
                  ],
                );
                return stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [artwork, const SizedBox(height: 12), info],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          artwork,
                          const SizedBox(width: 12),
                          Expanded(child: info),
                        ],
                      );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(
    IconData icon,
    String title,
    String body, {
    VoidCallback? action,
    String? actionText,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 2),
    child: Column(
      children: [
        Icon(icon, size: 36, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            height: 1.6,
            color: AppColors.textMuted,
          ),
        ),
        if (action != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: TextButton(onPressed: action, child: Text(actionText!)),
          ),
      ],
    ),
  );
}
