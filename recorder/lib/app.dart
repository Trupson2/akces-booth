import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class AkcesBoothRecorder extends StatelessWidget {
  const AkcesBoothRecorder({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akces Booth Recorder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}
