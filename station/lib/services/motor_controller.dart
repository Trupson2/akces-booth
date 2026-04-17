import 'package:flutter/foundation.dart';

/// Szkielet kontrolera silnika fotobudki (BLE).
///
/// Skopiowany logicznie z Recorder. W Sesji 4+ podepniemy real BLE.
/// W Sesji 3 to tylko placeholder zeby Settings / bt_setup mialy
/// do czego sie odwolac.
abstract class MotorController extends ChangeNotifier {
  bool get isConnected;
  bool get isScanning;
  String? get connectedDeviceName;

  Future<void> scanForDevices();
  Future<void> connectTo(String deviceId);
  Future<void> disconnect();
}

/// Mock implementation dla Sesji 3.
class MockStationMotorController extends MotorController {
  bool _connected = false;
  bool _scanning = false;
  String? _name;

  @override
  bool get isConnected => _connected;
  @override
  bool get isScanning => _scanning;
  @override
  String? get connectedDeviceName => _name;

  @override
  Future<void> scanForDevices() async {
    _scanning = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(seconds: 2));
    _scanning = false;
    notifyListeners();
  }

  @override
  Future<void> connectTo(String deviceId) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _connected = true;
    _name = 'YCKJNB-MOCK';
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _name = null;
    notifyListeners();
  }
}
