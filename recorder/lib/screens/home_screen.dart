import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/motor_state.dart';
import '../services/motor_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/big_button.dart';
import '../widgets/status_indicator.dart';

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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            children: [
              const _TopBar(),
              const SizedBox(height: 12),
              const _StatusRow(),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Expanded(flex: 5, child: _ControlsPanel()),
                    SizedBox(width: 16),
                    Expanded(flex: 4, child: _DebugLogPanel()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
          width: 40,
          height: 40,
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
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Akces Booth Recorder',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Sesja 1 - mock motor',
              style: TextStyle(color: AppTheme.muted, fontSize: 11),
            ),
          ],
        ),
        const Spacer(),
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

class _StatusRow extends StatelessWidget {
  const _StatusRow();

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorController>();
    return Row(
      children: [
        Expanded(
          child: StatusIndicator(
            icon: Icons.bluetooth_rounded,
            label: 'BLUETOOTH',
            value: motor.isConnected ? 'Connected (mock)' : 'Connecting...',
            color: motor.isConnected ? AppTheme.success : AppTheme.muted,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: StatusIndicator(
            icon: Icons.battery_4_bar_rounded,
            label: 'BATERIA',
            value: '67%',
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: StatusIndicator(
            icon: Icons.tablet_mac_rounded,
            label: 'TABLET',
            value: 'Oczekiwanie (Sesja 3)',
            color: AppTheme.muted,
          ),
        ),
      ],
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel();

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorController>();
    final connected = motor.isConnected;
    final running = motor.isRunning;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final startSize = (h * 0.88).clamp(110.0, 220.0);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _SpeedDisplay(speed: motor.currentSpeed),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          LayoutBuilder(
                            builder: (_, c) => BigButton(
                              label: 'SPEED -',
                              icon: Icons.remove_rounded,
                              color: AppTheme.accent,
                              size: c.maxHeight,
                              disabled: !connected ||
                                  motor.currentSpeed <= MotorState.minSpeed,
                              onTap: motor.speedDown,
                            ),
                          ),
                          LayoutBuilder(
                            builder: (_, c) => BigButton(
                              label: 'SPEED +',
                              icon: Icons.add_rounded,
                              color: AppTheme.accent,
                              size: c.maxHeight,
                              disabled: !connected ||
                                  motor.currentSpeed >= MotorState.maxSpeed,
                              onTap: motor.speedUp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      flex: 3,
                      child: LayoutBuilder(
                        builder: (_, c) => Center(
                          child: BigButton(
                            label: 'REVERSE',
                            subtitle: motor.direction.label,
                            icon: motor.direction == Direction.clockwise
                                ? Icons.rotate_right_rounded
                                : Icons.rotate_left_rounded,
                            color: AppTheme.primary,
                            size: c.maxHeight,
                            disabled: !connected,
                            onTap: motor.reverseDirection,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              BigButton(
                label: running ? 'STOP' : 'START',
                icon: running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: running ? AppTheme.error : AppTheme.success,
                size: startSize,
                disabled: !connected,
                onTap: running ? motor.stop : motor.start,
              ),
            ],
          ),
        );
      },
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
      mainAxisAlignment: MainAxisAlignment.center,
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
        const SizedBox(height: 2),
        Expanded(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              speed.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
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

class _DebugLogPanel extends StatelessWidget {
  const _DebugLogPanel();

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorController>();
    final log = motor.log;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.terminal_rounded, color: AppTheme.muted, size: 16),
              SizedBox(width: 6),
              Text(
                'DEBUG LOG (MOCK BLE)',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: log.isEmpty
                ? const Center(
                    child: Text(
                      'Brak komend.\nLaczenie z fotobudka...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.muted, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: log.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        log[i],
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.greenAccent,
                          fontSize: 10,
                          height: 1.25,
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
