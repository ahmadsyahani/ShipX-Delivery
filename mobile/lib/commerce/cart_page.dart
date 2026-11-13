import 'package:flutter/material.dart';
import '../catalog_page.dart' show rupiah;
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../catalog/product_art.dart';
import '../core/auth_api.dart';
import '../core/auth_session.dart';
import 'shop_widgets.dart';
import 'shopping_state.dart';
import 'orders_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({
    super.key,
    required this.session,
    required this.shopping,
    required this.chooseDelivery,
    required this.browse,
  });
  final AuthSession session;
  final ShoppingState shopping;
  final VoidCallback chooseDelivery, browse;
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  Map<String, dynamic>? _quote;
  String? _fingerprint, _error;
  bool _quoting = false;
  Future<void> _reviewed() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Riwayat sudah diperiksa?'),
        content: const Text(
          'Pastikan pesanan lama sudah ditemukan atau dipastikan tidak dibuat. Menutup permintaan lama akan memungkinkan Anda mulai memesan kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sudah saya periksa'),
          ),
        ],
      ),
    );
    if (yes == true) await widget.shopping.acknowledgeReviewed();
  }

  Future<void> _calculate() async {
    final fingerprint = widget.shopping.fingerprint;
    setState(() {
      _quoting = true;
      _error = null;
      _quote = null;
    });
    try {
      final quote = await widget.session.commerceRequest(
        'POST',
        '/order-quotes',
        body: widget.shopping.payload(),
      );
      if (mounted && fingerprint == widget.shopping.fingerprint) {
        setState(() {
          _quote = quote;
          _fingerprint = fingerprint;
        });
      }
    } on ApiException catch (error) {
      if (error.code == 'SLOT_CLOSED') widget.shopping.chooseSlot(null);
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Total belum dapat dihitung. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _create() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Buat pesanan COD?'),
        content: Text(
          'Total ${rupiah(_quote!['total_rp'])} dibayar tunai saat barang diterima. Pesanan akan menunggu konfirmasi admin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Buat pesanan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_quote == null || _fingerprint != widget.shopping.fingerprint) {
      setState(() {
        _quote = null;
        _error =
            'Isi keranjang atau jadwal berubah. Hitung ulang total sebelum memesan.';
      });
      return;
    }
    await widget.shopping.create(_quote!);
    if (mounted) setState(() => _quote = null);
  }

  void _orders() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          OrdersPage(session: widget.session, shopping: widget.shopping),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.shopping,
    builder: (context, _) {
      final state = widget.shopping;
      final valid = _quote != null && _fingerprint == state.fingerprint;
      final subtotal = state.lines.values.fold<int>(
        0,
        (sum, row) =>
            sum +
            (row['product']['unit_price_rp'] as int) * (row['quantity'] as int),
      );
      final deliveryReady = state.address != null && state.slot != null;
      return Column(
        children: [
          Expanded(
            child: ListView(
              key: const ValueKey('cart-content'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (!state.ready)
                  const Center(child: CircularProgressIndicator()),
                if (state.message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InfoBanner(message: state.message!),
                  ),
                if (state.storageError)
                  TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    onPressed: state.restore,
                    label: const Text('Baca ulang permintaan'),
                  ),
                if (state.pending != null) ...[
                  AppPanel(
                    color: AppColors.warningBg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ShopHeading('Permintaan tertunda'),
                        const Text(
                          'Periksa hasil sebelumnya sebelum memesan lagi. Pemeriksaan mengirim ulang permintaan yang sama.',
                          style: TextStyle(fontSize: 13, height: 1.6),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: state.busy ? null : state.retry,
                          child: Text(
                            state.busy
                                ? 'Memeriksa...'
                                : 'Periksa hasil permintaan',
                          ),
                        ),
                        TextButton(
                          onPressed: _orders,
                          child: const Text('Periksa riwayat pesanan'),
                        ),
                        if (state.needsReview)
                          OutlinedButton(
                            onPressed: state.busy ? null : _reviewed,
                            child: const Text(
                              'Tutup permintaan lama setelah diperiksa',
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (state.lines.isEmpty && state.pending == null) _empty(state),
                if (state.lines.isNotEmpty) ...[
                  DeliverySummary(
                    address: state.address,
                    slot: state.slot,
                    onTap: state.locked ? null : widget.chooseDelivery,
                  ),
                  const SizedBox(height: 14),
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ShopHeading(
                          'Pesanan',
                          action: TextButton(
                            onPressed: state.locked ? null : widget.browse,
                            child: const Text('Tambah'),
                          ),
                        ),
                        for (final line in state.lines.entries) ...[
                          _line(line, state, valid),
                          if (line.key != state.lines.keys.last)
                            const Divider(
                              height: 30,
                              color: AppColors.borderLight,
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppPanel(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.payments_outlined,
                            size: 23,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bayar di tempat',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Siapkan uang tunai saat pesanan diterima.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppPanel(
                    key: const ValueKey('cart-payment-summary'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ShopHeading('Ringkasan pembayaran'),
                        AppAmountLine(
                          label: valid ? 'Subtotal' : 'Perkiraan subtotal',
                          value: rupiah(
                            valid ? _quote!['subtotal_rp'] as int : subtotal,
                          ),
                        ),
                        AppAmountLine(
                          label: 'Ongkir',
                          value: valid
                              ? rupiah(_quote!['delivery_fee_rp'])
                              : 'Dihitung setelah cek total',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: AppColors.border),
                        ),
                        if (valid)
                          CodTotal(
                            key: const ValueKey('cart-cod-total'),
                            amountKey: const ValueKey('cart-cod-amount'),
                            amount: rupiah(_quote!['total_rp']),
                          ),
                        if (!valid)
                          const Text(
                            'Cek total untuk mendapatkan harga dan ongkir terbaru.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: AppColors.textMuted,
                            ),
                          ),
                        if (valid) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Stok dan harga diperiksa kembali saat pesanan dibuat.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.6,
                              color: AppColors.textMuted,
                            ),
                          ),
                          TextButton(
                            onPressed: state.locked || _quoting
                                ? null
                                : _calculate,
                            child: const Text('Perbarui total'),
                          ),
                          if (_quote!['stock_available_now'] != true)
                            const InfoBanner(
                              message:
                                  'Stok salah satu produk tidak cukup. Ubah jumlah atau muat ulang.',
                              color: AppColors.error,
                              backgroundColor: AppColors.errorBg,
                            ),
                        ],
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: InfoBanner(
                              message: _error!,
                              color: AppColors.error,
                              backgroundColor: AppColors.errorBg,
                            ),
                          ),
                        if (state.pending == null) ...[
                          const SizedBox(height: 16),
                          FilledButton(
                            key: const ValueKey('checkout-action'),
                            style: FilledButton.styleFrom(
                              shape: const StadiumBorder(),
                              minimumSize: const Size(48, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                            ),
                            onPressed:
                                state.locked ||
                                    _quoting ||
                                    (valid &&
                                        _quote!['stock_available_now'] != true)
                                ? null
                                : !deliveryReady
                                ? widget.chooseDelivery
                                : valid
                                ? _create
                                : _calculate,
                            child: Text(
                              _quoting
                                  ? 'Menghitung...'
                                  : !deliveryReady
                                  ? 'Atur pengiriman'
                                  : valid
                                  ? 'Pesan sekarang'
                                  : 'Hitung total',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _orders,
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('Lihat pesanan saya'),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _empty(ShoppingState state) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
    child: Column(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: ProductArt(
            category: state.lastOrder == null ? 'Paket' : 'Barang',
            transparent: true,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          state.lastOrder == null
              ? 'Masih kosong, nih.'
              : 'Pesanan sudah dibuat',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          state.lastOrder == null
              ? 'Pilih kebutuhanmu. Kami bantu antarkan.'
              : 'Lihat perkembangan pesanan di riwayat pembelian.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: state.lastOrder == null ? widget.browse : _orders,
          style: FilledButton.styleFrom(shape: const StadiumBorder()),
          child: Text(
            state.lastOrder == null ? 'Mulai belanja' : 'Lihat pesanan',
          ),
        ),
      ],
    ),
  );

  Widget _line(
    MapEntry<String, Map<String, dynamic>> line,
    ShoppingState state,
    bool valid,
  ) {
    var product = line.value['product'] as Map<String, dynamic>;
    if (valid) {
      for (final item in _quote!['items']) {
        if (item['product_id']?.toString() == line.key) {
          product = {...product, ...Map<String, dynamic>.from(item)};
        }
      }
    }
    final quantity = line.value['quantity'] as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 78,
              height: 88,
              child: ProductArt(
                category: product['category'] as String? ?? 'Barang',
                photoUrl: product['photo_url'] as String?,
                productName: product['name'] as String?,
                baseUrl: widget.session.api.baseUrl,
                transparent: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'],
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$quantity item',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    rupiah((product['unit_price_rp'] as int) * quantity),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton(
              tooltip: 'Hapus barang',
              onPressed: state.locked
                  ? null
                  : () => state.quantity(line.key, 0),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
            const Spacer(),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Kurangi',
                    onPressed: state.locked
                        ? null
                        : () => state.quantity(line.key, quantity - 1),
                    icon: const Icon(
                      Icons.remove_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '$quantity',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tambah',
                    onPressed: state.locked || quantity >= 20
                        ? null
                        : () => state.quantity(line.key, quantity + 1),
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
