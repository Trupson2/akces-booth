import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_client.dart';
import 'logger.dart';

/// Kolejka filmow ktore nie zostaly wyslane na RPi przy pierwszej probie.
///
/// Sesja 8a Block 3: gdy upload fail (brak netu / backend offline),
/// zamiast zostawiac goscia z niczym - generujemy QR z LOKALNYM URL
/// (LocalServer.localVideoUrl) i dodajemy do tej kolejki. W tle co X
/// sekund probujemy wyslac do backendu. Gdy sie uda - usuwamy z kolejki
/// (gosc moze nadal uzyc lokalnego URL, ale film tez jest na RPi).
class PendingUpload {
  PendingUpload({
    required this.localShortId,
    required this.localFilePath,
    required this.publishToFacebook,
    required this.createdAt,
    this.attemptCount = 0,
    this.lastError,
    this.remoteShortId,
  });

  /// Lokalnie wygenerowany short_id (uzywany w /local/<id>).
  final String localShortId;

  /// Sciezka do pliku na Tab.
  final String localFilePath;

  final bool publishToFacebook;
  final DateTime createdAt;
  int attemptCount;
  String? lastError;

  /// Po udanym upload'zie zapisujemy tutaj prawdziwy short_id z backendu.
  /// Klient moze potem scalic LocalServer.unregister i QR pointing.
  String? remoteShortId;

  Map<String, dynamic> toJson() => {
        'localShortId': localShortId,
        'localFilePath': localFilePath,
        'publishToFacebook': publishToFacebook,
        'createdAt': createdAt.toIso8601String(),
        'attemptCount': attemptCount,
        'lastError': lastError,
        'remoteShortId': remoteShortId,
      };

  factory PendingUpload.fromJson(Map<String, dynamic> j) => PendingUpload(
        localShortId: j['localShortId'] as String,
        localFilePath: j['localFilePath'] as String,
        publishToFacebook: j['publishToFacebook'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
        attemptCount: j['attemptCount'] as int? ?? 0,
        lastError: j['lastError'] as String?,
        remoteShortId: j['remoteShortId'] as String?,
      );
}

class PendingUploadsService extends ChangeNotifier {
  PendingUploadsService({required this.backend});

  static const _kQueueKey = 'pending_uploads.v1';
  static const Duration retryInterval = Duration(seconds: 45);

  final BackendClient backend;
  final List<PendingUpload> _queue = [];
  Timer? _retryTimer;

  List<PendingUpload> get queue => List.unmodifiable(_queue);
  int get length => _queue.length;
  bool get hasAny => _queue.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kQueueKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(PendingUpload.fromJson)
          .toList();
      _queue
        ..clear()
        ..addAll(list);
      Log.i('PendingUploads', 'loaded ${_queue.length} pending');
      notifyListeners();
    } catch (e) {
      Log.w('PendingUploads', 'load failed', error: e);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_queue.map((p) => p.toJson()).toList());
    await prefs.setString(_kQueueKey, raw);
  }

  /// Dodaj pending upload. Startuje retry loop jesli jeszcze nie chodzi.
  Future<void> enqueue(PendingUpload item) async {
    _queue.add(item);
    Log.i('PendingUploads', 'enqueued ${item.localShortId} '
        '(total: ${_queue.length})');
    await _save();
    notifyListeners();
    _ensureRetryLoop();
  }

  /// Usun z kolejki (np. po udanym upload).
  Future<void> remove(String localShortId) async {
    _queue.removeWhere((p) => p.localShortId == localShortId);
    await _save();
    notifyListeners();
    if (_queue.isEmpty) {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
  }

  void _ensureRetryLoop() {
    if (_retryTimer?.isActive ?? false) return;
    _retryTimer = Timer.periodic(retryInterval, (_) => retryAll());
    // Pierwsza proba od razu.
    unawaited(retryAll());
  }

  /// Probuj wyslac wszystko co jest w kolejce. Manualna wersja via
  /// debug panel "Retry all".
  Future<void> retryAll() async {
    if (!backend.isConfigured) {
      Log.d('PendingUploads', 'retry skip - backend not configured');
      return;
    }
    final snapshot = List<PendingUpload>.from(_queue);
    for (final item in snapshot) {
      if (item.remoteShortId != null) continue; // juz zsynchronizowany
      await _tryOne(item);
    }
  }

  Future<void> _tryOne(PendingUpload item) async {
    final file = File(item.localFilePath);
    if (!await file.exists()) {
      Log.w('PendingUploads', 'plik zniknal ${item.localFilePath}, usuwam');
      await remove(item.localShortId);
      return;
    }
    item.attemptCount++;
    notifyListeners();
    try {
      final result = await backend.uploadVideo(
        videoPath: item.localFilePath,
        publishToFacebook: item.publishToFacebook,
      );
      if (result != null) {
        item.remoteShortId = result.shortId;
        item.lastError = null;
        Log.i('PendingUploads', 'sync OK ${item.localShortId} -> '
            '${result.shortId}');
        await _save();
        notifyListeners();
        // Nie usuwamy od razu - gosc moze nadal otwierac z lokalnego URL.
        // Background cleanup gdy user zerowy aktywny.
      } else {
        item.lastError = 'upload returned null';
        Log.w('PendingUploads', 'sync fail ${item.localShortId}');
        await _save();
        notifyListeners();
      }
    } catch (e) {
      item.lastError = e.toString();
      Log.w('PendingUploads', 'sync error ${item.localShortId}', error: e);
      await _save();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}
