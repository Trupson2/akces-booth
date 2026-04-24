import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'logger.dart';

/// Lokalny HTTP serwer na Tab A11+.
///
/// Etap 3 Nearby: WS i /upload zniknely - caly Tab<->OP13 idzie przez
/// Nearby Connections. Tutaj zostaje TYLKO `/local/<short_id>` zeby PendingUploads
/// mial link do QR gdy backend offline (gosc pobiera film bezposrednio z Tabu).
///
/// Endpoints:
/// - `GET /health` - diagnostyka
/// - `GET /local/<short_id>` - serwuje mp4 z registerLocalVideo mapy
class LocalServer extends ChangeNotifier {
  LocalServer({this.port = 8080});

  final int port;

  HttpServer? _server;

  String? _localIp;
  String? _lastError;

  /// Map short_id -> sciezka lokalnego pliku. Serwujemy to pod /local/<id>
  /// jako fallback gdy upload do RPi niedostepny.
  final Map<String, String> _localVideos = {};

  bool get isRunning => _server != null;
  String? get localIp => _localIp;
  String? get lastError => _lastError;

  /// Publiczny URL do pobrania lokalnego filmu (do QR gdy offline).
  String localVideoUrl(String shortId) =>
      'http://${_localIp ?? "0.0.0.0"}:$port/local/$shortId';

  /// Zarejestruj plik do lokalnego serwowania - wywolywane przez state machine
  /// gdy upload do backendu fail i trzeba wygenerowac QR z lokalnym URL.
  void registerLocalVideo(String shortId, String filePath) {
    _localVideos[shortId] = filePath;
    Log.i('LocalServer', 'registered local video $shortId -> $filePath');
  }

  /// Wyczysc lokalny plik po udanym upload do backendu (oszczedzanie miejsca).
  void unregisterLocalVideo(String shortId) {
    final removed = _localVideos.remove(shortId);
    if (removed != null) {
      Log.d('LocalServer', 'unregistered local video $shortId');
    }
  }

  Future<void> start() async {
    if (_server != null) return;

    try {
      _localIp = await _detectLocalIp();

      final router = Router()
        ..get('/health', _handleHealth)
        ..get('/local/<short_id>', _handleLocalVideo);

      _server = await shelf_io.serve(
        router.call,
        InternetAddress.anyIPv4,
        port,
      );
      _lastError = null;
      debugPrint('[LocalServer] Listening on $_localIp:$port (local fallback only)');
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

  /// Health check - diagnostyka i monitoring.
  Response _handleHealth(Request req) {
    return Response.ok(
      jsonEncode({
        'app': 'akces_booth_station',
        'ready': true,
        'local_videos': _localVideos.length,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// GET /local/<short_id> - serwuje film bezposrednio z Tabu (offline fallback).
  /// Uzywane gdy RPi niedostepny - gosc pobiera film lokalnie. QR linkuje tutaj.
  Future<Response> _handleLocalVideo(Request req, String shortId) async {
    final path = _localVideos[shortId];
    if (path == null) {
      Log.w('LocalServer', 'local video not found: $shortId');
      return Response.notFound('Film nie znaleziony');
    }
    final file = File(path);
    if (!await file.exists()) {
      Log.w('LocalServer', 'local video file missing: $path');
      _localVideos.remove(shortId);
      return Response.notFound('Plik nie istnieje');
    }
    try {
      final bytes = await file.readAsBytes();
      Log.d('LocalServer', 'serving local $shortId (${bytes.length}B)');
      return Response.ok(
        bytes,
        headers: {
          'Content-Type': 'video/mp4',
          'Content-Length': bytes.length.toString(),
          'Content-Disposition':
              'attachment; filename="akces-booth-$shortId.mp4"',
          'Cache-Control': 'no-cache',
        },
      );
    } catch (e) {
      Log.e('LocalServer', 'local serve error', error: e);
      return Response.internalServerError(body: 'read failed');
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
