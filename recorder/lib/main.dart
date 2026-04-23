import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app.dart';
import 'services/camera_service.dart';
import 'services/mock_motor_controller.dart';
import 'services/motor_controller.dart';
import 'services/music_library.dart';
import 'services/real_motor_controller.dart';
import 'services/settings_store.dart';
import 'services/station_client.dart';
import 'services/video_processor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  // Ekran zawsze aktywny - fotobudka OnePlus nie moze sie zgasic podczas
  // eventu, bo wtedy kamera tez traci session i Recorder pada.
  // Wakelock trzyma display + CPU aktywnie caly czas dzialania apki.
  await WakelockPlus.enable();

  // Tryb demo - zapisany w SharedPreferences. Pozwala na prace bez fotobudki
  // (MockMotorController loguje komendy do debug log zamiast BLE).
  final store = SettingsStore();
  final demoMode = await store.loadDemoMode();

  final stationClient = StationClient();
  // Fire-and-forget - jesli jest zapamietany IP, od razu probuje sie polaczyc.
  unawaited(stationClient.loadAndConnect());

  // Music library - kopiuje MP3 z assets do docs/music/ przy starcie.
  final musicLib = MusicLibrary();
  unawaited(musicLib.initialize());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MotorController>(
          create: (_) => demoMode
              ? MockMotorController()
              : RealMotorController(),
        ),
        ChangeNotifierProvider<CameraService>(
          create: (_) => CameraService(),
        ),
        ChangeNotifierProvider<StationClient>.value(value: stationClient),
        ChangeNotifierProvider<VideoProcessor>(
          create: (_) => VideoProcessor(),
        ),
        ChangeNotifierProvider<MusicLibrary>.value(value: musicLib),
      ],
      child: const AkcesBoothRecorder(),
    ),
  );
}

void unawaited(Future<void> f) {
  // Tylko do debug - nie zjadamy errorow.
  f.catchError((Object e) => debugPrint('unawaited error: $e'));
}
