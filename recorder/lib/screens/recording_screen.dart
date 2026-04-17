import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recording_mode.dart';
import '../services/camera_service.dart';
import '../services/motor_controller.dart';
import '../theme/app_theme.dart';
import 'preview_screen.dart';

/// Maksymalna dlugosc nagrania (auto-stop).
const Duration _kMaxRecording = Duration(seconds: 8);

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _autoStopTimer;
  Timer? _uiTimer;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final camera = context.read<CameraService>();
      if (!camera.isInitialized && camera.status != CameraInitStatus.initializing) {
        await camera.initialize();
      }
    });
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _uiTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    final camera = context.read<CameraService>();
    final motor = context.read<MotorController>();

    if (camera.isRecording) {
      await _stopRecording();
      return;
    }

    // START: motor + camera razem
    try {
      await motor.start();
      await camera.startRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udalo sie rozpoczac: $e')),
        );
      }
      return;
    }

    // Odtwarzamy UI timer (rebuild co 100ms)
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => setState(() {}),
    );

    // Auto-stop po 8s
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(_kMaxRecording, _stopRecording);
  }

  Future<void> _stopRecording() async {
    _autoStopTimer?.cancel();
    _uiTimer?.cancel();
    _autoStopTimer = null;
    _uiTimer = null;

    final camera = context.read<CameraService>();
    final motor = context.read<MotorController>();

    final path = await camera.stopRecording();
    await motor.stop();

    if (!mounted || path == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PreviewScreen(videoPath: path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<CameraService>(
        builder: (context, camera, _) {
          return SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildPreviewOrPlaceholder(camera),
                _TopBar(camera: camera),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _BottomControls(
                    camera: camera,
                    isRecording: camera.isRecording,
                    elapsed: camera.recordingDuration,
                    max: _kMaxRecording,
                    onToggle: _toggleRecord,
                    pulse: _pulse,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewOrPlaceholder(CameraService camera) {
    switch (camera.status) {
      case CameraInitStatus.permissionDenied:
      case CameraInitStatus.permissionPermanentlyDenied:
        return _PermissionDeniedView(
          permanently:
              camera.status == CameraInitStatus.permissionPermanentlyDenied,
          onRetry: () => camera.initialize(),
          onOpenSettings: () => camera.openSystemSettings(),
        );
      case CameraInitStatus.error:
        return _ErrorView(
          message: camera.errorMessage ?? 'Blad kamery',
          onRetry: () => camera.initialize(),
        );
      case CameraInitStatus.idle:
      case CameraInitStatus.requestingPermission:
      case CameraInitStatus.initializing:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text(
                'Inicjalizacja kamery...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      case CameraInitStatus.ready:
        final ctrl = camera.controller;
        if (ctrl == null || !ctrl.value.isInitialized) {
          return const SizedBox.shrink();
        }
        // Camera preview w landscape - CameraPreview robi to automatycznie.
        return Center(
          child: AspectRatio(
            aspectRatio: ctrl.value.aspectRatio,
            child: CameraPreview(ctrl),
          ),
        );
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.camera});
  final CameraService camera;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Row(
        children: [
          _RoundBtn(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          if (camera.isInitialized)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    '${camera.mode.fps} fps',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (camera.highFpsDegraded) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.warning_amber_rounded,
                        size: 14, color: Colors.amber),
                  ],
                ],
              ),
            ),
          const Spacer(),
          if (!camera.isRecording && camera.isInitialized) _ModeChips(camera: camera),
        ],
      ),
    );
  }
}

class _ModeChips extends StatelessWidget {
  const _ModeChips({required this.camera});
  final CameraService camera;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: RecordingMode.values.map((m) {
          final selected = m == camera.mode;
          return GestureDetector(
            onTap: () => camera.setMode(m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (m.isBeta) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'BETA',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.camera,
    required this.isRecording,
    required this.elapsed,
    required this.max,
    required this.onToggle,
    required this.pulse,
  });

  final CameraService camera;
  final bool isRecording;
  final Duration elapsed;
  final Duration max;
  final VoidCallback onToggle;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    final double fraction =
        (elapsed.inMilliseconds / max.inMilliseconds).clamp(0.0, 1.0);
    final bool canTap = camera.isInitialized;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: isRecording
                ? _RecordingTimer(elapsed: elapsed, fraction: fraction, max: max)
                : _IdleHint(mode: camera.mode),
          ),
          const SizedBox(width: 16),
          _RecordButton(
            recording: isRecording,
            disabled: !canTap,
            pulse: pulse,
            onTap: onToggle,
          ),
          const SizedBox(width: 16),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint({required this.mode});
  final RecordingMode mode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'Nacisnij aby nagrac',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${mode.label} • auto-stop 8s',
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}

class _RecordingTimer extends StatelessWidget {
  const _RecordingTimer({
    required this.elapsed,
    required this.fraction,
    required this.max,
  });

  final Duration elapsed;
  final double fraction;
  final Duration max;

  @override
  Widget build(BuildContext context) {
    final sec = (elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    final total = max.inSeconds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${sec}s / ${total}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 240,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.error),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.recording,
    required this.disabled,
    required this.pulse,
    required this.onTap,
  });

  final bool recording;
  final bool disabled;
  final AnimationController pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, child) {
          final scale = recording ? 0.95 + (pulse.value * 0.1) : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: disabled
                      ? Colors.white30
                      : (recording ? AppTheme.error : Colors.white),
                  width: 4,
                ),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: recording ? 34 : 72,
                  height: recording ? 34 : 72,
                  decoration: BoxDecoration(
                    color: disabled
                        ? Colors.grey
                        : (recording ? AppTheme.error : AppTheme.error),
                    borderRadius:
                        BorderRadius.circular(recording ? 8 : 40),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.permanently,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final bool permanently;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt_outlined,
              size: 64, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            permanently
                ? 'Uprawnienia do kamery zablokowane'
                : 'Potrzebujemy dostepu do kamery i mikrofonu',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            permanently
                ? 'Wlacz uprawnienia w Ustawieniach aplikacji.'
                : 'Bez tych uprawnien nie nagramy nic.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: permanently ? onOpenSettings : onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                child: Text(permanently ? 'Otworz ustawienia' : 'Udziel zgody'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          const Text(
            'Blad kamery',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Sprobuj ponownie'),
          ),
        ],
      ),
    );
  }
}

