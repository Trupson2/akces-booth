import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lokalne preferencje Station: parametry nagrywania, fallback muzyki,
/// defaultowy stan checkboxa Facebook.
///
/// Te wartosci sa wysylane do Recordera wraz z event_config.
class SettingsStore extends ChangeNotifier {
  static const _kVideoDuration = 'rec.duration_s';
  static const _kSlowMoFactor = 'rec.slowmo_factor';
  static const _kRotationDir = 'rec.rotation_dir'; // 'cw' | 'ccw' | 'mixed'
  static const _kRotationSpeed = 'rec.rotation_speed'; // 1..10
  static const _kFbDefaultOn = 'ui.fb_default_on';
  static const _kFallbackMusic = 'rec.fallback_music'; // label

  // Defaults (zgodne z WORKFLOW.md - 8s, 2x, mixed, 7/10)
  int _videoDurationSec = 8;
  double _slowMoFactor = 2.0;
  String _rotationDir = 'mixed';
  int _rotationSpeed = 7;
  bool _fbDefaultOn = false;
  String _fallbackMusic = 'Energetic Party';

  bool _loaded = false;
  bool get isLoaded => _loaded;

  int get videoDurationSec => _videoDurationSec;
  double get slowMoFactor => _slowMoFactor;
  String get rotationDir => _rotationDir;
  int get rotationSpeed => _rotationSpeed;
  bool get fbDefaultOn => _fbDefaultOn;
  String get fallbackMusic => _fallbackMusic;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _videoDurationSec = p.getInt(_kVideoDuration) ?? 8;
    _slowMoFactor = p.getDouble(_kSlowMoFactor) ?? 2.0;
    _rotationDir = p.getString(_kRotationDir) ?? 'mixed';
    _rotationSpeed = p.getInt(_kRotationSpeed) ?? 7;
    _fbDefaultOn = p.getBool(_kFbDefaultOn) ?? false;
    _fallbackMusic = p.getString(_kFallbackMusic) ?? 'Energetic Party';
    _loaded = true;
    notifyListeners();
  }

  Future<void> setVideoDuration(int seconds) async {
    _videoDurationSec = seconds.clamp(3, 15);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kVideoDuration, _videoDurationSec);
    notifyListeners();
  }

  Future<void> setSlowMoFactor(double f) async {
    _slowMoFactor = f;
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kSlowMoFactor, f);
    notifyListeners();
  }

  Future<void> setRotationDir(String dir) async {
    _rotationDir = dir;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRotationDir, dir);
    notifyListeners();
  }

  Future<void> setRotationSpeed(int v) async {
    _rotationSpeed = v.clamp(1, 10);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kRotationSpeed, _rotationSpeed);
    notifyListeners();
  }

  Future<void> setFbDefault(bool on) async {
    _fbDefaultOn = on;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kFbDefaultOn, on);
    notifyListeners();
  }

  Future<void> setFallbackMusic(String label) async {
    _fallbackMusic = label;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kFallbackMusic, label);
    notifyListeners();
  }

  Map<String, dynamic> toRecorderConfig() {
    return {
      'video_duration_s': _videoDurationSec,
      'slowmo_factor': _slowMoFactor,
      'rotation_dir': _rotationDir,
      'rotation_speed': _rotationSpeed,
    };
  }
}
