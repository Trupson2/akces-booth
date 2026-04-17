import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Mala kropka z ikona - BT / Recorder / WiFi w rogu IdleScreen.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.icon,
    required this.label,
    required this.online,
  });

  final IconData icon;
  final String label;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppTheme.success : AppTheme.muted;
    return Tooltip(
      message: '$label: ${online ? "OK" : "off"}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.85)),
          ],
        ),
      ),
    );
  }
}
