import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/app_state.dart';
import 'screens/error_screen.dart';
import 'screens/idle_screen.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/preview_screen.dart';
import 'screens/processing_screen.dart';
import 'screens/qr_display_screen.dart';
import 'screens/recording_screen.dart';
import 'screens/thank_you_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/uploading_screen.dart';
import 'services/app_state_machine.dart';
import 'services/pin_service.dart';
import 'theme/app_theme.dart';

class AkcesBoothStation extends StatelessWidget {
  const AkcesBoothStation({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akces Booth Station',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const _Router(),
    );
  }
}

class _Router extends StatelessWidget {
  const _Router();

  @override
  Widget build(BuildContext context) {
    final pin = context.watch<PinService>();

    // Pierwszy start - PIN nie ustawiony. Wymus setup zanim ktokolwiek
    // bedzie mogl doklikac do Settings.
    if (!pin.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!pin.isPinSet) {
      return const PinSetupScreen(
        title: 'Witaj w Akces Booth',
        subtitle: 'Ustaw 4-cyfrowy PIN chroniacy Settings',
        closable: false,
      );
    }

    return Consumer<AppStateMachine>(
      builder: (context, sm, child) {
        final screen = _screenFor(sm.state);
        // Plynne przejscia miedzy stanami.
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: child,
          ),
          child: KeyedSubtree(
            key: ValueKey<AppState>(sm.state),
            child: screen,
          ),
        );
      },
    );
  }

  Widget _screenFor(AppState state) {
    switch (state) {
      case AppState.idle:
        return const IdleScreen();
      case AppState.recording:
        return const RecordingScreen();
      case AppState.processing:
        return const ProcessingScreen();
      case AppState.transfer:
        return const TransferScreen();
      case AppState.preview:
        return const PreviewScreen();
      case AppState.uploading:
        return const UploadingScreen();
      case AppState.qrDisplay:
        return const QrDisplayScreen();
      case AppState.thankYou:
        return const ThankYouScreen();
      case AppState.error:
        return const ErrorScreen();
    }
  }
}
