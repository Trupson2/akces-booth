import 'effect_templates.dart';

/// Konfiguracja post-processingu nagrania.
///
/// Od Sesji 6.5: per-nagranie losowany template + parametry przez
/// [RandomEffectPicker]. [ProcessingConfig] ma info co wylosowane + assets.
class ProcessingConfig {
  ProcessingConfig({
    required this.template,
    this.slowMoTailFactor = 3.0,
    this.slowMoTailSeconds = 2.0,
    this.speedUpFactor = 1.0,
    this.freezeSeconds = 0.0,
    this.musicPath,
    this.musicOffsetSec,
    this.overlayPath,
    this.textTop,
    this.textBottom,
    required this.inputDuration,
  });

  /// Wybrany wariant efektu.
  final EffectTemplate template;

  /// Slow-mo faktor na ogonie (np. 3.0 = 3x wolniej). 1.0 = brak.
  final double slowMoTailFactor;

  /// Dlugosc slow-mo tail (sekundy przed slow-mo faktorem).
  final double slowMoTailSeconds;

  /// Speed-up factor na pierwszych N sekundach (1.5 = 1.5x szybciej).
  /// Uzywane w [EffectTemplate.fastSlowFast].
  final double speedUpFactor;

  /// Czas freeze frame (sekundy) - [EffectTemplate.freezeReverse].
  final double freezeSeconds;

  final String? musicPath;

  /// Offset startu muzyki w sekundach. Null => heurystyka 30% dlugosci
  /// (fallback dla bundled tracks bez pre-analizy).
  /// Ustawiony przez Station z event config (AI viral albo manual z admin).
  final double? musicOffsetSec;

  final String? overlayPath;
  final String? textTop;
  final String? textBottom;

  final Duration inputDuration;

  /// Szacowana dlugosc outputu (dla progress bar).
  Duration get expectedOutputDuration {
    final inMs = inputDuration.inMilliseconds;
    final tailMs = (slowMoTailSeconds * 1000).round();
    final extra = ((slowMoTailFactor - 1.0) * tailMs).round();
    switch (template) {
      case EffectTemplate.classicBoomerang:
        return Duration(milliseconds: inMs * 2 + extra);
      case EffectTemplate.slowCinematic:
        return Duration(
            milliseconds: (inMs * slowMoTailFactor).round());
      case EffectTemplate.fastSlowFast:
        return Duration(milliseconds: inMs + extra);
      case EffectTemplate.freezeReverse:
        return Duration(
            milliseconds: inMs * 2 + (freezeSeconds * 1000).round() + extra);
    }
  }

  /// Buduje config z wylosowanych parametrow.
  factory ProcessingConfig.fromRandom({
    required RandomizedParams params,
    required Duration inputDuration,
  }) {
    switch (params.template) {
      case EffectTemplate.classicBoomerang:
        return ProcessingConfig(
          template: params.template,
          slowMoTailFactor: params.slowMoFactor,
          slowMoTailSeconds: params.tailSeconds,
          musicPath: params.musicPath,
          inputDuration: inputDuration,
        );
      case EffectTemplate.slowCinematic:
        return ProcessingConfig(
          template: params.template,
          slowMoTailFactor: params.slowMoFactor,
          slowMoTailSeconds: inputDuration.inSeconds.toDouble(),
          musicPath: params.musicPath,
          inputDuration: inputDuration,
        );
      case EffectTemplate.fastSlowFast:
        return ProcessingConfig(
          template: params.template,
          slowMoTailFactor: params.slowMoFactor,
          slowMoTailSeconds: params.tailSeconds,
          speedUpFactor: 1.5,
          musicPath: params.musicPath,
          inputDuration: inputDuration,
        );
      case EffectTemplate.freezeReverse:
        return ProcessingConfig(
          template: params.template,
          slowMoTailFactor: params.slowMoFactor,
          slowMoTailSeconds: params.tailSeconds,
          freezeSeconds: 0.5,
          musicPath: params.musicPath,
          inputDuration: inputDuration,
        );
    }
  }
}
