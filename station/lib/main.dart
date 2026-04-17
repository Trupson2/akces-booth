import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/app_state_machine.dart';
import 'services/local_server.dart';
import 'services/mock_services.dart';
import 'services/motor_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Local server startujemy z gorki, zeby Recorder mogl sie polaczyc od razu.
  final server = LocalServer();
  unawaitedStart(server);

  final stateMachine = AppStateMachine(server: server)..attachServer();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocalServer>.value(value: server),
        ChangeNotifierProvider<AppStateMachine>.value(value: stateMachine),
        ChangeNotifierProvider<ConnectivityStatus>(
          create: (_) => ConnectivityStatus(),
        ),
        ChangeNotifierProvider<MotorController>(
          create: (_) => MockStationMotorController(),
        ),
      ],
      child: const AkcesBoothStation(),
    ),
  );
}

/// Fire-and-forget bo w initState nie mozemy awaitowac.
void unawaitedStart(LocalServer s) {
  s.start();
}
