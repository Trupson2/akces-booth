import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/pin_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pin_keypad.dart';

/// Dwuetapowy setup PIN-u: wpisz -> potwierdz.
///
/// Uzywany:
/// - pierwszy start apki (pusty pin) -> barierka w IDLE
/// - ze Settings "Zmien PIN" (wtedy rodzic ma juz stary PIN zweryfikowany)
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({
    super.key,
    this.title = 'Ustaw PIN',
    this.subtitle = 'Wybierz 4-cyfrowy PIN do Settings',
    this.closable = false,
  });

  final String title;
  final String subtitle;

  /// True = mozna wyjsc bez ustawienia (zmiana PIN). False = wymuszone (first start).
  final bool closable;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _first;
  String? _error;
  final _ctrl = PinKeypadController();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<PinService>();
    final stage2 = _first != null;

    return Scaffold(
      appBar: widget.closable
          ? AppBar(
              backgroundColor: AppTheme.surface,
              title: Text(widget.title),
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: PinKeypad(
              controller: _ctrl,
              title: stage2 ? 'Powtorz PIN' : widget.title,
              subtitle: stage2
                  ? 'Wpisz jeszcze raz ten sam PIN'
                  : widget.subtitle,
              errorText: _error,
              onComplete: (pin) => _handle(pin, svc),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handle(String pin, PinService svc) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      _ctrl.clear();
      return;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = 'PIN-y sie nie zgadzaja - sprobuj jeszcze raz';
      });
      _ctrl.clear();
      return;
    }
    await svc.setPin(pin);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PIN ustawiony'),
        duration: Duration(seconds: 2),
      ),
    );
    // Pop tylko gdy PinSetupScreen byl pushed (closable = zmiana PIN w Settings).
    // Przy first-setup (closable=false) ekran jest root widget w _Router -
    // Navigator.pop tam = exit apki / czarny ekran. _Router rebuild (trigger
    // przez notifyListeners w svc.setPin) zastapi PinSetupScreen IdleScreenem.
    if (widget.closable && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }
}
