import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Prosty logger dla Station (Sesja 8a).
///
/// - In-memory ring buffer (ostatnie N wpisow, widoczne w debug panelu)
/// - Plik `docs/logs/booth_YYYY-MM-DD.log` (rotacja dzienna, retencja 7 dni)
/// - 4 poziomy: debug/info/warn/error
/// - Format: `[timestamp] [LEVEL] [source] message`
///
/// Singleton, uzywany z kazdego serwisu: `Log.i('Station', 'WS connected')`.
class BoothLogger extends ChangeNotifier {
  BoothLogger._();
  static final BoothLogger instance = BoothLogger._();

  static const int ringCapacity = 200;
  static const Duration rotateAfter = Duration(days: 1);
  static const int retainDays = 7;

  final Queue<LogEntry> _ring = Queue<LogEntry>();
  File? _file;
  IOSink? _sink;
  DateTime? _fileDate;
  bool _initialized = false;

  List<LogEntry> get recent => _ring.toList(growable: false);

  Future<void> init() async {
    if (_initialized) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'logs'));
      if (!await dir.exists()) await dir.create(recursive: true);
      await _rotateIfNeeded(dir);
      await _purgeOld(dir);
      _initialized = true;
      debugPrint('[BoothLogger] init ok, file=${_file?.path}');
    } catch (e) {
      debugPrint('[BoothLogger] init failed: $e');
      _initialized = true; // fallback: tylko ring buffer + debugPrint
    }
  }

  Future<void> _rotateIfNeeded(Directory dir) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_fileDate != null && _fileDate == today) return;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    final name = 'booth_${today.year.toString().padLeft(4, '0')}'
        '-${today.month.toString().padLeft(2, '0')}'
        '-${today.day.toString().padLeft(2, '0')}.log';
    _file = File(p.join(dir.path, name));
    _sink = _file!.openWrite(mode: FileMode.append);
    _fileDate = today;
  }

  Future<void> _purgeOld(Directory dir) async {
    final cutoff = DateTime.now().subtract(Duration(days: retainDays));
    try {
      await for (final e in dir.list()) {
        if (e is! File) continue;
        final stat = await e.stat();
        if (stat.modified.isBefore(cutoff)) {
          await e.delete();
        }
      }
    } catch (_) {}
  }

  void log(LogLevel level, String source, String message, {Object? error}) {
    final entry = LogEntry(
      ts: DateTime.now(),
      level: level,
      source: source,
      message: error == null ? message : '$message · $error',
    );
    _ring.addLast(entry);
    while (_ring.length > ringCapacity) {
      _ring.removeFirst();
    }
    notifyListeners();

    final formatted = entry.toLine();
    debugPrint(formatted);

    // Fire-and-forget flush do pliku.
    unawaited(_writeToFile(formatted));
  }

  Future<void> _writeToFile(String line) async {
    if (!_initialized) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'logs'));
      await _rotateIfNeeded(dir);
      _sink?.writeln(line);
    } catch (_) {
      // cicho - logger nie moze crashowac appa
    }
  }

  /// Shortcuts.
  void d(String source, String message) => log(LogLevel.debug, source, message);
  void i(String source, String message) => log(LogLevel.info, source, message);
  void w(String source, String message, {Object? error}) =>
      log(LogLevel.warn, source, message, error: error);
  void e(String source, String message, {Object? error}) =>
      log(LogLevel.error, source, message, error: error);

  Future<String?> dumpRecentToString() async {
    final buf = StringBuffer();
    for (final e in _ring) {
      buf.writeln(e.toLine());
    }
    return buf.toString();
  }
}

/// Module-level shortcut, zeby nie pisac BoothLogger.instance wszedzie.
final Log = BoothLogger.instance;

enum LogLevel { debug, info, warn, error }

class LogEntry {
  LogEntry({
    required this.ts,
    required this.level,
    required this.source,
    required this.message,
  });

  final DateTime ts;
  final LogLevel level;
  final String source;
  final String message;

  String toLine() {
    final t = _fmtTs(ts);
    final lv = level.name.toUpperCase().padRight(5);
    return '[$t] [$lv] [$source] $message';
  }

  static String _fmtTs(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}'
        '.${three(t.millisecond)}';
  }
}
