import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Wspolna baza dla stanow z progressem: recording / processing / transfer / uploading.
/// Layout samo-skalujacy - dziala zarowno na Tab A11+ (800h) jak telefonie landscape (~380h).
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            // Skalowanie font/emoji w zakresie telefon..tablet (380..800).
            final emojiSize = (h * 0.12).clamp(32.0, 80.0);
            final titleSize = (h * 0.085).clamp(24.0, 48.0);
            final subSize = (h * 0.03).clamp(12.0, 18.0);
            final pctSize = (h * 0.045).clamp(16.0, 28.0);

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 32,
                vertical: (h * 0.04).clamp(12.0, 32.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: TextStyle(fontSize: emojiSize)),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: subSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Progress
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pct,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: pctSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  if (footer != null) ...[
                    const SizedBox(height: 12),
                    footer!,
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
