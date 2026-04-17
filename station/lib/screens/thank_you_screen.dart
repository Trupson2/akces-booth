import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Wyswietla sie 3s miedzy QR_DISPLAY a IDLE.
/// Plynne pojawienie + delikatne skalowanie emoji - nic krzykliwego, bo
/// za chwile kolejny gosc ma czysty IDLE.
class ThankYouScreen extends StatefulWidget {
  const ThankYouScreen({super.key});

  @override
  State<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
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
          Center(
            child: FadeTransition(
              opacity: _c.drive(CurveTween(curve: Curves.easeOut)),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                  CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🎉', style: TextStyle(fontSize: 96)),
                    SizedBox(height: 16),
                    Text(
                      'Dziekujemy!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Kolejny gosc zapraszamy 🙂',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
