import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/recording_mode.dart';
import '../models/recording_resolution.dart';
import 'settings_store.dart';

/// Stan inicjalizacji serwisu kamery.
enum CameraInitStatus {
  idle,
  requestingPermission,
  permissionDenied,
  permissionPermanentlyDenied,
  initializing,
  ready,
  error,
}

/// Serwis zarzadzajacy CameraController, recordingiem i trybem FPS.
class CameraService extends ChangeNotifier {
  CameraService({SettingsStore? store}) : _store = store ?? SettingsStore();

  final SettingsStore _store;

  static const _diagChannel = MethodChannel('akces_booth/camera_diag');

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CameraDescription? _backCamera;

  CameraInitStatus _status = CameraInitStatus.idle;
  RecordingMode _mode = RecordingMode.fps60;
  RecordingResolution _resolution = RecordingResolution.fullHd;
  double _zoomLevel = 1.0;
  bool _isRecording = false;
  bool _highFpsDegraded = false;
  bool _resolutionDegraded = false;
  String? _errorMessage;
  String? _lastRecordingPath;
  DateTime? _recordingStartTime;

  CameraController? get controller => _controller;
  CameraInitStatus get status => _status;
  RecordingMode get mode => _mode;
  RecordingResolution get resolution => _resolution;
  bool get isInitialized =>
      _status == CameraInitStatus.ready && (_controller?.value.isInitialized ?? false);
  bool get isRecording => _isRecording;

  /// True jesli user wybral slowMo120 ale urzadzenie nie wspiera - dzialamy na 30 fps.
  bool get highFpsDegraded => _highFpsDegraded;

  /// True jesli wybrana rozdzielczosc nie byla wspierana - zrobilismy fallback.
  bool get resolutionDegraded => _resolutionDegraded;
  String? get errorMessage => _errorMessage;
  String? get lastRecordingPath => _lastRecordingPath;

  Duration get recordingDuration => _recordingStartTime == null
      ? Duration.zero
      : DateTime.now().difference(_recordingStartTime!);

  void _set(CameraInitStatus s, {String? error}) {
    _status = s;
    _errorMessage = error;
    notifyListeners();
  }

  /// Inicjalizuje kamere: sprawdza uprawnienia i tworzy CameraController.
  Future<void> initialize() async {
    if (_status == CameraInitStatus.initializing) return;

    _set(CameraInitStatus.requestingPermission);

    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();

    if (!camera.isGranted || !mic.isGranted) {
      if (camera.isPermanentlyDenied || mic.isPermanentlyDenied) {
        _set(CameraInitStatus.permissionPermanentlyDenied);
      } else {
        _set(CameraInitStatus.permissionDenied);
      }
      return;
    }

    _set(CameraInitStatus.initializing);

    try {
      // Zaladuj ostatnio wybrane ustawienia przed stworzeniem controllera.
      _mode = await _store.loadMode();
      _resolution = await _store.loadResolution();
      _zoomLevel = await _store.loadZoomLevel();

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _set(CameraInitStatus.error, error: 'Nie znaleziono zadnej kamery');
        return;
      }
      _backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      await _createController(_mode, _resolution);
      await _applyZoom(_zoomLevel);
      // Diagnostyka EIS - co tryb stabilizacji wspiera back camera
      // (native HAL). Logujemy przy starcie - przyda sie do decyzji
      // czy warto forkowac `camera_android_camerax` zeby wlaczyc
      // PREVIEW_STABILIZATION (API 33+).
      unawaited(_logStabilizationCapabilities());
      _set(CameraInitStatus.ready);
    } catch (e, st) {
      debugPrint('CameraService.initialize error: $e\n$st');
      _set(CameraInitStatus.error, error: e.toString());
    }
  }

  /// Tworzy nowy CameraController dla wybranego trybu i rozdzielczosci.
  /// Dla slow-mo probuje fps=120; przy fail fallback na 30fps.
  /// Dla 8K/4K probuje preset; przy fail fallback na nizsza rozdzielczosc.
  Future<void> _createController(
    RecordingMode mode,
    RecordingResolution resolution,
  ) async {
    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();

    final cam = _backCamera;
    if (cam == null) {
      throw StateError('Brak back camera');
    }

    _highFpsDegraded = false;
    _resolutionDegraded = false;

    Future<CameraController> build(ResolutionPreset preset, int? fps) async {
      final ctrl = CameraController(
        cam,
        preset,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.yuv420,
        fps: fps,
      );
      await ctrl.initialize();
      return ctrl;
    }

    // Resolution fallback chain: chosen -> 4K -> FullHD -> veryHigh
    final chain = <ResolutionPreset>[
      resolution.preset,
      if (resolution != RecordingResolution.uhd4k) ResolutionPreset.ultraHigh,
      if (resolution != RecordingResolution.fullHd) ResolutionPreset.veryHigh,
      ResolutionPreset.high,
    ];

    // 30 fps = default (null nie forsuje fps), 60/120 = explicit targetFps.
    final targetFps = mode == RecordingMode.normal ? null : mode.fps;

    CameraController? built;
    Object? lastError;
    for (int i = 0; i < chain.length; i++) {
      final preset = chain[i];
      try {
        built = await build(preset, targetFps);
        if (i > 0) {
          _resolutionDegraded = true;
          debugPrint(
              'Rozdzielczosc ${resolution.preset} nie wspierana, uzyto $preset');
        }
        break;
      } catch (e) {
        lastError = e;
        debugPrint('Preset $preset fail: $e');
      }
    }

    // Jesli fps 120 nie poszlo z zadnym presetem, sprobuj bez fps.
    if (built == null && targetFps != null) {
      _highFpsDegraded = true;
      for (final preset in chain) {
        try {
          built = await build(preset, null);
          if (preset != resolution.preset) _resolutionDegraded = true;
          break;
        } catch (e) {
          lastError = e;
        }
      }
    }

    if (built == null) {
      throw StateError('Nie udalo sie zbudowac CameraController: $lastError');
    }
    _controller = built;
  }

  /// Zmienia tryb nagrywania (rekreuje controller).
  Future<void> setMode(RecordingMode mode) async {
    if (mode == _mode && _controller != null) return;
    if (_isRecording) {
      debugPrint('Ignoruje setMode podczas nagrywania');
      return;
    }
    _mode = mode;
    await _store.saveMode(mode);
    _set(CameraInitStatus.initializing);
    try {
      await _createController(mode, _resolution);
      await _applyZoom(_zoomLevel);
      _set(CameraInitStatus.ready);
    } catch (e) {
      _set(CameraInitStatus.error, error: e.toString());
    }
  }

  /// Zmienia rozdzielczosc nagrania (rekreuje controller).
  Future<void> setResolution(RecordingResolution resolution) async {
    if (resolution == _resolution && _controller != null) return;
    if (_isRecording) {
      debugPrint('Ignoruje setResolution podczas nagrywania');
      return;
    }
    _resolution = resolution;
    await _store.saveResolution(resolution);
    _set(CameraInitStatus.initializing);
    try {
      await _createController(_mode, resolution);
      await _applyZoom(_zoomLevel);
      _set(CameraInitStatus.ready);
    } catch (e) {
      _set(CameraInitStatus.error, error: e.toString());
    }
  }

  /// Zastosuj zoom na biezacym CameraController. Clampuje do min/max kamery.
  /// Dla 0.6x na OP13 przelacza na ultrawide lens (wiecej kadru). Gdy kamera
  /// nie wspiera danego zoom lvl -> uzywa najblizszej wartosci.
  Future<void> _applyZoom(double requested) async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    try {
      final min = await ctrl.getMinZoomLevel();
      final max = await ctrl.getMaxZoomLevel();
      final clamped = requested.clamp(min, max);
      await ctrl.setZoomLevel(clamped);
      debugPrint('[CameraService] zoom: requested=$requested '
          'range=[$min..$max] -> applied=$clamped');
    } catch (e) {
      debugPrint('[CameraService] zoom apply fail: $e');
    }
  }

  /// Zmiana zoom - trwala (zapisuje w SettingsStore) i natychmiastowa
  /// na biezacym kontrolerze (bez rekreacji sesji).
  Future<void> setZoomLevel(double zoom) async {
    _zoomLevel = zoom;
    await _store.saveZoomLevel(zoom);
    await _applyZoom(zoom);
  }

  double get zoomLevel => _zoomLevel;

  /// Otwiera ustawienia systemowe (gdy uprawnienia sa permanently denied).
  Future<bool> openSystemSettings() => openAppSettings();

  /// Zapytaj native platform channel o wspierane tryby EIS/OIS back camery.
  /// Tylko logowanie - Flutter camera plugin i tak sam decyduje co zastosuje.
  Future<void> _logStabilizationCapabilities() async {
    try {
      final res = await _diagChannel.invokeMethod<Map<Object?, Object?>>(
        'getBackCameraStabilization',
      );
      debugPrint('[CameraService] EIS/OIS caps: $res');
    } catch (e) {
      debugPrint('[CameraService] EIS caps query fail: $e');
    }
  }

  /// Rozpoczyna nagrywanie wideo do tymczasowego pliku.
  Future<void> startRecording() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      throw StateError('Camera nie zainicjalizowana');
    }
    if (_isRecording) return;

    await ctrl.startVideoRecording();
    _isRecording = true;
    _recordingStartTime = DateTime.now();
    notifyListeners();
  }

  /// Konczy nagrywanie, przenosi plik do docs/recordings/raw_{ts}.mp4 i zwraca sciezke.
  Future<String?> stopRecording() async {
    final ctrl = _controller;
    if (ctrl == null || !_isRecording) return null;

    final XFile xfile = await ctrl.stopVideoRecording();
    _isRecording = false;

    final dir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${dir.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final target = '${recordingsDir.path}/raw_$ts.mp4';
    await File(xfile.path).rename(target);

    _lastRecordingPath = target;
    _recordingStartTime = null;
    notifyListeners();
    return target;
  }

  /// Anuluje recording bez zapisywania (jesli StartRecording sie pod naszym kontrolerem).
  Future<void> cancelRecording() async {
    final ctrl = _controller;
    if (ctrl != null && _isRecording) {
      try {
        final xf = await ctrl.stopVideoRecording();
        await File(xf.path).delete().catchError((_) => File(xf.path));
      } catch (_) {}
      _isRecording = false;
      _recordingStartTime = null;
      notifyListeners();
    }
  }

  /// Usuwa plik nagrania z dysku.
  Future<void> deleteRecording(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
      if (_lastRecordingPath == path) _lastRecordingPath = null;
    } catch (e) {
      debugPrint('deleteRecording error: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await cancelRecording();
    await _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}
