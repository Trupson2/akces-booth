import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state_machine.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_screen_template.dart';

class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sm = context.watch<AppStateMachine>();

    return ProgressScreenTemplate(
      emoji: '📡',
      title: 'Odbieram film...',
      subtitle: 'Transfer z kamery do tabletu przez WiFi',
      progress: sm.progress,
      barColor: AppTheme.accent,
    );
  }
}
