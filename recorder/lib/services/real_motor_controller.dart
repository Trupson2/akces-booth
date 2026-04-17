import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/motor_state.dart';
import 'booth_protocol.dart';
import 'motor_controller.dart';

/// Prawdziwa implementacja [MotorController] - BLE do fotobudki 360 Controller.
///
/// Uzywa protokolu rozszyfrowanego w [BoothProtocol]. Wspiera:
/// - skan + auto-connect po nazwie `"360 Controller"`
/// - START CW / CCW z auto-stop po [recordingDuration]
/// - STOP rozkaz (manual early stop)
/// - zmiana kierunku (reverse) - aktywna przy nastepnym start
/// - speed 1-8
/// - log ostatnich 30 wpisow (TX/events)
class RealMotorController extends MotorController {
  RealMotorController({this.recordingDuration = const Duration(seconds: 8)});

  /// Dlugosc nagrania - zgodne z CameraService/_kMaxRecording.
  /// ChackTok dolicza +3s bufora, my tez.
  final Duration recordingDuration;

  MotorState _state = const MotorState.initial();
  final List<String> _log = <String>[];

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _runningResetTimer;

  @override
  MotorState get state => _state;

  @override
  List<String> get log => List.unmodifiable(_log);

  void _logMsg(String msg) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    _log.insert(0, '[$hh:$mm:$ss] $msg');
    if (_log.length > 30) {
      _log.removeRange(30, _log.length);
    }
    debugPrint('[BLE] $msg');
  }

  @override
  Future<void> connect() async {
    if (_state.connected) return;

    // 1. Uprawnienia. Android 12+ wymaga BLUETOOTH_SCAN + CONNECT. Android 10/11
    // wymaga ACCESS_FINE_LOCATION dla skanu.
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    for (final entry in results.entries) {
      if (!entry.value.isGranted) {
        _logMsg('Brak uprawnienia: ${entry.key}');
      }
    }

    // 2. BLE dostepne?
    final supported = await FlutterBluePlus.isSupported;
    if (!supported) {
      _logMsg('BLE nie wspierane na tym urzadzeniu');
      return;
    }

    // 3. BT on? Jak off - poprosimy usera o wlaczenie.
    final adapter = await FlutterBluePlus.adapterState.first;
    if (adapter != BluetoothAdapterState.on) {
      _logMsg('Bluetooth wylaczony - wlacz i sprobuj ponownie');
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        _logMsg('Nie udalo sie wlaczyc BT: $e');
        return;
      }
    }

    // 4. Skan.
    _logMsg('Skanowanie fotobudki...');
    final found = Completer<BluetoothDevice?>();

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.device.platformName;
        if (name.startsWith(BoothProtocol.deviceNamePrefix)) {
          if (!found.isCompleted) {
            found.complete(r.device);
          }
          break;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      _logMsg('startScan fail: $e');
    }

    final device = await found.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => null,
    );
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;

    if (device == null) {
      _logMsg('Nie znaleziono fotobudki (timeout)');
      return;
    }

    _logMsg('Znaleziono: ${device.platformName} ${device.remoteId}');

    // 5. Podlacz.
    try {
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );
    } catch (e) {
      _logMsg('Connect fail: $e');
      return;
    }

    _device = device;

    // 6. Discover services.
    try {
      final services = await device.discoverServices();
      BluetoothService? target;
      for (final s in services) {
        if (s.uuid.str.toUpperCase().contains('FFF0')) {
          target = s;
          break;
        }
      }
      if (target == null) {
        _logMsg('Brak serwisu FFF0');
        await device.disconnect();
        _device = null;
        return;
      }

      BluetoothCharacteristic? writeChar;
      for (final c in target.characteristics) {
        if (c.uuid.str.toUpperCase().contains('FFF1')) {
          writeChar = c;
          break;
        }
      }
      if (writeChar == null) {
        _logMsg('Brak charakterystyki FFF1');
        await device.disconnect();
        _device = null;
        return;
      }
      _writeChar = writeChar;
      _logMsg('FFF1 props: write=${writeChar.properties.write} '
          'writeNoResp=${writeChar.properties.writeWithoutResponse} '
          'notify=${writeChar.properties.notify}');

      // Enable notifications (FastBLE w ChackTok to robi - fotobudka moze
      // wymagac aktywnej subskrypcji zeby akceptowac komendy).
      try {
        if (writeChar.properties.notify || writeChar.properties.indicate) {
          await writeChar.setNotifyValue(true);
          writeChar.lastValueStream.listen((value) {
            _logMsg('RX ${BoothProtocol.toHex(value)}');
          });
          _logMsg('Notify enabled');
        }
      } catch (e) {
        _logMsg('Notify setup fail: $e');
      }
    } catch (e) {
      _logMsg('Discover fail: $e');
      await device.disconnect();
      _device = null;
      return;
    }

    // 7. Listen connection state for disconnects.
    await _connStateSub?.cancel();
    _connStateSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        _logMsg('Rozlaczono');
        _writeChar = null;
        _device = null;
        _state = _state.copyWith(connected: false, running: false);
        _runningResetTimer?.cancel();
        _runningResetTimer = null;
        notifyListeners();
      }
    });

    _state = _state.copyWith(connected: true);
    _logMsg('Polaczono');
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _runningResetTimer?.cancel();
    _runningResetTimer = null;
    await _connStateSub?.cancel();
    _connStateSub = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _writeChar = null;
    _state = _state.copyWith(connected: false, running: false);
    _logMsg('Disconnect manual');
    notifyListeners();
  }

  Future<void> _writeCommand(List<int> bytes) async {
    final ch = _writeChar;
    if (ch == null) {
      _logMsg('Brak polaczenia - skip TX');
      return;
    }
    try {
      // Wybor write type po properties. ChackTok (FastBLE) w HCI mial type=1
      // = with response. Ale jesli kontroler obsluguje tylko WriteNoResponse,
      // uzyjemy tego.
      final useNoResp = !ch.properties.write &&
          ch.properties.writeWithoutResponse;
      await ch.write(bytes, withoutResponse: useNoResp);
      _logMsg('TX ${BoothProtocol.toHex(bytes)} '
          '(${useNoResp ? "noResp" : "withResp"})');
    } catch (e) {
      _logMsg('TX fail: $e');
      // Fallback - sprobuj przeciwny typ.
      try {
        await ch.write(bytes, withoutResponse: true);
        _logMsg('TX retry noResp OK');
      } catch (e2) {
        _logMsg('TX retry fail: $e2');
      }
    }
  }

  @override
  Future<void> start() async {
    if (!_state.connected) {
      _logMsg('start: nie polaczono');
      return;
    }
    final switchByte = _state.direction == Direction.clockwise
        ? BoothProtocol.switchStartCw
        : BoothProtocol.switchStartCcw;

    final totalSec =
        recordingDuration.inSeconds + BoothProtocol.durationBufferSeconds;
    final bytes = BoothProtocol.build(
      switchByte: switchByte,
      speed: _state.speed,
      durationSeconds: totalSec,
    );
    await _writeCommand(bytes);

    _state = _state.copyWith(running: true);
    notifyListeners();

    // Auto-reset running flag po duration (fotobudka sama sie zatrzymuje).
    _runningResetTimer?.cancel();
    _runningResetTimer = Timer(
      Duration(seconds: totalSec),
      () {
        if (_state.running) {
          _state = _state.copyWith(running: false);
          _logMsg('Motor auto-stop (duration end)');
          notifyListeners();
        }
      },
    );
  }

  @override
  Future<void> stop() async {
    if (!_state.connected) return;
    final bytes = BoothProtocol.stopCmd(
      speed: _state.speed,
      durationSeconds: 0,
    );
    await _writeCommand(bytes);
    _runningResetTimer?.cancel();
    _runningResetTimer = null;
    _state = _state.copyWith(running: false);
    notifyListeners();
  }

  @override
  Future<void> setSpeed(int level) async {
    final clamped = level.clamp(MotorState.minSpeed, MotorState.maxSpeed);
    if (clamped == _state.speed) return;
    _state = _state.copyWith(speed: clamped);
    _logMsg('Speed set to $clamped (wysylane przy nastepnym start)');
    notifyListeners();
  }

  @override
  Future<void> speedUp() => setSpeed(_state.speed + 1);

  @override
  Future<void> speedDown() => setSpeed(_state.speed - 1);

  @override
  Future<void> reverseDirection() async {
    _state = _state.copyWith(direction: _state.direction.flipped);
    _logMsg('Direction -> ${_state.direction.label}');
    notifyListeners();
  }

  @override
  void dispose() {
    _runningResetTimer?.cancel();
    _scanSub?.cancel();
    _connStateSub?.cancel();
    _device?.disconnect();
    super.dispose();
  }
}
