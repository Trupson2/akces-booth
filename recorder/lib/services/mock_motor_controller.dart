import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/motor_state.dart';
import 'motor_controller.dart';

/// Mock implementacja - loguje hex komendy do konsoli zamiast wysyla\u0107 BLE.
/// Podmieniamy na prawdziwy driver w Sesji 7.
class MockMotorController extends MotorController {
  MotorState _state = const MotorState.initial();
  final List<String> _log = <String>[];

  static const int _logLimit = 10;

  @override
  MotorState get state => _state;

  @override
  List<String> get log => List.unmodifiable(_log);

  /// Przykladowe naglowki protokolu - imitujemy to co prawdopodobnie wysyla ChackTok.
  static const int _header = 0xA5;
  static const int _cmdConnect = 0xC0;
  static const int _cmdDisconnect = 0xCF;
  static const int _cmdStart = 0x01;
  static const int _cmdStop = 0x02;
  static const int _cmdSpeed = 0x03;
  static const int _cmdDirection = 0x04;

  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

  String _ts() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  /// Zapisuje wpis i robi notifyListeners(). CRC/checksum bajt na koncu (mock 0x5A).
  void _pushCmd(List<int> payload, String description) {
    final bytes = [_header, ...payload, 0x5A];
    final line = '[${_ts()}] [MOCK] [${_hex(bytes)}] $description';
    debugPrint(line);
    _log.insert(0, line);
    if (_log.length > _logLimit) {
      _log.removeRange(_logLimit, _log.length);
    }
  }

  @override
  Future<void> connect() async {
    if (_state.connected) return;
    _pushCmd(const [_cmdConnect, 0x00, 0x00], 'CONNECT scan...');
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _state = _state.copyWith(connected: true);
    _pushCmd(const [_cmdConnect, 0x01, 0x00], 'CONNECT ok');
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    if (!_state.connected) return;
    _pushCmd(const [_cmdDisconnect, 0x00, 0x00], 'DISCONNECT');
    _state = const MotorState.initial();
    notifyListeners();
  }

  @override
  Future<void> start() async {
    if (!_state.connected) {
      debugPrint('[${_ts()}] [MOCK] START ignored - not connected');
      return;
    }
    _pushCmd(const [_cmdStart, 0x00, 0x00], 'START command');
    _state = _state.copyWith(running: true);
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    if (!_state.connected) return;
    _pushCmd(const [_cmdStop, 0x00, 0x00], 'STOP command');
    _state = _state.copyWith(running: false);
    notifyListeners();
  }

  @override
  Future<void> setSpeed(int level) async {
    final clamped = level.clamp(MotorState.minSpeed, MotorState.maxSpeed);
    _pushCmd([_cmdSpeed, clamped, 0x00], 'SET_SPEED=$clamped');
    _state = _state.copyWith(speed: clamped);
    notifyListeners();
  }

  @override
  Future<void> speedUp() => setSpeed(_state.speed + 1);

  @override
  Future<void> speedDown() => setSpeed(_state.speed - 1);

  @override
  Future<void> reverseDirection() async {
    final next = _state.direction.flipped;
    final byte = next == Direction.clockwise ? 0x00 : 0x01;
    _pushCmd([_cmdDirection, byte, 0x00], 'REVERSE -> ${next.label}');
    _state = _state.copyWith(direction: next);
    notifyListeners();
  }
}
