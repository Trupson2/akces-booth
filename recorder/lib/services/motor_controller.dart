import 'package:flutter/foundation.dart';

import '../models/motor_state.dart';

/// Abstract interface sterownika silnika fotobudki 360.
///
/// Implementacje:
///   * [MockMotorController] - Sesja 1 (konsola zamiast BLE)
///   * RealMotorController   - Sesja 7 (po reverse engineeringu ChackTok)
abstract class MotorController extends ChangeNotifier {
  MotorState get state;

  bool get isConnected => state.connected;
  bool get isRunning => state.running;
  int get currentSpeed => state.speed;
  Direction get direction => state.direction;

  /// Ostatnie 10 wpisow FIFO - do debug panelu w UI.
  List<String> get log;

  Future<void> connect();
  Future<void> disconnect();

  Future<void> start();
  Future<void> stop();

  Future<void> setSpeed(int level);
  Future<void> speedUp();
  Future<void> speedDown();

  Future<void> reverseDirection();
}
