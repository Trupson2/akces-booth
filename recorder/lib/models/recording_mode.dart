/// Tryb nagrywania - wplywa na FPS kamery.
///
/// Flutter camera package 0.11.x wspiera zmienne FPS przez parametr `fps`
/// w CameraController, ale wsparcie dla wysokich klatek zalezy od urzadzenia.
/// Jesli 120 fps nie jest dostepne, spadamy do normalnego trybu i oznaczamy
/// degrade w UI.
///
/// TODO(sesja-6): Dla prawdziwego slow-mo 120/240 fps na SD8 Elite trzeba
/// zrobic platform channel do CameraX + Camera2 API (`createConstrainedHighSpeedCaptureSession`).
/// camera package 0.11.x nie wystawia high-speed session - szybka sciezka nie istnieje.
/// Dzisiejszy fallback zapisuje 30fps i pokazuje warning ⚠️ w UI.
enum RecordingMode {
  /// 30 fps - domyslny, szybka inicjalizacja, pewne dzialanie.
  normal,

  /// 60 fps - plynne nagranie z wiekszym klatkazem, dobre do boomerangu.
  fps60,

  /// 120 fps - slow-motion (beta). Platform channel dla 240 fps w Sesji 6.
  slowMo120,
}

extension RecordingModeX on RecordingMode {
  String get label {
    switch (this) {
      case RecordingMode.normal:
        return 'Normal 30';
      case RecordingMode.fps60:
        return '60 fps';
      case RecordingMode.slowMo120:
        return 'Slow-mo 120';
    }
  }

  int get fps {
    switch (this) {
      case RecordingMode.normal:
        return 30;
      case RecordingMode.fps60:
        return 60;
      case RecordingMode.slowMo120:
        return 120;
    }
  }

  bool get isBeta => this == RecordingMode.slowMo120;
}
