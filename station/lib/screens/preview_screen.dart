import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../models/video_job.dart';
import '../services/app_state_machine.dart';
import '../theme/app_theme.dart';
import '../widgets/big_action_button.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _missingAsset = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initVideo());
  }

  Future<void> _initVideo() async {
    final job = context.read<AppStateMachine>().currentJob;
    if (job == null) return;

    try {
      final ctrl = _resolveController(job);
      if (ctrl == null) {
        setState(() => _missingAsset = true);
        return;
      }
      _controller = ctrl
        ..setLooping(true)
        ..setVolume(0);
      await _controller!.initialize();
      if (!mounted) return;
      await _controller!.play();
      setState(() => _ready = true);
    } catch (e) {
      debugPrint('PreviewScreen video init failed: $e');
      if (!mounted) return;
      setState(() => _missingAsset = true);
    }
  }

  VideoPlayerController? _resolveController(VideoJob job) {
    if (job.localFilePath != null) {
      return VideoPlayerController.file(File(job.localFilePath!));
    }
    if (job.assetPath != null) {
      // Sprawdzimy przy initialize - brak pliku rzuci exception.
      return VideoPlayerController.asset(job.assetPath!);
    }
    return null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sm = context.watch<AppStateMachine>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Video preview area (60% wysokosci)
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildVideo(),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Jak Ci sie podoba? 😊',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),

              // Akcje
              Row(
                children: [
                  Expanded(
                    child: BigActionButton(
                      label: 'AKCEPTUJ',
                      icon: Icons.check_rounded,
                      color: AppTheme.success,
                      height: 100,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        sm.acceptVideo();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BigActionButton(
                      label: 'POWTORZ',
                      icon: Icons.replay_rounded,
                      color: AppTheme.surfaceLight,
                      height: 100,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        sm.rejectVideo();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (_missingAsset) {
      return const _VideoPlaceholder(
        message: 'Brak assets/mock_video.mp4\n'
            '(wygeneruj ffmpeg - README w assets/)',
      );
    }
    if (!_ready || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_rounded,
                size: 64, color: AppTheme.muted),
            const SizedBox(height: 12),
            const Text(
              '[MOCK VIDEO PLACEHOLDER]',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
