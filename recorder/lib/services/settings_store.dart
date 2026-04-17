import 'package:shared_preferences/shared_preferences.dart';

import '../models/recording_mode.dart';
import '../models/recording_resolution.dart';

/// Persystentne ustawienia uzytkownika (ostatnio uzyta rozdzielczosc + tryb).
class SettingsStore {
  static const _kResolution = 'recorder.resolution';
  static const _kMode = 'recorder.mode';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _get() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<RecordingResolution> loadResolution() async {
    final p = await _get();
    final raw = p.getString(_kResolution);
    if (raw == null) return RecordingResolution.fullHd;
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
    if (raw == null) return RecordingMode.normal;
    return RecordingMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => RecordingMode.normal,
    );
  }

  Future<void> saveMode(RecordingMode m) async {
    final p = await _get();
    await p.setString(_kMode, m.name);
  }
}
