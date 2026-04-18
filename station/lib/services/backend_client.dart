import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Klient REST do backendu (Flask na RPi albo localhost w dev).
///
/// Tylko publicznie dostepne endpointy:
/// - GET /api/events/active - pobierz aktywny event + URLs overlay/music
/// - GET /api/events/overlay/{id} - pobierz PNG overlay (do cache)
/// - GET /api/events/music/{id} - pobierz MP3 muzyki (do cache)
/// - POST /api/upload - upload filmu po akceptacji gosc'a
class BackendClient {
  BackendClient();

  // Klucze w SharedPreferences dla persystencji URL i API key.
  static const _kBaseUrl = 'backend.base_url';
  static const _kApiKey = 'backend.api_key';

  String _baseUrl = '';
  String _apiKey = '';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(minutes: 5),
  ));

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = (prefs.getString(_kBaseUrl) ?? '').trim();
    _apiKey = (prefs.getString(_kApiKey) ?? '').trim();
  }

  Future<void> saveConfig({required String baseUrl, String? apiKey}) async {
    _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (apiKey != null) _apiKey = apiKey.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, _baseUrl);
    await prefs.setString(_kApiKey, _apiKey);
  }

  /// Test polaczenia - GET /healthz.
  Future<bool> testConnection() async {
    if (!isConfigured) return false;
    try {
      final r = await _dio.get<dynamic>('$_baseUrl/healthz');
      return r.statusCode == 200;
    } catch (e) {
      debugPrint('[BackendClient] health fail: $e');
      return false;
    }
  }

  /// Pobierz aktywny event (public endpoint).
  Future<BackendEvent?> getActiveEvent() async {
    if (!isConfigured) return null;
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/api/events/active',
      );
      if (r.statusCode == 200 && r.data?['active'] == true) {
        final raw = r.data?['event'] as Map<String, dynamic>?;
        if (raw == null) return null;
        return BackendEvent.fromJson(raw);
      }
      return null;
    } catch (e) {
      debugPrint('[BackendClient] getActiveEvent fail: $e');
      return null;
    }
  }

  /// Pobiera asset (overlay/music) do lokalnego cache. Zwraca sciezke pliku.
  Future<String?> downloadAsset(String url, String cacheKey) async {
    if (url.isEmpty) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(p.join(dir.path, 'backend_cache'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      final target = File(p.join(cacheDir.path, cacheKey));

      if (await target.exists() && await target.length() > 0) {
        return target.path; // cached
      }

      await _dio.download(url, target.path);
      return target.path;
    } catch (e) {
      debugPrint('[BackendClient] downloadAsset fail: $e');
      return null;
    }
  }

  /// Upload mp4 do backendu. Zwraca short_id + public_url albo null.
  Future<BackendUploadResult?> uploadVideo({
    required String videoPath,
    bool publishToFacebook = false,
    void Function(double progress)? onProgress,
  }) async {
    if (!isConfigured) return null;
    final file = File(videoPath);
    if (!await file.exists()) return null;

    try {
      final bytes = await file.readAsBytes();
      final filename = p.basename(videoPath);

      final r = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/api/upload',
        data: bytes,
        options: Options(
          headers: {
            'Content-Type': 'video/mp4',
            'X-API-Key': _apiKey,
            'X-Filename': filename,
            'X-Publish-Facebook': publishToFacebook ? '1' : '0',
          },
        ),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );

      if (r.statusCode == 200) {
        return BackendUploadResult.fromJson(r.data ?? {});
      }
      return null;
    } catch (e) {
      debugPrint('[BackendClient] uploadVideo fail: $e');
      return null;
    }
  }
}

class BackendEvent {
  BackendEvent({
    required this.id,
    required this.name,
    this.eventDate,
    this.eventType,
    this.textTop,
    this.textBottom,
    this.accessKey,
    this.overlayId,
    this.musicId,
    this.overlayUrl,
    this.musicUrl,
    this.musicOffsetSec,
    this.musicOffsetMode,
    this.videoCount = 0,
  });

  final int id;
  final String name;
  final String? eventDate;
  final String? eventType;
  final String? textTop;
  final String? textBottom;
  final String? accessKey;
  final int? overlayId;
  final int? musicId;
  final String? overlayUrl;
  final String? musicUrl;
  final double? musicOffsetSec;
  final String? musicOffsetMode;
  final int videoCount;

  factory BackendEvent.fromJson(Map<String, dynamic> j) {
    return BackendEvent(
      id: (j['id'] as num).toInt(),
      name: j['name']?.toString() ?? '',
      eventDate: j['event_date']?.toString(),
      eventType: j['event_type']?.toString(),
      textTop: j['text_top']?.toString(),
      textBottom: j['text_bottom']?.toString(),
      accessKey: j['access_key']?.toString(),
      overlayId: j['overlay_id'] as int?,
      musicId: j['music_id'] as int?,
      overlayUrl: j['overlay_url']?.toString(),
      musicUrl: j['music_url']?.toString(),
      musicOffsetSec: (j['music_offset_sec'] as num?)?.toDouble(),
      musicOffsetMode: j['music_offset_mode']?.toString(),
      videoCount: (j['video_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class BackendUploadResult {
  BackendUploadResult({
    required this.shortId,
    required this.publicUrl,
    required this.qrCodeUrl,
    required this.fileSize,
  });

  final String shortId;
  final String publicUrl;
  final String qrCodeUrl;
  final int fileSize;

  factory BackendUploadResult.fromJson(Map<String, dynamic> j) {
    return BackendUploadResult(
      shortId: j['short_id']?.toString() ?? '',
      publicUrl: j['public_url']?.toString() ?? '',
      qrCodeUrl: j['qr_code_url']?.toString() ?? '',
      fileSize: (j['file_size'] as num?)?.toInt() ?? 0,
    );
  }
}
