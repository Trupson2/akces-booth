import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_state.dart';
import '../models/video_job.dart';
import 'backend_client.dart';
import 'event_manager.dart';
import 'local_server.dart';
import 'logger.dart';
import 'pending_uploads.dart';
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
  AppStateMachine({
    this.server,
    this.backend,
    this.eventManager,
    this.pendingUploads,
  });

  /// Ustawiany przez main.dart po starcie serwera.
  final LocalServer? server;

  /// Klient backendu - real upload.
  final BackendClient? backend;

  /// Event manager - licznik filmow + config.
  final EventManager? eventManager;

  /// Kolejka pending uploads (offline fallback, Sesja 8a Block 3).
  final PendingUploadsService? pendingUploads;

  AppState _state = AppState.idle;
  VideoJob? _currentJob;
  double _progress = 0.0;
  int _videoCount = 0;
  int _qrCountdownSeconds = 0;

  /// Informacja o bledzie - pokazywana na ErrorScreen.
  String _errorTitle = '';
  String _errorMessage = '';
  AppState _errorFrom = AppState.idle;

  Timer? _autoAdvance;
  Timer? _progressTicker;
  Timer? _countdownTicker;
  Timer? _timeoutGuard;

  // Czasy dla mock mode (brak Recordera) - szybsze niz real flow zeby
  // developerski test klik START -> QR zajmowal ~13s zamiast 28s.
  // Real mode (Recorder polaczony) uzywa prawdziwych eventow z WS,
  // te timery sa tylko safety/fallback.
  static const Duration recordingDuration = Duration(seconds: 6);
  static const Duration processingDuration = Duration(seconds: 3);
  static const Duration transferDuration = Duration(seconds: 2);
  static const Duration uploadingDuration = Duration(seconds: 2);
  static const Duration qrDisplayDuration = Duration(seconds: 60);
  static const Duration thankYouDuration = Duration(seconds: 3);

  // Sesja 8a: per-state maksymalne czasy (bezpiecznik na zawieszenie Recordera,
  // FFmpeg, transferu, uploadu). Po ich przekroczeniu -> AppState.error.
  //
  // Bardzo hojne wartosci zeby nie wyrzucac uzytkownika przy chwilowym lagu,
  // ale krotsze niz "30 min wisi PROCESSING i nikt nie wie co sie dzieje".
  static const Duration recordingMaxDuration = Duration(seconds: 20);    // 8s + 12s bufora
  static const Duration processingMaxDuration = Duration(seconds: 45);   // Snapdragon 8 Elite robi <15s
  static const Duration transferMaxDuration = Duration(seconds: 90);     // 40MB na WiFi
  static const Duration uploadingMaxDuration = Duration(minutes: 5);     // duzy margines dla slabego neta

  /// Legacy alias (nadal uzywany w attachServer handlerach, nie zmieniam).
  static const Duration recorderTimeout = recordingMaxDuration;

  AppState get state => _state;
  VideoJob? get currentJob => _currentJob;
  double get progress => _progress.clamp(0.0, 1.0);
  int get videoCount => _videoCount;
  int get qrCountdownSeconds => _qrCountdownSeconds;
  String get errorTitle => _errorTitle;
  String get errorMessage => _errorMessage;
  AppState get errorFrom => _errorFrom;

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
      Log.e('StateMachine', 'Remote error z Recorder: $msg');
      _enterError(
        title: 'Blad po stronie fotobudki',
        message: 'Recorder zaraportowal: $msg',
        from: _state == AppState.idle ? AppState.recording : _state,
      );
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
          _timeoutGuard = Timer(recordingMaxDuration, () {
            Log.w('StateMachine', 'timeout in RECORDING after '
                '${recordingMaxDuration.inSeconds}s');
            _enterError(
              title: 'Fotobudka nie odpowiada',
              message: 'Recorder nie przyslal potwierdzenia nagrywania. '
                  'Sprawdz BT i Wi-Fi fotobudki, potem sprobuj ponownie.',
              from: AppState.recording,
            );
          });
        } else {
          _runProgressThen(recordingDuration, AppState.processing);
        }
        break;

      case AppState.processing:
        if (fromRemote || isRealMode) {
          _timeoutGuard = Timer(processingMaxDuration, () {
            Log.w('StateMachine', 'timeout in PROCESSING after '
                '${processingMaxDuration.inSeconds}s');
            _enterError(
              title: 'Przetwarzanie trwa za dlugo',
              message: 'FFmpeg na Recorderze sie zaciol. '
                  'Sprobuj ponownie - zwykle trwa to 15-20s.',
              from: AppState.processing,
            );
          });
        } else {
          _runProgressThen(processingDuration, AppState.transfer);
        }
        break;

      case AppState.transfer:
        if (fromRemote || isRealMode) {
          _timeoutGuard = Timer(transferMaxDuration, () {
            Log.w('StateMachine', 'timeout in TRANSFER after '
                '${transferMaxDuration.inSeconds}s');
            _enterError(
              title: 'Problem z przeslaniem filmu',
              message: 'Recorder nie mogl wyslac filmu do Station. '
                  'Sprawdz Wi-Fi, film moze byc nadal na telefonie.',
              from: AppState.transfer,
            );
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

      case AppState.error:
        // Blokuje auto-reset. Gosc/operator musi kliknac "Sprobuj ponownie"
        // albo "Anuluj" (powrot do idle).
        break;
    }
  }

  /// Przejscie do stanu bledu. Zatrzymuje wszystko, pokazuje ErrorScreen.
  /// `from` zapamietany do retry - np. z error po UPLOADING
  /// kliknac "Sprobuj" wraca do UPLOADING (a nie do IDLE).
  void _enterError({
    required String title,
    required String message,
    required AppState from,
  }) {
    _cancelAllTimers();
    _errorTitle = title;
    _errorMessage = message;
    _errorFrom = from;
    _state = AppState.error;
    Log.e('StateMachine', '$title (from ${from.name}): $message');
    notifyListeners();
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

    _timeoutGuard = Timer(uploadingMaxDuration, () {
      Log.w('StateMachine', 'upload timeout after '
          '${uploadingMaxDuration.inSeconds}s');
      _enterError(
        title: 'Upload filmu nie powiodl sie',
        message: 'Serwer booth.akces360.pl nie odpowiada. '
            'Mozemy sprobowac ponownie - film jest zapisany lokalnie.',
        from: AppState.uploading,
      );
    });

    final result = await be.uploadVideo(
      videoPath: job.localFilePath!,
      publishToFacebook: job.publishToFacebook,
      onProgress: (p) {
        _progress = p;
        notifyListeners();
      },
    );

    _timeoutGuard?.cancel();
    _timeoutGuard = null;

    // Juz w stanie error (timeout) - nie nadpisuj.
    if (_state == AppState.error) return;

    if (result == null) {
      Log.w('StateMachine', 'upload returned null - offline fallback');
      await _fallbackToLocalServe(job);
      return;
    }

    // Update job z prawdziwymi URL-ami z backendu.
    _currentJob = job.copyWith(
      shortId: result.shortId,
      publicUrl: result.publicUrl,
    );

    // Powiadom event manager (animacja "+1 film!").
    eventManager?.onVideoUploaded();

    _enter(AppState.qrDisplay);
  }

  /// Offline fallback - gdy backend nie przyjal, generujemy LOKALNY QR URL
  /// (Station IP) i dokladamy do kolejki pending. W tle PendingUploadsService
  /// co 45s probuje wyslac - gdy sie uda, plik pojawi sie tez na RPi, ale
  /// gosc nadal moze uzyc lokalnego URL przez caly event.
  Future<void> _fallbackToLocalServe(VideoJob job) async {
    final srv = server;
    final pu = pendingUploads;
    final localPath = job.localFilePath;

    if (srv == null || pu == null || localPath == null) {
      Log.w('StateMachine', 'fallback niemozliwy (srv/pu/path null) - mock QR');
      _currentJob = _currentJob?.asUploaded();
      _enter(AppState.qrDisplay);
      return;
    }

    // Generuj lokalny short_id (distinguishable od backendowych).
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final shortId = 'L${ts.substring(ts.length - 5)}';

    srv.registerLocalVideo(shortId, localPath);
    final localUrl = srv.localVideoUrl(shortId);

    await pu.enqueue(PendingUpload(
      localShortId: shortId,
      localFilePath: localPath,
      publishToFacebook: job.publishToFacebook,
      createdAt: DateTime.now(),
    ));

    _currentJob = job.copyWith(
      shortId: shortId,
      publicUrl: localUrl,
    );
    Log.i('StateMachine', 'offline fallback - QR=$localUrl');
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

  /// Ustawia flage FB (z checkboxa na QR screen / Preview).
  void setPublishToFacebook(bool value) {
    final job = _currentJob;
    if (job == null) return;
    _currentJob = job.copyWith(publishToFacebook: value);
    notifyListeners();
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

  /// Sprobuj ponownie z ekranu error.
  ///
  /// Decyzja per-stan od ktorego wrocilismy:
  /// - error z RECORDING/PROCESSING/TRANSFER -> reset do IDLE, gosc klika START ponownie
  /// - error z UPLOADING -> jesli jest lokalny film, jedziemy ponownie UPLOADING
  void retryFromError() {
    if (_state != AppState.error) return;
    Log.i('StateMachine', 'retry from error (was ${_errorFrom.name})');

    final from = _errorFrom;
    _errorTitle = '';
    _errorMessage = '';
    _errorFrom = AppState.idle;

    switch (from) {
      case AppState.uploading:
        if (_currentJob?.localFilePath != null) {
          _enter(AppState.uploading);
          return;
        }
        _reset();
        break;
      case AppState.recording:
      case AppState.processing:
      case AppState.transfer:
      default:
        _reset();
        break;
    }
  }

  /// Anuluj error, wroc do IDLE (powielanie debugReset ale z czytelna nazwa).
  void cancelFromError() {
    if (_state != AppState.error) return;
    Log.i('StateMachine', 'cancel from error -> idle');
    _errorTitle = '';
    _errorMessage = '';
    _errorFrom = AppState.idle;
    _reset();
  }

  /// Programowo wymusz error - wykorzystywane przez zewnetrzne sygnaly
  /// (np. disconnect WiFi w trakcie cyklu). Public bo moze byc wywolane
  /// z LocalServer/BackendClient.
  void reportError(String title, String message) {
    if (_state == AppState.idle || _state == AppState.error) return;
    _enterError(title: title, message: message, from: _state);
  }
}
