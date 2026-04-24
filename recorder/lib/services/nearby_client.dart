import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/event_config.dart';
import '../models/recording_resolution.dart';
import 'settings_store.dart';
import 'wire_protocol.dart';

const String _kServiceId = 'pl.akces360.booth.nearby.v1';
const String _kDiscovererName = 'AkcesBooth-Recorder';

enum NearbyClientState {
  idle,
  discovering,
  connecting,
  connected,
  error,
}

/// Recorder-side Nearby Connections transport.
///
/// Rola: **Discoverer**. OP13 skanuje otoczenie dla `_kServiceId`, gdy
/// znajdzie Tab Station - wysyla connection request, Station auto-accept.
///
/// API ksztaltem naslladuje stary `StationClient` zeby Etap 3 byl czysty
/// swap a nie refaktor warstwy wyzej:
/// - `sendToStation(Map<String,dynamic>)` - JSON bytes do peera
/// - `sendFileToStation(File, short_name)` - file payload dla MP4 (Etap 3)
/// - `onStartRequested` / `onStopRequested` / `onEventConfig(EventConfig)`
/// - Periodic status push (bateria + dysk) jak w StationClient
/// - Auto-download overlay/music z URL-i gdy Station siedzi na innym
///   urzadzeniu (lokalne sciezki Stationa tu nie istnieja)
class NearbyClient extends ChangeNotifier {
  NearbyClient({SettingsStore? store}) : _store = store ?? SettingsStore();

  final Nearby _nearby = Nearby();
  final SettingsStore _store;
  final Battery _battery = Battery();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(minutes: 2),
  ));

  NearbyClientState _state = NearbyClientState.idle;
  String? _connectedEndpointId;
  String? _discoveredEndpointId;
  String? _lastError;
  Timer? _statusTimer;
  String? _docsDir;

  /// Ostatnio odebrany event_config (cache'owany, z juz pobranymi assetami).
  EventConfig? _lastEventConfig;
  EventConfig? get lastEventConfig => _lastEventConfig;

  /// Ostatnio zaraportowane przez OS status baterii/dysku - cache do fallback.
  int? _lastBatteryPct;
  double? _lastDiskFreeGb;

  // Callbacki dla komend ze Stationa - nakladaja na siebie jak w
  // StationClient (recording_screen override'uje onStartRequested itd.).
  void Function()? onStartRequested;
  void Function()? onStopRequested;
  void Function(EventConfig cfg)? onEventConfig;

  NearbyClientState get state => _state;
  bool get isConnected => _state == NearbyClientState.connected;
  String? get lastError => _lastError;

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  /// Start discovery. Nearby skanuje otoczenie dla Service ID naszej apki.
  /// Gdy znajdzie - auto-requestConnection, auto-accept po stronie Stationa.
  Future<void> start() async {
    if (_state == NearbyClientState.discovering ||
        _state == NearbyClientState.connected) {
      return;
    }
    // Pre-populate docsDir dla sync _cachedAssetPath zeby pierwszy event_config
    // po restart'ie mogl od razu uzywac cached overlay (bez czekania na
    // async download i race z user klikajacym record).
    try {
      final dir = await getApplicationDocumentsDirectory();
      _docsDir = dir.path;
    } catch (_) {}

    try {
      final started = await _nearby.startDiscovery(
        _kDiscovererName,
        Strategy.P2P_POINT_TO_POINT,
        serviceId: _kServiceId,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
      );
      if (started) {
        _setState(NearbyClientState.discovering);
        debugPrint('[NearbyClient] discovering for $_kServiceId');
      } else {
        _setState(NearbyClientState.error,
            error: 'startDiscovery returned false');
      }
    } catch (e, st) {
      debugPrint('[NearbyClient] start failed: $e\n$st');
      _setState(NearbyClientState.error, error: e.toString());
    }
  }

  Future<void> stop() async {
    _statusTimer?.cancel();
    _statusTimer = null;
    try {
      await _nearby.stopDiscovery();
      await _nearby.stopAllEndpoints();
    } catch (e) {
      debugPrint('[NearbyClient] stop err: $e');
    }
    _connectedEndpointId = null;
    _discoveredEndpointId = null;
    _setState(NearbyClientState.idle);
  }

  // ------------------------------------------------------------------
  // Nearby callbacks
  // ------------------------------------------------------------------

  Future<void> _onEndpointFound(
      String endpointId, String endpointName, String serviceId) async {
    debugPrint('[NearbyClient] found $endpointId ($endpointName)');
    if (_state == NearbyClientState.connected ||
        _state == NearbyClientState.connecting) return;
    _discoveredEndpointId = endpointId;
    _setState(NearbyClientState.connecting);
    try {
      await _nearby.requestConnection(
        _kDiscovererName,
        endpointId,
        onConnectionInitiated: _onConnInit,
        onConnectionResult: _onConnResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      debugPrint('[NearbyClient] requestConnection fail: $e');
      _setState(NearbyClientState.discovering, error: e.toString());
    }
  }

  void _onEndpointLost(String? endpointId) {
    debugPrint('[NearbyClient] endpoint lost $endpointId');
    if (endpointId == _discoveredEndpointId) {
      _discoveredEndpointId = null;
    }
  }

  Future<void> _onConnInit(
      String endpointId, ConnectionInfo info) async {
    debugPrint('[NearbyClient] conn init from $endpointId');
    try {
      await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: (id, payload) => _onPayload(id, payload),
        onPayloadTransferUpdate: (id, update) => _onPayloadUpdate(id, update),
      );
    } catch (e) {
      debugPrint('[NearbyClient] accept fail: $e');
    }
  }

  void _onConnResult(String endpointId, Status status) {
    debugPrint('[NearbyClient] conn result $status');
    if (status == Status.CONNECTED) {
      _connectedEndpointId = endpointId;
      _setState(NearbyClientState.connected);
      // Stop discovery po udanym connect - P2P_POINT_TO_POINT =
      // mamy jeden peer, nie szukamy wiecej.
      _nearby.stopDiscovery();
      _startStatusPush();
    } else {
      _connectedEndpointId = null;
      _setState(NearbyClientState.discovering);
      // Nearby sam spróbuje znowu poprzez onEndpointFound.
    }
  }

  void _onDisconnected(String endpointId) {
    debugPrint('[NearbyClient] disconnected $endpointId');
    _connectedEndpointId = null;
    _statusTimer?.cancel();
    _statusTimer = null;
    _setState(NearbyClientState.idle);
    // Auto-restart discovery - Nearby ponownie znajdzie Tab.
    Future<void>.delayed(const Duration(seconds: 2), () => start());
  }

  Future<void> _onPayload(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.BYTES) {
      final bytes = payload.bytes;
      if (bytes == null) return;
      try {
        final str = utf8.decode(bytes);
        final msg = jsonDecode(str) as Map<String, dynamic>;
        _handleMessage(msg);
      } catch (e) {
        debugPrint('[NearbyClient] bytes parse: $e');
      }
    }
  }

  void _onPayloadUpdate(String endpointId, PayloadTransferUpdate update) {
    if (update.status == PayloadStatus.SUCCESS) {
      debugPrint('[NearbyClient] payload ${update.id} sent OK');
    } else if (update.status == PayloadStatus.FAILURE) {
      debugPrint('[NearbyClient] payload ${update.id} FAILED');
    }
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'];
    switch (type) {
      case WireMsg.startRecording:
        onStartRequested?.call();
        break;
      case WireMsg.stopRecording:
        onStopRequested?.call();
        break;
      case WireMsg.eventConfig:
        // Async handler - pobiera overlay/music lokalnie gdy sa dostarczone
        // jako URL-e (Station na innym urzadzeniu, lokalne sciezki Stationa
        // tutaj nie istnieja). Lapiemy bledy z future zeby zobaczyc co wali.
        _handleEventConfig(msg).catchError((Object e, StackTrace st) {
          debugPrint('[NearbyClient] eventConfig handler error: $e\n$st');
        });
        break;
      case WireMsg.ping:
        // Nearby ma wewnetrzny keepalive wiec Station nie powinien juz
        // wysylac ping - ale zachowujemy zgodnosc z WS fallback (np. testy).
        sendToStation({'type': WireMsg.pong});
        break;
      default:
        debugPrint('[NearbyClient] Unknown msg: $type');
    }
  }

  // ------------------------------------------------------------------
  // Event config + asset download
  // ------------------------------------------------------------------

  Future<void> _handleEventConfig(Map<String, dynamic> msg) async {
    final cfg = EventConfig.fromJson(msg);

    // Eager-set lastEventConfig z tym co mamy (sciezki z msg albo cache).
    // Download leci w tle - gdy skonczy, aktualizujemy drugi raz. Tak samo
    // jak StationClient, zeby unikac race z user klikajacym record PRZED
    // zakonczeniem downloadu (wtedy overlay=null i overlay sie pomija).
    String? overlayLocal = cfg.overlayPath;
    String? musicLocal = cfg.musicPath;
    if (overlayLocal != null && !File(overlayLocal).existsSync()) {
      overlayLocal = null;
    }
    if (musicLocal != null && !File(musicLocal).existsSync()) {
      musicLocal = null;
    }

    if (overlayLocal == null && cfg.overlayUrl != null &&
        cfg.overlayUrl!.isNotEmpty) {
      final cached = _cachedAssetPath(cfg.overlayUrl!, 'overlay');
      if (cached != null) overlayLocal = cached;
    }
    if (musicLocal == null && cfg.musicUrl != null &&
        cfg.musicUrl!.isNotEmpty) {
      final cached = _cachedAssetPath(cfg.musicUrl!, 'music');
      if (cached != null) musicLocal = cached;
    }

    var finalCfg = cfg.copyWith(
      overlayPath: overlayLocal,
      musicPath: musicLocal,
    );
    _lastEventConfig = finalCfg;
    _applyRecordingParams(finalCfg);
    onEventConfig?.call(finalCfg);
    notifyListeners();
    debugPrint('[NearbyClient] Event config (eager): ${finalCfg.eventName} '
        'overlay=${finalCfg.overlayPath != null} '
        'music=${finalCfg.musicPath != null}');

    // Download brakujacych assetow w tle.
    bool updated = false;
    if (overlayLocal == null && cfg.overlayUrl != null &&
        cfg.overlayUrl!.isNotEmpty) {
      final path = await _downloadEventAsset(cfg.overlayUrl!, 'overlay');
      if (path != null) {
        overlayLocal = path;
        updated = true;
      }
    }
    if (musicLocal == null && cfg.musicUrl != null &&
        cfg.musicUrl!.isNotEmpty) {
      final path = await _downloadEventAsset(cfg.musicUrl!, 'music');
      if (path != null) {
        musicLocal = path;
        updated = true;
      }
    }

    if (updated) {
      finalCfg = cfg.copyWith(
        overlayPath: overlayLocal,
        musicPath: musicLocal,
      );
      _lastEventConfig = finalCfg;
      onEventConfig?.call(finalCfg);
      notifyListeners();
      debugPrint('[NearbyClient] Event config (downloaded): '
          'overlay=${finalCfg.overlayPath != null} '
          'music=${finalCfg.musicPath != null}');
    }
  }

  /// Sprawdza czy asset dla danego URL jest juz w cache lokalnym.
  /// Synchroniczne - zeby uniknac await przy pierwszym set lastEventConfig.
  String? _cachedAssetPath(String url, String label) {
    try {
      if (_docsDir == null) return null;
      final key = url.hashCode.toUnsigned(32).toRadixString(36);
      final target = File(p.join(_docsDir!, 'event_assets',
          'asset_${label}_$key.bin'));
      if (target.existsSync() && target.lengthSync() > 0) {
        return target.path;
      }
    } catch (_) {}
    return null;
  }

  /// Pobiera URL backendu do docs/event_assets/<hash>.bin. Cache keyed by
  /// URL - ten sam URL = ten sam plik (skip re-download). Plik zachowany
  /// miedzy sesjami Recorder.
  Future<String?> _downloadEventAsset(String url, String label) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _docsDir = dir.path;
      final cacheDir = Directory(p.join(dir.path, 'event_assets'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      final key = url.hashCode.toUnsigned(32).toRadixString(36);
      final target = File(p.join(cacheDir.path, 'asset_${label}_$key.bin'));
      if (await target.exists() && await target.length() > 0) {
        return target.path;
      }
      await _dio.download(url, target.path);
      debugPrint('[NearbyClient] Downloaded $label from $url '
          '-> ${target.path} (${await target.length()} bytes)');
      return target.path;
    } catch (e) {
      debugPrint('[NearbyClient] download $label fail: $e');
      return null;
    }
  }

  /// Zastosuj parametry nagrywania z event_config Station do lokalnych
  /// preferences Recordera. Fire-and-forget - jesli zapis sie wywali,
  /// i tak next recording uzyje wczesniejszej wartosci.
  Future<void> _applyRecordingParams(EventConfig cfg) async {
    try {
      final resName = cfg.resolution;
      if (resName != null && resName.isNotEmpty) {
        RecordingResolution? target;
        for (final r in RecordingResolution.values) {
          if (r.name == resName) {
            target = r;
            break;
          }
        }
        if (target != null) {
          await _store.saveResolution(target);
          debugPrint('[NearbyClient] resolution z Station -> ${target.name}');
        }
      }
      if (cfg.stabilize != null) {
        await _store.saveStabilize(cfg.stabilize!);
        debugPrint('[NearbyClient] stabilize z Station -> ${cfg.stabilize}');
      }
      if (cfg.zoomLevel != null) {
        await _store.saveZoomLevel(cfg.zoomLevel!);
        debugPrint('[NearbyClient] zoom_level z Station -> ${cfg.zoomLevel}');
      }
    } catch (e) {
      debugPrint('[NearbyClient] _applyRecordingParams error: $e');
    }
  }

  // ------------------------------------------------------------------
  // Status push (battery + disk co 30s)
  // ------------------------------------------------------------------

  void _startStatusPush() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_pushStatus());
    });
    // I od razu pierwszy push.
    unawaited(_pushStatus());
  }

  Future<void> _pushStatus() async {
    try {
      final battery = await _probeBatteryPct();
      final disk = await _probeDiskFreeGb();
      _lastBatteryPct = battery;
      _lastDiskFreeGb = disk;
      sendStatus(batteryPct: battery, diskFreeGb: disk);
    } catch (e) {
      debugPrint('[NearbyClient] _pushStatus err: $e');
    }
  }

  Future<int?> _probeBatteryPct() async {
    try {
      final lvl = await _battery.batteryLevel;
      return lvl.clamp(0, 100);
    } catch (e) {
      debugPrint('[NearbyClient] battery probe fail: $e');
      return _lastBatteryPct;
    }
  }

  Future<double?> _probeDiskFreeGb() async {
    // Placeholder - pozniej platform channel dla statfs. Fallback do cache.
    return _lastDiskFreeGb;
  }

  // ------------------------------------------------------------------
  // Public send API
  // ------------------------------------------------------------------

  /// Wysyla JSON msg (bytes payload) do Stationa.
  Future<void> sendToStation(Map<String, dynamic> msg) async {
    final id = _connectedEndpointId;
    if (id == null) return;
    try {
      final bytes = utf8.encode(jsonEncode(msg));
      await _nearby.sendBytesPayload(id, bytes);
    } catch (e) {
      debugPrint('[NearbyClient] sendBytes fail: $e');
    }
  }

  /// Wysyla plik (MP4) do Stationa. Nearby auto-upgrade'uje do WiFi Direct
  /// dla duzych plikow. Zwraca true gdy callback SUCCESS, false na FAILURE.
  ///
  /// TODO(Etap 3): track SUCCESS via _onPayloadUpdate (payloadId -> completer),
  /// na razie fire-and-forget.
  Future<bool> sendFileToStation(File file, {String? shortName}) async {
    final id = _connectedEndpointId;
    if (id == null || !file.existsSync()) return false;
    try {
      // Prekursor bytes - Station wie co za plik przychodzi.
      await sendToStation({
        'type': 'file_incoming',
        'short_name': shortName ?? 'video.mp4',
        'size': file.lengthSync(),
      });
      final payload = await _nearby.sendFilePayload(id, file.path);
      debugPrint('[NearbyClient] file payload id=$payload');
      return true;
    } catch (e) {
      debugPrint('[NearbyClient] sendFile fail: $e');
      return false;
    }
  }

  // Wrapper helpers - mirror starego StationClient.sendXxx API, zeby
  // recording_screen / video_processor mogly podmienic typ klienta
  // w Etap 3 bez zmian w call-site.
  void sendRecordingStarted() =>
      sendToStation({'type': WireMsg.recordingStarted});
  void sendRecordingProgress(double p) =>
      sendToStation({'type': WireMsg.recordingProgress, 'progress': p});
  void sendRecordingStopped() =>
      sendToStation({'type': WireMsg.recordingStopped});
  void sendProcessingProgress(double p) =>
      sendToStation({'type': WireMsg.processingProgress, 'progress': p});
  void sendProcessingDone() =>
      sendToStation({'type': WireMsg.processingDone});
  void sendUploadProgress(double p) =>
      sendToStation({'type': WireMsg.uploadProgress, 'progress': p});
  void sendError(String msg) =>
      sendToStation({'type': WireMsg.error, 'message': msg});
  void sendStatus({int? batteryPct, double? diskFreeGb}) =>
      sendToStation({
        'type': WireMsg.recorderStatus,
        if (batteryPct != null) 'battery': batteryPct,
        if (diskFreeGb != null) 'disk_free_gb': diskFreeGb,
      });

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  void _setState(NearbyClientState s, {String? error}) {
    _state = s;
    _lastError = error;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
