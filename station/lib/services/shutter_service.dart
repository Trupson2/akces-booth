import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Mostek do native'u ktory lapie klawisze z BT shutter'a (pilocika
/// sparowanego z Tabem jako HID keyboard).
///
/// MainActivity.kt override dispatchKeyEvent() - filtruje VOLUME_UP /
/// DOWN / CAMERA / MEDIA_PLAY_PAUSE / ENTER / DPAD_CENTER i wysyla
/// przez MethodChannel 'shutter'.
///
/// Uzycie:
/// ```dart
/// final shutter = ShutterService(onTrigger: () => stateMachine.startRecording());
/// shutter.start();
/// ```
class ShutterService {
  ShutterService({required this.onTrigger});

  static const _channel = MethodChannel('pl.akces360.booth.station/shutter');

  /// Wywolywane przy kazdym klikniciu BT shutter'a. Typowo: sm.startRecording().
  final VoidCallback onTrigger;

  /// Debounce - niektore shuttery dzwonia 2x dla jednego nacisku.
  DateTime _lastTrigger = DateTime.fromMillisecondsSinceEpoch(0);
  static const _debounce = Duration(milliseconds: 500);

  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'shutter') return null;
      final now = DateTime.now();
      if (now.difference(_lastTrigger) < _debounce) {
        debugPrint('[ShutterService] debounced');
        return null;
      }
      _lastTrigger = now;
      final keyCode = (call.arguments as Map?)?['keyCode'];
      debugPrint('[ShutterService] TRIGGER (keyCode=$keyCode)');
      try {
        onTrigger();
      } catch (e) {
        debugPrint('[ShutterService] onTrigger err: $e');
      }
      return null;
    });
    debugPrint('[ShutterService] started');
  }

  void stop() {
    _channel.setMethodCallHandler(null);
    _started = false;
  }
}
