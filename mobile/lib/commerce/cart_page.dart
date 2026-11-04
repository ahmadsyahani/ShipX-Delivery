import 'package:flutter/material.dart';
import '../catalog_page.dart' show rupiah;
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
        padding: const EdgeInsets.all(22),
        children: [
          Text('Keranjang', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          if (!state.ready) const Center(child: CircularProgressIndicator()),
          if (state.message != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              color: const Color(0xFFE7F4F4),
              child: Text(state.message!),
            ),
          if (state.storageError)
            TextButton(
              onPressed: state.restore,
              child: const Text('Baca ulang permintaan'),
            ),
          if (state.pending != null) ...[
            const Text(
              'Jangan membuat permintaan baru sampai hasil sebelumnya dipastikan. Tombol berikut mengirim ulang permintaan yang sama.',
            ),
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
                child: const Text('Tutup permintaan lama setelah diperiksa'),
              ),
          ],
          if (state.lines.isEmpty && state.pending == null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Keranjang kosong. Pilih barang dari katalog untuk mulai memesan.',
              ),
            ),
            OutlinedButton(
              onPressed: widget.browse,
              child: const Text('Buka katalog'),
            ),
          ],
          for (final line in state.lines.entries)
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.value['product']['name'],
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${rupiah(line.value['product']['unit_price_rp'])} / ${line.value['product']['unit_label']}',
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Kurangi',
                          onPressed: state.locked
                              ? null
                              : () => state.quantity(
                                  line.key,
                                  line.value['quantity'] - 1,
                                ),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('${line.value['quantity']}'),
                        IconButton(
                          tooltip: 'Tambah',
                          onPressed:
                              state.locked || line.value['quantity'] >= 20
                              ? null
                              : () => state.quantity(
                                  line.key,
                                  line.value['quantity'] + 1,
                                ),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Hapus barang',
                          onPressed: state.locked
                              ? null
                              : () => state.quantity(line.key, 0),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (state.lines.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Tujuan & jadwal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              state.address == null
                  ? 'Alamat belum dipilih.'
                  : '${state.address!['label']} · ${state.address!['address_text']}',
            ),
            Text(
              state.slot == null
                  ? 'Jadwal belum dipilih.'
                  : '${slotDate(state.slot!['window_start_at'], state.slot!['timezone'])} ${slotTime(state.slot!['window_start_at'], state.slot!['timezone'])}–${slotTime(state.slot!['window_end_at'], state.slot!['timezone'])}',
            ),
            TextButton(
              onPressed: state.locked ? null : widget.chooseDelivery,
              child: const Text('Pilih alamat dan jadwal'),
            ),
            OutlinedButton(
              onPressed:
                  state.locked ||
                      _quoting ||
                      state.address == null ||
                      state.slot == null
                  ? null
                  : _calculate,
              child: Text(_quoting ? 'Menghitung...' : 'Hitung total terbaru'),
            ),
          ],
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (valid) ...[
            const Divider(height: 30),
            Text(
              'Ringkasan dari server',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final item in _quote!['items'])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '${item['quantity']} × ${item['name']}: ${rupiah(item['line_total_rp'])}',
                ),
              ),
            Text('Subtotal ${rupiah(_quote!['subtotal_rp'])}'),
            Text('Ongkir ${rupiah(_quote!['delivery_fee_rp'])}'),
            Text(
              'Total COD ${rupiah(_quote!['total_rp'])}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${_quote!['total_weight_g']} gram · ${_quote!['total_volume_cm3']} cm³',
            ),
            if (_quote!['stock_available_now'] != true)
              const Text(
                'Stok salah satu produk tidak cukup. Ubah jumlah atau muat ulang.',
                style: TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: state.locked || _quote!['stock_available_now'] != true
                  ? null
                  : _create,
              child: const Text('Lanjut buat pesanan COD'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Perhitungan ini belum mereservasi stok. Harga dan ketersediaan diperiksa lagi saat pesanan dibuat.',
            ),
          ],
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _orders,
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Lihat pesanan saya'),
          ),
        ],
      );
    },
  );
}
