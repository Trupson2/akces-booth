import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Prosty licznik z animacja przy zmianie. Uzywany na IdleScreen ("Dzis: 23 filmy").
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.label,
    this.style,
  });

  final int value;
  final String? label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final valueStyle = style ??
        const TextStyle(
          color: Colors.white,
          fontSize: 42,
          fontWeight: FontWeight.w800,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Text(
            '$value',
            key: ValueKey<int>(value),
            style: valueStyle,
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 2),
          Text(
            label!,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
