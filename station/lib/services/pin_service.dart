import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zarzadza 4-cyfrowym PIN-em chroniacym Settings.
///
/// - Hash SHA-256 + sol (nigdy plain text).
/// - Lockout po 3 zlych probach (30s).
/// - Pierwszy start apki: `isPinSet == false` -> poprosimy o setup.
class PinService extends ChangeNotifier {
  static const _kHash = 'pin.hash';
  static const _kSalt = 'pin.salt';
  static const _kFailCount = 'pin.fail_count';
  static const _kLockUntil = 'pin.lock_until_ms';

  static const pinLength = 4;
  static const maxAttempts = 3;
  static const lockoutSeconds = 30;

  bool _loaded = false;
  bool _isPinSet = false;
  int _failCount = 0;
  DateTime? _lockedUntil;

  Timer? _tick;

  bool get isLoaded => _loaded;
  bool get isPinSet => _isPinSet;
  int get failCount => _failCount;
  int get attemptsLeft => (maxAttempts - _failCount).clamp(0, maxAttempts);

  bool get isLocked {
    final l = _lockedUntil;
    if (l == null) return false;
    return DateTime.now().isBefore(l);
  }

  int get lockSecondsLeft {
    final l = _lockedUntil;
    if (l == null) return 0;
    final diff = l.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isPinSet = prefs.getString(_kHash)?.isNotEmpty ?? false;
    _failCount = prefs.getInt(_kFailCount) ?? 0;
    final lockMs = prefs.getInt(_kLockUntil);
    if (lockMs != null && lockMs > DateTime.now().millisecondsSinceEpoch) {
      _lockedUntil = DateTime.fromMillisecondsSinceEpoch(lockMs);
      _startLockTicker();
    }
    _loaded = true;
    notifyListeners();
  }

  void _startLockTicker() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!isLocked) {
        t.cancel();
        _tick = null;
        _lockedUntil = null;
        notifyListeners();
      } else {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Ustaw PIN (pierwszy start albo zmiana). [pin] musi miec [pinLength] cyfr.
  Future<void> setPin(String pin) async {
    assert(pin.length == pinLength && RegExp(r'^\d+$').hasMatch(pin));
    final prefs = await SharedPreferences.getInstance();
    final salt = _randomSalt();
    final hash = _hash(pin, salt);
    await prefs.setString(_kSalt, salt);
    await prefs.setString(_kHash, hash);
    await prefs.setInt(_kFailCount, 0);
    await prefs.remove(_kLockUntil);
    _isPinSet = true;
    _failCount = 0;
    _lockedUntil = null;
    notifyListeners();
  }

  /// Sprawdz PIN. True = ok (reset faili). False = zly (zwieksz fail count).
  Future<bool> verify(String pin) async {
    if (isLocked) return false;
    final prefs = await SharedPreferences.getInstance();
    final salt = prefs.getString(_kSalt) ?? '';
    final stored = prefs.getString(_kHash) ?? '';
    if (stored.isEmpty || salt.isEmpty) return false;

    final given = _hash(pin, salt);
    final ok = _constantTimeEq(given, stored);

    if (ok) {
      _failCount = 0;
      _lockedUntil = null;
      await prefs.setInt(_kFailCount, 0);
      await prefs.remove(_kLockUntil);
      notifyListeners();
      return true;
    }

    _failCount++;
    await prefs.setInt(_kFailCount, _failCount);
    if (_failCount >= maxAttempts) {
      final until = DateTime.now().add(
        const Duration(seconds: lockoutSeconds),
      );
      _lockedUntil = until;
      await prefs.setInt(_kLockUntil, until.millisecondsSinceEpoch);
      _failCount = 0;
      await prefs.setInt(_kFailCount, 0);
      _startLockTicker();
    }
    notifyListeners();
    return false;
  }

  /// Wyloguj = wyczysc PIN (apka przy nastepnym uruchomieniu poprosi o setup).
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHash);
    await prefs.remove(_kSalt);
    await prefs.remove(_kFailCount);
    await prefs.remove(_kLockUntil);
    _isPinSet = false;
    _failCount = 0;
    _lockedUntil = null;
    notifyListeners();
  }

  String _randomSalt() {
    final rnd = DateTime.now().microsecondsSinceEpoch;
    return sha256
        .convert(utf8.encode('booth_$rnd'))
        .toString()
        .substring(0, 16);
  }

  String _hash(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin:akcesbooth')).toString();
  }

  bool _constantTimeEq(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
