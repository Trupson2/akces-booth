import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/camera_service.dart';
import 'services/motor_controller.dart';
import 'services/real_motor_controller.dart';
import 'services/station_client.dart';
import 'services/video_processor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  final stationClient = StationClient();
  // Fire-and-forget - jesli jest zapamietany IP, od razu probuje sie polaczyc.
  unawaited(stationClient.loadAndConnect());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MotorController>(
          create: (_) => RealMotorController(),
        ),
        ChangeNotifierProvider<CameraService>(
          create: (_) => CameraService(),
        ),
        ChangeNotifierProvider<StationClient>.value(value: stationClient),
        ChangeNotifierProvider<VideoProcessor>(
          create: (_) => VideoProcessor(),
        ),
      ],
      child: const AkcesBoothRecorder(),
    ),
  );
}

void unawaited(Future<void> f) {
  // Tylko do debug - nie zjadamy errorow.
  f.catchError((Object e) => debugPrint('unawaited error: $e'));
}
