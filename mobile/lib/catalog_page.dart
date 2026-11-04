import 'package:flutter/material.dart';
import 'core/auth_session.dart';
import 'commerce/shopping_state.dart';

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
  final List<Map<String, dynamic>> _products = [];
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
        page: next ? _page + 1 : 1,
      );
      if (!mounted || generation != _generation) return;
      final products = (result['data'] as List).cast<Map<String, dynamic>>();
      setState(() {
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

  void _detail(Map<String, dynamic> p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: Color(0xFF087E8B),
              ),
              const SizedBox(height: 16),
              Text(
                p['category'],
                style: const TextStyle(color: Color(0xFF087E8B)),
              ),
              Text(p['name'], style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                '${rupiah(p['unit_price_rp'])} / ${p['unit_label']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Divider(height: 32),
              Text('Berat kemasan: ${p['shipping_weight_g']} gram'),
              Text(
                'Ukuran: ${p['length_mm']} × ${p['width_mm']} × ${p['height_mm']} mm',
              ),
              Text('Volume: ${p['shipping_volume_cm3']} cm³'),
              if (p['handling_notes'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(p['handling_notes']),
                ),
              const SizedBox(height: 24),
              const Text(
                'Stok diperiksa kembali saat checkout. Bayar tunai saat barang diterima.',
              ),
              const SizedBox(height: 16),
              if (widget.shopping != null)
                FilledButton.icon(
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
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

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => _load(),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: Color(0xFF087E8B),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _depot,
                style: const TextStyle(color: Color(0xFF657B83)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Kebutuhan Anda,\nsatu tempat.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Temukan barang untuk keseharian Anda.',
          style: TextStyle(color: Color(0xFF657B83)),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _search,
          maxLength: 100,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Cari produk atau kategori',
            counterText: '',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Cari',
              onPressed: () {
                _query = _search.text.trim();
                _load();
              },
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
          onSubmitted: (value) {
            _query = value.trim();
            _load();
          },
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: Text(
                _query.isEmpty ? 'Jelajahi katalog' : 'Hasil pencarian',
                style: Theme.of(context).textTheme.titleLarge,
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
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _message(
            Icons.cloud_off_outlined,
            'Koneksi belum tersedia',
            _error!,
            action: () => _load(next: _retryNext),
            actionText: 'Coba lagi',
          )
        else if (_products.isEmpty)
          _message(
            Icons.inventory_2_outlined,
            _query.isEmpty
                ? 'Katalog sedang disiapkan'
                : 'Produk tidak ditemukan',
            _query.isEmpty
                ? 'Produk akan muncul di sini setelah tersedia. Tarik layar untuk memuat ulang.'
                : 'Coba nama atau kategori yang berbeda.',
            action: _query.isEmpty
                ? null
                : () {
                    _search.clear();
                    _query = '';
                    _load();
                  },
            actionText: 'Lihat semua produk',
          )
        else ...[
          for (final p in _products)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFDFE9ED)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _detail(p),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 66,
                          height: 76,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F4F4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            size: 32,
                            color: Color(0xFF087E8B),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['category'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF657B83),
                                ),
                              ),
                              Text(
                                p['name'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Stok tersedia: ${p['available_quantity'] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF657B83),
                                ),
                              ),
                              Text(
                                rupiah(p['unit_price_rp']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF087E8B),
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                '/ ${p['unit_label']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF657B83),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Color(0xFF657B83),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_page < _lastPage)
            OutlinedButton(
              onPressed: _more ? null : () => _load(next: true),
              child: Text(_more ? 'Memuat...' : 'Muat produk lainnya'),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Harga dan stok diperiksa kembali saat checkout.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF657B83), fontSize: 12),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _message(
    IconData icon,
    String title,
    String body, {
    VoidCallback? action,
    String? actionText,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: [
        Icon(icon, size: 48, color: const Color(0xFF087E8B)),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF657B83)),
        ),
        if (action != null)
          TextButton(onPressed: action, child: Text(actionText!)),
      ],
    ),
  );
}
