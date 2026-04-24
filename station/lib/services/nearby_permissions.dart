import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permissions wymagane przez Nearby Connections na Android 12+.
///
/// Uwaga: GPS musi byc ON dla Nearby scan (nie wystarczy sama location
/// permission - Android wymaga fizycznie wlaczonej lokalizacji). To sprawdza
/// sie osobno przez [Geolocator.isLocationServiceEnabled()] albo po prostu
/// komunikatem w UI.
///
/// Service-side (Station, advertising) + client-side (Recorder, discovery)
/// potrzebuja tego samego zestawu:
/// - bluetooth_advertise / _connect / _scan (A12+ runtime perms)
/// - location fine (pre-A13 / A12 fallback; A13+ z `NEARBY_WIFI_DEVICES`
///   flag `neverForLocation` nie wymaga, ale `nearby_connections` v4 i tak
///   sprawdza location dla starszych API levels)
/// - nearbyWifiDevices (A13+, auto-upgrade hybrid)
class NearbyPermissions {
  NearbyPermissions._();

  /// Lista permissions jakie Nearby wymaga. Kolejnosc nieistotna - flag
  /// request zbiera je wszystkie w jeden dialog systemowy.
  static final List<Permission> _required = <Permission>[
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.locationWhenInUse,
    Permission.nearbyWifiDevices,
  ];

  /// True gdy wszystkie Nearby permissions granted. Cache sprawdzany bez
  /// pokazywania dialogu - dobre na start UI zeby wiedziec czy pokazywac
  /// permission gate czy juz jechac.
  static Future<bool> hasAll() async {
    for (final p in _required) {
      final s = await p.status;
      if (!(s.isGranted || s.isLimited)) return false;
    }
    return true;
  }

  /// Pokazuje systemowy dialog dla wszystkich brakujacych permissions.
  /// Zwraca true jesli po tym mamy komplet.
  ///
  /// Jesli user kliknie "Dont ask again" albo jest juz permanent-denied,
  /// dialog sie nie pokaze - uzyj [openSystemSettings] zeby reczenie dojsc.
  ///
  /// Race guard: retry do 3 prob jesli inny request permissions jest
  /// rownolegly aktywny (PlatformException "already running").
  static Future<bool> requestAll() async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final statuses = await _required.request();
        final allGranted = statuses.values.every(
          (s) => s.isGranted || s.isLimited,
        );
        debugPrint('[NearbyPermissions] requestAll -> granted=$allGranted '
            '(attempt $attempt) statuses=$statuses');
        return allGranted;
      } catch (e) {
        final isRace = e.toString().contains('already running');
        debugPrint('[NearbyPermissions] requestAll error (attempt $attempt): $e');
        if (isRace && attempt < 3) {
          await Future<void>.delayed(const Duration(milliseconds: 800));
          continue;
        }
        return false;
      }
    }
    return false;
  }

  /// True gdy przynajmniej jedna z wymaganych permissions jest
  /// permanent-denied (user odkrecil "Nigdy nie pytaj" w systemowym dialogu).
  /// W tym stanie [requestAll] juz nic nie pokaze - trzeba wyslac do Settings.
  static Future<bool> anyPermanentlyDenied() async {
    for (final p in _required) {
      final s = await p.status;
      if (s.isPermanentlyDenied) return true;
    }
    return false;
  }

  /// Otwiera systemowe ustawienia aplikacji zeby user recznie odblokowal
  /// permissions. Uzywane gdy [anyPermanentlyDenied] == true.
  static Future<bool> openSystemSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('[NearbyPermissions] openAppSettings error: $e');
      return false;
    }
  }

  /// Diagnostyka: zwraca map permission -> status dla UI (debug panel,
  /// permission gate screen).
  static Future<Map<Permission, PermissionStatus>> currentStatuses() async {
    final result = <Permission, PermissionStatus>{};
    for (final p in _required) {
      result[p] = await p.status;
    }
    return result;
  }

  /// Czytelne nazwy dla UI (ludzie nie rozumieja "Permission.bluetoothAdvertise").
  static String labelFor(Permission p) {
    if (p == Permission.bluetoothAdvertise) return 'Bluetooth - reklamowanie';
    if (p == Permission.bluetoothConnect) return 'Bluetooth - polaczenie';
    if (p == Permission.bluetoothScan) return 'Bluetooth - skanowanie';
    if (p == Permission.locationWhenInUse) return 'Lokalizacja';
    if (p == Permission.nearbyWifiDevices) return 'WiFi - Nearby Devices';
    return p.toString();
  }
}
