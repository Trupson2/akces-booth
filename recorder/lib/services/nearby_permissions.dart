import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permissions wymagane przez Nearby Connections na Android 12+.
///
/// Ten sam zestaw co Station (advertising) - Recorder (discovery) tez potrzebuje
/// bluetooth_scan + location zeby moc znalezc Station. Szczegoly w
/// station/lib/services/nearby_permissions.dart.
class NearbyPermissions {
  NearbyPermissions._();

  static final List<Permission> _required = <Permission>[
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.locationWhenInUse,
    Permission.nearbyWifiDevices,
  ];

  static Future<bool> hasAll() async {
    for (final p in _required) {
      final s = await p.status;
      if (!(s.isGranted || s.isLimited)) return false;
    }
    return true;
  }

  static Future<bool> requestAll() async {
    // Short-circuit: jesli wszystkie sa juz granted, nie odpalamy dialog -
    // unikamy "Akceptuj all" przy kazdym starcie apki.
    if (await hasAll()) {
      debugPrint('[NearbyPermissions] requestAll short-circuit: all granted');
      return true;
    }
    // Race guard: plugin permission_handler rzuca PlatformException gdy
    // drugi request wystartuje podczas aktywnego (np. MotorController BT
    // perms + NearbyPermissions w tym samym post-frame callback). Retry
    // z delayem rozwiazuje bez user-visible bledu.
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
        final msg = e.toString();
        final isRace = msg.contains('already running');
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

  static Future<bool> anyPermanentlyDenied() async {
    for (final p in _required) {
      final s = await p.status;
      if (s.isPermanentlyDenied) return true;
    }
    return false;
  }

  static Future<bool> openSystemSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('[NearbyPermissions] openAppSettings error: $e');
      return false;
    }
  }

  static Future<Map<Permission, PermissionStatus>> currentStatuses() async {
    final result = <Permission, PermissionStatus>{};
    for (final p in _required) {
      result[p] = await p.status;
    }
    return result;
  }

  static String labelFor(Permission p) {
    if (p == Permission.bluetoothAdvertise) return 'Bluetooth - reklamowanie';
    if (p == Permission.bluetoothConnect) return 'Bluetooth - polaczenie';
    if (p == Permission.bluetoothScan) return 'Bluetooth - skanowanie';
    if (p == Permission.locationWhenInUse) return 'Lokalizacja';
    if (p == Permission.nearbyWifiDevices) return 'WiFi - Nearby Devices';
    return p.toString();
  }
}
