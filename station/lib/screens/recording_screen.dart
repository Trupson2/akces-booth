import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state_machine.dart';
import '../theme/app_theme.dart';
import '../widgets/big_action_button.dart';
import '../widgets/progress_screen_template.dart';

class RecordingScreen extends StatelessWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sm = context.watch<AppStateMachine>();
    final seconds = AppStateMachine.recordingDuration.inSeconds;
    final currentSec = (sm.progress * seconds).clamp(0.0, seconds.toDouble());

    return ProgressScreenTemplate(
      emoji: '🔴',
      title: 'NAGRYWAM...',
      subtitle: 'Usmiechnij sie! 😊',
      progress: sm.progress,
      barColor: AppTheme.error,
      percentLabel: '${currentSec.toStringAsFixed(1)}s / ${seconds}s',
      footer: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: BigActionButton(
          label: 'STOP TERAZ',
          icon: Icons.stop_rounded,
          color: AppTheme.error,
          height: 96,
          onTap: sm.stopRecordingEarly,
        ),
      ),
    );
  }
}
