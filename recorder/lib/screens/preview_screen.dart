import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../services/camera_service.dart';
import '../theme/app_theme.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.videoPath});
  final String videoPath;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  int _sizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..setLooping(true)
      ..initialize().then((_) async {
        if (!mounted) return;
        _sizeBytes = await File(widget.videoPath).length();
        setState(() => _ready = true);
        await _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _retake() async {
    final camera = context.read<CameraService>();
    await camera.deleteRecording(widget.videoPath);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _accept() {
    // TODO(sesja-4): transfer do Station przez WiFi.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Plik zachowany. Transfer do Station w Sesji 4 (placeholder).'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: _ready
                  ? AspectRatio(
                      // FFmpeg wypisuje MP4 z prawidlowym aspect (transpose+scale
                      // juz w video_processor). Czytamy wymiary z pliku bez
                      // forsowania portrait/landscape - controller wie jak jest.
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(color: AppTheme.primary),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _retake,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                ),
              ),
            ),
            if (_ready)
              Positioned(
                top: 12,
                right: 12,
                child: _MetadataBadge(
                  duration: _controller.value.duration,
                  size: _sizeBytes,
                  resolution:
                      '${_controller.value.size.width.toInt()}x${_controller.value.size.height.toInt()}',
                ),
              ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 20,
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Nagraj ponownie',
                      icon: Icons.replay_rounded,
                      color: Colors.white24,
                      textColor: Colors.white,
                      onTap: _retake,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActionButton(
                      label: 'Uzyj tego filmu',
                      icon: Icons.check_rounded,
                      color: AppTheme.success,
                      textColor: Colors.white,
                      onTap: _ready ? _accept : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataBadge extends StatelessWidget {
  const _MetadataBadge({
    required this.duration,
    required this.size,
    required this.resolution,
  });

  final Duration duration;
  final int size;
  final String resolution;

  String _formatSize(int b) {
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final durStr =
        '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.movie_rounded, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            '$durStr • $resolution • ${_formatSize(size)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
