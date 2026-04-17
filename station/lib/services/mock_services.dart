import 'package:flutter/foundation.dart';

/// Status zewnetrznych polaczen - uzywany przez StatusIndicator na IdleScreen.
///
/// W Sesji 3 to wszystko placeholder / zawsze "OK". W pozniejszych sesjach
/// podepniemy: flutter_blue_plus do BT, WifiInfo do Recorder LAN, fetch na
/// booth.akces360.pl/healthz do Internetu.
class ConnectivityStatus extends ChangeNotifier {
  bool _bluetoothReady = true;
  bool _recorderOnline = true;
  bool _internetOnline = true;

  bool get bluetoothReady => _bluetoothReady;
  bool get recorderOnline => _recorderOnline;
  bool get internetOnline => _internetOnline;

  /// Dev toggle - pozwala miedzy innymi testowac czerwone kropki w Settings.
  @visibleForTesting
  void setBluetooth(bool v) {
    _bluetoothReady = v;
    notifyListeners();
  }

  @visibleForTesting
  void setRecorder(bool v) {
    _recorderOnline = v;
    notifyListeners();
  }

  @visibleForTesting
  void setInternet(bool v) {
    _internetOnline = v;
    notifyListeners();
  }
}
