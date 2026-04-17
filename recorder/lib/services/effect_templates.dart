import 'dart:math';

/// Rodzaje efektow post-processing. Losowanie daje "kazdy film inny".
enum EffectTemplate {
  /// Forward -> reverse -> slow-mo tail 3x (oryginalny boomerang)
  classicBoomerang,

  /// Tylko forward, caly film spowolniony 2.5x (cinematic one-way)
  slowCinematic,

  /// Szybki start (1.5x) -> normal -> slow tail 3x (akcja -> emocja)
  fastSlowFast,

  /// Forward -> freeze na 0.5s -> reverse -> slow tail (dramatic pause)
  freezeReverse,
}

extension EffectTemplateX on EffectTemplate {
  String get label {
    switch (this) {
      case EffectTemplate.classicBoomerang:
        return 'Classic Boomerang';
      case EffectTemplate.slowCinematic:
        return 'Slow Cinematic';
      case EffectTemplate.fastSlowFast:
        return 'Fast-Slow-Fast';
      case EffectTemplate.freezeReverse:
        return 'Freeze + Reverse';
    }
  }

  String get shortId {
    switch (this) {
      case EffectTemplate.classicBoomerang:
        return 'CBR';
      case EffectTemplate.slowCinematic:
        return 'SCN';
      case EffectTemplate.fastSlowFast:
        return 'FSF';
      case EffectTemplate.freezeReverse:
        return 'FRV';
    }
  }
}

/// Parametry wylosowane dla konkretnego nagrania.
class RandomizedParams {
  RandomizedParams({
    required this.template,
    required this.musicPath,
    required this.slowMoFactor,
    required this.tailSeconds,
  });

  final EffectTemplate template;
  final String? musicPath; // null jesli brak muzyki w pool
  final double slowMoFactor;
  final double tailSeconds;

  String get debugSignature =>
      '${template.shortId} slow=${slowMoFactor.toStringAsFixed(1)} '
      'tail=${tailSeconds.toStringAsFixed(1)}s '
      'music=${musicPath?.split("/").last ?? "brak"}';
}

/// Losuje parametry efektu.
class RandomEffectPicker {
  RandomEffectPicker({Random? random}) : _rng = random ?? Random();

  final Random _rng;

  /// Zwraca wylosowane parametry.
  /// [musicPool] - lista sciezek do MP3 (moze byc pusta).
  /// [allowedTemplates] - null = wszystkie, niepusta lista = tylko te.
  RandomizedParams pick({
    required List<String> musicPool,
    List<EffectTemplate>? allowedTemplates,
  }) {
    final templates = allowedTemplates ?? EffectTemplate.values;
    final template = templates[_rng.nextInt(templates.length)];

    // Slow-mo factor 2.2 - 3.5
    final slowMo = 2.2 + _rng.nextDouble() * 1.3;

    // Tail length 1.5 - 2.5s
    final tail = 1.5 + _rng.nextDouble() * 1.0;

    final music = musicPool.isEmpty
        ? null
        : musicPool[_rng.nextInt(musicPool.length)];

    return RandomizedParams(
      template: template,
      musicPath: music,
      slowMoFactor: slowMo,
      tailSeconds: tail,
    );
  }
}
