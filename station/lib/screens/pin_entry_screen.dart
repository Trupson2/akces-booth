import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/pin_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pin_keypad.dart';

/// Weryfikacja PIN-u przed wejsciem do Settings.
///
/// Zwraca `true` przez `Navigator.pop(context, true)` jesli PIN ok.
class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key});

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  String? _error;
  final _ctrl = PinKeypadController();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<PinService>();
    final locked = svc.isLocked;
    final subtitle = locked
        ? 'Zbyt wiele prob. Sprobuj za ${svc.lockSecondsLeft}s.'
        : 'Wpisz PIN aby wejsc do Settings';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('PIN'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: PinKeypad(
              controller: _ctrl,
              enabled: !locked,
              title: locked ? 'Zablokowane' : 'Podaj PIN',
              subtitle: subtitle,
              errorText: _error,
              onComplete: (pin) => _handle(pin, svc),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handle(String pin, PinService svc) async {
    final ok = await svc.verify(pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    _ctrl.clear();
    setState(() {
      if (svc.isLocked) {
        _error =
            'Zbyt wiele bledow - zablokowano na ${PinService.lockoutSeconds}s';
      } else {
        _error = 'Bledny PIN (pozostalo prob: ${svc.attemptsLeft})';
      }
    });
  }
}
