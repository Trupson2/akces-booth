import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/recording_resolution.dart';
import 'settings_store.dart';
import 'wire_protocol.dart';

/// Konfig eventu przyslany ze Station (Sesja 7 + parametry nagrywania Sesja 9).
class EventConfig {
  EventConfig({
    required this.eventId,
    required this.eventName,
    this.overlayPath,
    this.musicPath,
    this.overlayUrl,
    this.musicUrl,
    this.musicOffsetSec,
    this.musicOffsetMode,
    this.textTop,
    this.textBottom,
    this.resolution,
    this.videoDurationSec,
    this.slowmoFactor,
    this.rotationDir,
    this.rotationSpeed,
    this.stabilize,
  });

  final int eventId;
  final String eventName;
  /// Local filesystem path (set by Station when Station==Recorder, or later by
  /// Recorder after downloading from overlayUrl/musicUrl).
  final String? overlayPath;
  final String? musicPath;
  /// Backend URL dla overlay/music. Recorder pobiera do swojego docs cache
  /// gdy te URL-e sa dostarczone (Station na innym urzadzeniu = nie mozemy
  /// polegac na lokalnej sciezce Stationa).
  final String? overlayUrl;
  final String? musicUrl;
  /// Offset (sekundy) skad ma startowac miks muzyki. Null => heurystyka
  /// recordera (30% dlugosci clamp 30-60). Ustawiony przez backend library
  /// (AI viral analysis albo manual w admin panel).
  final double? musicOffsetSec;
  final String? musicOffsetMode; // 'default_30s' | 'ai' | 'custom'
  final String? textTop;
  final String? textBottom;

  // Parametry nagrywania ze Station Settings (nadpisuja lokalne).
  // resolution: 'fullHd' | 'uhd4k' (8K usuniete - za dlugo FFmpeg).
  final String? resolution;
  final int? videoDurationSec;
  final double? slowmoFactor;
  final String? rotationDir; // 'cw' | 'ccw' | 'mixed'
  final int? rotationSpeed;

  /// Czy wlaczyc post-process stabilizacji (FFmpeg deshake). Null = brak
  /// nadpisania (Recorder uzywa ostatniej wartosci w SettingsStore).
  final bool? stabilize;

  factory EventConfig.fromJson(Map<String, dynamic> j) => EventConfig(
        eventId: (j['event_id'] as num?)?.toInt() ?? 0,
        eventName: j['event_name']?.toString() ?? '',
        overlayPath: j['overlay_path']?.toString(),
        musicPath: j['music_path']?.toString(),
        overlayUrl: j['overlay_url']?.toString(),
        musicUrl: j['music_url']?.toString(),
        musicOffsetSec: (j['music_offset_sec'] as num?)?.toDouble(),
        musicOffsetMode: j['music_offset_mode']?.toString(),
        textTop: j['text_top']?.toString(),
        textBottom: j['text_bottom']?.toString(),
        resolution: j['resolution']?.toString(),
        videoDurationSec: (j['video_duration_s'] as num?)?.toInt(),
        slowmoFactor: (j['slowmo_factor'] as num?)?.toDouble(),
        rotationDir: j['rotation_dir']?.toString(),
        rotationSpeed: (j['rotation_speed'] as num?)?.toInt(),
        stabilize: j['stabilize'] is bool ? j['stabilize'] as bool : null,
      );

  EventConfig copyWith({String? overlayPath, String? musicPath}) => EventConfig(
        eventId: eventId,
        eventName: eventName,
        overlayPath: overlayPath ?? this.overlayPath,
        musicPath: musicPath ?? this.musicPath,
        overlayUrl: overlayUrl,
        musicUrl: musicUrl,
        musicOffsetSec: musicOffsetSec,
        musicOffsetMode: musicOffsetMode,
        textTop: textTop,
        textBottom: textBottom,
        resolution: resolution,
        videoDurationSec: videoDurationSec,
        slowmoFactor: slowmoFactor,
        rotationDir: rotationDir,
        rotationSpeed: rotationSpeed,
        stabilize: stabilize,
      );
}

/// Stan polaczenia z Station.
enum StationConnState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Klient do Station: WebSocket + HTTP upload + auto-reconnect.
class StationClient extends ChangeNotifier {
  StationClient({SettingsStore? store}) : _store = store ?? SettingsStore();

  final SettingsStore _store;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(minutes: 2),
    sendTimeout: const Duration(minutes: 2),
  ));

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _statusTimer;

  StationConnState _state = StationConnState.disconnected;
  String? _ip;
  int _port = 8080;
  String? _lastError;
  bool _autoReconnect = true;

  // Exponential backoff: 1, 2, 5, 10, 30, 30... (sekundy)
  // Zaczyna od 0 i inkrementuje przy kazdej nieudanej probie.
  static const List<int> _backoffSecondsSchedule = [1, 2, 5, 10, 30];
  int _reconnectAttempts = 0;

  /// Ostatnio zaraportowany przez OS status baterii/dysku - cache.
  int? _lastBatteryPct;
  double? _lastDiskFreeGb;

  /// Callback: Station prosi o start nagrywania.
  void Function()? onStartRequested;

  /// Callback: Station prosi o manualny stop.
  void Function()? onStopRequested;

  /// Callback: Station wyslala konfig aktywnego eventu (Sesja 7).
  void Function(EventConfig config)? onEventConfig;

  /// Ostatni event config z Station (persystuje miedzy nagraniami).
  EventConfig? _lastEventConfig;
  EventConfig? get lastEventConfig => _lastEventConfig;

  StationConnState get state => _state;
  bool get isConnected => _state == StationConnState.connected;
  String? get ip => _ip;
  int get port => _port;
  String? get lastError => _lastError;
  String get httpBaseUrl => 'http://${_ip ?? "0.0.0.0"}:$_port';
  String get wsUrl => 'ws://${_ip ?? "0.0.0.0"}:$_port/ws';

  Future<void> loadAndConnect() async {
    // Pre-populate docsDir dla sync _cachedAssetPath zeby pierwszy event_config
    // po restart'ie mogl od razu uzywac cached overlay (bez czekania na
    // async download i race z user klikajacym record).
    try {
      final dir = await getApplicationDocumentsDirectory();
      _docsDir = dir.path;
    } catch (_) {}

    _ip = await _store.loadStationIp();
    _port = await _store.loadStationPort();
    if (_ip == null || _ip!.isEmpty) {
      debugPrint('[StationClient] No IP configured - idle');
      return;
    }
    await connect();
  }

  /// Zapis ustawien i reconnect pod nowy adres.
  Future<void> configure(String ip, int port) async {
    _ip = ip;
    _port = port;
    await _store.saveStationIp(ip);
    await _store.saveStationPort(port);
    await disconnect(keepAutoReconnect: true);
    await connect();
  }

  /// Probny GET /health bez pelnego WS connect. Uzywane z Setup screen.
  Future<bool> testConnection(String ip, int port) async {
    try {
      final res = await _dio.get<dynamic>(
        'http://$ip:$port/health',
        options: Options(responseType: ResponseType.plain),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[StationClient] testConnection fail: $e');
      return false;
    }
  }

  Future<void> connect() async {
    final ip = _ip;
    if (ip == null || ip.isEmpty) return;
    if (_state == StationConnState.connecting ||
        _state == StationConnState.connected) {
      return;
    }

    _setState(StationConnState.connecting);
    _lastError = null;

    try {
      // IOWebSocketChannel z timeoutem.
      final ws = await WebSocket.connect(wsUrl)
          .timeout(const Duration(seconds: 5));
      final ch = IOWebSocketChannel(ws);
      _channel = ch;

      _sub = ch.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: (Object e) {
          debugPrint('[StationClient] WS error: $e');
          _lastError = e.toString();
          _onDisconnected();
        },
        cancelOnError: true,
      );

      _setState(StationConnState.connected);
      _reconnectAttempts = 0;
      debugPrint('[StationClient] Connected $wsUrl');

      // Ping co 20s zeby wykryc zerwane polaczenie.
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        send({'type': WireMsg.ping});
      });

      // Status push co 30s (bateria/dysk) - Station pokazuje w debug panelu.
      _statusTimer?.cancel();
      _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _pushStatus();
      });
      // I od razu pierwszy push.
      unawaited(_pushStatus());
    } catch (e) {
      debugPrint('[StationClient] connect fail: $e');
      _lastError = e.toString();
      _setState(StationConnState.error);
      _scheduleReconnect();
    }
  }

  /// Wysle recorder_status - bateria i wolny dysk.
  /// Na Android potrzebujemy platform channel dla baterii, na razie
  /// podajemy null jesli niedostepne (Station pokazuje "-").
  Future<void> _pushStatus() async {
    try {
      final battery = await _probeBatteryPct();
      final disk = await _probeDiskFreeGb();
      _lastBatteryPct = battery;
      _lastDiskFreeGb = disk;
      send({
        'type': WireMsg.recorderStatus,
        if (battery != null) 'battery': battery,
        if (disk != null) 'disk_free_gb': disk,
      });
    } catch (e) {
      debugPrint('[StationClient] _pushStatus err: $e');
    }
  }

  /// Placeholder - battery_plus package moze to dostarczyc pozniej.
  /// Na razie zwraca null (Station wyswietli "-").
  Future<int?> _probeBatteryPct() async => _lastBatteryPct;

  /// Probe wolnego miejsca na docs directory. Fallback do null.
  Future<double?> _probeDiskFreeGb() async {
    // Placeholder - pozniej moze dsk_free albo platform channel.
    return _lastDiskFreeGb;
  }

  Future<void> disconnect({bool keepAutoReconnect = false}) async {
    _autoReconnect = keepAutoReconnect;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _statusTimer?.cancel();
    _statusTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    _setState(StationConnState.disconnected);
  }

  void _onDisconnected() {
    _channel = null;
    _sub?.cancel();
    _sub = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _statusTimer?.cancel();
    _statusTimer = null;
    _setState(StationConnState.disconnected);
    if (_autoReconnect) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (!_autoReconnect) return;
    // Exponential backoff: 1, 2, 5, 10, 30, 30, 30...
    final idx = _reconnectAttempts.clamp(0, _backoffSecondsSchedule.length - 1);
    final delay = Duration(seconds: _backoffSecondsSchedule[idx]);
    _reconnectAttempts++;
    debugPrint('[StationClient] Reconnect #$_reconnectAttempts '
        'za ${delay.inSeconds}s');
    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  void _onMessage(dynamic raw) {
    try {
      final Map<String, dynamic> msg = jsonDecode(raw as String);
      switch (msg['type']) {
        case WireMsg.startRecording:
          onStartRequested?.call();
          break;
        case WireMsg.stopRecording:
          onStopRequested?.call();
          break;
        case WireMsg.ping:
          send({'type': WireMsg.pong});
          break;
        case WireMsg.eventConfig:
          // Async handler - pobiera overlay/music lokalnie gdy sa dostarczone
          // jako URL-e (Station na innym urzadzeniu, lokalne sciezki Stationa
          // tutaj nie istnieja). Lapiemy bledy z future zeby pokazac co
          // wali - unawaited by default polyka bledy.
          _handleEventConfig(msg).catchError((Object e, StackTrace st) {
            debugPrint('[StationClient] eventConfig handler error: $e\n$st');
          });
          break;
        default:
          debugPrint('[StationClient] Unknown msg: ${msg['type']}');
      }
    } catch (e, st) {
      // Log raw bez sensitywnych danych (skroc) zeby zobaczyc co wali.
      final preview = (raw is String ? raw : raw.toString());
      final short = preview.length > 200
          ? '${preview.substring(0, 200)}...<${preview.length} chars>'
          : preview;
      debugPrint('[StationClient] parse error: $e\nraw=$short\n$st');
    }
  }

  Future<void> _handleEventConfig(Map<String, dynamic> msg) async {
    final cfg = EventConfig.fromJson(msg);

    // Immediately set lastEventConfig z sciezkami ze Stationa (tam gdzie
    // istnieja na naszym urzadzeniu bedzie dzialac, tam gdzie nie - fallback
    // na null i skip). Robimy to przed downloadem zeby uniknac race:
    // Recorder laczy sie, dostaje event_config, user szybko klika record
    // PRZED zakonczeniem downloadu -> bez tego lastEventConfig=null i
    // overlay sie pomija. Po downloadzie zaktualizujemy do lokalnych plikow.
    String? overlayLocal = cfg.overlayPath;
    String? musicLocal = cfg.musicPath;
    if (overlayLocal != null && !File(overlayLocal).existsSync()) {
      overlayLocal = null;
    }
    if (musicLocal != null && !File(musicLocal).existsSync()) {
      musicLocal = null;
    }

    // Sprawdz czy mamy juz cache z poprzedniego downloadu (urlHash ->
    // ten sam plik). Jesli tak - uzyj od razu, bez await.
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

    // Set lastEventConfig z tym co mamy (sciezki moga byc jeszcze null dla
    // pierwszego event_config po instalacji).
    var finalCfg = cfg.copyWith(
      overlayPath: overlayLocal,
      musicPath: musicLocal,
    );
    _lastEventConfig = finalCfg;
    _applyRecordingParams(finalCfg);
    onEventConfig?.call(finalCfg);
    debugPrint('[StationClient] Event config (eager): ${finalCfg.eventName} '
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
      debugPrint('[StationClient] Event config (downloaded): '
          'overlay=${finalCfg.overlayPath != null} '
          'music=${finalCfg.musicPath != null}');
    }
  }

  /// Sprawdza czy asset dla danego URL jest juz w cache lokalnym.
  /// Zwraca sciezke jesli tak, null gdy brak. Synchroniczne zeby uniknac
  /// await przy pierwszym set lastEventConfig.
  String? _cachedAssetPath(String url, String label) {
    try {
      // path_provider getApplicationDocumentsDirectory jest async - wiec
      // robimy check sync tylko gdy znamy sciezke. Zapamietamy w _docsDir
      // przy pierwszym download.
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

  String? _docsDir;

  /// Pobiera URL backendu do docs/event_assets/<hash>.bin. Cache keyed by
  /// URL - ten sam URL = ten sam plik (skip re-download). Plik zachowany
  /// miedzy sesjami Recorder.
  Future<String?> _downloadEventAsset(String url, String label) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _docsDir = dir.path; // cache dla sync _cachedAssetPath
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
      debugPrint('[StationClient] Downloaded $label from $url '
          '-> ${target.path} (${await target.length()} bytes)');
      return target.path;
    } catch (e) {
      debugPrint('[StationClient] download $label fail: $e');
      return null;
    }
  }

  void send(Map<String, dynamic> msg) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(msg));
    } catch (e) {
      debugPrint('[StationClient] send error: $e');
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
          debugPrint('[StationClient] resolution z Station -> ${target.name}');
        }
      }
      if (cfg.stabilize != null) {
        await _store.saveStabilize(cfg.stabilize!);
        debugPrint('[StationClient] stabilize z Station -> ${cfg.stabilize}');
      }
      // TODO: saveVideoDuration / saveSlowmo / saveRotation jesli SettingsStore
      // rozszerzymy. Na razie Recorder ma tylko resolution + mode + stabilize.
    } catch (e) {
      debugPrint('[StationClient] _applyRecordingParams error: $e');
    }
  }

  void sendRecordingStarted() =>
      send({'type': WireMsg.recordingStarted});

  void sendRecordingProgress(double progress) =>
      send({'type': WireMsg.recordingProgress, 'progress': progress});

  void sendRecordingStopped() =>
      send({'type': WireMsg.recordingStopped});

  void sendProcessingProgress(double progress) =>
      send({'type': WireMsg.processingProgress, 'progress': progress});

  void sendProcessingDone() =>
      send({'type': WireMsg.processingDone});

  void sendUploadProgress(double progress) =>
      send({'type': WireMsg.uploadProgress, 'progress': progress});

  void sendError(String message) =>
      send({'type': WireMsg.error, 'message': message});

  /// Upload pliku mp4 do Station. Zwraca true jesli OK.
  Future<bool> uploadVideo(String videoPath) async {
    if (!isConnected) return false;
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        debugPrint('[StationClient] upload: file missing $videoPath');
        return false;
      }
      final bytes = await file.readAsBytes();
      final filename = p.basename(videoPath);

      final res = await _dio.post<dynamic>(
        '$httpBaseUrl/upload',
        data: bytes,
        options: Options(
          headers: {
            'Content-Type': 'video/mp4',
            'Content-Length': bytes.length,
            'X-Filename': filename,
          },
          responseType: ResponseType.plain,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            // Station jest w stanie `transfer` podczas uploadu - wysylamy
            // upload_progress, nie processing_progress.
            sendUploadProgress(sent / total);
          }
        },
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[StationClient] upload error: $e');
      sendError('Upload failed: $e');
      return false;
    }
  }

  void _setState(StationConnState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
