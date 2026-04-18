import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Biblioteka muzyki. Laduje liste MP3 z bundled assets na disk temp
/// (FFmpeg wymaga file path, nie asset URL).
///
/// Dodatkowo trzyma mape pre-analyzed viral offsets (librosa skrypt uruchomiony
/// off-line na tracks, wynik w `assets/music/viral_offsets.json`).
/// Brak wpisu => recorder uzyje heurystyki 30% dlugosci (fallback).
///
/// Pliki MP3 trzymamy w `assets/music/` (trzeba dodac rozszerzenie w pubspec).
/// Tu jest lista znanych plikow - patrz [knownTracks]. Jak dodasz nowy plik,
/// dopisz tu nazwe.
///
/// W Sesji 7 (Content Sync) zastapimy statyczna liste dynamiczna - Station
/// bedzie pobierala muzyke z RPi per-event.
///
/// TODO: switch na royalty-free przed produkcja (Mixkit, Pixabay, YouTube
/// Audio Library). Obecne dla dev/demo - Instagram mutuje copyright automatycznie.
class MusicLibrary extends ChangeNotifier {
  MusicLibrary();

  /// 50 tracks polskiej playlisty weselnej 2026.
  /// MusicLibrary pominie te ktorych brak w assets (graceful skip).
  static const List<String> knownTracks = [
    // Top Pop & Radiowe 1-10
    'track_01.webm', 'track_02.webm', 'track_03.webm', 'track_04.webm',
    'track_05.webm', 'track_06.webm', 'track_07.webm', 'track_08.webm',
    'track_09.webm', 'track_10.webm',
    // Klubowe & Remixy 11-20
    'track_11.webm', 'track_12.webm', 'track_13.webm', 'track_14.webm',
    'track_15.webm', 'track_16.webm', 'track_17.webm', 'track_18.webm',
    'track_19.webm', 'track_20.webm',
    // Disco Polo & Dance 21-30
    'track_21.webm', 'track_22.webm', 'track_23.webm', 'track_24.webm',
    'track_25.webm', 'track_26.webm', 'track_27.webm', 'track_28.webm',
    'track_29.webm', 'track_30.webm',
    // Biesiadne & Rock 31-40
    'track_31.webm', 'track_32.webm', 'track_33.webm', 'track_34.webm',
    'track_35.webm', 'track_36.webm', 'track_37.webm', 'track_38.webm',
    'track_39.webm', 'track_40.webm',
    // Nowosci & Viral 2026 41-50
    'track_41.webm', 'track_42.webm', 'track_43.webm', 'track_44.webm',
    'track_45.webm', 'track_46.webm', 'track_47.webm', 'track_48.webm',
    'track_49.webm', 'track_50.webm',
  ];

  final List<String> _cachedPaths = [];
  /// filename (np. 'track_03.webm') -> viral offset (sekundy).
  final Map<String, double> _viralOffsets = {};
  bool _ready = false;

  bool get isReady => _ready;
  List<String> get availablePaths => List.unmodifiable(_cachedPaths);

  /// Zwraca viral offset dla danej sciezki albo null jesli brak analizy.
  /// Dopasowuje po filename (basename), wiec dziala zarowno dla bundled
  /// paths w ApplicationDocuments, jak i event-specific sciezek - jezeli
  /// filename akurat pasuje.
  double? viralOffsetFor(String path) {
    final name = p.basename(path);
    return _viralOffsets[name];
  }

  /// Kopiuje wszystkie tracks z assets do app documents directory.
  /// Skipuje pliki ktorych brak w assets.
  Future<void> initialize() async {
    if (_ready) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final musicDir = Directory(p.join(docsDir.path, 'music'));
    if (!await musicDir.exists()) {
      await musicDir.create(recursive: true);
    }

    _cachedPaths.clear();
    for (final name in knownTracks) {
      final targetPath = p.join(musicDir.path, name);
      try {
        // Sprawdz czy juz skopiowane (size > 0).
        final targetFile = File(targetPath);
        if (await targetFile.exists() && await targetFile.length() > 0) {
          _cachedPaths.add(targetPath);
          continue;
        }

        // Copy z assets.
        final data = await rootBundle.load('assets/music/$name');
        await targetFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
        _cachedPaths.add(targetPath);
        debugPrint('[MusicLibrary] cached $name');
      } catch (e) {
        // Brak pliku w assets (np. jeszcze nie dodany przez usera) - skip.
        debugPrint('[MusicLibrary] skip $name: $e');
      }
    }

    // Zaladuj pre-analyzed offsets. Brak pliku = graceful (heurystyka).
    await _loadViralOffsets();

    _ready = true;
    notifyListeners();
    debugPrint('[MusicLibrary] ready: ${_cachedPaths.length} tracks, '
        '${_viralOffsets.length} viral offsets');
  }

  Future<void> _loadViralOffsets() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/music/viral_offsets.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _viralOffsets.clear();
        decoded.forEach((key, value) {
          if (key is String && value is num) {
            _viralOffsets[key] = value.toDouble();
          }
        });
      }
    } catch (e) {
      debugPrint('[MusicLibrary] viral_offsets.json brak lub invalid: $e');
    }
  }
}
