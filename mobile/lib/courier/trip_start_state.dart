import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/auth_api.dart';
import '../core/auth_session.dart';
import '../commerce/shopping_state.dart' show PendingStore, SecurePendingStore;

class TripStartState extends ChangeNotifier {
  TripStartState({
    required this.session,
    required this.tripId,
    PendingStore? store,
  }) : store =
           store ??
           SecurePendingStore('courier-start.${session.user!.id}.$tripId');
  final AuthSession session;
  final String tripId;
  final PendingStore store;
  Map<String, dynamic>? pending;
  bool ready = false, busy = false, storageError = false, _disposed = false;
  String? message;
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
    if (busy) return;
    ready = false;
    storageError = false;
    message = null;
    notifyListeners();
    try {
      final raw = await store.read();
      if (raw != null) {
        final value = jsonDecode(raw) as Map<String, dynamic>;
        if (value['trip_id'] != tripId ||
            value['key'] is! String ||
            value['payload'] is! Map ||
            value['payload']['manifest'] is! List) {
          throw const FormatException('Invalid pending start');
        }
        pending = value;
      } else {
        pending = null;
      }
    } catch (_) {
      storageError = true;
      message =
          'Permintaan tersimpan belum dapat dibaca. Coba periksa penyimpanan kembali.';
    }
    ready = true;
    notifyListeners();
  }

  Future<bool> submit(Map<String, dynamic> payload) async {
    if (!ready || busy || storageError || pending != null) return false;
    busy = true;
    message = null;
    notifyListeners();
    pending = {
      'trip_id': tripId,
      'key': const Uuid().v4(),
      'payload': jsonDecode(jsonEncode(payload)),
    };
    try {
      await store.write(jsonEncode(pending));
    } catch (_) {
      busy = false;
      storageError = true;
      message = 'Permintaan belum tersimpan. Trip belum dikirim untuk dimulai.';
      notifyListeners();
      return false;
    }
    return _send();
  }

  Future<bool> retry() async {
    if (!ready || busy || storageError || pending == null) return false;
    busy = true;
    message = null;
    notifyListeners();
    return _send();
  }

  Future<bool> _clear() async {
    try {
      await store.clear();
      pending = null;
      storageError = false;
      return true;
    } catch (_) {
      storageError = true;
      return false;
    }
  }

  Future<void> observeStarted() async {
    if (!busy && pending != null) {
      if (!await _clear()) {
        message =
            'Trip sudah berangkat. Catatan lokal belum dapat dibersihkan; periksa penyimpanan kembali.';
      }
      notifyListeners();
    }
  }

  Future<bool> _send() async {
    try {
      await session.commerceRequest(
        'POST',
        '/courier/trips/$tripId/start',
        key: pending!['key'],
        body: Map<String, dynamic>.from(pending!['payload']),
      );
      final cleared = await _clear();
      message = cleared
          ? 'Muatan dikonfirmasi. Trip sudah berangkat.'
          : 'Trip sudah berangkat. Catatan lokal belum dapat dibersihkan.';
      return true;
    } on ApiException catch (e) {
      if (e.status >= 400 &&
          e.status < 500 &&
          ![401, 403, 408, 429].contains(e.status) &&
          e.code != 'REQUEST_IN_PROGRESS') {
        await _clear();
        message = e.message;
      } else {
        message =
            'Hasil mulai trip belum dipastikan. Perbarui tugas atau coba ulang permintaan yang sama.';
      }
      return false;
    } catch (_) {
      message =
          'Koneksi terputus; hasil mulai trip belum dipastikan. Perbarui tugas atau coba ulang permintaan yang sama.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
