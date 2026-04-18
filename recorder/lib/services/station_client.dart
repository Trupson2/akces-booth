import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'settings_store.dart';
import 'wire_protocol.dart';

/// Konfig eventu przyslany ze Station (Sesja 7).
class EventConfig {
  EventConfig({
    required this.eventId,
    required this.eventName,
    this.overlayPath,
    this.musicPath,
    this.textTop,
    this.textBottom,
  });

  final int eventId;
  final String eventName;
  final String? overlayPath;
  final String? musicPath;
  final String? textTop;
  final String? textBottom;

  factory EventConfig.fromJson(Map<String, dynamic> j) => EventConfig(
        eventId: (j['event_id'] as num?)?.toInt() ?? 0,
        eventName: j['event_name']?.toString() ?? '',
        overlayPath: j['overlay_path']?.toString(),
        musicPath: j['music_path']?.toString(),
        textTop: j['text_top']?.toString(),
        textBottom: j['text_bottom']?.toString(),
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
          final cfg = EventConfig.fromJson(msg);
          _lastEventConfig = cfg;
          debugPrint('[StationClient] Event config: ${cfg.eventName}');
          onEventConfig?.call(cfg);
          break;
        default:
          debugPrint('[StationClient] Unknown msg: ${msg['type']}');
      }
    } catch (e) {
      debugPrint('[StationClient] parse error: $e');
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
