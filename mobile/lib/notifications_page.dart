import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'core/auth_session.dart';
import 'core/auth_api.dart';
import 'commerce/order_refresh.dart';

typedef NotificationTarget = Future<void> Function(String kind, String id);

class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    required this.session,
    required this.openTarget,
    this.color,
  });
  final AuthSession session;
  final NotificationTarget openTarget;
  final Color? color;
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with OrderRefresh<NotificationBell> {
  int _unread = 0;
  bool _busy = false;
  String? _latest;
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    _load();
    startOrderRefresh(_load);
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsPage(
          session: widget.session,
          openTarget: widget.openTarget,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    _busy = true;
    try {
      final response = await widget.session.commerceRequest(
        'GET',
        '/notifications',
        envelope: true,
      );
      if (!mounted) return;
      final rows = (response['data']['data'] as List)
          .cast<Map<String, dynamic>>();
      final latest = rows.firstOrNull;
      if (_loaded &&
          latest != null &&
          latest['id'] != _latest &&
          latest['read_at'] == null &&
          ModalRoute.of(context)?.isCurrent == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${latest['data']['message']}'),
            action: SnackBarAction(label: 'Lihat', onPressed: _open),
          ),
        );
      }
      setState(() {
        _unread = (response['unread_count'] as num).toInt();
        _latest = latest?['id'];
        _loaded = true;
      });
    } catch (_) {
      // The inbox keeps its last badge until connectivity recovers.
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Notifikasi',
    onPressed: _open,
    icon: Badge(
      isLabelVisible: _unread > 0,
      label: Text(_unread > 99 ? '99+' : '$_unread'),
      child: Icon(Icons.notifications_outlined, color: widget.color),
    ),
  );
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.session,
    required this.openTarget,
  });
  final AuthSession session;
  final NotificationTarget openTarget;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with OrderRefresh<NotificationsPage> {
  final List<Map<String, dynamic>> _items = [];
  int _page = 1, _lastPage = 1;
  bool _busy = false, _marking = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
    startOrderRefresh(() => _load());
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await widget.session.commerceRequest(
        'GET',
        '/notifications?page=${more ? _page + 1 : 1}',
        envelope: true,
      );
      if (!mounted) return;
      final data = result['data'];
      setState(() {
        if (!more) _items.clear();
        _items.addAll((data['data'] as List).cast<Map<String, dynamic>>());
        _page = data['current_page'];
        _lastPage = data['last_page'];
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          if (error is ApiException && [401, 403].contains(error.status)) {
            _items.clear();
            _page = _lastPage = 1;
          }
          _error =
              'Notifikasi belum dapat dimuat. Periksa koneksi dan coba lagi.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _read(Map<String, dynamic> item) async {
    if (_marking) return;
    _marking = true;
    try {
      await widget.session.commerceRequest(
        'PUT',
        '/notifications/${item['id']}/read',
        body: {},
      );
      if (!mounted) return;
      final data = item['data'];
      if (['order', 'trip'].contains(data['kind'])) {
        await widget.openTarget('${data['kind']}', '${data['target_id']}');
      }
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Notifikasi belum dapat dibuka. Coba lagi.');
      }
    } finally {
      _marking = false;
    }
  }

  Future<void> _readAll() async {
    if (_marking) return;
    setState(() => _marking = true);
    try {
      await widget.session.commerceRequest(
        'PUT',
        '/notifications/read-all',
        body: {},
      );
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Notifikasi belum dapat ditandai dibaca. Coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifikasi'),
      actions: [
        IconButton(
          onPressed: _marking ? null : _readAll,
          tooltip: 'Tandai semua dibaca',
          icon: const Icon(Icons.done_all_rounded),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.warning),
              ),
            ),
          if (_busy && _items.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (!_busy && _error == null && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Text('Belum ada notifikasi.', textAlign: TextAlign.center),
            ),
          ..._items.map((item) {
            final data = item['data'];
            final unread = item['read_at'] == null;
            final created = DateTime.tryParse(
              '${item['created_at']}',
            )?.toLocal();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: unread ? AppColors.primaryLight : Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _marking ? null : () => _read(item),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              data['kind'] == 'order'
                                  ? Icons.receipt_long_outlined
                                  : Icons.local_shipping_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${data['title']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: unread
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Text(
                          '${data['message']}',
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        ),
                        if (created != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 9),
                            child: Text(
                              '${created.day}/${created.month}/${created.year} ${created.hour.toString().padLeft(2, '0')}.${created.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (_page < _lastPage)
            TextButton(
              onPressed: _busy ? null : () => _load(more: true),
              child: const Text('Muat notifikasi lainnya'),
            ),
        ],
      ),
    ),
  );
}
