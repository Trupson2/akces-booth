import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state_machine.dart';
import '../services/event_manager.dart';
import '../services/local_server.dart';
import '../services/mock_services.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_counter.dart';
import '../widgets/big_action_button.dart';
import '../widgets/status_indicator.dart';
import 'pin_entry_screen.dart';
import 'settings_screen.dart';

class IdleScreen extends StatelessWidget {
  const IdleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sm = context.watch<AppStateMachine>();
    final conn = context.watch<ConnectivityStatus>();
    final server = context.watch<LocalServer>();
    final events = context.watch<EventManager>();

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
                        value: events.hasActiveEvent
                            ? events.videoCount
                            : sm.videoCount,
                        label: events.hasActiveEvent
                            ? (events.activeEvent!.name.toUpperCase())
                            : 'DZIS FILMOW',
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
                        // Real: z WS polaczenia. Fallback: z mock serwisu.
                        online: server.isRecorderConnected ||
                            conn.recorderOnline,
                      ),
                      const SizedBox(width: 8),
                      StatusDot(
                        icon: Icons.wifi_rounded,
                        label: 'Internet',
                        online: conn.internetOnline,
                      ),
                    ],
                  ),

                  // Greeting bezposrednio pod status dotami (nie tak wysoko
                  // jak Expanded + Align.topCenter by centrowalo, bo wizualnie
                  // ludzik gubil sie w pustce). Nad START zostaje malo miejsca
                  // zeby wszystko bylo w gornej polowie ekranu.
                  const SizedBox(height: 4),
                  const _Greeting(),
                  const SizedBox(height: 12),

                  // Duzy START tuz pod greeting, bez rozciagania Spacer'em.
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
                  // Spacer rozpycha footer na sam dol, greeting+start
                  // zostaja w gornej polowie ekranu.
                  const Spacer(),

                  // Footer: tylko Akces 360 logo (long-press 3s = sekretne
                  // wejscie do Settings - gosc nie widzi hintu).
                  Row(
                    children: [
                      _AkcesLogoGate(),
                      const Spacer(),
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
        // Ilustracja + tekst w natural size - kompakt zeby Column
        // + START button zmiescili sie w wysokosci viewportu (w landscape
        // OnePlus/Tab maja ~500-800 px wysokosci uzytecznej).
        final screenH = MediaQuery.of(context).size.height;
        final illustrationSize = (screenH * 0.28).clamp(110.0, 220.0);
        final headlineFontSize = (screenH * 0.07).clamp(28.0, 44.0);
        final subFontSize = (screenH * 0.025).clamp(12.0, 16.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Ilustracja z Claude Design (Pakiet D)
            Image.asset(
              'assets/illustrations/idle.png',
              width: illustrationSize,
              height: illustrationSize,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 4),
            Text(
              'Wejdz na platforme',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: headlineFontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Usmiech, pozycja, klik START',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: subFontSize,
                fontWeight: FontWeight.w500,
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

/// Dlugie przytrzymanie loga Akces 360 (3s) -> PIN -> Settings.
class _AkcesLogoGate extends StatefulWidget {
  @override
  State<_AkcesLogoGate> createState() => _AkcesLogoGateState();
}

class _AkcesLogoGateState extends State<_AkcesLogoGate>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 3);

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: _holdDuration,
  );

  bool _opening = false;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onDown(_) {
    _anim.forward(from: 0.0);
  }

  void _onUpOrCancel([_]) {
    if (_anim.isCompleted) return;
    _anim.stop();
    _anim.reverse();
  }

  Future<void> _onHoldComplete() async {
    if (_opening) return;
    _opening = true;
    try {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PinEntryScreen()),
      );
      if (!mounted) return;
      if (ok == true) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      }
    } finally {
      _opening = false;
      if (mounted) _anim.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onDown,
      onTapUp: _onUpOrCancel,
      onTapCancel: _onUpOrCancel,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          if (_anim.isCompleted && !_opening) {
            // Wystartuj flow po dotarciu do konca paska.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _onHoldComplete();
            });
          }
          final progress = _anim.value;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primary
                        .withValues(alpha: 0.15 + 0.7 * progress),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Akces 360',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
              ),
              // Progress fill - narastajacy pasek indigo pokazujacy 0..3s.
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
