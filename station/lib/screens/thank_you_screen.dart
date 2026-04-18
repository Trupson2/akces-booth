import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Wyswietla sie 3s miedzy QR_DISPLAY a IDLE.
///
/// Sesja 9: fade + scale in (statyczne emoji).
/// Pakiet D (Claude Design): PNG ilustracja "dziadek + wnuk" + unoszace sie
/// konfetti animowane niezaleznie w tle.
class ThankYouScreen extends StatefulWidget {
  const ThankYouScreen({super.key});

  @override
  State<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen>
    with TickerProviderStateMixin {
  // Controller dla glownego "wejscia" sceny (fade + scale).
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  // Controller dla wiecznie-zapetlonych konfetti (niezalezny, leci w kolko).
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  // Losowe pozycje/skale konfetti - stabilne per instance screenu.
  late final List<_Sparkle> _sparkles = _generateSparkles();

  List<_Sparkle> _generateSparkles() {
    final rng = math.Random(42); // deterministyczne rozmieszczenie
    final emojis = ['🎉', '✨', '⭐', '🎊', '💫'];
    return List.generate(14, (i) {
      return _Sparkle(
        emoji: emojis[rng.nextInt(emojis.length)],
        // Start X: losowa pozycja [0..1] szerokosci ekranu
        startX: rng.nextDouble(),
        // Start Y: zaczynaja rozrzucone pionowo, kazdy ma offset w cyklu
        phaseOffset: rng.nextDouble(),
        // Skala 0.5-1.2 - rozny rozmiar konfetti
        scale: 0.5 + rng.nextDouble() * 0.7,
        // Predkosc: rozny czas obiegu
        speedMultiplier: 0.7 + rng.nextDouble() * 0.8,
        // Przesuniecie X w trakcie unoszenia (lekkie buja w bok)
        swayAmplitude: 0.02 + rng.nextDouble() * 0.05,
      );
    });
  }

  @override
  void dispose() {
    _entry.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Subtelne zielone tlo - sygnal sukcesu.
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0x5510B981),
                  Color(0xFF0F172A),
                ],
                radius: 1.2,
                center: Alignment.center,
              ),
            ),
          ),

          // Konfetti unoszace sie w tle - za sceny ale nad backgroundem.
          _ConfettiLayer(
            sparkles: _sparkles,
            controller: _confetti,
          ),

          // Glowna scena: ilustracja + teksty z fade+scale entry.
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _entry.drive(CurveTween(curve: Curves.easeOut)),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.88, end: 1.0).animate(
                    CurvedAnimation(parent: _entry, curve: Curves.easeOutBack),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ilustracja dziadek + wnuk z fotobudka.
                      // Bazuje na mniejszym wymiarze (min(w, h)) zeby byla
                      // proporcjonalna i na telefonie (w landscape ma malo h)
                      // i na tablecie (Tab A11+ landscape da duzo wiecej).
                      LayoutBuilder(
                        builder: (context, _) {
                          final mq = MediaQuery.of(context).size;
                          final minSide = mq.width < mq.height ? mq.width : mq.height;
                          final size = (minSide * 0.75).clamp(280.0, 600.0);
                          return SizedBox(
                            width: size,
                            height: size,
                            child: Image.asset(
                              'assets/illustrations/dziekujemy.png',
                              fit: BoxFit.contain,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Dziekujemy!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Kolejny gosc zapraszamy 🙂',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Konfiguracja jednego unoszacego sie konfetti.
class _Sparkle {
  _Sparkle({
    required this.emoji,
    required this.startX,
    required this.phaseOffset,
    required this.scale,
    required this.speedMultiplier,
    required this.swayAmplitude,
  });

  final String emoji;
  final double startX;       // 0..1 ulamek szerokosci ekranu
  final double phaseOffset;  // 0..1 offset w cyklu animacji
  final double scale;        // 0.5..1.2 rozmiar
  final double speedMultiplier; // 0.7..1.5 predkosc animacji
  final double swayAmplitude; // 0..0.05 ulamek szerokosci - lekkie buja w bok
}

/// Warstwa konfetti - renderuje wszystkie sparkle w kolko.
class _ConfettiLayer extends StatelessWidget {
  const _ConfettiLayer({required this.sparkles, required this.controller});

  final List<_Sparkle> sparkles;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Stack(
              children: [
                for (final s in sparkles) _buildSparkle(s, w, h),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSparkle(_Sparkle s, double w, double h) {
    // Progres w zakresie 0..1 z uwzglednieniem fazy offset i predkosci.
    final raw = (controller.value * s.speedMultiplier + s.phaseOffset) % 1.0;

    // Y: konfetti unosi sie od dolu do gory (h -> 0)
    final y = h - (raw * (h + 100)); // +100 zeby wychodzilo pod ekran i od gory

    // X: lekkie buja w bok (sinus)
    final swayPx = s.swayAmplitude * w * math.sin(raw * 2 * math.pi);
    final x = s.startX * w + swayPx;

    // Opacity: pojawia sie szybko, zanikaj pod koniec
    double opacity;
    if (raw < 0.1) {
      opacity = raw * 10;
    } else if (raw > 0.85) {
      opacity = (1 - raw) / 0.15;
    } else {
      opacity = 1.0;
    }
    opacity = opacity.clamp(0.0, 0.75);

    return Positioned(
      left: x - 20,
      top: y - 20,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: raw * 2 * math.pi,
          child: Transform.scale(
            scale: s.scale,
            child: Text(s.emoji, style: const TextStyle(fontSize: 28)),
          ),
        ),
      ),
    );
  }
}
