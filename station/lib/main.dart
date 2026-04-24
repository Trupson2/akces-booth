import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app.dart';
import 'services/app_state_machine.dart';
import 'services/backend_client.dart';
import 'services/event_manager.dart';
import 'services/local_server.dart';
import 'services/logger.dart';
import 'services/mock_services.dart';
import 'services/motor_controller.dart';
import 'services/nearby_permissions.dart';
import 'services/nearby_server.dart';
import 'services/pending_uploads.dart';
import 'services/pin_service.dart';
import 'services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Kiosk mode - ukrywa pasek statusu (gorny) + nav bar (dolny) zeby gosc
  // widzial tylko apke. `immersiveSticky`: swipe z brzegu na chwile pokazuje
  // paski, po chwili znikaja automatycznie. Dla Tab A11+ przy fotobudce =
  // single-purpose device.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
  // Ekran zawsze aktywny - Tab nie moze isc spac podczas eventu, inaczej
  // goscie nie moga kliknac START i QR nie wyswietla sie po nagraniu.
  await WakelockPlus.enable();

  // Logger najpierw - pozostale serwisy zapisza wszystko od startu.
  await Log.init();
  Log.i('Station', 'boot start');

  // Nearby advertising startujemy po permission check (post-runApp zeby
  // dialog mogl sie pokazac). LocalServer moze ruszyc od razu - HTTP nie
  // potrzebuje runtime perms.
  final nearby = NearbyServer();
  final server = LocalServer();
  unawaitedStart(server);

  final backend = BackendClient();
  final settings = SettingsStore();
  final eventManager = EventManager(
    backend: backend,
    nearby: nearby,
    settings: settings,
  );
  final pendingUploads = PendingUploadsService(backend: backend);

  final stateMachine = AppStateMachine(
    nearby: nearby,
    server: server,
    backend: backend,
    eventManager: eventManager,
    pendingUploads: pendingUploads,
  )..attachServer();

  // PIN + SettingsStore (juz utworzony wyzej) - ladujemy przed runApp,
  // zeby router mogl od razu zdecydowac czy pokazac PinSetupScreen.
  final pin = PinService();
  await Future.wait([pin.load(), settings.load(), pendingUploads.load()]);

  // Event manager start (async - loads config, first sync, starts polling).
  unawaitedStartEvents(eventManager);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NearbyServer>.value(value: nearby),
        ChangeNotifierProvider<LocalServer>.value(value: server),
        ChangeNotifierProvider<AppStateMachine>.value(value: stateMachine),
        ChangeNotifierProvider<EventManager>.value(value: eventManager),
        Provider<BackendClient>.value(value: backend),
        ChangeNotifierProvider<ConnectivityStatus>(
          create: (_) => ConnectivityStatus(),
        ),
        ChangeNotifierProvider<MotorController>(
          create: (_) => MockStationMotorController(),
        ),
        ChangeNotifierProvider<PinService>.value(value: pin),
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ChangeNotifierProvider<PendingUploadsService>.value(value: pendingUploads),
        ChangeNotifierProvider<BoothLogger>.value(value: Log),
      ],
      child: const AkcesBoothStation(),
    ),
  );

  // Po wystartowaniu UI - request permissions, potem start Nearby.
  // addPostFrameCallback czeka na pierwszy frame wiec dialog pojawi sie
  // nad zaladowana apka (nie na pustym tle).
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final granted = await NearbyPermissions.requestAll();
    if (granted) {
      await nearby.start();
      Log.i('Station', 'Nearby advertising started');
    } else {
      Log.w('Station', 'Nearby permissions denied - advertising off '
          '(Settings -> POLACZENIE -> przycisk Permissions)');
    }
  });
}

/// Fire-and-forget bo w initState nie mozemy awaitowac.
void unawaitedStart(LocalServer s) {
  s.start();
}

void unawaitedStartEvents(EventManager m) {
  m.start();
}
