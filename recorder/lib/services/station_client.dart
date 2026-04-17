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

  StationConnState _state = StationConnState.disconnected;
  String? _ip;
  int _port = 8080;
  String? _lastError;
  bool _autoReconnect = true;

  /// Callback: Station prosi o start nagrywania.
  void Function()? onStartRequested;

  /// Callback: Station prosi o manualny stop.
  void Function()? onStopRequested;

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
      debugPrint('[StationClient] Connected $wsUrl');

      // Ping co 20s zeby wykryc zerwane polaczenie.
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        send({'type': WireMsg.ping});
      });
    } catch (e) {
      debugPrint('[StationClient] connect fail: $e');
      _lastError = e.toString();
      _setState(StationConnState.error);
      _scheduleReconnect();
    }
  }

  Future<void> disconnect({bool keepAutoReconnect = false}) async {
    _autoReconnect = keepAutoReconnect;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
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
    _setState(StationConnState.disconnected);
    if (_autoReconnect) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (!_autoReconnect) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('[StationClient] Reconnecting...');
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
            sendProcessingProgress(sent / total);
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
