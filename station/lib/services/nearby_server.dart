import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'logger.dart';
import 'wire_protocol.dart';

/// Prefix Service ID - unikalny identyfikator apki (nie konkretnego booth).
/// Zmien `.v2` suffix przy zmianie protokolu wymagajacej reinstall.
///
/// Pelny serviceId = `$_kServiceIdPrefix.<boothCode>`. BoothCode zapewnia
/// ze Recorder widzi tylko swoj Station - dwa boothy obok siebie nie mixuja.
const String _kServiceIdPrefix = 'pl.akces360.booth.nearby.v1';

/// Nazwa widoczna po stronie Recordera w discovery.
const String _kAdvertiserName = 'AkcesBooth-Station';

String _serviceIdFor(String boothCode) => '$_kServiceIdPrefix.$boothCode';

/// Stan polaczenia - pojedynczy peer Recorder (P2P_POINT_TO_POINT).
enum NearbyConnState {
  idle,
  advertising,
  connectingRequest,
  connected,
  error,
}

/// Station-side Nearby Connections transport.
///
/// Rola: **Advertiser**. Tab siedzi w tle anoncujac `_kServiceId`.
/// Recorder (Discoverer) znajduje i wysyla connection request. Auto-accept
/// bo to trusted device (jedna para Tab+OP13 per booth).
///
/// API ksztaltem naslladuje stary `LocalServer` zeby Etap 3 byl swap
/// a nie refaktor wyzej:
/// - `sendToRecorder(Map<String,dynamic>)` - broadcast JSON bytes do peera
/// - `onRecordingStarted/Stopped`, `onProcessingProgress/Done`,
///   `onUploadProgress`, `onRemoteError` - typed callbacks jak w LocalServer
/// - `onBytesReceived` - generic callback dla nieznanych typow (debugowanie)
/// - `onFileReceived(filename, path, bytes)` - po file transfer (Etap 3)
/// - Status tracking: `lastRecorderBattery`, `lastRecorderDiskFreeGb`
///
/// Notes:
/// - Nearby.endpointId to ID per-session (nie trwale), ale mamy 1 peera
///   wiec trackujemy po prostu `_connectedEndpointId`.
/// - sendFilePayload uzywa auto-upgrade do WiFi Direct dla dużych plikow;
///   dla bytes zostaje BT (LTE wystarcza).
class NearbyServer extends ChangeNotifier {
  NearbyServer();

  final Nearby _nearby = Nearby();

  NearbyConnState _state = NearbyConnState.idle;
  String? _connectedEndpointId;
  String? _lastError;

  /// Aktualny booth code uzyty w serviceId. Zmieniany przez [restartWithCode]
  /// gdy user rotuje kod w Settings.
  String _boothCode = '';
  String get boothCode => _boothCode;
  String get serviceId => _serviceIdFor(_boothCode);

  /// Ostatnio zaraportowane przez Recorder (komunikat `recorder_status`).
  /// Null = jeszcze nic nie dotarlo.
  int? _lastRecorderBattery;
  double? _lastRecorderDiskFreeGb;

  int? get lastRecorderBattery => _lastRecorderBattery;
  double? get lastRecorderDiskFreeGb => _lastRecorderDiskFreeGb;

  /// Callback gdy Recorder (re)connects - use do push event_config od razu.
  void Function()? onRecorderConnect;

  /// Callback przy disconnect.
  void Function()? onRecorderDisconnect;

  /// Typed callbacks - mirror starego LocalServer (AppStateMachine podpina).
  void Function()? onRecordingStarted;
  void Function(double progress)? onRecordingProgress;
  void Function()? onRecordingStopped;
  void Function(double progress)? onProcessingProgress;
  void Function()? onProcessingDone;
  void Function(double progress)? onUploadProgress;
  void Function(String message)? onRemoteError;

  /// Generic fallback dla nieznanych typow (diagnostyka) - optional.
  void Function(Map<String, dynamic> msg)? onBytesReceived;

  /// Callback gdy plik przesylany (filename, filePath lokalny, size).
  /// Etap 3: wywolywany po SUCCESS z _onPayloadUpdate i przenoszeniu
  /// pliku do `received/`. Mirror LocalServer.onVideoReceived.
  void Function(String filename, String path, int bytes)? onFileReceived;

  /// FIFO queue pending short_name z prekursor msg `file_incoming`. Kazdy
  /// nowy FILE payload konsumuje pierwsza nazwe. Dla P2P 1:1 wystarczy -
  /// jeden Recorder wysyla po kolei.
  final List<String> _pendingFileNames = [];

  /// Map payload.id -> source (content URI na A11+, absolutna sciezka na
  /// A10-). Set na FILE payload init, read przy SUCCESS zeby znalezc plik
  /// do przeniesienia.
  final Map<int, String> _fileSources = {};

  /// Stan widoczny dla UI (idle/advertising/connected).
  NearbyConnState get state => _state;
  bool get isRecorderConnected => _state == NearbyConnState.connected;
  String? get lastError => _lastError;

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  /// Start advertising. Powinno byc wolane raz po permission check z
  /// aktualnym boothCode z SettingsStore.
  Future<void> start(String boothCode) async {
    if (boothCode.length != 4) {
      _setState(NearbyConnState.error,
          error: 'booth code invalid: "$boothCode"');
      return;
    }
    if (_state == NearbyConnState.advertising ||
        _state == NearbyConnState.connected) {
      if (boothCode == _boothCode) return; // juz chodzi z tym kodem
      // Inny kod - restart.
      await stop();
    }
    _boothCode = boothCode;
    try {
      final started = await _nearby.startAdvertising(
        _kAdvertiserName,
        Strategy.P2P_POINT_TO_POINT,
        serviceId: serviceId,
        onConnectionInitiated: _onConnInit,
        onConnectionResult: _onConnResult,
        onDisconnected: _onDisconnected,
      );
      if (started) {
        _setState(NearbyConnState.advertising);
        Log.i('NearbyServer',
            'advertising as $_kAdvertiserName (serviceId=$serviceId)');
      } else {
        _setState(NearbyConnState.error,
            error: 'startAdvertising returned false');
      }
    } catch (e, st) {
      Log.e('NearbyServer', 'start failed: $e\n$st');
      _setState(NearbyConnState.error, error: e.toString());
    }
  }

  /// Restart advertising z nowym boothCode (po zmianie w Settings).
  Future<void> restartWithCode(String newCode) async {
    Log.i('NearbyServer', 'restart with new code $newCode (was $_boothCode)');
    await stop();
    await start(newCode);
  }

  /// Stop - uzywane gdy app goes inactive/dispose.
  Future<void> stop() async {
    try {
      await _nearby.stopAllEndpoints();
      await _nearby.stopAdvertising();
    } catch (e) {
      debugPrint('[NearbyServer] stop err: $e');
    }
    _connectedEndpointId = null;
    _setState(NearbyConnState.idle);
  }

  // ------------------------------------------------------------------
  // Nearby callbacks
  // ------------------------------------------------------------------

  Future<void> _onConnInit(String endpointId, ConnectionInfo info) async {
    Log.i('NearbyServer',
        'conn init from $endpointId (${info.endpointName})');
    _setState(NearbyConnState.connectingRequest);
    // Auto-accept: jedna para Tab+OP13, bez pinu.
    try {
      await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: (id, payload) => _onPayload(id, payload),
        onPayloadTransferUpdate: (id, update) => _onPayloadUpdate(id, update),
      );
    } catch (e) {
      Log.e('NearbyServer', 'accept failed: $e');
      _setState(NearbyConnState.error, error: e.toString());
    }
  }

  void _onConnResult(String endpointId, Status status) {
    Log.i('NearbyServer',
        'conn result $endpointId -> ${status.toString()}');
    if (status == Status.CONNECTED) {
      _connectedEndpointId = endpointId;
      _setState(NearbyConnState.connected);
      try {
        onRecorderConnect?.call();
      } catch (e) {
        debugPrint('[NearbyServer] onConnect cb err: $e');
      }
    } else {
      _connectedEndpointId = null;
      _setState(NearbyConnState.advertising);
    }
  }

  void _onDisconnected(String endpointId) {
    Log.w('NearbyServer', 'disconnected $endpointId');
    if (_connectedEndpointId == endpointId) {
      _connectedEndpointId = null;
      try {
        onRecorderDisconnect?.call();
      } catch (_) {}
      _setState(NearbyConnState.advertising);
    }
  }

  /// Obsluga payload - bytes (JSON msg) lub file (MP4 upload).
  Future<void> _onPayload(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.BYTES) {
      try {
        final bytes = payload.bytes;
        if (bytes == null) return;
        final str = utf8.decode(bytes);
        final msg = jsonDecode(str) as Map<String, dynamic>;
        _handleMessage(msg);
      } catch (e) {
        Log.w('NearbyServer', 'bytes parse fail: $e');
      }
    } else if (payload.type == PayloadType.FILE) {
      // Nearby zapisuje plik w scoped storage. Na A11+ plugin wystawia
      // content URI (payload.uri), na A10- absolutna sciezka (filePath).
      // Preferujemy uri - to standardowy sposob A11+.
      // ignore: deprecated_member_use (filePath fallback dla starszych Androidow)
      final source = payload.uri ?? payload.filePath ?? '';
      if (source.isNotEmpty) {
        _fileSources[payload.id] = source;
      }
      Log.i('NearbyServer',
          'file payload ${payload.id} started (source=$source)');
    }
  }

  /// Routing wiadomosci z Recorder - mirror LocalServer._onMessage.
  /// Dispatch do typed callbacks; nieznane typy -> onBytesReceived fallback.
  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    switch (type) {
      case WireMsg.recorderStatus:
        final battery = msg['battery'];
        final disk = msg['disk_free_gb'];
        if (battery is num) _lastRecorderBattery = battery.toInt();
        if (disk is num) _lastRecorderDiskFreeGb = disk.toDouble();
        notifyListeners();
        break;
      case WireMsg.recordingStarted:
        onRecordingStarted?.call();
        break;
      case WireMsg.recordingProgress:
        final p = msg['progress'];
        if (p is num) onRecordingProgress?.call(p.toDouble());
        break;
      case WireMsg.recordingStopped:
        onRecordingStopped?.call();
        break;
      case WireMsg.processingProgress:
        final p = msg['progress'];
        if (p is num) onProcessingProgress?.call(p.toDouble());
        break;
      case WireMsg.processingDone:
        onProcessingDone?.call();
        break;
      case WireMsg.uploadProgress:
        final p = msg['progress'];
        if (p is num) onUploadProgress?.call(p.toDouble());
        break;
      case WireMsg.error:
        onRemoteError?.call(msg['message']?.toString() ?? 'Unknown error');
        break;
      case WireMsg.pong:
        // Nearby ma wewnetrzny keepalive wiec pong legacy, ignorujemy.
        break;
      case WireMsg.ping:
        // Legacy - zachowujemy ze odsylamy pong, ale Nearby keepalive
        // robi to za nas. W Etap 3 Recorder juz nie bedzie wysylal.
        sendToRecorder({'type': WireMsg.pong});
        break;
      case 'file_incoming':
        // Prekursor przed sendFilePayload - kolejkujemy short_name zeby
        // _onPayloadUpdate wiedzial jak nazwac plik po SUCCESS.
        final shortName = msg['short_name']?.toString();
        if (shortName != null && shortName.isNotEmpty) {
          _pendingFileNames.add(shortName);
        }
        final size = msg['size'];
        Log.d('NearbyServer',
            'file_incoming $shortName (${size}B) queue=${_pendingFileNames.length}');
        break;
      default:
        debugPrint('[NearbyServer] Unknown msg type: $type');
        try {
          onBytesReceived?.call(msg);
        } catch (e) {
          debugPrint('[NearbyServer] onBytesReceived cb err: $e');
        }
    }
  }

  Future<void> _onPayloadUpdate(
      String endpointId, PayloadTransferUpdate update) async {
    // BYTES SUCCESS/FAILURE zostaje no-op (dostarczenie potwierdzone przez
    // nasz handshake message-level). Tu obsługujemy tylko FILE transfer.
    final source = _fileSources.remove(update.id);
    if (source == null) {
      // Nie znalezlismy mapowania -> to byl BYTES lub nieoczekiwany payload.
      if (update.status == PayloadStatus.FAILURE) {
        Log.w('NearbyServer', 'payload ${update.id} FAILURE (bytes?)');
      }
      return;
    }

    if (update.status == PayloadStatus.SUCCESS) {
      final shortName = _pendingFileNames.isNotEmpty
          ? _pendingFileNames.removeAt(0)
          : 'video_${update.id}.mp4';
      final bytes = update.bytesTransferred;
      Log.i('NearbyServer',
          'file payload ${update.id} SUCCESS ($bytes B) -> $shortName');

      try {
        final destDir = await receivedDir();
        final destPath = p.join(destDir, shortName);
        String? finalPath;

        if (source.startsWith('content://')) {
          // A11+: plugin helper otwiera ContentResolver.openInputStream(uri),
          // kopiuje do newPath, usuwa original przez content resolver.
          final ok = await _nearby.copyFileAndDeleteOriginal(source, destPath);
          if (ok) {
            finalPath = destPath;
          } else {
            Log.w('NearbyServer',
                'copyFileAndDeleteOriginal fail for uri=$source');
          }
        } else {
          // A10-: absolutna sciezka, rename (atomic na tym samym FS) albo
          // copy+delete jako fallback.
          final tempFile = File(source);
          if (!await tempFile.exists()) {
            Log.w('NearbyServer', 'temp file missing: $source');
            return;
          }
          try {
            final renamed = await tempFile.rename(destPath);
            finalPath = renamed.path;
          } on FileSystemException {
            final copied = await tempFile.copy(destPath);
            try {
              await tempFile.delete();
            } catch (_) {}
            finalPath = copied.path;
          }
        }

        if (finalPath != null) {
          Log.i('NearbyServer', 'file saved: $finalPath');
          try {
            onFileReceived?.call(shortName, finalPath, bytes);
          } catch (e) {
            Log.e('NearbyServer', 'onFileReceived cb err: $e');
          }
        }
      } catch (e, st) {
        Log.e('NearbyServer', 'file move error: $e\n$st');
      }
    } else if (update.status == PayloadStatus.FAILURE) {
      Log.w('NearbyServer', 'file payload ${update.id} FAILURE');
      // Prekursor (short_name) konsumujemy zeby nie zostawic kolejki brudnej.
      if (_pendingFileNames.isNotEmpty) _pendingFileNames.removeAt(0);
      // Cleanup - przy URI plugin sam ogarnia via ContentResolver, przy
      // filePath probujemy usunac plik.
      if (!source.startsWith('content://')) {
        try {
          final f = File(source);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }

  // ------------------------------------------------------------------
  // Public send API (mirror starego LocalServer.sendToRecorder)
  // ------------------------------------------------------------------

  /// Wysyla JSON msg do Recordera (bytes payload).
  /// Silently drops jesli brak polaczenia (LocalServer tez tak robil).
  Future<void> sendToRecorder(Map<String, dynamic> msg) async {
    final id = _connectedEndpointId;
    if (id == null || _state != NearbyConnState.connected) {
      debugPrint('[NearbyServer] sendToRecorder: no peer (drop $msg)');
      return;
    }
    try {
      final bytes = utf8.encode(jsonEncode(msg));
      await _nearby.sendBytesPayload(id, bytes);
    } catch (e) {
      Log.w('NearbyServer', 'sendBytes fail: $e');
    }
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  void _setState(NearbyConnState s, {String? error}) {
    _state = s;
    _lastError = error;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// Pomocnik zeby inne moduly mogly wywolac get dir receive.
  static Future<String> receivedDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'received'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }
}
