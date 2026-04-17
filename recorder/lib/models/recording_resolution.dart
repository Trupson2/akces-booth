import 'package:camera/camera.dart';

/// Rozdzielczosc nagrania - mapuje sie na ResolutionPreset kamery.
///
/// Urzadzenia roznia sie w wspieranych rozdzielczosciach. Jesli wybrana
/// rozdzielczosc nie jest dostepna, CameraService robi fallback w dol
/// i ustawia flage [CameraService.resolutionDegraded].
enum RecordingResolution {
  /// 1920x1080 - FullHD, bezpieczny default, maly plik.
  fullHd,

  /// 3840x2160 - 4K UHD, zalecane dla eventow.
  uhd4k,

  /// Najwyzsza dostepna (na OnePlus 13 z SD8 Elite = 8K 7680x4320).
  max,
}

extension RecordingResolutionX on RecordingResolution {
  String get label {
    switch (this) {
      case RecordingResolution.fullHd:
        return 'FullHD';
      case RecordingResolution.uhd4k:
        return '4K';
      case RecordingResolution.max:
        return '8K';
    }
  }

  /// Krotki opis dla tooltipa / UI.
  String get dimensions {
    switch (this) {
      case RecordingResolution.fullHd:
        return '1920x1080';
      case RecordingResolution.uhd4k:
        return '3840x2160';
      case RecordingResolution.max:
        return '7680x4320';
    }
  }

  ResolutionPreset get preset {
    switch (this) {
      case RecordingResolution.fullHd:
        return ResolutionPreset.veryHigh;
      case RecordingResolution.uhd4k:
        return ResolutionPreset.ultraHigh;
      case RecordingResolution.max:
        return ResolutionPreset.max;
    }
  }

  /// Ciezsze rozdzielczosci - ostrzezenie w UI.
  bool get isHeavy =>
      this == RecordingResolution.uhd4k || this == RecordingResolution.max;
}
