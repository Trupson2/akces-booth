import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/recording_screen.dart';
import 'services/nearby_client.dart';
import 'theme/app_theme.dart';

/// Globalny navigator key - uzywany zeby otworzyc RecordingScreen gdy
/// przyjdzie WS start od Station a jestesmy na HomeScreen.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class AkcesBoothRecorder extends StatefulWidget {
  const AkcesBoothRecorder({super.key});

  @override
  State<AkcesBoothRecorder> createState() => _AkcesBoothRecorderState();
}

class _AkcesBoothRecorderState extends State<AkcesBoothRecorder> {
  @override
  void initState() {
    super.initState();
    // Globalny fallback handler. Jesli jestesmy na HomeScreen i Station
    // pushuje start, pushujemy RecordingScreen(autoStart: true).
    // RecordingScreen przy initState nadpisuje handler na _toggleRecord
    // zeby nie stakowac RecordingScreenow jak user jest juz w nim.
    // W dispose RecordingScreen przywraca ten globalny handler.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      installGlobalStartHandler(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akces Booth Recorder',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}

/// Instaluje handler onStartRequested ktory otwiera RecordingScreen z autoStart.
/// Wywolywany z app.dart na init i z RecordingScreen.dispose.
void installGlobalStartHandler(BuildContext context) {
  final client = context.read<NearbyClient>();
  client.onStartRequested = () {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const RecordingScreen(autoStart: true),
      ),
    );
  };
  client.onStopRequested = null; // Stop tylko na RecordingScreen.
}
