import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ThankYouScreen extends StatelessWidget {
  const ThankYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0x5510B981),
                  Color(0xFF0F172A),
                ],
                radius: 1.2,
                center: Alignment.center,
              ),
            ),
          ),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🙂', style: TextStyle(fontSize: 96)),
                SizedBox(height: 16),
                Text(
                  'Dziekujemy!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Zapraszamy kolejnego goscia',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
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
