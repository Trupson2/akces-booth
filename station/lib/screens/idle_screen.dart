import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state_machine.dart';
import '../services/event_manager.dart';
import '../services/mock_services.dart';
import '../services/nearby_server.dart';
import '../services/settings_store.dart';
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
    final nearby = context.watch<NearbyServer>();
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
              // SingleChildScrollView zabezpiecza przed overflow na waskich
              // landscape viewportach (np. S21 Ultra). Gdy content miesci sie
              // w wysokosci - zachowuje sie jak Column (Spacer dziala). Gdy
              // nie - mozna przescrollowac zeby zobaczyc footer (logo).
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.vertical - 40,
                  ),
                  child: Column(
                children: [
                  // Top bar: status indicators + dzienny licznik + gear settings
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
                        // Real: z Nearby Connections. Fallback: z mock serwisu.
                        online: nearby.isRecorderConnected ||
                            conn.recorderOnline,
                      ),
                      const SizedBox(width: 8),
                      StatusDot(
                        icon: Icons.wifi_rounded,
                        label: 'Internet',
                        online: conn.internetOnline,
                      ),
                      const SizedBox(width: 8),
                      // Widoczny przycisk settings - gosc nie wejdzie bez PIN,
                      // wiec branding+sekret przez logo zostaje (fallback),
                      // a admin ma szybki dostep bez kombinowania z 3s hold.
                      _SettingsGearButton(),
                    ],
                  ),

                  // Greeting bezposrednio pod status dotami (nie tak wysoko
                  // jak Expanded + Align.topCenter by centrowalo, bo wizualnie
                  // ludzik gubil sie w pustce). Nad START zostaje malo miejsca
                  // zeby wszystko bylo w gornej polowie ekranu.
                  const SizedBox(height: 4),
                  const _Greeting(),
                  const SizedBox(height: 8),

                  // Quick-toggle rozdzielczosci - szybki wybor bez wchodzenia
                  // w Settings. Obsluga klika przed eventem FullHD (szybko)
                  // lub 4K (premium, wolniejsze).
                  const _ResolutionChip(),
                  const SizedBox(height: 8),

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
                  // Wewnatrz SingleChildScrollView Spacer nie zadziala
                  // (nieograniczona wysokosc). Staly margin zeby footer nie
                  // wchodzil za blisko START.
                  const SizedBox(height: 40),

                  // Footer: tylko Akces 360 logo (long-press 3s = sekretne
                  // wejscie do Settings - gosc nie widzi hintu). Plus widoczna
                  // ikonka ustawien w topbarze dla admina.
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
            ),
          ),
        ],
      ),
    );
  }
}

/// Widoczna ikonka kolnierzasto-zebatki w topbarze - admin PIN -> Settings.
/// Drugi wariant oprocz long-press _AkcesLogoGate; oba prowadza przez PIN.
class _SettingsGearButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const PinEntryScreen()),
          );
          if (ok == true && context.mounted) {
            await Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          }
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.6),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.settings_rounded,
            color: Colors.white70,
            size: 20,
          ),
        ),
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

/// Quick-toggle rozdzielczosci na ekranie IDLE.
///
/// Klik pokazuje bottom sheet z wyborem Full HD / 4K + krotki opis
/// (szybkosc transferu vs jakosc). Zmiana natychmiast pushuje do Recordera
/// przez WS (bez czekania na 30s poll).
class _ResolutionChip extends StatelessWidget {
  const _ResolutionChip();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final isHd = settings.resolution == 'fullHd';
    final label = isHd ? 'Full HD · szybko' : '4K · premium';
    final icon = isHd ? Icons.flash_on_rounded : Icons.hd_rounded;

    return Center(
      child: GestureDetector(
        onTap: () => _showPicker(context, settings),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: isHd ? 0.3 : 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16,
                  color: isHd ? AppTheme.success : AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.unfold_more_rounded,
                  size: 14, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, SettingsStore settings) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Rozdzielczosc nagrania',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Zmiana dotyczy nastepnego nagrania',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                _ResolutionOption(
                  icon: Icons.flash_on_rounded,
                  iconColor: AppTheme.success,
                  title: 'Full HD 1080p',
                  subtitle: 'Szybko · transfer Nearby 2-4s · ~40MB',
                  selected: settings.resolution == 'fullHd',
                  onTap: () async {
                    await settings.setResolution('fullHd');
                    if (ctx.mounted) {
                      context.read<EventManager>().pushRecorderConfig();
                      Navigator.of(ctx).pop();
                    }
                  },
                ),
                const SizedBox(height: 8),
                _ResolutionOption(
                  icon: Icons.hd_rounded,
                  iconColor: AppTheme.accent,
                  title: '4K Ultra HD',
                  subtitle: 'Premium · transfer Nearby 8-15s · ~150MB',
                  selected: settings.resolution == 'uhd4k',
                  onTap: () async {
                    await settings.setResolution('uhd4k');
                    if (ctx.mounted) {
                      context.read<EventManager>().pushRecorderConfig();
                      Navigator.of(ctx).pop();
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResolutionOption extends StatelessWidget {
  const _ResolutionOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : AppTheme.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.primary : Colors.white.withValues(alpha: 0.06),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
