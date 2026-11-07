import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../core/auth_session.dart';
import '../catalog_page.dart' show rupiah;
import '../delivery/delivery_page.dart' show slotDate, slotTime;
import 'shopping_state.dart';
import 'order_refresh.dart';
import '../courier/delivery_result_view.dart';

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
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const AppPageIntro(
            title: 'Setiap pesanan, jelas.',
            description:
                'Pantau proses pengiriman dan lihat riwayat belanjamu.',
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            AppPanel(
              child: Column(
                children: [
                  InfoBanner(message: _error!),
                  TextButton(
                    onPressed: () => _load(),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          if (!_busy && _orders.isEmpty && _error == null)
            const AppPanel(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 44,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 18),
                  Text(
                    'Belum ada pesanan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Pesanan yang berhasil dibuat akan tampil di sini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          for (final order in _orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
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
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: StatusBadge(
                            status: order['status'],
                            text: orderStatus(order['status']),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          order['order_number'],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.6,
                          ),
                        ),
                        const Divider(height: 26),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total pesanan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    rupiah(order['total_rp']),
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'COD tunai',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!_busy && _page < _last)
            OutlinedButton(
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
              [
                'pending',
                'confirmed',
                'assigned',
                'out_for_delivery',
              ].contains(_order!['status']))) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (_error != null) ...[
                    InfoBanner(
                      message: _error!,
                      color: AppColors.error,
                      backgroundColor: AppColors.errorBg,
                    ),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Muat ulang'),
                    ),
                  ],
                  if (_order != null) ...[
                    AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusBadge(
                            status: _order!['status'],
                            text: orderStatus(_order!['status']),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _order!['order_number'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            switch (_order!['status']) {
                              'out_for_delivery' =>
                                'Kurir sudah berangkat membawa pesanan Anda. Pembatalan tidak tersedia.',
                              'assigned' =>
                                'Pesanan sudah masuk penugasan trip. Pembatalan perlu ditinjau admin sebelum keberangkatan.',
                              'confirmed' =>
                                'Pesanan diterima admin. Pengantaran sedang disiapkan.',
                              'rejected' =>
                                'Pesanan ditolak admin. Tidak ada pembayaran yang perlu dilakukan.',
                              'delivered' =>
                                'Pesanan sudah diserahkan. Terima kasih telah berbelanja.',
                              'failed' =>
                                'Pesanan belum berhasil diantar. Lihat hasil pengiriman di bawah.',
                              'cancelled' => 'Pesanan telah dibatalkan.',
                              _ => 'Pesanan menunggu konfirmasi admin.',
                            },
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.7,
                              color: AppColors.textBody,
                            ),
                          ),
                          if (_order!['confirmed_at'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                'Dikonfirmasi ${slotDate(_order!['confirmed_at'], _order!['timezone'])} ${slotTime(_order!['confirmed_at'], _order!['timezone'])}.',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
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
                            title: 'Tujuan pengantaran',
                            icon: Icons.location_on_outlined,
                          ),
                          Text(
                            _order!['address']['recipient_name'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _order!['address']['phone'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _order!['address']['address_text'],
                            style: const TextStyle(fontSize: 13, height: 1.6),
                          ),
                          const Divider(height: 28),
                          const AppSectionTitle(
                            title: 'Jadwal pengiriman',
                            icon: Icons.schedule_rounded,
                          ),
                          Text(
                            '${slotDate(_order!['window_start_at'], _order!['timezone'])} ${slotTime(_order!['window_start_at'], _order!['timezone'])}-${slotTime(_order!['window_end_at'], _order!['timezone'])}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.6,
                            ),
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
                            title: 'Rincian pesanan',
                            icon: Icons.receipt_long_outlined,
                          ),
                          for (final item in _order!['items'])
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                '${item['quantity']} item ${item['name']} - ${rupiah(item['line_total_rp'])}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          const Divider(height: 24),
                          AppAmountLine(
                            label: 'Ongkos kirim',
                            value:
                                'Ongkir ${rupiah(_order!['delivery_fee_rp'])}',
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Pembayaran COD',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Total COD ${rupiah(_order!['total_rp'])}',
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          if (_order!['status'] == 'pending')
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Text(
                                'Batas konfirmasi ${slotDate(_order!['pending_expires_at'], _order!['timezone'])} ${slotTime(_order!['pending_expires_at'], _order!['timezone'])}. Stok dilepas jika batas konfirmasi habis.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          if (_order!['status_reason'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: InfoBanner(
                                message:
                                    _order!['status_reason'] ==
                                        'PENDING_EXPIRED'
                                    ? 'Batas konfirmasi habis.'
                                    : _order!['status'] == 'rejected'
                                    ? 'Alasan penolakan: ${_order!['status_reason']}'
                                    : _order!['status_reason'],
                                color: AppColors.error,
                                backgroundColor: AppColors.errorBg,
                              ),
                            ),
                          if ([
                            'pending',
                            'confirmed',
                          ].contains(_order!['status'])) ...[
                            const SizedBox(height: 20),
                            OutlinedButton(
                              onPressed: widget.shopping.locked
                                  ? null
                                  : _cancel,
                              child: const Text('Batalkan pesanan'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_order!['delivery_result'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: DeliveryResultView(
                          session: widget.session,
                          result: _order!['delivery_result'],
                        ),
                      ),
                  ],
                  if (widget.shopping.pending != null) ...[
                    const SizedBox(height: 16),
                    AppPanel(
                      color: AppColors.warningBg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Ada permintaan yang hasilnya belum pasti. Periksa dengan permintaan yang sama.',
                            style: TextStyle(fontSize: 13, height: 1.6),
                          ),
                          const SizedBox(height: 12),
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
                      ),
                    ),
                  ],
                ],
              ),
            ),
    ),
  );
}
