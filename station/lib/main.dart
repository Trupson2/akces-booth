import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/app_state_machine.dart';
import 'services/mock_services.dart';
import 'services/motor_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateMachine>(
          create: (_) => AppStateMachine(),
        ),
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
