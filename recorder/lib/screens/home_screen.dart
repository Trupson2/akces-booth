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
            children: const [
              _TopBar(),
              SizedBox(height: 14),
              _StatusColumn(),
              SizedBox(height: 14),
              _StartButton(),
              SizedBox(height: 14),
              _SpeedSection(),
              SizedBox(height: 12),
              _ReverseButton(),
              SizedBox(height: 12),
              Expanded(child: _DebugLogPanel()),
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

class _DebugLogPanel extends StatelessWidget {
  const _DebugLogPanel();

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorController>();
    final log = motor.log;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 6),
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
                          height: 1.3,
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
