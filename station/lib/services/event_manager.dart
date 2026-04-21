import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backend_client.dart';
import 'local_server.dart';
import 'settings_store.dart';
import 'wire_protocol.dart';

/// Menedzer aktywnego eventu.
///
/// - Co [syncInterval] sekund pyta backend o aktywny event.
/// - Sciaga overlay PNG + muzyke do cache Tab.
/// - Po pobraniu wysyla konfigurację do Recordera przez LocalServer WS.
class EventManager extends ChangeNotifier {
  EventManager({
    required this.backend,
    required this.server,
    this.settings,
    this.syncInterval = const Duration(seconds: 30),
  });

  final BackendClient backend;
  final LocalServer server;
  final SettingsStore? settings;
  final Duration syncInterval;

  BackendEvent? _activeEvent;
  String? _cachedOverlayPath;
  String? _cachedMusicPath;
  int _videoCountCache = 0;
  int _localVideoDelta = 0; // animated bump po lokalnym upload
  bool _syncInFlight = false;
  String? _lastError;

  Timer? _poll;

  BackendEvent? get activeEvent => _activeEvent;
  String? get cachedOverlayPath => _cachedOverlayPath;
  String? get cachedMusicPath => _cachedMusicPath;

  /// Calkowity licznik: backend + lokalne uploady przed kolejnym sync.
  int get videoCount => _videoCountCache + _localVideoDelta;
  bool get hasActiveEvent => _activeEvent != null;
  String? get lastError => _lastError;

  /// Wywolaj raz na starcie.
  Future<void> start() async {
    await backend.loadConfig();
    await syncNow();
    _poll = Timer.periodic(syncInterval, (_) => syncNow());
    // Gdy Recorder (re)connect - natychmiast push aktualny event_config.
    // Bez tego Recorder musi czekac do 30s az poll sie odpali.
    server.onRecorderConnect = () {
      if (_activeEvent != null) {
        debugPrint('[EventManager] Recorder reconnect -> push config');
        _sendConfigToRecorder();
      }
    };
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Reconfigure backend (po zmianie URL w Settings) i natychmiast re-sync.
  Future<void> reconfigure({required String baseUrl, String? apiKey}) async {
    await backend.saveConfig(baseUrl: baseUrl, apiKey: apiKey);
    await syncNow();
  }

  /// Zsynchronizuj z backendem teraz (manual albo z tickera).
  Future<void> syncNow() async {
    if (!backend.isConfigured) {
      _lastError = 'Brak konfiguracji backendu';
      notifyListeners();
      return;
    }
    if (_syncInFlight) return;
    _syncInFlight = true;
    try {
      final event = await backend.getActiveEvent();
      if (event == null) {
        if (_activeEvent != null) {
          _activeEvent = null;
          _cachedOverlayPath = null;
          _cachedMusicPath = null;
          _videoCountCache = 0;
          _localVideoDelta = 0;
          notifyListeners();
        }
        _lastError = 'Brak aktywnego eventu w backend';
        return;
      }

      // Sciagnij overlay/music jesli sa i zmienily sie.
      final overlayChanged = _activeEvent?.overlayId != event.overlayId;
      final musicChanged = _activeEvent?.musicId != event.musicId;

      if (event.overlayUrl != null && (overlayChanged || _cachedOverlayPath == null)) {
        _cachedOverlayPath = await backend.downloadAsset(
          event.overlayUrl!,
          'overlay_${event.overlayId}.png',
        );
      }
      if (event.musicUrl != null && (musicChanged || _cachedMusicPath == null)) {
        _cachedMusicPath = await backend.downloadAsset(
          event.musicUrl!,
          'music_${event.musicId}.mp3',
        );
      }

      // Nowy event - zresetuj lokalny licznik delta.
      if (_activeEvent?.id != event.id) {
        _localVideoDelta = 0;
      }

      _activeEvent = event;
      _videoCountCache = event.videoCount;
      _lastError = null;
      notifyListeners();

      // Push config do Recordera (jesli polaczony).
      _sendConfigToRecorder();
    } catch (e) {
      _lastError = 'Sync error: $e';
      debugPrint('[EventManager] syncNow fail: $e');
      notifyListeners();
    } finally {
      _syncInFlight = false;
    }
  }

  void _sendConfigToRecorder() {
    final e = _activeEvent;
    if (e == null) return;
    final recorderConfig = settings?.toRecorderConfig() ?? const {};
    server.sendToRecorder({
      'type': WireMsg.eventConfig,
      'event_id': e.id,
      'event_name': e.name,
      // Lokalne sciezki Stationa (deprecated - gdy Station=Recorder=to samo
      // urzadzenie, nadal dzialaja; na dwoch urzadzeniach Recorder ich nie
      // otworzy). Trzymamy dla backward-compat do czasu gdy wszyscy recorderzy
      // beda na nowym APK.
      'overlay_path': _cachedOverlayPath,
      'music_path': _cachedMusicPath,
      // URL-e backendu - Recorder sam pobiera do swojego docs cache.
      'overlay_url': e.overlayUrl,
      'music_url': e.musicUrl,
      'music_offset_sec': e.musicOffsetSec,
      'music_offset_mode': e.musicOffsetMode,
      'text_top': e.textTop,
      'text_bottom': e.textBottom,
      // Parametry nagrywania z SettingsStore (resolution, duration, slowmo,
      // rotation). Recorder zapisuje je lokalnie i stosuje przy kolejnym
      // start_recording.
      ...recorderConfig,
    });
  }

  /// Wywolaj po zmianie SettingsStore (rozdzielczosc, slowmo, itd.) -
  /// pushuje aktualny config do Recordera bez czekania na poll eventu.
  void pushRecorderConfig() => _sendConfigToRecorder();

  /// Wywolywane po udanym uploadzie video z Station do backendu.
  /// Zwiekszamy licznik lokalnie (animated), prawdziwa wartosc przyjdzie
  /// w nastepnym sync cycle.
  void onVideoUploaded() {
    _localVideoDelta++;
    notifyListeners();
  }
}
