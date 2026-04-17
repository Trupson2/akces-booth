import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state_machine.dart';
import '../services/mock_services.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_counter.dart';
import '../widgets/big_action_button.dart';
import '../widgets/status_indicator.dart';
import 'settings_screen.dart';

class IdleScreen extends StatelessWidget {
  const IdleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sm = context.watch<AppStateMachine>();
    final conn = context.watch<ConnectivityStatus>();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Subtelne tlo - radial gradient indigo.
          const _BrandingBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              child: Column(
                children: [
                  // Top bar: status indicators + dzienny licznik
                  Row(
                    children: [
                      AnimatedCounter(
                        value: sm.videoCount,
                        label: 'DZIS FILMOW',
                      ),
                      const Spacer(),
                      StatusDot(
                        icon: Icons.bluetooth_rounded,
                        label: 'Bluetooth',
                        online: conn.bluetoothReady,
                      ),
                      const SizedBox(width: 8),
                      StatusDot(
                        icon: Icons.phone_iphone_rounded,
                        label: 'Recorder',
                        online: conn.recorderOnline,
                      ),
                      const SizedBox(width: 8),
                      StatusDot(
                        icon: Icons.wifi_rounded,
                        label: 'Internet',
                        online: conn.internetOnline,
                      ),
                    ],
                  ),

                  // Greeting - dominuje ekran
                  const Expanded(
                    child: Center(
                      child: _Greeting(),
                    ),
                  ),

                  // Duzy START na dole - wysokosc skalowana od ekranu
                  // (na Tab A11+ 800px wysokosci daje ~130, na telefonie ~90).
                  LayoutBuilder(
                    builder: (context, _) {
                      final screenH = MediaQuery.of(context).size.height;
                      final btnH = (screenH * 0.18).clamp(80.0, 140.0);
                      return BigActionButton(
                        label: 'START NAGRANIA',
                        subtitle: 'albo nacisnij pilota',
                        icon: Icons.play_arrow_rounded,
                        color: AppTheme.success,
                        height: btnH,
                        onTap: () => sm.startRecording(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Footer: logo + settings
                  Row(
                    children: [
                      const Text(
                        'Akces 360',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3,
                        ),
                      ),
                      const Spacer(),
                      _SettingsLink(onLongPress: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Skalujemy z wysokosci dostepnego miejsca - na telefonach landscape
        // miejsca jest malo, na Tab A11+ (800px) duzo.
        final h = constraints.maxHeight;
        final titleSize = (h * 0.22).clamp(28.0, 56.0);
        final emojiSize = (h * 0.26).clamp(36.0, 72.0);
        final subSize = (h * 0.08).clamp(12.0, 16.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('👋', style: TextStyle(fontSize: emojiSize)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Wejdz na platforme',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Usmiech, pozycja, klik START - film bedzie za 30s',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: subSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BrandingBackdrop extends StatelessWidget {
  const _BrandingBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Color(0x556366F1),
            Color(0xFF0F172A),
          ],
          radius: 1.2,
          center: Alignment(0, -0.3),
        ),
      ),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({required this.onLongPress});
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Przytrzymaj 1s zeby otworzyc ustawienia',
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.settings_rounded, size: 18, color: AppTheme.muted),
            SizedBox(width: 6),
            Text(
              'Ustawienia',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
