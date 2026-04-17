import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/recording_mode.dart';

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
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CameraDescription? _backCamera;

  CameraInitStatus _status = CameraInitStatus.idle;
  RecordingMode _mode = RecordingMode.normal;
  bool _isRecording = false;
  bool _highFpsDegraded = false;
  String? _errorMessage;
  String? _lastRecordingPath;
  DateTime? _recordingStartTime;

  CameraController? get controller => _controller;
  CameraInitStatus get status => _status;
  RecordingMode get mode => _mode;
  bool get isInitialized =>
      _status == CameraInitStatus.ready && (_controller?.value.isInitialized ?? false);
  bool get isRecording => _isRecording;

  /// True jesli user wybral slowMo120 ale urzadzenie nie wspiera - dzialamy na 30 fps.
  bool get highFpsDegraded => _highFpsDegraded;
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
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _set(CameraInitStatus.error, error: 'Nie znaleziono zadnej kamery');
        return;
      }
      _backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      await _createController(_mode);
      _set(CameraInitStatus.ready);
    } catch (e, st) {
      debugPrint('CameraService.initialize error: $e\n$st');
      _set(CameraInitStatus.error, error: e.toString());
    }
  }

  /// Tworzy nowy CameraController dla wybranego trybu.
  /// Dla slow-mo probuje ustawic fps=120; przy fail robi fallback na normal.
  Future<void> _createController(RecordingMode mode) async {
    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();

    final cam = _backCamera;
    if (cam == null) {
      throw StateError('Brak back camera');
    }

    _highFpsDegraded = false;

    Future<CameraController> build(int? fps) async {
      final ctrl = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.yuv420,
        fps: fps,
      );
      await ctrl.initialize();
      return ctrl;
    }

    if (mode == RecordingMode.slowMo120) {
      try {
        _controller = await build(120);
      } catch (e) {
        debugPrint('Slow-mo 120fps nie wspierane, fallback na 30fps: $e');
        _highFpsDegraded = true;
        _controller = await build(null);
      }
    } else {
      _controller = await build(null);
    }
  }

  /// Zmienia tryb nagrywania (rekreuje controller).
  Future<void> setMode(RecordingMode mode) async {
    if (mode == _mode && _controller != null) return;
    if (_isRecording) {
      debugPrint('Ignoruje setMode podczas nagrywania');
      return;
    }
    _mode = mode;
    _set(CameraInitStatus.initializing);
    try {
      await _createController(mode);
      _set(CameraInitStatus.ready);
    } catch (e) {
      _set(CameraInitStatus.error, error: e.toString());
    }
  }

  /// Otwiera ustawienia systemowe (gdy uprawnienia sa permanently denied).
  Future<bool> openSystemSettings() => openAppSettings();

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
