import 'package:flutter/material.dart';
import '../core/auth_session.dart';
import '../catalog_page.dart' show rupiah;
import '../delivery/delivery_page.dart' show slotDate, slotTime;
import 'shopping_state.dart';
import 'order_refresh.dart';

String orderStatus(String value) => switch (value) {
  'pending' => 'Menunggu konfirmasi',
  'confirmed' => 'Dikonfirmasi',
  'rejected' => 'Ditolak',
  'cancelled' => 'Dibatalkan',
  'assigned' => 'Ditugaskan',
  'out_for_delivery' => 'Dalam pengantaran',
  'delivered' => 'Terkirim',
  'failed' => 'Gagal diantar',
  _ => value,
};

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.session, required this.shopping});
  final AuthSession session;
  final ShoppingState shopping;
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with OrderRefresh<OrdersPage> {
  final List<Map<String, dynamic>> _orders = [];
  bool _busy = true, _more = false;
  String? _error;
  int _page = 0, _last = 1;
  bool _fetching = false;
  @override
  void initState() {
    super.initState();
    _load();
    startOrderRefresh(() async {
      if (_page <= 1 &&
          !widget.shopping.busy &&
          widget.shopping.pending == null) {
        await _load(background: true);
      }
    });
  }

  Future<void> _load({bool next = false, bool background = false}) async {
    if (_fetching) return;
    _fetching = true;
    setState(() {
      _error = null;
      if (next) {
        _more = true;
      } else if (!background) {
        _busy = true;
      }
    });
    try {
      final r = await widget.session.commerceRequest(
        'GET',
        '/orders?page=${next ? _page + 1 : 1}',
        envelope: true,
      );
      if (!mounted) return;
      setState(() {
        if (!next) _orders.clear();
        _orders.addAll((r['data'] as List).cast<Map<String, dynamic>>());
        _page = r['meta']['current_page'];
        _last = r['meta']['last_page'];
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Pesanan belum dapat dimuat. Periksa koneksi dan coba lagi.',
        );
      }
    } finally {
      _fetching = false;
      if (mounted) {
        setState(() {
          _busy = false;
          _more = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pesanan saya'),
      actions: [
        IconButton(
          tooltip: 'Perbarui status',
          onPressed: _fetching ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        children: [
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: () => _load(),
              child: const Text('Coba lagi'),
            ),
          ],
          if (!_busy && _orders.isEmpty && _error == null)
            const Text(
              'Belum ada pesanan. Pesanan yang berhasil dibuat akan tampil di sini.',
            ),
          if (!_busy)
            for (final order in _orders)
              Card(
                color: Colors.white,
                child: ListTile(
                  title: Text(order['order_number']),
                  subtitle: Text(
                    '${orderStatus(order['status'])}\n${rupiah(order['total_rp'])} · COD tunai',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailPage(
                          session: widget.session,
                          shopping: widget.shopping,
                          id: order['id'],
                        ),
                      ),
                    );
                    if (mounted) _load();
                  },
                ),
              ),
          if (!_busy && _page < _last)
            TextButton(
              onPressed: _more ? null : () => _load(next: true),
              child: Text(_more ? 'Memuat...' : 'Muat pesanan lainnya'),
            ),
        ],
      ),
    ),
  );
}

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    super.key,
    required this.session,
    required this.shopping,
    required this.id,
  });
  final AuthSession session;
  final ShoppingState shopping;
  final String id;
  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage>
    with OrderRefresh<OrderDetailPage> {
  Map<String, dynamic>? _order;
  String? _error;
  bool _busy = true;
  bool _fetching = false;
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
    startOrderRefresh(() async {
      if (!widget.shopping.busy &&
          widget.shopping.pending == null &&
          (_order == null ||
              ['pending', 'confirmed'].contains(_order!['status']))) {
        await _load(background: true);
      }
    });
  }

  Future<void> _load({bool background = false}) async {
    if (_fetching) return;
    _fetching = true;
    setState(() {
      if (!background) _busy = true;
      _error = null;
    });
    try {
      final data = await widget.session.commerceRequest(
        'GET',
        '/orders/${widget.id}',
      );
      if (mounted) setState(() => _order = data);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Detail pesanan belum dapat dimuat. Coba lagi.',
        );
      }
    } finally {
      _fetching = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final controller = _reason..clear();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: TextField(
          controller: controller,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Alasan pembatalan'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(c, controller.text.trim());
              }
            },
            child: const Text('Batalkan pesanan'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    final result = await widget.shopping.cancel(_order!, reason);
    if (!mounted) return;
    if (result != null) {
      setState(() => _order = result);
    } else {
      setState(
        () => _error =
            widget.shopping.message ?? 'Periksa permintaan pada keranjang.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.shopping,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Detail pesanan'),
        actions: [
          IconButton(
            tooltip: 'Perbarui status',
            onPressed: _fetching ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(22),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Muat ulang'),
                    ),
                  ],
                  if (_order != null) ...[
                    Text(
                      _order!['order_number'],
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(orderStatus(_order!['status'])),
                    if (_order!['status'] == 'confirmed')
                      const Text(
                        'Pesanan diterima admin. Pengantaran sedang disiapkan.',
                      ),
                    if (_order!['confirmed_at'] != null)
                      Text(
                        'Dikonfirmasi ${slotDate(_order!['confirmed_at'], _order!['timezone'])} ${slotTime(_order!['confirmed_at'], _order!['timezone'])}.',
                      ),
                    if (_order!['status'] == 'rejected')
                      const Text(
                        'Pesanan ditolak admin. Tidak ada pembayaran yang perlu dilakukan.',
                      ),
                    const SizedBox(height: 16),
                    Text(
                      '${_order!['address']['recipient_name']} · ${_order!['address']['phone']}',
                    ),
                    Text(_order!['address']['address_text']),
                    Text(
                      '${slotDate(_order!['window_start_at'], _order!['timezone'])} ${slotTime(_order!['window_start_at'], _order!['timezone'])}–${slotTime(_order!['window_end_at'], _order!['timezone'])}',
                    ),
                    const Divider(height: 32),
                    for (final item in _order!['items'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${item['quantity']} ${item['unit_label']} ${item['name']} · ${rupiah(item['line_total_rp'])}',
                        ),
                      ),
                    Text('Ongkir ${rupiah(_order!['delivery_fee_rp'])}'),
                    Text(
                      'Total COD ${rupiah(_order!['total_rp'])}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_order!['status'] == 'pending')
                      Text(
                        'Batas konfirmasi ${slotDate(_order!['pending_expires_at'], _order!['timezone'])} ${slotTime(_order!['pending_expires_at'], _order!['timezone'])}. Stok dilepas jika batas konfirmasi habis.',
                      ),
                    if (_order!['status_reason'] != null)
                      Text(
                        _order!['status_reason'] == 'PENDING_EXPIRED'
                            ? 'Batas konfirmasi habis.'
                            : _order!['status'] == 'rejected'
                            ? 'Alasan penolakan: ${_order!['status_reason']}'
                            : _order!['status_reason'],
                      ),
                    const SizedBox(height: 24),
                    if (['pending', 'confirmed'].contains(_order!['status']))
                      OutlinedButton(
                        onPressed: widget.shopping.locked ? null : _cancel,
                        child: const Text('Batalkan pesanan'),
                      ),
                  ],
                  if (widget.shopping.pending != null) ...[
                    const Text(
                      'Ada permintaan yang hasilnya belum pasti. Periksa dengan permintaan yang sama.',
                    ),
                    FilledButton(
                      onPressed: widget.shopping.busy
                          ? null
                          : () async {
                              await widget.shopping.retry();
                              if (mounted) await _load();
                            },
                      child: const Text('Periksa hasil permintaan'),
                    ),
                  ],
                ],
              ),
            ),
    ),
  );
}
