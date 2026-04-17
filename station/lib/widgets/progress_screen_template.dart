import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Wspolna baza dla stanow z progressem: recording / processing / transfer / uploading.
class ProgressScreenTemplate extends StatelessWidget {
  const ProgressScreenTemplate({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.progress,
    this.barColor = AppTheme.primary,
    this.footer,
    this.percentLabel,
  });

  final String emoji;
  final String title;
  final String subtitle;

  /// 0.0 - 1.0.
  final double progress;
  final Color barColor;
  final Widget? footer;

  /// Overrides automatyczny "XX%" (np. dla recording "3.5s / 8s").
  final String? percentLabel;

  @override
  Widget build(BuildContext context) {
    final pct = percentLabel ?? '${(progress * 100).toInt()}%';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Text(emoji, style: const TextStyle(fontSize: 72)),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),

              // Progress
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 16,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                pct,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const Spacer(),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}
