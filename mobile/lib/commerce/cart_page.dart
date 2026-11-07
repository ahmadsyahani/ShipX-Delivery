import 'package:flutter/material.dart';
import '../catalog_page.dart' show rupiah;
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../catalog/product_art.dart';
import '../core/auth_api.dart';
import '../core/auth_session.dart';
import '../delivery/delivery_page.dart' show slotTime, slotDate;
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
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const AppPageIntro(
            title: 'Keranjang kamu',
            description: 'Periksa pilihanmu sebelum membuat pesanan.',
          ),
          if (!state.ready) const Center(child: CircularProgressIndicator()),
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
                  const AppSectionTitle(
                    title: 'Permintaan tertunda',
                    icon: Icons.hourglass_top_rounded,
                  ),
                  const Text(
                    'Periksa hasil sebelumnya sebelum memesan lagi. Pemeriksaan mengirim ulang permintaan yang sama.',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: state.busy ? null : state.retry,
                    child: Text(
                      state.busy ? 'Memeriksa...' : 'Periksa hasil permintaan',
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
          if (state.lines.isEmpty && state.pending == null)
            AppPanel(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 52,
                      color: AppColors.primary,
                    ),
                  ),
                  const Text(
                    'Belum ada barang pilihan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pilih barang dari katalog, lalu atur pengirimannya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: widget.browse,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Buka katalog'),
                  ),
                ],
              ),
            ),
          if (state.lines.isNotEmpty) ...[
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSectionTitle(
                    title: 'Pilihanmu',
                    subtitle: '${state.count} barang di keranjang',
                    icon: Icons.shopping_bag_outlined,
                  ),
                  for (final line in state.lines.entries) ...[
                    _line(line, state),
                    if (line.key != state.lines.keys.last)
                      const Divider(height: 28),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: state.locked ? null : widget.browse,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Tambah barang lain'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSectionTitle(
                    title: 'Pengiriman',
                    subtitle: 'Tujuan dan jadwal pesanan',
                    icon: Icons.local_shipping_outlined,
                  ),
                  Text(
                    state.address == null
                        ? 'Alamat belum dipilih.'
                        : '${state.address!['label']} - ${state.address!['address_text']}',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.slot == null
                        ? 'Jadwal belum dipilih.'
                        : '${slotDate(state.slot!['window_start_at'], state.slot!['timezone'])} ${slotTime(state.slot!['window_start_at'], state.slot!['timezone'])}-${slotTime(state.slot!['window_end_at'], state.slot!['timezone'])}',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: state.locked ? null : widget.chooseDelivery,
                    child: const Text('Pilih alamat dan jadwal'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSectionTitle(
                    title: 'Pembayaran',
                    subtitle: 'COD tunai saat pesanan diterima',
                    icon: Icons.payments_outlined,
                  ),
                  if (!valid)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Hitung total untuk melihat harga barang dan ongkir terbaru.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InfoBanner(
                        message: _error!,
                        color: AppColors.error,
                        backgroundColor: AppColors.errorBg,
                      ),
                    ),
                  OutlinedButton(
                    onPressed:
                        state.locked ||
                            _quoting ||
                            state.address == null ||
                            state.slot == null
                        ? null
                        : _calculate,
                    child: Text(
                      _quoting ? 'Menghitung...' : 'Hitung total terbaru',
                    ),
                  ),
                  if (valid) ...[
                    const SizedBox(height: 18),
                    for (final item in _quote!['items'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${item['quantity']} x ${item['name']}: ${rupiah(item['line_total_rp'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: AppColors.textBody,
                          ),
                        ),
                      ),
                    const Divider(height: 24),
                    AppAmountLine(
                      label: 'Subtotal',
                      value: rupiah(_quote!['subtotal_rp']),
                    ),
                    AppAmountLine(
                      label: 'Ongkir',
                      value: rupiah(_quote!['delivery_fee_rp']),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total COD ${rupiah(_quote!['total_rp'])}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_quote!['stock_available_now'] != true)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: InfoBanner(
                          message:
                              'Stok salah satu produk tidak cukup. Ubah jumlah atau muat ulang.',
                          color: AppColors.error,
                          backgroundColor: AppColors.errorBg,
                        ),
                      ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed:
                          state.locked || _quote!['stock_available_now'] != true
                          ? null
                          : _create,
                      child: const Text('Lanjut buat pesanan COD'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Harga dan ketersediaan diperiksa lagi saat pesanan dibuat. Perhitungan ini belum menahan stok.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _orders,
            icon: const Icon(Icons.receipt_long_outlined, size: 20),
            label: const Text('Lihat pesanan saya'),
          ),
        ],
      );
    },
  );

  Widget _line(
    MapEntry<String, Map<String, dynamic>> line,
    ShoppingState state,
  ) {
    final product = line.value['product'] as Map<String, dynamic>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 60,
              height: 72,
              child: ProductArt(
                category: product['category'] as String? ?? 'Barang',
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
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${rupiah(product['unit_price_rp'])} / item',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Kurangi',
                    onPressed: state.locked
                        ? null
                        : () => state.quantity(
                            line.key,
                            line.value['quantity'] - 1,
                          ),
                    icon: const Icon(Icons.remove_rounded, size: 18),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${line.value['quantity']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tambah',
                    onPressed: state.locked || line.value['quantity'] >= 20
                        ? null
                        : () => state.quantity(
                            line.key,
                            line.value['quantity'] + 1,
                          ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Hapus barang',
              onPressed: state.locked
                  ? null
                  : () => state.quantity(line.key, 0),
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: 20,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
