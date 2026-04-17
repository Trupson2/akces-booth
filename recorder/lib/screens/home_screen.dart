import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/motor_state.dart';
import '../services/motor_controller.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TopBar(),
              const SizedBox(height: 14),
              const _StatusColumn(),
              const SizedBox(height: 14),
              const _StartButton(),
              const SizedBox(height: 14),
              const _SpeedSection(),
              const SizedBox(height: 12),
              const _ReverseButton(),
              const SizedBox(height: 12),
              const Spacer(),
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
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.camera_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Akces Booth Recorder',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Sesja 1 - mock motor',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.muted, fontSize: 11),
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
}

class _StatusColumn extends StatelessWidget {
  const _StatusColumn();

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatusIndicator(
          icon: Icons.bluetooth_rounded,
          label: 'BLUETOOTH',
          value: motor.isConnected ? 'Connected (mock)' : 'Connecting...',
          color: motor.isConnected ? AppTheme.success : AppTheme.muted,
        ),
        const SizedBox(height: 8),
        const StatusIndicator(
          icon: Icons.battery_4_bar_rounded,
          label: 'BATERIA',
          value: '67%',
          color: AppTheme.success,
        ),
        const SizedBox(height: 8),
        const StatusIndicator(
          icon: Icons.tablet_mac_rounded,
          label: 'TABLET',
          value: 'Oczekiwanie (Sesja 3)',
          color: AppTheme.muted,
        ),
      ],
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
                'DEBUG LOG (MOCK BLE)',
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
                      'DEBUG LOG (MOCK BLE)',
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
