import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../core/auth_api.dart';
import '../core/auth_session.dart';

abstract class PendingStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecurePendingStore implements PendingStore {
  SecurePendingStore(String user) : _key = 'shipx.pending.$user';
  final String _key;
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class ShoppingState extends ChangeNotifier {
  ShoppingState({required this.session, PendingStore? store})
    : store = store ?? SecurePendingStore(session.user!.id);
  final AuthSession session;
  final PendingStore store;
  final Map<String, Map<String, dynamic>> lines = {};
  Map<String, dynamic>? address, slot, pending, lastOrder;
  String? message;
  bool ready = false, busy = false, storageError = false, _disposed = false;
  bool _reviewRequired = false;
  bool get needsReview =>
      pending != null &&
      (_reviewRequired ||
          DateTime.now()
                  .toUtc()
                  .difference(DateTime.parse(pending!['created_at']))
                  .inDays >=
              30);
  Future<void> acknowledgeReviewed() async {
    if (!needsReview || busy) return;
    try {
      await store.clear();
      pending = null;
      _reviewRequired = false;
      message =
          'Permintaan lama ditutup setelah pemeriksaan riwayat. Periksa kembali barang dan total sebelum memesan.';
    } catch (_) {
      message = 'Permintaan lama belum dapat dibersihkan. Coba lagi.';
    }
    notifyListeners();
  }

  bool get locked => !ready || busy || pending != null || storageError;
  int get count =>
      lines.values.fold(0, (sum, line) => sum + (line['quantity'] as int));
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> restore() async {
    ready = false;
    storageError = false;
    notifyListeners();
    try {
      final raw = await store.read();
      if (raw != null) {
        final value = jsonDecode(raw) as Map<String, dynamic>;
        if (value['key'] is! String ||
            value['payload'] is! Map ||
            !['create', 'cancel'].contains(value['kind'])) {
          throw const FormatException();
        }
        DateTime.parse(value['created_at']);
        pending = value;
        message =
            'Ada permintaan yang hasilnya belum dipastikan. Periksa dengan permintaan yang sama.';
      }
    } catch (_) {
      storageError = true;
      message =
          'Permintaan tersimpan belum dapat dibaca. Coba lagi sebelum memesan.';
    }
    ready = true;
    notifyListeners();
  }

  String? add(Map<String, dynamic> product) {
    if (locked) {
      return 'Selesaikan pemeriksaan permintaan sebelumnya terlebih dahulu.';
    }
    final id = product['id'] as String;
    final old = lines[id];
    if (old == null && lines.length >= 20) {
      return 'Maksimal 20 jenis barang dalam satu pesanan.';
    }
    if (old != null && old['quantity'] >= 20) {
      return 'Maksimal 20 unit per produk.';
    }
    lines[id] = {
      'product': Map<String, dynamic>.from(product),
      'quantity': (old?['quantity'] as int? ?? 0) + 1,
    };
    lastOrder = null;
    message = null;
    notifyListeners();
    return null;
  }

  void quantity(String id, int value) {
    if (locked || !lines.containsKey(id) || value < 0 || value > 20) return;
    if (value == 0) {
      lines.remove(id);
    } else {
      lines[id]!['quantity'] = value;
    }
    message = null;
    notifyListeners();
  }

  void chooseAddress(Map<String, dynamic>? value) {
    if (locked) return;
    address = value;
    notifyListeners();
  }

  void chooseSlot(Map<String, dynamic>? value) {
    if (locked) return;
    slot = value;
    notifyListeners();
  }

  Map<String, dynamic> payload() {
    final items =
        lines.entries
            .map((e) => {'product_id': e.key, 'quantity': e.value['quantity']})
            .toList()
          ..sort(
            (a, b) => int.parse(
              a['product_id'] as String,
            ).compareTo(int.parse(b['product_id'] as String)),
          );
    return {
      'address_id': address?['id'],
      'delivery_slot_id': slot?['id'],
      if (slot?.containsKey('delivery_type') == true)
        'delivery_type': slot!['delivery_type'],
      'items': items,
    };
  }

  String get fingerprint => jsonEncode(payload());

  Future<Map<String, dynamic>?> create(Map<String, dynamic> quote) async {
    if (locked) return null;
    if (lines.isEmpty || address == null || slot == null) {
      message = 'Lengkapi barang, alamat dan jadwal terlebih dahulu.';
      notifyListeners();
      return null;
    }
    return _start('create', '/orders', {
      ...payload(),
      'expected_total_rp': quote['total_rp'],
    });
  }

  Future<Map<String, dynamic>?> cancel(
    Map<String, dynamic> order,
    String reason,
  ) async {
    if (locked) return null;
    return _start('cancel', '/orders/${order['id']}/cancel', {
      'lock_version': order['lock_version'],
      'reason': reason,
    });
  }

  Future<Map<String, dynamic>?> _start(
    String kind,
    String path,
    Map<String, dynamic> body,
  ) async {
    busy = true;
    message = null;
    notifyListeners();
    final draft = {
      'kind': kind,
      'path': path,
      'key': const Uuid().v4(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'payload': body,
    };
    try {
      await store.write(jsonEncode(draft));
      pending = draft;
    } catch (_) {
      message =
          'Permintaan belum dikirim karena penyimpanan aman gagal. Coba lagi.';
      busy = false;
      notifyListeners();
      return null;
    }
    busy = false;
    return retry();
  }

  Future<Map<String, dynamic>?> retry() async {
    if (pending == null || busy) return null;
    final request = Map<String, dynamic>.from(pending!);
    if (DateTime.now()
            .toUtc()
            .difference(DateTime.parse(request['created_at']))
            .inDays >=
        30) {
      message =
          'Permintaan ini berumur 30 hari atau lebih. Periksa riwayat pesanan sebelum membuat pesanan baru.';
      notifyListeners();
      return null;
    }
    busy = true;
    message = null;
    notifyListeners();
    try {
      final result = await session.commerceRequest(
        'POST',
        request['path'],
        body: Map<String, dynamic>.from(request['payload']),
        key: request['key'],
      );
      lastOrder = result;
      await store.clear();
      pending = null;
      if (request['kind'] == 'create') lines.clear();
      message = request['kind'] == 'create'
          ? 'Pesanan berhasil dibuat.'
          : 'Pesanan dibatalkan.';
      return result;
    } on ApiException catch (error) {
      _reviewRequired = [
        'IDEMPOTENCY_CONFLICT',
        'IDEMPOTENCY_EXPIRED',
      ].contains(error.code);
      final uncertain =
          error.status >= 500 ||
          error.status == 401 ||
          error.status == 403 ||
          [
            'REQUEST_IN_PROGRESS',
            'IDEMPOTENCY_CONFLICT',
            'IDEMPOTENCY_EXPIRED',
          ].contains(error.code);
      if (!uncertain) {
        try {
          await store.clear();
          pending = null;
          if (error.code == 'SLOT_CLOSED') slot = null;
        } catch (_) {
          message =
              'Hasil diterima, tetapi permintaan tersimpan belum dapat dibersihkan. Coba periksa lagi.';
          return null;
        }
      }
      message = error.message;
    } catch (_) {
      message =
          'Hasil permintaan belum diketahui. Periksa koneksi lalu coba lagi dengan permintaan yang sama.';
    } finally {
      busy = false;
      notifyListeners();
    }
    return null;
  }
}
