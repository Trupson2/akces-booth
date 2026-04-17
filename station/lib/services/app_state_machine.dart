import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_state.dart';
import '../models/video_job.dart';

/// Centralny state controller - decyduje ktory ekran jest wyswietlany.
///
/// W Sesji 3 wszystkie przejscia sa zmockowane przez Timery. W Sesji 4+
/// podepniemy prawdziwe zdarzenia (start z Recorder przez WiFi, FFmpeg
/// progress z OnePlus, transfer finish, upload do RPi).
///
/// UWAGA dla Sesji 6 (FFmpeg post-processing): NIE dodawac logo overlayu
/// "Akces 360" na finalnym filmie - decyzja Adriana 17.04.2026.
/// Tekst "Logo Akces 360" zostal usuniety z ProcessingScreen steps.
class AppStateMachine extends ChangeNotifier {
  AppStateMachine();

  AppState _state = AppState.idle;
  VideoJob? _currentJob;
  double _progress = 0.0;

  /// Licznik filmow ukonczonych na evencie.
  int _videoCount = 0;

  /// Countdown na QR screen.
  int _qrCountdownSeconds = 0;

  Timer? _autoAdvance;
  Timer? _progressTicker;
  Timer? _countdownTicker;

  // Mock durations (configurable dla Sesji 3).
  static const Duration recordingDuration = Duration(seconds: 8);
  static const Duration processingDuration = Duration(seconds: 10);
  static const Duration transferDuration = Duration(seconds: 5);
  static const Duration uploadingDuration = Duration(seconds: 5);
  static const Duration qrDisplayDuration = Duration(seconds: 60);
  static const Duration thankYouDuration = Duration(seconds: 3);

  AppState get state => _state;
  VideoJob? get currentJob => _currentJob;
  double get progress => _progress.clamp(0.0, 1.0);
  int get videoCount => _videoCount;
  int get qrCountdownSeconds => _qrCountdownSeconds;

  /// Ile sekund zostalo dla biezacego stanu z progress barem.
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

  @override
  void dispose() {
    _cancelAllTimers();
    super.dispose();
  }

  void _cancelAllTimers() {
    _autoAdvance?.cancel();
    _progressTicker?.cancel();
    _countdownTicker?.cancel();
    _autoAdvance = null;
    _progressTicker = null;
    _countdownTicker = null;
  }

  /// Przejscie do stanu + odpowiednie strategia (progress ticker + auto advance).
  void _enter(AppState target) {
    _state = target;
    _progress = 0.0;
    notifyListeners();

    // Logowanie pomocne w dev.
    debugPrint('[StateMachine] -> ${target.name}');

    switch (target) {
      case AppState.idle:
        _cancelAllTimers();
        break;
      case AppState.recording:
        _runProgressThen(recordingDuration, AppState.processing);
        break;
      case AppState.processing:
        _runProgressThen(processingDuration, AppState.transfer);
        break;
      case AppState.transfer:
        _runProgressThen(transferDuration, AppState.preview, onComplete: () {
          // Mock: tworzymy job gdy transfer konczy sie.
          _currentJob = VideoJob.mock();
        });
        break;
      case AppState.preview:
        // Czeka na akcje usera (akceptuj / powtorz).
        _cancelAllTimers();
        break;
      case AppState.uploading:
        _runProgressThen(uploadingDuration, AppState.qrDisplay, onComplete: () {
          _currentJob = _currentJob?.asUploaded();
        });
        break;
      case AppState.qrDisplay:
        _startQrCountdown();
        break;
      case AppState.thankYou:
        _cancelAllTimers();
        _autoAdvance = Timer(thankYouDuration, _reset);
        break;
    }
  }

  /// Uruchamia progress ticker od 0 do 1 przez [total]. Potem idzie do [next].
  void _runProgressThen(Duration total, AppState next,
      {VoidCallback? onComplete}) {
    _cancelAllTimers();
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

  /// Countdown 60 -> 0 na QR screen. Po zakonczeniu przechodzi do thankYou.
  void _startQrCountdown() {
    _cancelAllTimers();
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

  // Public actions

  /// Start nagrywania (pilot / tablet / telefon).
  void startRecording() {
    if (_state != AppState.idle) return;
    _enter(AppState.recording);
  }

  /// Manual STOP podczas recording - skraca do processing.
  void stopRecordingEarly() {
    if (_state != AppState.recording) return;
    _cancelAllTimers();
    _enter(AppState.processing);
  }

  /// Z preview: gosc akceptuje film.
  void acceptVideo() {
    if (_state != AppState.preview) return;
    _enter(AppState.uploading);
  }

  /// Z preview: gosc odrzuca film.
  void rejectVideo() {
    if (_state != AppState.preview) return;
    _currentJob = null;
    _reset();
  }

  /// Z QR screen: skip na kolejnego goscia.
  void nextGuest() {
    if (_state != AppState.qrDisplay) return;
    _cancelAllTimers();
    _videoCount++;
    _enter(AppState.thankYou);
  }

  /// Debug / dev: wymuszenie resetu (uzywane w Settings "Reset state machine").
  void debugReset() => _reset();
}
