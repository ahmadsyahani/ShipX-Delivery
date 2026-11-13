import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'core/auth_session.dart';
import 'commerce/shopping_state.dart';
import 'catalog/product_art.dart';
import 'catalog/catalog_location_header.dart';
import 'commerce/shop_widgets.dart';

String rupiah(int amount) =>
    'Rp${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')}';

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    super.key,
    required this.session,
    this.shopping,
    this.openCart,
    this.chooseDelivery,
    this.keyboardVisible = false,
    this.initialCollection = 'all',
  });
  final AuthSession session;
  final String initialCollection;
  final ShoppingState? shopping;
  final VoidCallback? openCart, chooseDelivery;
  final bool keyboardVisible;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _search = TextEditingController();
  bool _searchOpen = false;
  String? _storeName;
  final _productScroll = ScrollController();
  final _categoryScroll = ScrollController();
  final _viewportKey = GlobalKey();
  final _sectionKeys = <String, GlobalKey>{};
  final _pillKeys = <String, GlobalKey>{};
  int _jumpGeneration = 0;
  bool _jumping = false;
  bool _trackingScheduled = false;

  final List<Map<String, dynamic>> _products = [];
  List<String> _categories = [];
  String? _category;
  String _collection = 'all';
  final Set<String> _savingFavorites = {};
  String _query = '';
  String? _error;
  bool _loading = true, _more = false;
  bool _retryNext = false;
  int _page = 0, _lastPage = 1, _generation = 0;
  @override
  void initState() {
    super.initState();
    _collection = widget.initialCollection;
    _productScroll.addListener(_queueCategoryTracking);
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
        grouped: _collection != 'frequent',
        collection: _collection,
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
      setState(() {
        _categories = categories;
        _storeName = (result['depot'] as Map?)?['name'] as String?;
        if (!next) {
          _products.clear();
          _category = null;
        }
        _products.addAll(products);
        _page = result['meta']['current_page'] as int;
        _lastPage = result['meta']['last_page'] as int;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _trackCategory();
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
                    child: ProductArt(
                      category: p['category'] as String? ?? 'Barang',
                      photoUrl: p['photo_url'] as String?,
                      productName: p['name'] as String?,
                      baseUrl: widget.session.api.baseUrl,
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
    _jumpGeneration++;
    _jumping = false;
    _query = value.trim();
    _category = null;
    if (_productScroll.hasClients) _productScroll.jumpTo(0);
    _load();
  }

  Future<void> _selectCategory(String? value) async {
    if (_collection == 'frequent') {
      await _selectCollection('all');
      if (!mounted || _collection != 'all') return;
    }
    final jump = ++_jumpGeneration;
    _jumping = true;
    setState(() => _category = value);
    try {
      while (value != null &&
          !_products.any((product) => product['category'] == value) &&
          _page < _lastPage) {
        final previousPage = _page;
        await _load(next: true);
        if (!mounted || jump != _jumpGeneration) return;
        if (_page == previousPage) break;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || jump != _jumpGeneration || !_productScroll.hasClients) {
        return;
      }
      final section = value == null
          ? null
          : _sectionKeys[value]?.currentContext?.findRenderObject()
                as RenderBox?;
      final viewport =
          _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      final offset = section == null || viewport == null
          ? 0.0
          : _productScroll.offset +
                section.localToGlobal(Offset.zero).dy -
                viewport.localToGlobal(Offset.zero).dy;
      await _productScroll.animateTo(
        offset.clamp(0.0, _productScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      if (!mounted || jump != _jumpGeneration) return;
      _revealPill(value);
    } finally {
      if (mounted && jump == _jumpGeneration) {
        _jumping = false;
        _trackCategory();
      }
    }
  }

  void _revealPill(String? category) {
    final context = _pillKeys[category ?? 'all']?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        alignment: .5,
        duration: const Duration(milliseconds: 180),
      );
    }
  }

  void _queueCategoryTracking() {
    if (_trackingScheduled) return;
    _trackingScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackingScheduled = false;
      if (mounted) _trackCategory();
    });
  }

  void _trackCategory() {
    if (!_productScroll.hasClients || _loading || _jumping) return;
    if (_collection == 'frequent') {
      if (_productScroll.position.extentAfter < 180 &&
          _page < _lastPage &&
          !_more &&
          _error == null) {
        _load(next: true);
      }
      return;
    }
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    String? active;
    var closest = double.negativeInfinity;
    for (final entry in _sectionKeys.entries) {
      final section =
          entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (section != null) {
        final position = section.localToGlobal(Offset.zero).dy;
        if (position <= top + 60 && position > closest) {
          active = entry.key;
          closest = position;
        }
      }
    }
    if (_productScroll.offset <= 1) {
      active = null;
    } else if (_productScroll.position.extentAfter <= 1 &&
        _page == _lastPage &&
        _products.isNotEmpty) {
      active = _products.last['category'] as String;
    }
    if (active != _category) {
      setState(() => _category = active);
      _revealPill(active);
    }
    if (_productScroll.position.extentAfter < 180 &&
        _page < _lastPage &&
        !_more &&
        _error == null) {
      _load(next: true);
    }
  }

  Future<void> _selectCollection(String collection) async {
    if (_collection == collection) return;
    _jumpGeneration++;
    _jumping = false;
    _collection = collection;
    _category = null;
    _query = '';
    _search.clear();
    if (_productScroll.hasClients) _productScroll.jumpTo(0);
    await _load();
  }

  Future<void> _toggleFavorite(Map<String, dynamic> product) async {
    final id = product['id'] as String;
    if (_savingFavorites.contains(id)) return;
    final favorite = product['is_favorite'] != true;
    setState(() => _savingFavorites.add(id));
    try {
      await widget.session.commerceRequest(
        'PUT',
        '/catalog/$id/favorite',
        body: {'is_favorite': favorite},
      );
      if (!mounted) return;
      setState(() {
        for (final row in _products) {
          if (row['id'] == id) row['is_favorite'] = favorite;
        }
      });
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Favorit belum dapat disimpan. Coba lagi.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingFavorites.remove(id));
    }
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
    final shopping = widget.shopping;
    final subtotal =
        shopping?.lines.values.fold<int>(
          0,
          (sum, row) =>
              sum +
              (row['product']['unit_price_rp'] as int) *
                  (row['quantity'] as int),
        ) ??
        0;
    return Column(
      children: [
        if (!widget.keyboardVisible)
          CatalogLocationHeader(
            session: widget.session,
            storeName: _storeName,
            address: shopping?.address,
            onChooseAddress: shopping?.locked == true
                ? null
                : widget.chooseDelivery,
          ),
        ColoredBox(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
            child: Row(
              children: [
                IconButton.outlined(
                  key: const ValueKey('catalog-collection-frequent'),
                  tooltip: 'Paling sering dipesan',
                  isSelected: _collection == 'frequent',
                  onPressed: () => _selectCollection('frequent'),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: _collection == 'frequent'
                        ? AppColors.primaryLight
                        : Colors.white,
                    side: BorderSide(
                      color: _collection == 'frequent'
                          ? AppColors.primary
                          : const Color(0xFFBABFBC),
                    ),
                  ),
                  icon: const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFE6BA56),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('catalog-categories'),
                    controller: _categoryScroll,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          key: const ValueKey('catalog-collection-favorites'),
                          label: const Icon(
                            Icons.favorite_border_rounded,
                            size: 18,
                          ),
                          tooltip: 'Barang favorit',
                          selected: _collection == 'favorites',
                          shape: const StadiumBorder(),
                          showCheckmark: false,
                          selectedColor: AppColors.primaryLight,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFBABFBC)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 9,
                          ),
                          onSelected: (_) => _selectCollection(
                            _collection == 'favorites' ? 'all' : 'favorites',
                          ),
                        ),
                        const SizedBox(width: 8),
                        for (final category in <String?>[null, ..._categories])
                          Padding(
                            key: _pillKeys.putIfAbsent(
                              category ?? 'all',
                              () => GlobalKey(),
                            ),
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              key: ValueKey('category-${category ?? 'all'}'),
                              label: Text(category ?? 'Semua'),
                              selected:
                                  _collection != 'frequent' &&
                                  _category == category,
                              shape: const StadiumBorder(),
                              side: BorderSide(
                                color: _category == category
                                    ? AppColors.primary
                                    : const Color(0xFFBABFBC),
                              ),
                              backgroundColor: Colors.white,
                              selectedColor: AppColors.primaryLight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 9,
                              ),
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: _category == category
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _category == category
                                    ? AppColors.primaryDark
                                    : AppColors.textBody,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              elevation: 0,
                              pressElevation: 0,
                              showCheckmark: false,
                              onSelected: _loading || _more
                                  ? null
                                  : (_) => _selectCategory(category),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: _searchOpen ? 'Tutup pencarian' : 'Cari barang',
                  onPressed: () => setState(() => _searchOpen = !_searchOpen),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    side: const BorderSide(color: Color(0xFFBABFBC)),
                    backgroundColor: _query.isEmpty
                        ? Colors.white
                        : AppColors.primaryLight,
                  ),
                  icon: Icon(
                    _searchOpen ? Icons.close : Icons.search,
                    color: AppColors.textMain,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_searchOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: _searchProducts,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: 'Cari kebutuhanmu',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Hapus pencarian',
                  onPressed: () {
                    _search.clear();
                    _searchProducts('');
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
        Expanded(
          key: _viewportKey,
          child: RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView(
              key: const ValueKey('catalog-products'),
              controller: _productScroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _query.isNotEmpty
                            ? 'Hasil pencarian'
                            : _category ??
                                  switch (_collection) {
                                    'favorites' => 'Barang favorit',
                                    'frequent' => 'Paling sering dipesan',
                                    _ => 'Pilihan barang',
                                  },
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Muat ulang',
                      onPressed: _loading ? null : () => _load(),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
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
                    switch (_collection) {
                      'favorites' => 'Belum ada barang favorit',
                      'frequent' => 'Belum ada riwayat pesanan',
                      _ =>
                        _query.isEmpty && _category == null
                            ? 'Katalog sedang disiapkan'
                            : 'Produk tidak ditemukan',
                    },
                    _collection == 'favorites'
                        ? 'Ketuk ikon hati pada barang yang kamu suka.'
                        : 'Coba kategori atau kata pencarian lain.',
                    action: _query.isNotEmpty || _category != null
                        ? () {
                            _search.clear();
                            _searchProducts('');
                          }
                        : null,
                    actionText: 'Lihat semua produk',
                  )
                else
                  LayoutBuilder(
                    builder: (context, box) {
                      final columns =
                          box.maxWidth >= 300 &&
                              MediaQuery.textScalerOf(context).scale(1) <= 1.25
                          ? 2
                          : 1;
                      final width =
                          (box.maxWidth - (columns - 1) * 12) / columns;
                      final groups = <String, List<Map<String, dynamic>>>{};
                      for (final product in _products) {
                        groups
                            .putIfAbsent(
                              _collection == 'frequent'
                                  ? 'Paling sering dipesan'
                                  : product['category'] as String,
                              () => [],
                            )
                            .add(product);
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final group in groups.entries)
                            Padding(
                              key: _sectionKeys.putIfAbsent(
                                group.key,
                                () => GlobalKey(),
                              ),
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_collection != 'frequent')
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Text(
                                        group.key,
                                        key: ValueKey(
                                          'section-heading-${group.key}',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      for (final product in group.value)
                                        SizedBox(
                                          width: width,
                                          child: _productTile(product),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                if (_error != null && _retryNext)
                  TextButton(
                    onPressed: () => _load(next: true),
                    child: const Text('Coba lagi'),
                  ),
                if (_page < _lastPage && !_loading)
                  OutlinedButton(
                    onPressed: _more ? null : () => _load(next: true),
                    child: Text(_more ? 'Memuat...' : 'Muat produk lainnya'),
                  ),
              ],
            ),
          ),
        ),
        if (shopping != null &&
            shopping.count > 0 &&
            widget.openCart != null &&
            !widget.keyboardVisible)
          ShopDock(
            caption: '${shopping.count} item dipilih',
            amount: rupiah(subtotal),
            action: 'Checkout',
            onPressed: widget.openCart,
            buttonKey: const ValueKey('catalog-checkout'),
            compact: true,
            tinted: true,
            icon: Icons.arrow_forward_rounded,
          ),
      ],
    );
  }

  Widget _productTile(Map<String, dynamic> product) {
    final available = (product['available_quantity'] as int? ?? 0) > 0;
    final favorite = product['is_favorite'] == true;
    final name = product['name'] as String;
    final quantity =
        widget.shopping?.lines[product['id']]?['quantity'] as int? ?? 0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _detail(product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: AppColors.primaryLight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ProductArt(
                        category: product['category'],
                        photoUrl: product['photo_url'] as String?,
                        productName: name,
                        baseUrl: widget.session.api.baseUrl,
                        transparent: true,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      tooltip: favorite
                          ? 'Hapus $name dari favorit'
                          : 'Favoritkan $name',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      onPressed: _savingFavorites.contains(product['id'])
                          ? null
                          : () => _toggleFavorite(product),
                      icon: Icon(
                        favorite ? Icons.favorite : Icons.favorite_border,
                        color: favorite ? AppColors.error : AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['category'] as String,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: 40 * MediaQuery.textScalerOf(context).scale(1),
                    ),
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    rupiah(product['unit_price_rp']),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (widget.shopping != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (quantity > 0) ...[
                          IconButton.outlined(
                            tooltip: 'Kurangi $name',
                            onPressed: widget.shopping!.locked
                                ? null
                                : () => widget.shopping!.quantity(
                                    product['id'] as String,
                                    quantity - 1,
                                  ),
                            style: IconButton.styleFrom(
                              fixedSize: const Size(32, 32),
                              minimumSize: const Size(32, 32),
                              padding: const EdgeInsets.all(6),
                            ),
                            icon: const Icon(Icons.remove, size: 18),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 24),
                            child: Text(
                              '$quantity',
                              key: ValueKey(
                                'catalog-quantity-${product['id']}',
                              ),
                              textAlign: TextAlign.center,
                              semanticsLabel:
                                  '$quantity item $name di keranjang',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        IconButton.filled(
                          tooltip: 'Tambah $name',
                          onPressed:
                              available &&
                                  !widget.shopping!.locked &&
                                  quantity < 20
                              ? () => _add(product)
                              : null,
                          style: IconButton.styleFrom(
                            fixedSize: const Size(32, 32),
                            minimumSize: const Size(32, 32),
                            padding: const EdgeInsets.all(6),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
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
