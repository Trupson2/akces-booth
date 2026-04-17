import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Wielki ksztalt przycisku na Tab A11+ (1280x800 landscape).
/// Zoptymalizowany pod "gosc klika palcem w stresie imprezy".
class BigActionButton extends StatefulWidget {
  const BigActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = AppTheme.primary,
    this.subtitle,
    this.height = 120,
    this.disabled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final String? subtitle;
  final double height;
  final bool disabled;

  @override
  State<BigActionButton> createState() => _BigActionButtonState();
}

class _BigActionButtonState extends State<BigActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.disabled
        ? widget.color.withValues(alpha: 0.25)
        : widget.color;

    return Opacity(
      opacity: widget.disabled ? 0.55 : 1,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
          final glow = widget.disabled
              ? 0.0
              : (0.25 + (_pulse.value * 0.25));
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.disabled ? null : widget.onTap,
              borderRadius: BorderRadius.circular(28),
              child: Ink(
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bg, bg.withValues(alpha: 0.7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: glow),
                      blurRadius: 32,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, size: 44, color: Colors.white),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.subtitle!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
