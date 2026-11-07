import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/auth_api.dart';
import '../core/auth_session.dart';
import '../commerce/shopping_state.dart' show PendingStore, SecurePendingStore;

class DeliveryResultState extends ChangeNotifier {
  DeliveryResultState({
    required this.session,
    required this.tripId,
    required this.stopId,
    PendingStore? store,
  }) : store =
           store ??
           SecurePendingStore('delivery-result.${session.user!.id}.$stopId');
  final AuthSession session;
  final String tripId;
  final String stopId;
  final PendingStore store;
  Map<String, dynamic>? pending;
  bool ready = false,
      busy = false,
      storageError = false,
      needsReview = false,
      _disposed = false;
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
      pending = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
      if (pending != null &&
          (pending!['trip_id'] != tripId ||
              pending!['stop_id'] != stopId ||
              pending!['payload'] is! Map ||
              pending!['result_key'] is! String ||
              pending!['upload_key'] is! String)) {
        throw const FormatException('Invalid pending result');
      }
    } catch (_) {
      storageError = true;
      message =
          'Permintaan tersimpan belum dapat dibaca. Periksa penyimpanan kembali.';
    }
    ready = true;
    notifyListeners();
  }

  Future<bool> submit(Map<String, dynamic> payload, String? photoPath) async {
    if (!ready || busy || storageError || pending != null) return false;
    pending = {
      'trip_id': tripId,
      'stop_id': stopId,
      'result_key': const Uuid().v4(),
      'upload_key': const Uuid().v4(),
      'photo_path': photoPath,
      'payload': jsonDecode(jsonEncode(payload)),
    };
    try {
      await store.write(jsonEncode(pending));
    } catch (_) {
      storageError = true;
      message = 'Permintaan belum tersimpan. Hasil belum dikirim.';
      notifyListeners();
      return false;
    }
    return retry();
  }

  Future<void> _clear({bool removePhoto = true}) async {
    final path = pending?['photo_path'] as String?;
    if (removePhoto && path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await store.clear();
    pending = null;
    storageError = false;
    needsReview = false;
  }

  Future<void> observeCompleted() async {
    if (busy || pending == null) return;
    try {
      await _clear();
      message = null;
    } catch (_) {
      storageError = true;
      message = 'Hasil sudah tercatat. Catatan lokal belum dapat dibersihkan.';
    }
    notifyListeners();
  }

  Future<void> reviewAgain() async {
    if (busy || !needsReview) return;
    try {
      await _clear(removePhoto: false);
      message = null;
    } catch (_) {
      storageError = true;
      message = 'Catatan lokal belum dapat dibersihkan.';
    }
    notifyListeners();
  }

  Future<bool> retry() async {
    if (!ready || busy || storageError || pending == null || needsReview) {
      return false;
    }
    busy = true;
    message = null;
    notifyListeners();
    try {
      final payload = Map<String, dynamic>.from(pending!['payload']);
      final path = pending!['photo_path'] as String?;
      if (path != null && payload['proof_upload_id'] == null) {
        final file = File(path);
        if (!await file.exists()) {
          throw const ApiException(
            'Foto lokal tidak ditemukan. Periksa ulang dan ambil foto kembali.',
            422,
          );
        }
        if (await file.length() > 2 * 1024 * 1024) {
          throw const ApiException(
            'Foto maksimal 2 MB. Pilih foto yang lebih kecil.',
            422,
          );
        }
        final upload = await session.uploadProof(
          '/courier/trips/$tripId/stops/$stopId/proofs',
          await file.readAsBytes(),
          pending!['upload_key'],
        );
        payload['proof_upload_id'] = upload['id'];
        pending!['payload'] = payload;
        await store.write(jsonEncode(pending));
      }
      await session.commerceRequest(
        'POST',
        '/courier/trips/$tripId/stops/$stopId/result',
        key: pending!['result_key'],
        body: payload,
      );
      try {
        await _clear();
        message = 'Hasil kiriman dan COD sudah tercatat.';
      } catch (_) {
        storageError = true;
        message =
            'Hasil sudah tercatat. Catatan lokal belum dapat dibersihkan.';
      }
      return true;
    } on ApiException catch (error) {
      needsReview =
          error.status >= 400 &&
          error.status < 500 &&
          ![401, 403, 408, 429].contains(error.status) &&
          error.code != 'REQUEST_IN_PROGRESS';
      message = needsReview
          ? error.message
          : 'Hasil belum dapat dipastikan. Perbarui tugas atau coba ulang permintaan yang sama.';
      return false;
    } catch (_) {
      message =
          'Koneksi atau penyimpanan terganggu. Perbarui tugas atau coba ulang permintaan yang sama.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
