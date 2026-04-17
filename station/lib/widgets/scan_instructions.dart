import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Animowana 3-krokowa instrukcja dla starszych gosci na QR screen:
/// 1. Otworz aparat, 2. Skieruj na kod, 3. Stuknij link.
///
/// Pulsuje kolejno "aktywny" krok co ~2s, zeby zwrocic uwage.
class ScanInstructions extends StatefulWidget {
  const ScanInstructions({super.key});

  @override
  State<ScanInstructions> createState() => _ScanInstructionsState();
}

class _ScanInstructionsState extends State<ScanInstructions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        // Ktory krok aktywny: 0, 1, 2 - kazdy 2s.
        final active = (_loop.value * 3).floor().clamp(0, 2);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Step(
              number: 1,
              icon: Icons.photo_camera_rounded,
              text: 'Otworz aparat w telefonie',
              active: active == 0,
            ),
            const SizedBox(height: 8),
            _Step(
              number: 2,
              icon: Icons.qr_code_scanner_rounded,
              text: 'Skieruj go na kod obok',
              active: active == 1,
            ),
            const SizedBox(height: 8),
            _Step(
              number: 3,
              icon: Icons.touch_app_rounded,
              text: 'Stuknij w link, ktory wyskoczy',
              active: active == 2,
            ),
          ],
        );
      },
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.icon,
    required this.text,
    required this.active,
  });
  final int number;
  final IconData icon;
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? AppTheme.primary.withValues(alpha: 0.18)
        : AppTheme.surface;
    final border = active
        ? AppTheme.primary
        : Colors.white.withValues(alpha: 0.08);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: active ? AppTheme.primary : AppTheme.surfaceLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon,
              size: 20,
              color: active ? AppTheme.primary : AppTheme.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
