import 'package:shared_preferences/shared_preferences.dart';

import '../models/recording_mode.dart';
import '../models/recording_resolution.dart';

/// Persystentne ustawienia uzytkownika (rozdzielczosc, tryb, adres Station).
class SettingsStore {
  static const _kResolution = 'recorder.resolution';
  static const _kMode = 'recorder.mode';
  static const _kStationIp = 'recorder.station.ip';
  static const _kStationPort = 'recorder.station.port';
  static const _kStabilize = 'recorder.stabilize';
  static const _kDemoMode = 'recorder.demo_mode';
  static const _kZoomLevel = 'recorder.zoom_level';
  static const _kBoothCode = 'nearby.booth_code'; // 4-digit pairing code

  SharedPreferences? _prefs;

  Future<SharedPreferences> _get() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<RecordingResolution> loadResolution() async {
    final p = await _get();
    final raw = p.getString(_kResolution);
    if (raw == null) return RecordingResolution.fullHd;
    // Migration 8K -> FullHD: FFmpeg na 8K trwal >60s + timeout. 8K nie jest
    // juz dostepne w UI, wymuszamy downgrade dla istniejacych instalek.
    if (raw == 'max') {
      await p.setString(_kResolution, RecordingResolution.fullHd.name);
      return RecordingResolution.fullHd;
    }
    return RecordingResolution.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => RecordingResolution.fullHd,
    );
  }

  Future<void> saveResolution(RecordingResolution r) async {
    final p = await _get();
    await p.setString(_kResolution, r.name);
  }

  Future<RecordingMode> loadMode() async {
    final p = await _get();
    final raw = p.getString(_kMode);
    // Default 60 fps - user zgłosił że 30 fps za malo klatkaz dla
    // boomeranga (szarpane po slowmo). 60 fps = plynne nawet po 3x slow.
    if (raw == null) return RecordingMode.fps60;
    return RecordingMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => RecordingMode.fps60,
    );
  }

  Future<void> saveMode(RecordingMode m) async {
    final p = await _get();
    await p.setString(_kMode, m.name);
  }

  Future<String?> loadStationIp() async {
    final p = await _get();
    return p.getString(_kStationIp);
  }

  Future<void> saveStationIp(String ip) async {
    final p = await _get();
    await p.setString(_kStationIp, ip);
  }

  Future<int> loadStationPort() async {
    final p = await _get();
    return p.getInt(_kStationPort) ?? 8080;
  }

  Future<void> saveStationPort(int port) async {
    final p = await _get();
    await p.setInt(_kStationPort, port);
  }

  /// Stabilizacja post-process (FFmpeg deshake). Default false - deshake
  /// wydluza processing o ~15-25%, wlaczamy gdy rzeczywiscie potrzebne.
  Future<bool> loadStabilize() async {
    final p = await _get();
    return p.getBool(_kStabilize) ?? false;
  }

  Future<void> saveStabilize(bool on) async {
    final p = await _get();
    await p.setBool(_kStabilize, on);
  }

  /// Tryb demo - uzywamy MockMotorController zamiast RealMotorController (BLE).
  /// Pozwala uzyc recordera bez podpietej fotobudki - wszystkie komendy motor
  /// sa logowane do debug log zamiast wysylane przez BLE.
  Future<bool> loadDemoMode() async {
    final p = await _get();
    return p.getBool(_kDemoMode) ?? false;
  }

  Future<void> saveDemoMode(bool on) async {
    final p = await _get();
    await p.setBool(_kDemoMode, on);
  }

  /// Zoom aparatu - np 0.6x (ultrawide), 1.0x (main), 2.0x (tele).
  /// Finalny zoom clampujemy do min/max wspieranego przez kamere przy init
  /// (OP13 ma zakres ~0.6-6.0x, niektore telefony tylko 1.0-10.0x).
  Future<double> loadZoomLevel() async {
    final p = await _get();
    return p.getDouble(_kZoomLevel) ?? 1.0;
  }

  Future<void> saveZoomLevel(double z) async {
    final p = await _get();
    await p.setDouble(_kZoomLevel, z);
  }

  /// Kod booth do pairingu z Nearby. User wpisuje raz (pobrany z Station
  /// Settings), potem autoconnect. Bez kodu NearbyClient nie uruchamia
  /// discovery - serviceId nie dopasowany = nigdy nie znajdziemy Station.
  Future<String?> loadBoothCode() async {
    final p = await _get();
    final code = p.getString(_kBoothCode);
    if (code == null || code.length != 4) return null;
    return code;
  }

  Future<void> saveBoothCode(String code) async {
    final clean = code.trim();
    if (clean.length != 4 || int.tryParse(clean) == null) return;
    final p = await _get();
    await p.setString(_kBoothCode, clean);
  }
}
