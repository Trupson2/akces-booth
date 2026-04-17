import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Generyczny keypad 4-cyfrowy z kolkami postepu.
///
/// Wola [onComplete] gdy user wpisze 4 cyfry. Rodzic decyduje co dalej
/// (set PIN, verify, change PIN). Po weryfikacji rodzic moze zresetowac
/// wpis przez `clear()` via [controller].
class PinKeypad extends StatefulWidget {
  const PinKeypad({
    super.key,
    required this.onComplete,
    this.controller,
    this.title,
    this.subtitle,
    this.errorText,
    this.enabled = true,
  });

  final String? title;
  final String? subtitle;

  /// Pokazuje sie pod kropkami (czerwony). Rodzic czysci po nowej probie.
  final String? errorText;

  /// Blokuje klawisze (np. podczas lockoutu).
  final bool enabled;

  final ValueChanged<String> onComplete;
  final PinKeypadController? controller;

  @override
  State<PinKeypad> createState() => _PinKeypadState();
}

class _PinKeypadState extends State<PinKeypad> {
  String _entered = '';

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  void clear() {
    if (!mounted) return;
    setState(() => _entered = '');
  }

  void _onDigit(String d) {
    if (!widget.enabled) return;
    if (_entered.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() => _entered = _entered + d);
    if (_entered.length == 4) {
      widget.onComplete(_entered);
    }
  }

  void _onBackspace() {
    if (!widget.enabled) return;
    if (_entered.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (widget.subtitle != null)
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
        const SizedBox(height: 20),
        _Dots(count: _entered.length),
        const SizedBox(height: 10),
        SizedBox(
          height: 18,
          child: Text(
            widget.errorText ?? '',
            style: const TextStyle(
              color: AppTheme.error,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Klawiatura 3x4
        _Grid(
          enabled: widget.enabled,
          onDigit: _onDigit,
          onBackspace: _onBackspace,
        ),
      ],
    );
  }
}

class PinKeypadController {
  _PinKeypadState? _state;

  void _attach(_PinKeypadState s) => _state = s;
  void _detach() => _state = null;

  /// Wyczysc wprowadzone cyfry (po weryfikacji ktora failed).
  void clear() => _state?.clear();
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final filled = i < count;
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: filled ? AppTheme.primary : Colors.transparent,
            border: Border.all(color: AppTheme.primary, width: 2),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, {VoidCallback? onTap}) {
      return SizedBox(
        width: 80,
        height: 80,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: enabled ? onTap : null,
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Center(child: child),
          ),
        ),
      );
    }

    Widget digit(String d) => key(
          Text(
            d,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () => onDigit(d),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [digit('1'), digit('2'), digit('3')],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [digit('4'), digit('5'), digit('6')],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [digit('7'), digit('8'), digit('9')],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 80, height: 80),
            digit('0'),
            key(
              const Icon(Icons.backspace_rounded,
                  color: AppTheme.muted, size: 22),
              onTap: onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}
