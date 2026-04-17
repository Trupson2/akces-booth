/// Konfiguracja post-processingu nagrania.
///
/// Dla Sesji 6 MVP: boomerang (forward + reverse) + slow-mo na koncu.
/// W kolejnych sesjach: muzyka, overlay PNG, drawtext.
class ProcessingConfig {
  ProcessingConfig({
    this.boomerang = true,
    this.slowMoTailFactor = 3.0,
    this.slowMoTailSeconds = 2.0,
    this.musicPath,
    this.overlayPath,
    this.textTop,
    this.textBottom,
    required this.inputDuration,
  });

  /// True = forward + reverse. False = tylko forward.
  final bool boomerang;

  /// Slow-motion na ostatnie N sekund (np. 3.0 = 3x wolniej).
  /// 1.0 = brak slow-mo.
  final double slowMoTailFactor;

  /// Dlugosc ogonu ktora jest slow-mo (przed slow-mo faktorem).
  /// Dla 8s input + boomerang = 16s output; slowMoTailSeconds=2 oznacza
  /// ze ostatnie 2s reverse (14-16s w output) staje sie slow-mo.
  final double slowMoTailSeconds;

  /// Opcjonalny MP3 tla.
  final String? musicPath;

  /// Opcjonalny PNG overlay (ramka 1080p/4K).
  final String? overlayPath;

  /// Tekst u gory (np. "Wesele Ania & Tomek").
  final String? textTop;

  /// Tekst u dolu (np. "15.04.2026").
  final String? textBottom;

  /// Dlugosc raw nagrania.
  final Duration inputDuration;

  /// Obliczona dlugosc wyjscia (dla progress bar).
  Duration get expectedOutputDuration {
    var base = inputDuration.inMilliseconds;
    if (boomerang) base *= 2;
    // slow-mo wydluza ogon o (factor-1) * tailSec
    final tailExtraMs =
        ((slowMoTailFactor - 1.0) * slowMoTailSeconds * 1000).round();
    return Duration(milliseconds: base + tailExtraMs);
  }

  /// Default dla Sesji 6 - bez muzyki/overlay/tekstu, pelen boomerang 2x + 3x slow-mo na 2s.
  factory ProcessingConfig.defaultBoomerang(Duration inputDuration) {
    return ProcessingConfig(
      boomerang: true,
      slowMoTailFactor: 3.0,
      slowMoTailSeconds: 2.0,
      inputDuration: inputDuration,
    );
  }
}
