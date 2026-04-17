import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_state.dart';
import '../models/video_job.dart';
import 'backend_client.dart';
import 'event_manager.dart';
import 'local_server.dart';
import 'wire_protocol.dart';

/// Centralny state controller - decyduje ktory ekran jest wyswietlany.
///
/// Sesja 3: wszystkie przejscia zmockowane timery.
/// Sesja 4: real WebSocket do Recorder. Mock timery zostaja jako FALLBACK
/// gdy Recorder nie jest polaczony (dev na jednym urzadzeniu, demo).
///
/// Jesli `server.isRecorderConnected == true`:
///   - startRecording() wysyla 'start_recording' do Recorder
///   - Progress/state leci z WS, mock timery wylaczone
/// W przeciwnym razie: stary flow mockowy.
///
/// UWAGA dla Sesji 6 (FFmpeg post-processing): NIE dodawac logo overlayu
/// "Akces 360" na finalnym filmie - decyzja Adriana 17.04.2026.
class AppStateMachine extends ChangeNotifier {
  AppStateMachine({this.server, this.backend, this.eventManager});

  /// Ustawiany przez main.dart po starcie serwera.
  final LocalServer? server;

  /// Klient backendu - real upload.
  final BackendClient? backend;

  /// Event manager - licznik filmow + config.
  final EventManager? eventManager;

  AppState _state = AppState.idle;
  VideoJob? _currentJob;
  double _progress = 0.0;
  int _videoCount = 0;
  int _qrCountdownSeconds = 0;

  Timer? _autoAdvance;
  Timer? _progressTicker;
  Timer? _countdownTicker;
  Timer? _timeoutGuard;

  static const Duration recordingDuration = Duration(seconds: 8);
  static const Duration processingDuration = Duration(seconds: 10);
  static const Duration transferDuration = Duration(seconds: 5);
  static const Duration uploadingDuration = Duration(seconds: 5);
  static const Duration qrDisplayDuration = Duration(seconds: 60);
  static const Duration thankYouDuration = Duration(seconds: 3);

  /// Maksymalny czas na cykl Recording->Preview (bezpiecznik na zawieszenie).
  static const Duration recorderTimeout = Duration(seconds: 60);

  AppState get state => _state;
  VideoJob? get currentJob => _currentJob;
  double get progress => _progress.clamp(0.0, 1.0);
  int get videoCount => _videoCount;
  int get qrCountdownSeconds => _qrCountdownSeconds;

  /// True jesli mamy zywe polaczenie z Recorder. Inaczej -> mock mode.
  bool get isRealMode => server?.isRecorderConnected ?? false;

  Duration get currentStateDuration {
    switch (_state) {
      case AppState.recording:
        return recordingDuration;
      case AppState.processing:
        return processingDuration;
      case AppState.transfer:
        return transferDuration;
      case AppState.uploading:
        return uploadingDuration;
      default:
        return Duration.zero;
    }
  }

  /// Wire callbacks z LocalServer -> state machine. Wywolywane raz z main.
  void attachServer() {
    final s = server;
    if (s == null) return;

    s.onRecordingStarted = () {
      if (_state == AppState.recording) return; // juz jestesmy
      _enter(AppState.recording, fromRemote: true);
    };
    s.onRecordingProgress = (p) {
      if (_state != AppState.recording) return;
      _progress = p;
      notifyListeners();
    };
    s.onRecordingStopped = () {
      if (_state != AppState.recording) return;
      _enter(AppState.processing, fromRemote: true);
    };
    s.onProcessingProgress = (p) {
      if (_state != AppState.processing) return;
      _progress = p;
      notifyListeners();
    };
    s.onProcessingDone = () {
      if (_state != AppState.processing) return;
      _enter(AppState.transfer, fromRemote: true);
    };
    s.onUploadProgress = (p) {
      if (_state != AppState.transfer) return;
      _progress = p;
      notifyListeners();
    };
    s.onVideoReceived = (path) {
      if (_state != AppState.transfer && _state != AppState.processing) {
        // Recorder moze uploadowac troche wczesniej niz dojdzie processingDone
        // - i tak chcemy go odebrac.
        debugPrint(
            '[StateMachine] onVideoReceived in state ${_state.name}, forcing preview');
      }
      _currentJob = VideoJob(
        id: 'rx_${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
        localFilePath: path,
      );
      _enter(AppState.preview, fromRemote: true);
    };
    s.onRemoteError = (msg) {
      debugPrint('[StateMachine] Remote error: $msg');
      _reset();
    };
  }

  @override
  void dispose() {
    _cancelAllTimers();
    super.dispose();
  }

  void _cancelAllTimers() {
    _autoAdvance?.cancel();
    _progressTicker?.cancel();
    _countdownTicker?.cancel();
    _timeoutGuard?.cancel();
    _autoAdvance = null;
    _progressTicker = null;
    _countdownTicker = null;
    _timeoutGuard = null;
  }

  /// Przejscie do stanu.
  /// [fromRemote] = true gdy event pochodzi z WS - nie odpalaj mock timerow.
  void _enter(AppState target, {bool fromRemote = false}) {
    _state = target;
    _progress = 0.0;
    notifyListeners();

    debugPrint(
        '[StateMachine] -> ${target.name} ${fromRemote ? "(remote)" : "(local)"}');

    _cancelAllTimers();

    switch (target) {
      case AppState.idle:
        // Nothing scheduled.
        break;

      case AppState.recording:
        if (fromRemote || isRealMode) {
          // Tylko safety timeout - dzialamy reaktywnie z WS.
          _timeoutGuard = Timer(recorderTimeout, () {
            debugPrint('[StateMachine] recorder timeout in RECORDING');
            _reset();
          });
        } else {
          _runProgressThen(recordingDuration, AppState.processing);
        }
        break;

      case AppState.processing:
        if (fromRemote || isRealMode) {
          _timeoutGuard = Timer(recorderTimeout, () {
            debugPrint('[StateMachine] recorder timeout in PROCESSING');
            _reset();
          });
        } else {
          _runProgressThen(processingDuration, AppState.transfer);
        }
        break;

      case AppState.transfer:
        if (fromRemote || isRealMode) {
          _timeoutGuard = Timer(recorderTimeout, () {
            debugPrint('[StateMachine] recorder timeout in TRANSFER');
            _reset();
          });
        } else {
          _runProgressThen(transferDuration, AppState.preview, onComplete: () {
            _currentJob = VideoJob.mock();
          });
        }
        break;

      case AppState.preview:
        // Czeka na user input.
        break;

      case AppState.uploading:
        _doRealUpload();
        break;

      case AppState.qrDisplay:
        _startQrCountdown();
        break;

      case AppState.thankYou:
        _autoAdvance = Timer(thankYouDuration, _reset);
        break;
    }
  }

  void _runProgressThen(Duration total, AppState next,
      {VoidCallback? onComplete}) {
    const tickMs = 100;
    final totalMs = total.inMilliseconds;
    int elapsed = 0;

    _progressTicker = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      elapsed += tickMs;
      _progress = (elapsed / totalMs).clamp(0.0, 1.0);
      notifyListeners();
      if (elapsed >= totalMs) {
        t.cancel();
        _progressTicker = null;
        onComplete?.call();
        _enter(next);
      }
    });
  }

  void _startQrCountdown() {
    _qrCountdownSeconds = qrDisplayDuration.inSeconds;
    notifyListeners();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      _qrCountdownSeconds--;
      notifyListeners();
      if (_qrCountdownSeconds <= 0) {
        t.cancel();
        _countdownTicker = null;
        _videoCount++;
        _enter(AppState.thankYou);
      }
    });
  }

  void _reset() {
    _cancelAllTimers();
    _currentJob = null;
    _progress = 0.0;
    _qrCountdownSeconds = 0;
    _state = AppState.idle;
    notifyListeners();
  }

  /// Real upload do backendu. Jesli backend nie skonfigurowany lub fail -
  /// fallback do mock timera (zeby gosci nie zostawic z niczym).
  Future<void> _doRealUpload() async {
    final job = _currentJob;
    final be = backend;

    if (job == null || job.localFilePath == null || be == null || !be.isConfigured) {
      debugPrint('[StateMachine] upload: brak job/backendu - mock fallback');
      _runProgressThen(uploadingDuration, AppState.qrDisplay, onComplete: () {
        _currentJob = _currentJob?.asUploaded();
      });
      return;
    }

    _timeoutGuard = Timer(const Duration(minutes: 3), () {
      debugPrint('[StateMachine] upload timeout');
      _reset();
    });

    final result = await be.uploadVideo(
      videoPath: job.localFilePath!,
      onProgress: (p) {
        _progress = p;
        notifyListeners();
      },
    );

    _timeoutGuard?.cancel();
    _timeoutGuard = null;

    if (result == null) {
      debugPrint('[StateMachine] upload failed - fallback mock');
      _currentJob = _currentJob?.asUploaded();
      _enter(AppState.qrDisplay);
      return;
    }

    // Update job z prawdziwymi URL-ami z backendu.
    _currentJob = VideoJob(
      id: job.id,
      createdAt: job.createdAt,
      localFilePath: job.localFilePath,
      shortId: result.shortId,
      publicUrl: result.publicUrl,
    );

    // Powiadom event manager (animacja "+1 film!").
    eventManager?.onVideoUploaded();

    _enter(AppState.qrDisplay);
  }

  // Public actions

  /// Start - wysylany z pilota/tabletu. Jesli Recorder online: komenda WS.
  /// Inaczej: mock flow.
  void startRecording() {
    if (_state != AppState.idle) return;
    server?.sendToRecorder({'type': WireMsg.startRecording});
    _enter(AppState.recording);
  }

  void stopRecordingEarly() {
    if (_state != AppState.recording) return;
    server?.sendToRecorder({'type': WireMsg.stopRecording});
    if (!isRealMode) {
      // mock mode: nie czekamy na recorder, sami idziemy dalej.
      _enter(AppState.processing);
    }
  }

  void acceptVideo() {
    if (_state != AppState.preview) return;
    _enter(AppState.uploading);
  }

  void rejectVideo() {
    if (_state != AppState.preview) return;
    _currentJob = null;
    _reset();
  }

  void nextGuest() {
    if (_state != AppState.qrDisplay) return;
    _cancelAllTimers();
    _videoCount++;
    _enter(AppState.thankYou);
  }

  void debugReset() => _reset();
}
