import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/motor_state.dart';
import '../services/mock_motor_controller.dart';
import '../services/motor_controller.dart';
import '../services/nearby_client.dart';
import '../services/nearby_permissions.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/big_button.dart';
import '../widgets/status_indicator.dart';
import 'recording_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-connect po pierwszej klatce.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MotorController>().connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Scrollowalna sekcja glowna - na mniejszych telefonach
              // po prostu scrolluje sie, zero overflow.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const [
                      _TopBar(),
                      SizedBox(height: 8),
                      _EventBadge(),
                      SizedBox(height: 12),
                      _StatusColumn(),
                      SizedBox(height: 12),
                      _StartButton(),
                      SizedBox(height: 12),
                      _SpeedSection(),
                      SizedBox(height: 10),
                      _ReverseButton(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _DebugLogButton(onTap: () => _openDebugLog(context)),
            ],
          ),
        ),
      ),
    );
  }

  void _openDebugLog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DebugLogSheet(),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorController>();
    final isDemo = motor is MockMotorController;
    return Row(
      children: [
        GestureDetector(
          onLongPress: () => _openDemoDialog(context, isDemo: isDemo),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDemo
                    ? const [Colors.orange, Colors.deepOrange]
                    : const [AppTheme.primary, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.camera_rounded,
                color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Akces Booth Recorder',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                isDemo
                    ? 'TRYB DEMO - bez fotobudki'
                    : 'Fotobudka 360 - motor BLE',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDemo ? Colors.orangeAccent : AppTheme.muted,
                  fontSize: 11,
                  fontWeight: isDemo ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        Icon(
          motor.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
          color: motor.isConnected ? AppTheme.success : AppTheme.muted,
          size: 22,
        ),
        const SizedBox(width: 10),
        const Icon(Icons.battery_std_rounded, color: AppTheme.muted, size: 22),
        const SizedBox(width: 10),
        const Icon(Icons.tablet_rounded, color: AppTheme.muted, size: 22),
      ],
    );
  }

  Future<void> _openDemoDialog(BuildContext context,
      {required bool isDemo}) async {
    HapticFeedback.mediumImpact();
    final want = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          isDemo ? 'Wylaczyc tryb demo?' : 'Wlaczyc tryb demo?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          isDemo
              ? 'Recorder wroci do prawdziwej fotobudki (BLE). Wymaga restartu apki.'
              : 'Recorder bedzie dzialal bez fotobudki - wszystkie komendy motor '
                'logowane do debug log zamiast BLE. Przydatne do testow bez sprzetu.\n\n'
                'Wymaga restartu apki.',
          style: const TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Anuluj', style: TextStyle(color: AppTheme.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text(
              isDemo ? 'Wylacz demo' : 'Wlacz demo',
              style: const TextStyle(color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
    if (want != true || !context.mounted) return;
    await SettingsStore().saveDemoMode(!isDemo);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Zrestartuj apke',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Zamknij i otworz apke zeby zmiana sie zastosowala.',
          style: TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('OK', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }
}

/// Kompaktowy pasek z nazwa aktywnego eventu (dostarczonego przez Station
/// przez event_config WS). Wyswietla sie tylko gdy event jest aktywny -
/// inaczej zera pionowej wysokosci (sam SizedBox.shrink).
class _EventBadge extends StatelessWidget {
  const _EventBadge();

  @override
  Widget build(BuildContext context) {
    final client = context.watch<NearbyClient>();
    final cfg = client.lastEventConfig;
    final name = cfg?.eventName.trim();
    if (name == null || name.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'AKTYWNY EVENT',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusColumn extends StatelessWidget {
  const _StatusColumn();

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorController>();
    final client = context.watch<NearbyClient>();

    String stationValue;
    Color stationColor;
    switch (client.state) {
      case NearbyClientState.connected:
        stationValue = 'Nearby polaczony';
        stationColor = AppTheme.success;
        break;
      case NearbyClientState.discovering:
        stationValue = 'Szukam...';
        stationColor = AppTheme.muted;
        break;
      case NearbyClientState.connecting:
        stationValue = 'Lacze...';
        stationColor = AppTheme.muted;
        break;
      case NearbyClientState.error:
        stationValue = client.lastError ?? 'Blad Nearby';
        stationColor = AppTheme.error;
        break;
      case NearbyClientState.idle:
        stationValue = 'Nearby wylaczony';
        stationColor = AppTheme.muted;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatusIndicator(
          icon: Icons.bluetooth_rounded,
          label: 'BLUETOOTH',
          value: motor.isConnected ? '360 Controller polaczony' : 'Laczenie...',
          color: motor.isConnected ? AppTheme.success : AppTheme.muted,
        ),
        const SizedBox(height: 8),
        const _BatteryIndicator(),
        const SizedBox(height: 8),
        // Nearby auto-discovery - nie ma juz Setup screena (IP config
        // byl tylko dla WS). Tap -> status bottom sheet z permission retry.
        InkWell(
          onTap: () => _showNearbyActions(context),
          borderRadius: BorderRadius.circular(12),
          child: StatusIndicator(
            icon: Icons.tablet_mac_rounded,
            label: 'STATION',
            value: stationValue,
            color: stationColor,
          ),
        ),
      ],
    );
  }

  void _showNearbyActions(BuildContext context) {
    final n = context.read<NearbyClient>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nearby: ${n.state.name}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              if (n.lastError != null) ...[
                const SizedBox(height: 6),
                Text(n.lastError!,
                    style: const TextStyle(
                        color: AppTheme.error, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final granted = await NearbyPermissions.requestAll();
                  if (!context.mounted) return;
                  if (granted) {
                    await n.start();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Permissions OK - szukam Station')),
                    );
                  } else if (await NearbyPermissions.anyPermanentlyDenied()) {
                    if (!context.mounted) return;
                    _showPermDeniedDialog(context);
                  } else {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Czesc permissions odrzucona')),
                    );
                  }
                },
                icon: const Icon(Icons.verified_user_rounded, size: 16),
                label: const Text('Sprawdz permissions'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await n.start();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Restart discovery'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPermDeniedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Permissions zablokowane',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Niektore permissions sa ustawione "Nigdy nie pytaj". '
          'Otworz systemowe ustawienia aplikacji i odblokuj recznie: '
          'Bluetooth (Advertise/Connect/Scan), Lokalizacja, Nearby WiFi.',
          style: TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dCtx).pop();
              await NearbyPermissions.openSystemSettings();
            },
            child: const Text('Otworz Settings'),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorController>();
    final connected = motor.isConnected;
    final running = motor.isRunning;

    return SizedBox(
      height: 150,
      child: LayoutBuilder(
        builder: (_, c) => BigButton(
          label: running ? 'STOP' : 'START',
          icon: running ? Icons.stop_rounded : Icons.videocam_rounded,
          color: running ? AppTheme.error : AppTheme.success,
          size: 150,
          width: c.maxWidth,
          height: 150,
          disabled: !connected,
          onTap: running
              ? motor.stop
              : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RecordingScreen(),
                    ),
                  ),
        ),
      ),
    );
  }
}

class _SpeedSection extends StatelessWidget {
  const _SpeedSection();

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorController>();
    final connected = motor.isConnected;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SpeedDisplay(speed: motor.currentSpeed),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, c) => BigButton(
                      label: 'SPEED -',
                      icon: Icons.remove_rounded,
                      color: AppTheme.accent,
                      size: 56,
                      width: c.maxWidth,
                      height: 56,
                      disabled: !connected ||
                          motor.currentSpeed <= MotorState.minSpeed,
                      onTap: motor.speedDown,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, c) => BigButton(
                      label: 'SPEED +',
                      icon: Icons.add_rounded,
                      color: AppTheme.accent,
                      size: 56,
                      width: c.maxWidth,
                      height: 56,
                      disabled: !connected ||
                          motor.currentSpeed >= MotorState.maxSpeed,
                      onTap: motor.speedUp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedDisplay extends StatelessWidget {
  const _SpeedDisplay({required this.speed});
  final int speed;

  @override
  Widget build(BuildContext context) {
    final fraction = (speed - MotorState.minSpeed) /
        (MotorState.maxSpeed - MotorState.minSpeed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'PREDKOSC',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.muted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          speed.toString(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 52,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
      ],
    );
  }
}

/// Pokazuje aktualny % baterii - battery_plus, odswieza co 30s i na
/// zmiany stanu (charging/discharging). Ikonka adaptuje sie do level.
class _BatteryIndicator extends StatefulWidget {
  const _BatteryIndicator();

  @override
  State<_BatteryIndicator> createState() => _BatteryIndicatorState();
}

class _BatteryIndicatorState extends State<_BatteryIndicator> {
  final Battery _battery = Battery();
  int? _level;
  BatteryState _state = BatteryState.unknown;
  Timer? _timer;
  StreamSubscription<BatteryState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    // BatteryState changes - trigger natychmiastowy refresh po wpieciu
    // ladowarki / odepnieciu (zeby kolor i ikona sie odswiezyly od razu).
    _stateSub = _battery.onBatteryStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
      _refresh();
    });
  }

  Future<void> _refresh() async {
    try {
      final lvl = await _battery.batteryLevel;
      if (!mounted) return;
      setState(() => _level = lvl.clamp(0, 100));
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  IconData get _icon {
    final l = _level ?? 0;
    if (_state == BatteryState.charging) return Icons.battery_charging_full_rounded;
    if (l >= 90) return Icons.battery_full_rounded;
    if (l >= 75) return Icons.battery_6_bar_rounded;
    if (l >= 50) return Icons.battery_4_bar_rounded;
    if (l >= 30) return Icons.battery_3_bar_rounded;
    if (l >= 15) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  Color get _color {
    final l = _level ?? 100;
    if (_state == BatteryState.charging) return AppTheme.success;
    if (l >= 30) return AppTheme.success;
    if (l >= 15) return Colors.orange;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final value = _level == null
        ? '...'
        : (_state == BatteryState.charging
            ? '$_level% (ladowanie)'
            : '$_level%');
    return StatusIndicator(
      icon: _icon,
      label: 'BATERIA',
      value: value,
      color: _color,
    );
  }
}

class _ReverseButton extends StatelessWidget {
  const _ReverseButton();

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorController>();
    final connected = motor.isConnected;

    return SizedBox(
      height: 64,
      child: LayoutBuilder(
        builder: (_, c) => BigButton(
          label: 'REVERSE',
          subtitle: motor.direction.label,
          icon: motor.direction == Direction.clockwise
              ? Icons.rotate_right_rounded
              : Icons.rotate_left_rounded,
          color: AppTheme.primary,
          size: 64,
          width: c.maxWidth,
          height: 64,
          disabled: !connected,
          onTap: motor.reverseDirection,
        ),
      ),
    );
  }
}

class _DebugLogButton extends StatelessWidget {
  const _DebugLogButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorController>();
    final count = motor.log.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              const Icon(Icons.terminal_rounded,
                  color: AppTheme.muted, size: 18),
              const SizedBox(width: 10),
              const Text(
                'DEBUG LOG (BLE 360)',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_up_rounded,
                  color: AppTheme.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugLogSheet extends StatelessWidget {
  const _DebugLogSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Grab handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.terminal_rounded,
                        color: AppTheme.muted, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'DEBUG LOG (BLE 360)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Zamknij',
                      icon: const Icon(Icons.close_rounded,
                          color: AppTheme.muted),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              Expanded(
                child: Consumer<MotorController>(
                  builder: (_, motor, child) {
                    final log = motor.log;
                    if (log.isEmpty) {
                      return const Center(
                        child: Text(
                          'Brak komend.\nLaczenie z fotobudka...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.muted, fontSize: 13),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      itemCount: log.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: SelectableText(
                          log[i],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.greenAccent,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
