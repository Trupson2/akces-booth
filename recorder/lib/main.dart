import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app.dart';
import 'services/camera_service.dart';
import 'services/mock_motor_controller.dart';
import 'services/motor_controller.dart';
import 'services/music_library.dart';
import 'services/nearby_client.dart';
import 'services/nearby_permissions.dart';
import 'services/real_motor_controller.dart';
import 'services/settings_store.dart';
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

  // Nearby Connections discovery - OP13 sam szuka Tab Station w zasiegu
  // (BT+WiFi Direct hybrid). Bez hotspotu, bez IP config.
  // Start po permission check w post-runApp callback (dialog wymaga UI).
  final nearbyClient = NearbyClient(store: store);

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
        ChangeNotifierProvider<NearbyClient>.value(value: nearbyClient),
        ChangeNotifierProvider<VideoProcessor>(
          create: (_) => VideoProcessor(),
        ),
        ChangeNotifierProvider<MusicLibrary>.value(value: musicLib),
      ],
      child: const AkcesBoothRecorder(),
    ),
  );

  // Po wystartowaniu UI - request permissions, potem start Nearby discovery.
  // addPostFrameCallback czeka na pierwszy frame zeby dialog pojawil sie
  // nad zaladowana apka (nie na pustym tle).
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final granted = await NearbyPermissions.requestAll();
    if (granted) {
      await nearbyClient.start();
      debugPrint('[Recorder] Nearby discovery started');
    } else {
      debugPrint('[Recorder] Nearby permissions denied - discovery off');
    }
  });
}

void unawaited(Future<void> f) {
  // Tylko do debug - nie zjadamy errorow.
  f.catchError((Object e) => debugPrint('unawaited error: $e'));
}
