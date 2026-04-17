import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state_machine.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_screen_template.dart';

class ProcessingScreen extends StatelessWidget {
  const ProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sm = context.watch<AppStateMachine>();
    final p = sm.progress;

    return ProgressScreenTemplate(
      emoji: '⏳',
      title: 'Magia w toku...',
      subtitle: 'Robimy slow-mo, dorzucamy muzyke',
      progress: p,
      barColor: AppTheme.primary,
      footer: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 60),
        child: Column(
          children: [
            _Step(label: 'Slow motion 2x', done: p > 0.33),
            const SizedBox(height: 6),
            _Step(label: 'Muzyka dodana', done: p > 0.66),
            const SizedBox(height: 6),
            _Step(label: 'Finalny render', done: p >= 1.0),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
          color: done ? AppTheme.success : AppTheme.muted,
          size: 20,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: done ? Colors.white : AppTheme.muted,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
