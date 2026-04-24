import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'logger.dart';
import 'wire_protocol.dart';

/// Service ID - unikalny identyfikator naszej apki.
/// Zmien suffix na `.v2` przy zmianie protokolu wymagajacej reinstall.
const String _kServiceId = 'pl.akces360.booth.nearby.v1';

/// Nazwa widoczna po stronie Recordera w discovery.
const String _kAdvertiserName = 'AkcesBooth-Station';

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

  /// Ostatnio zakomunikowany "prekursor" dla file transfer (short_name, size).
  /// Po SUCCESS payload FILE - kojarzymy z tym prekursorem.
  /// Uzupelniane w Etap 3.
  String? _pendingFileShortName;
  int? _pendingFileSize;

  /// Stan widoczny dla UI (idle/advertising/connected).
  NearbyConnState get state => _state;
  bool get isRecorderConnected => _state == NearbyConnState.connected;
  String? get lastError => _lastError;

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  /// Start advertising. Powinno byc wolane raz po permission check.
  Future<void> start() async {
    if (_state == NearbyConnState.advertising ||
        _state == NearbyConnState.connected) {
      return;
    }
    try {
      final started = await _nearby.startAdvertising(
        _kAdvertiserName,
        Strategy.P2P_POINT_TO_POINT,
        serviceId: _kServiceId,
        onConnectionInitiated: _onConnInit,
        onConnectionResult: _onConnResult,
        onDisconnected: _onDisconnected,
      );
      if (started) {
        _setState(NearbyConnState.advertising);
        Log.i('NearbyServer', 'advertising as $_kAdvertiserName');
      } else {
        _setState(NearbyConnState.error,
            error: 'startAdvertising returned false');
      }
    } catch (e, st) {
      Log.e('NearbyServer', 'start failed: $e\n$st');
      _setState(NearbyConnState.error, error: e.toString());
    }
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
      // File path bedzie znany po _onPayloadUpdate SUCCESS.
      Log.i('NearbyServer',
          'file payload ${payload.id} started (dest=${payload.filePath})');
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
        // Prekursor przed sendFilePayload - zapisujemy kontekst dla
        // _onPayloadUpdate SUCCESS (Etap 3 pelna obsluga).
        _pendingFileShortName = msg['short_name']?.toString();
        final size = msg['size'];
        _pendingFileSize = size is num ? size.toInt() : null;
        Log.d('NearbyServer', 'file_incoming '
            '${_pendingFileShortName} (${_pendingFileSize}B)');
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
    // Nearby przenosi plik do temp path. Po SUCCESS musimy go przeniesc
    // do naszego katalogu `received/` zeby zachowac trwalosc.
    if (update.status == PayloadStatus.SUCCESS) {
      Log.i('NearbyServer',
          'payload ${update.id} SUCCESS (${update.bytesTransferred}B)');
      // TODO(Etap 3): plik payload - przeniesc z temp do received/,
      // wywolac onFileReceived(filename, path, bytes). Na razie zapisujemy
      // _pendingFileShortName/_pendingFileSize w _handleMessage (file_incoming
      // prekursor) i zostawiamy pelna logike dla Etap 3.
      _pendingFileShortName = null;
      _pendingFileSize = null;
    } else if (update.status == PayloadStatus.FAILURE) {
      Log.w('NearbyServer', 'payload ${update.id} FAILURE');
      _pendingFileShortName = null;
      _pendingFileSize = null;
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
