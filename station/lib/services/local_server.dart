import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'wire_protocol.dart';

/// Lokalny HTTP + WebSocket serwer na Tab A11+.
/// - `GET /ws` - WebSocket do real-time komunikacji (Recorder klient)
/// - `POST /upload` - upload gotowego filmu (raw body = mp4)
///
/// Eventy z Recorder sa tlumaczone na callbacki dla AppStateMachine.
class LocalServer extends ChangeNotifier {
  LocalServer({this.port = 8080});

  final int port;

  HttpServer? _server;
  WebSocketChannel? _recorderChannel;
  String? _localIp;
  String? _lastError;

  /// Callbacks ustawiane przez AppStateMachine. Brak -> ignoruj event.
  void Function()? onRecordingStarted;
  void Function(double progress)? onRecordingProgress;
  void Function()? onRecordingStopped;
  void Function(double progress)? onProcessingProgress;
  void Function()? onProcessingDone;
  void Function(double progress)? onUploadProgress;
  void Function(String path)? onVideoReceived;
  void Function(String message)? onRemoteError;

  bool get isRunning => _server != null;
  bool get isRecorderConnected => _recorderChannel != null;
  String? get localIp => _localIp;
  String? get lastError => _lastError;
  String get webSocketUrl =>
      'ws://${_localIp ?? "0.0.0.0"}:$port/ws';
  String get uploadUrl => 'http://${_localIp ?? "0.0.0.0"}:$port/upload';

  Future<void> start() async {
    if (_server != null) return;

    try {
      _localIp = await _detectLocalIp();

      final router = Router()
        ..get('/health', _handleHealth)
        ..get('/ws', webSocketHandler(_handleSocket))
        ..post('/upload', _handleUpload);

      _server = await shelf_io.serve(
        router.call,
        InternetAddress.anyIPv4,
        port,
      );
      _lastError = null;
      debugPrint('[LocalServer] Listening on $_localIp:$port');
      notifyListeners();
    } catch (e, st) {
      _lastError = e.toString();
      debugPrint('[LocalServer] start error: $e\n$st');
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _recorderChannel?.sink.close();
    _recorderChannel = null;
    notifyListeners();
  }

  Future<String?> _detectLocalIp() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      if (ip != null && ip.isNotEmpty) return ip;
    } catch (_) {}
    // Fallback - pierwsza niedlugopetelnowa IPv4.
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Health check - Recorder moze testowac polaczenie z Setup screen.
  Response _handleHealth(Request req) {
    return Response.ok(
      jsonEncode({
        'app': 'akces_booth_station',
        'ready': true,
        'recorderConnected': isRecorderConnected,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Jeden Recorder na raz. Stary kanal zamykamy.
  void _handleSocket(WebSocketChannel channel, String? protocol) {
    debugPrint('[LocalServer] Recorder connected');
    _recorderChannel?.sink.close();
    _recorderChannel = channel;
    notifyListeners();

    channel.stream.listen(
      _onMessage,
      onDone: () {
        debugPrint('[LocalServer] Recorder disconnected');
        if (_recorderChannel == channel) {
          _recorderChannel = null;
          notifyListeners();
        }
      },
      onError: (Object e) {
        debugPrint('[LocalServer] WS error: $e');
        if (_recorderChannel == channel) {
          _recorderChannel = null;
          notifyListeners();
        }
      },
    );
  }

  void _onMessage(dynamic raw) {
    try {
      final Map<String, dynamic> msg = jsonDecode(raw as String);
      final type = msg['type'] as String?;
      switch (type) {
        case WireMsg.recordingStarted:
          onRecordingStarted?.call();
          break;
        case WireMsg.recordingProgress:
          onRecordingProgress?.call((msg['progress'] as num).toDouble());
          break;
        case WireMsg.recordingStopped:
          onRecordingStopped?.call();
          break;
        case WireMsg.processingProgress:
          onProcessingProgress?.call((msg['progress'] as num).toDouble());
          break;
        case WireMsg.processingDone:
          onProcessingDone?.call();
          break;
        case WireMsg.uploadProgress:
          onUploadProgress?.call((msg['progress'] as num).toDouble());
          break;
        case WireMsg.error:
          onRemoteError?.call(msg['message']?.toString() ?? 'Unknown error');
          break;
        case WireMsg.pong:
          // ignorujemy
          break;
        case WireMsg.ping:
          // Odsylamy pong - Recorder sprawdza ze zyjemy.
          sendToRecorder({'type': WireMsg.pong});
          break;
        default:
          debugPrint('[LocalServer] Unknown msg type: $type');
      }
    } catch (e) {
      debugPrint('[LocalServer] _onMessage parse error: $e');
    }
  }

  /// Wysyla komende do Recorder. No-op jesli brak polaczenia.
  void sendToRecorder(Map<String, dynamic> message) {
    final ch = _recorderChannel;
    if (ch == null) {
      debugPrint('[LocalServer] sendToRecorder: no client (drop $message)');
      return;
    }
    try {
      ch.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('[LocalServer] send error: $e');
    }
  }

  /// POST /upload - raw mp4 w body, X-Filename w headers.
  Future<Response> _handleUpload(Request req) async {
    try {
      final bytes = await req.read().fold<List<int>>(
            <int>[],
            (acc, chunk) => acc..addAll(chunk),
          );
      final filename = req.headers['x-filename'] ??
          'video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final dir = await getApplicationDocumentsDirectory();
      final rxDir = Directory(p.join(dir.path, 'received'));
      if (!await rxDir.exists()) {
        await rxDir.create(recursive: true);
      }
      final target = File(p.join(rxDir.path, filename));
      await target.writeAsBytes(bytes);

      debugPrint('[LocalServer] Received ${bytes.length} bytes -> ${target.path}');
      onVideoReceived?.call(target.path);

      return Response.ok(
        jsonEncode({
          'status': 'ok',
          'path': target.path,
          'size': bytes.length,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      debugPrint('[LocalServer] upload error: $e\n$st');
      return Response.internalServerError(body: 'upload failed: $e');
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
