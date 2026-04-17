import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state_machine.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_screen_template.dart';

class UploadingScreen extends StatelessWidget {
  const UploadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sm = context.watch<AppStateMachine>();

    return ProgressScreenTemplate(
      emoji: '☁️',
      title: 'Wysylam na serwer...',
      subtitle: 'Film bedzie dostepny pod unikalnym linkiem',
      progress: sm.progress,
      barColor: AppTheme.success,
    );
  }
}
