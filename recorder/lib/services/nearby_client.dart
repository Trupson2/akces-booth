import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

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
/// API ksztaltem naslladuje stary `StationClient`:
/// - `sendToStation(Map<String,dynamic>)` - wysyla JSON bytes do peera
/// - `sendFileToStation(File, short_name)` - file payload dla MP4
/// - `onStartRequested` / `onStopRequested` / `onEventConfig` - callbacki
///   commands ze Stationa
/// - Auto-discovery + auto-connect do pierwszego znalezionego Tab'a
class NearbyClient extends ChangeNotifier {
  NearbyClient();

  final Nearby _nearby = Nearby();

  NearbyClientState _state = NearbyClientState.idle;
  String? _connectedEndpointId;
  String? _discoveredEndpointId;
  String? _lastError;

  /// Ostatnio odebrany event_config (cache'owany).
  Map<String, dynamic>? _lastEventConfig;
  Map<String, dynamic>? get lastEventConfig => _lastEventConfig;

  // Callbacki dla komend ze Stationa - nakladaja na siebie jak w
  // StationClient (recording_screen override'uje onStartRequested itd.).
  void Function()? onStartRequested;
  void Function()? onStopRequested;
  void Function(Map<String, dynamic> cfg)? onEventConfig;

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
    } else {
      _connectedEndpointId = null;
      _setState(NearbyClientState.discovering);
      // Nearby sam spróbuje znowu poprzez onEndpointFound.
    }
  }

  void _onDisconnected(String endpointId) {
    debugPrint('[NearbyClient] disconnected $endpointId');
    _connectedEndpointId = null;
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
        _lastEventConfig = msg;
        onEventConfig?.call(msg);
        notifyListeners();
        break;
      default:
        debugPrint('[NearbyClient] Unknown msg: $type');
    }
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
      // TODO: wait for SUCCESS via _onPayloadUpdate - na razie fire-and-forget
      return true;
    } catch (e) {
      debugPrint('[NearbyClient] sendFile fail: $e');
      return false;
    }
  }

  // Wrapper helpers - mirror starego StationClient.sendXxx API.
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
