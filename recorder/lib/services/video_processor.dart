import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'effect_templates.dart';
import 'processing_config.dart';

/// Post-processing nagrania przez FFmpeg.
///
/// **Pipeline dla boomerang + slow-mo tail (Sesja 6 MVP):**
///
/// 1. Split video na 2 strumienie
/// 2. Reverse drugiego
/// 3. Concat forward + reverse → 2× dlugosci inputu
/// 4. Split concat na 2: firstpart (0..end-tail) + tail (ostatnie tailSec)
/// 5. Slow-mo na tail (setpts=factor×PTS)
/// 6. Concat firstpart + slowTail
/// 7. Encode h264 (libx264 preset fast, CRF 23), no audio (bo reverse dzwieku brzmi fatalnie)
///
/// **Dla default 8s input + boomerang + 3× slow-mo na 2s ogona:**
/// Output = 8s + 8s + (2×3 - 2) = 20s przyblizenie. Dokladnie:
/// - Forward: 0-8s
/// - Reverse 0-6s: 8-14s
/// - Reverse slow (ostatnie 2s reverse, 3× wolniej): 14-20s
class VideoProcessor extends ChangeNotifier {
  VideoProcessor();

  bool _isProcessing = false;
  double _progress = 0.0;
  String _stage = '';
  String? _lastOutputPath;
  String? _lastError;

  bool get isProcessing => _isProcessing;
  double get progress => _progress;
  String get stage => _stage;
  String? get lastOutputPath => _lastOutputPath;
  String? get lastError => _lastError;

  void _set({
    bool? processing,
    double? progress,
    String? stage,
    String? error,
  }) {
    if (processing != null) _isProcessing = processing;
    if (progress != null) _progress = progress.clamp(0.0, 1.0);
    if (stage != null) _stage = stage;
    if (error != null) _lastError = error;
    notifyListeners();
  }

  /// Przetwarza [inputPath] → zwraca sciezke do gotowego MP4.
  /// Na bledzie rzuca [VideoProcessingException].
  ///
  /// [onProgress] jest callbackiem do publikowania progress do Station.
  Future<String> process({
    required String inputPath,
    required ProcessingConfig config,
    void Function(double progress, String stage)? onProgress,
  }) async {
    if (!await File(inputPath).exists()) {
      throw VideoProcessingException('Input not found: $inputPath');
    }

    _set(processing: true, progress: 0.0, stage: 'Przygotowanie', error: '');
    onProgress?.call(0.0, 'Przygotowanie');

    final docsDir = await getApplicationDocumentsDirectory();
    final processedDir = Directory(p.join(docsDir.path, 'processed'));
    if (!await processedDir.exists()) {
      await processedDir.create(recursive: true);
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outputPath = p.join(processedDir.path, 'boomerang_$ts.mp4');

    // Zmierz actual duration przez FFprobe (raw nagranie bywa krotsze niz
    // zaplanowane 8s - camera init delay, wczesniejszy stop).
    final actualDuration = await _probeDuration(inputPath) ?? config.inputDuration;

    // Pomiar rozmiaru video (W, H) - uzywane do skalowania overlayu do
    // rozdzielczosci wejscia. Fallback 1080x1920 gdy probe padnie.
    final dims = await _probeVideoDimensions(inputPath) ??
        const _VideoDims(1080, 1920);

    // Music offset - priorytet: config.musicOffsetSec (z AI viral analysis
    // albo manual admin) -> heurystyka 30% dlugosci jako fallback.
    int musicOffsetSec = 0;
    if (config.musicPath != null && File(config.musicPath!).existsSync()) {
      if (config.musicOffsetSec != null && config.musicOffsetSec! >= 0) {
        musicOffsetSec = config.musicOffsetSec!.round();
        debugPrint('[VideoProcessor] Music offset (from config): '
            '${musicOffsetSec}s');
      } else {
        final musicDur = await _probeDuration(config.musicPath!);
        if (musicDur != null && musicDur.inSeconds > 30) {
          musicOffsetSec = (musicDur.inSeconds * 0.3).round().clamp(30, 60);
        } else {
          musicOffsetSec = 40;
        }
        debugPrint('[VideoProcessor] Music offset (heuristic): '
            '${musicOffsetSec}s (dur: ${musicDur?.inSeconds ?? "?"}s)');
      }
    }

    // Drawtext fallback: jesli event ma text_top/text_bottom ale nie ma
    // przypisanej ramki (overlay) - rysujemy prosty tekst na wideo przez
    // FFmpeg drawtext. Potrzebuje font file (TTF) i tekst w temp pliku
    // (textfile= unika zmagan z escape FFmpeg drawtext syntax).
    final drawText = await _prepareDrawText(config, processedDir);

    final args = _buildArgs(
      inputPath: inputPath,
      outputPath: outputPath,
      config: config,
      actualDuration: actualDuration,
      musicOffsetSec: musicOffsetSec,
      videoDims: dims,
      drawText: drawText,
    );

    debugPrint('[FFmpeg] args: ${args.join(" ")}');
    _set(stage: 'Efekty...');
    onProgress?.call(0.1, 'Efekty');

    final session = await FFmpegKit.executeWithArgumentsAsync(
      args,
      (FFmpegSession s) async {
        final rc = await s.getReturnCode();
        if (ReturnCode.isSuccess(rc)) {
          debugPrint('[FFmpeg] SUCCESS');
        } else if (ReturnCode.isCancel(rc)) {
          debugPrint('[FFmpeg] CANCELLED');
        } else {
          final logs = await s.getAllLogsAsString();
          debugPrint('[FFmpeg] FAIL rc=$rc\n$logs');
        }
      },
      (log) {
        // FFmpeg log - pomijamy w UI, tylko debugPrint dla dev.
        final m = log.getMessage().trim();
        if (m.isNotEmpty) debugPrint('[FFmpeg log] $m');
      },
      (stats) {
        final expectedMs = config.expectedOutputDuration.inMilliseconds;
        final processedMs = stats.getTime();
        if (expectedMs > 0) {
          final pct = (processedMs / expectedMs).clamp(0.0, 1.0);
          _set(progress: pct, stage: 'Renderowanie');
          onProgress?.call(pct, 'Renderowanie');
        }
      },
    );

    // Poczekaj na zakonczenie sesji. Fix: ffmpeg_kit_flutter_new 4.1.0
    // zmienilo state names (nie ma juz 'COMPLETED'/'FAILED' literalnie),
    // uzywamy getReturnCode() ktore zwraca null pokad sesja leci,
    // non-null po zakonczeniu (success/fail/cancel).
    // Plus safety timeout 90s (ochrona przed infinity loop gdyby ffmpeg
    // zawisl - Station ma swoje 45s processingMaxDuration).
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (true) {
      final rc = await session.getReturnCode();
      if (rc != null) break;
      if (DateTime.now().isAfter(deadline)) {
        debugPrint('[FFmpeg] timeout 90s waiting for session completion');
        await session.cancel();
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      final logs = await session.getAllLogsAsString();
      final shortErr = (logs ?? '').split('\n').take(20).join('\n');
      _set(processing: false, error: 'FFmpeg fail: rc=$rc');
      onProgress?.call(1.0, 'Blad FFmpeg');
      throw VideoProcessingException('FFmpeg failed (rc=$rc):\n$shortErr');
    }

    final out = File(outputPath);
    if (!await out.exists()) {
      _set(processing: false, error: 'Output not created');
      throw VideoProcessingException('Output file not created: $outputPath');
    }

    _lastOutputPath = outputPath;
    _set(processing: false, progress: 1.0, stage: 'Gotowe');
    onProgress?.call(1.0, 'Gotowe');
    debugPrint('[FFmpeg] output: $outputPath (${await out.length()} bytes)');
    return outputPath;
  }

  /// Cache na path do extracted font TTF.
  String? _cachedFontPath;

  /// Zwraca sciezke do TTF fontu dla FFmpeg drawtext.
  ///
  /// Priorytet: 1) Android system font (dziala zawsze, world-readable),
  /// 2) bundled Roboto-Bold.ttf extracted do docs/fonts/ (fallback).
  ///
  /// Dlaczego system first: mobile ffmpeg-kit builds maja ograniczony
  /// dostep do zewnetrznych paths - Android SELinux czasem blokuje
  /// odczyt z app-specific directory pod native kodem. /system/fonts/
  /// jest world-readable i native kod ma do niego dostep.
  Future<String?> _ensureFontExtracted() async {
    if (_cachedFontPath != null && File(_cachedFontPath!).existsSync()) {
      return _cachedFontPath;
    }
    // 1) System font - pewne rozwiazanie dla Android.
    for (final sys in const [
      '/system/fonts/Roboto-Regular.ttf',
      '/system/fonts/Roboto-Bold.ttf',
      '/system/fonts/DroidSans.ttf',
    ]) {
      if (File(sys).existsSync()) {
        _cachedFontPath = sys;
        debugPrint('[VideoProcessor] font: using system $sys');
        return _cachedFontPath;
      }
    }
    // 2) Bundled fallback - jesli jakims dziwnym sposobem brak system font.
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final fontsDir = Directory(p.join(docsDir.path, 'fonts'));
      if (!await fontsDir.exists()) {
        await fontsDir.create(recursive: true);
      }
      final target = File(p.join(fontsDir.path, 'Roboto-Bold.ttf'));
      if (!await target.exists() || await target.length() == 0) {
        final data = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      _cachedFontPath = target.path;
      debugPrint('[VideoProcessor] font: using bundled ${target.path}');
      return _cachedFontPath;
    } catch (e) {
      debugPrint('[VideoProcessor] font extract fail: $e');
      return null;
    }
  }

  /// Przygotowuje drawtext: ekstraktuje font, eskejpuje text do inline.
  /// Zwraca null gdy nie ma czego rysowac albo gdy font extract zawiedzie.
  Future<_DrawTextAssets?> _prepareDrawText(
    ProcessingConfig config,
    Directory processedDir, // nadal przyjmujemy ale nie uzywamy (byl
    // textfile=), zostawiamy na przyszle uzycie.
  ) async {
    final top = config.textTop?.trim();
    final bottom = config.textBottom?.trim();
    final hasText = (top != null && top.isNotEmpty) ||
        (bottom != null && bottom.isNotEmpty);
    if (!hasText) return null;
    // Drawtext zawsze aktywny gdy text_top/bottom sa w evencie - niezaleznie
    // czy overlay (ramka AI) jest czy nie. Ramki teraz generowane bez tekstu
    // (Gemini przekrecal pisownie "Adriany" -> "Adriana"), wiec drawtext jest
    // jedynym zrodlem prawdy dla imion i dat na video.
    final fontPath = await _ensureFontExtracted();
    if (fontPath == null) return null;

    return _DrawTextAssets(
      fontPath: fontPath,
      topText: (top != null && top.isNotEmpty) ? top : null,
      bottomText: (bottom != null && bottom.isNotEmpty) ? bottom : null,
    );
  }

  /// Wyciagnij actual duration video streamu przez FFprobe.
  Future<Duration?> _probeDuration(String path) async {
    try {
      final info = await FFprobeKit.getMediaInformation(path);
      final mediaInfo = info.getMediaInformation();
      if (mediaInfo == null) return null;
      final durationStr = mediaInfo.getDuration();
      if (durationStr == null) return null;
      final seconds = double.tryParse(durationStr);
      if (seconds == null) return null;
      return Duration(milliseconds: (seconds * 1000).round());
    } catch (e) {
      debugPrint('[FFprobe] fail: $e');
      return null;
    }
  }

  /// Wyciagnij wymiary video (W, H) ze streamu. Null gdy probe zawiedzie.
  /// Zwracamy DISPLAY dimensions - jak MP4 ma rotation metadata 90/270 to
  /// swapujemy w/h zeby overlay pasowal do faktycznie widocznej orientacji.
  /// Android camera czesto zapisuje landscape 3840x2160 + rotation=90 dla
  /// portrait recordingu - bez swapa overlay ladowal w rogu video.
  Future<_VideoDims?> _probeVideoDimensions(String path) async {
    try {
      final info = await FFprobeKit.getMediaInformation(path);
      final media = info.getMediaInformation();
      if (media == null) return null;
      final streams = media.getStreams();
      for (final s in streams) {
        final type = s.getType();
        if (type != 'video') continue;
        final w = s.getWidth();
        final h = s.getHeight();
        if (w == null || h == null || w <= 0 || h <= 0) continue;

        // Detekcja rotacji - stary field 'rotate' (ffmpeg <5) i nowy
        // side_data_list z 'Display Matrix' + rotation (ffmpeg 5+).
        int rotation = 0;
        final rotateStr = s.getStringProperty('rotate') ?? '';
        final parsed = int.tryParse(rotateStr);
        if (parsed != null) rotation = parsed;
        if (rotation == 0) {
          final all = s.getAllProperties();
          if (all != null) {
            final sdl = all['side_data_list'];
            if (sdl is List) {
              for (final sd in sdl) {
                if (sd is Map && sd['rotation'] is num) {
                  rotation = (sd['rotation'] as num).toInt();
                  break;
                }
              }
            }
          }
        }
        final normalized = ((rotation % 360) + 360) % 360;
        if (normalized == 90 || normalized == 270) {
          debugPrint('[FFprobe] dims: stored ${w}x$h rotation=$normalized '
              '-> display ${h}x$w');
          return _VideoDims(h, w);
        }
        debugPrint('[FFprobe] dims: ${w}x$h rotation=$normalized');
        return _VideoDims(w, h);
      }
      return null;
    } catch (e) {
      debugPrint('[FFprobe] dims fail: $e');
      return null;
    }
  }

  /// Buduje liste argumentow FFmpeg.
  List<String> _buildArgs({
    required String inputPath,
    required String outputPath,
    required ProcessingConfig config,
    required Duration actualDuration,
    int musicOffsetSec = 0,
    _VideoDims videoDims = const _VideoDims(1080, 1920),
    _DrawTextAssets? drawText,
  }) {
    final args = <String>['-y', '-i', inputPath];

    // Music input (optional)
    final hasMusic = config.musicPath != null &&
        File(config.musicPath!).existsSync();
    if (hasMusic) {
      // -ss przed -i = fast seek na wejsciu muzyki (skip do chorus'a).
      if (musicOffsetSec > 0) {
        args.addAll(['-ss', '$musicOffsetSec']);
      }
      args.addAll(['-i', config.musicPath!]);
    }

    // Overlay input (optional)
    final hasOverlay = config.overlayPath != null &&
        File(config.overlayPath!).existsSync();
    if (hasOverlay) {
      args.addAll(['-i', config.overlayPath!]);
    }

    // Build filter_complex
    final filter = _buildFilterComplex(
      config,
      hasOverlay: hasOverlay,
      actualDuration: actualDuration,
      videoDims: videoDims,
      drawText: drawText,
    );
    args.addAll(['-filter_complex', filter, '-map', '[vout]']);

    // Audio
    if (hasMusic) {
      // music = input index 1
      final aIdx = 1;
      args.addAll([
        '-map',
        '$aIdx:a',
        '-shortest',
      ]);
    } else {
      // no audio
      args.add('-an');
    }

    // Encoding
    args.addAll([
      '-c:v', 'libx264',
      '-preset', 'ultrafast', // szybkosc > jakosc (OnePlus i tak da rade na fast, ale ultra = bezpieczniej)
      '-crf', '23',
      '-pix_fmt', 'yuv420p',
      '-movflags', '+faststart',
      outputPath,
    ]);

    return args;
  }

  /// Filter chain - routuje per-template.
  String _buildFilterComplex(
    ProcessingConfig config, {
    required bool hasOverlay,
    required Duration actualDuration,
    _VideoDims videoDims = const _VideoDims(1080, 1920),
    _DrawTextAssets? drawText,
  }) {
    final parts = <String>[];
    // Stabilizacja: FFmpeg deshake 1-pass przed resztą filtrów.
    // rx/ry=24 = max shift 24px horizontal/vertical (solidna kompensacja
    // dla drgań motoru fotobudki), edge=mirror zamiast czarnych brzegów.
    // Uwaga: deshake zwiększa czas processingu o ~15-25%.
    // vidstab byłby lepszy (2-pass) ale nie ma go w min-gpl build ffmpeg-kit.
    final preV = config.stabilize
        ? '[0:v]deshake=rx=24:ry=24:edge=mirror,format=yuv420p,fps=30[v0]'
        : '[0:v]format=yuv420p,fps=30[v0]';
    parts.add(preV);

    final actualSec = actualDuration.inMilliseconds / 1000.0;
    String currentLabel;

    switch (config.template) {
      case EffectTemplate.classicBoomerang:
        currentLabel = _classicBoomerang(parts, config, actualSec);
        break;
      case EffectTemplate.slowCinematic:
        currentLabel = _slowCinematic(parts, config);
        break;
      case EffectTemplate.fastSlowFast:
        currentLabel = _fastSlowFast(parts, config, actualSec);
        break;
      case EffectTemplate.freezeReverse:
        currentLabel = _freezeReverse(parts, config, actualSec);
        break;
    }

    // Overlay PNG (opcjonalnie). Rozciagamy na dokladne wymiary video -
    // zawsze wypelnia ekran 100%. PNG generowany jest portrait 1080x1920
    // (taki sam aspect jak video), wiec stretch nie deformuje zauwazalnie.
    // Dla nietypowych aspect ratio akceptujemy minimalne rozciagniecie
    // na rzecz pewnosci ze ramka jest dopasowana do calego obrazu.
    if (hasOverlay) {
      // Input indices: 0=video, 1=music (jesli jest), 2=overlay (lub 1 gdy brak music).
      final ovIdx = (config.musicPath != null) ? 2 : 1;
      final w = videoDims.width;
      final h = videoDims.height;
      parts.add('[$ovIdx:v]format=rgba,scale=$w:$h[ovfit]');
      parts.add('$currentLabel[ovfit]overlay=0:0[ov]');
      currentLabel = '[ov]';
    }

    // Drawtext fallback - wlaczony tylko gdy event ma text_top/text_bottom
    // i NIE ma overlayu (ramki AI). Rysujemy tekst bialy + cien + box
    // polprzezroczysty dla czytelnosci na roznych tlach.
    // Sciezki do font/textfile eskejpujemy slash'em zeby FFmpeg nie
    // interpretowal : w sciezkach Windowsowych jako separator filtr-opcji.
    if (drawText != null) {
      final drawtextFilters = <String>[];
      final fontEsc = _escapeFfmpegPath(drawText.fontPath);
      // Styl:
      //  - fontsize = h*0.032 (~62px na 1920p portrait, dobre do czytania
      //    z odleglosci ~2m, nie dominuje kadru)
      //  - fontcolor = white z lekka alpha dla miekszego akcentu
      //  - box z 40% alpha czarna + padding 12px = czytelne na kwiatach
      //  - shadowx/y = subtelny cien
      const style = 'fontsize=h*0.032:fontcolor=white:'
          'box=1:boxcolor=black@0.35:boxborderw=12:'
          'shadowcolor=black@0.6:shadowx=2:shadowy=2';
      if (drawText.topText != null) {
        final esc = _escapeFfmpegText(drawText.topText!);
        drawtextFilters.add(
          "drawtext=fontfile=$fontEsc:text='$esc':"
          'x=(w-text_w)/2:y=h*0.04:$style',
        );
      }
      if (drawText.bottomText != null) {
        final esc = _escapeFfmpegText(drawText.bottomText!);
        drawtextFilters.add(
          "drawtext=fontfile=$fontEsc:text='$esc':"
          'x=(w-text_w)/2:y=h-text_h-h*0.04:$style',
        );
      }
      if (drawtextFilters.isNotEmpty) {
        parts.add('$currentLabel${drawtextFilters.join(",")}[dt]');
        currentLabel = '[dt]';
      }
    }

    // Final rename do [vout]
    parts.add('${currentLabel}null[vout]');

    return parts.join(';');
  }
}

/// Prosty holder na wymiary video (W x H). Uzywany do skalowania overlayu
/// i innych filtrow ktore potrzebuja znac rozdzielczosc wejscia.
class _VideoDims {
  final int width;
  final int height;
  const _VideoDims(this.width, this.height);
}

/// Assets dla drawtext fallback: font + tekst inline (text=).
/// Oba topText i bottomText moga byc null niezaleznie.
class _DrawTextAssets {
  final String fontPath;
  final String? topText;
  final String? bottomText;
  const _DrawTextAssets({
    required this.fontPath,
    this.topText,
    this.bottomText,
  });
}

/// Escape sciezki do FFmpeg drawtext filter - FFmpeg traktuje `:` jako
/// separator opcji wewnatrz filtra, a backslash jako escape. Musimy:
/// - C: -> C\\:  (escape `:` w sciezce Win)
/// - \ -> \\   (escape backslash)
/// Ciapki otaczajace cala sciezke robimy z pojedynczych cudzyslowow
/// ('path') w call site zeby nie kolidowac z wartosciami opcji.
String _escapeFfmpegPath(String path) {
  return path.replaceAll(r'\', r'\\').replaceAll(':', r'\:');
}

/// Escape tekstu do drawtext text='...' opcji.
/// FFmpeg drawtext w quoted string obsluguje backslash escape dla:
/// - `\` -> `\\`
/// - `'` -> `\'` (zamykalby quoted string)
/// - `%` i `\n` sa specjalne ale zostawiamy literal (user raczej nie wpisze)
/// Polskie znaki (ą, ć, ę) leca jako UTF-8 bytes bez escape - FFmpeg text
/// param jest raw string, kodowanie trzyma system file-level.
String _escapeFfmpegText(String s) {
  return s
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('%', r'\%')
      .replaceAll('\n', r'\n');
}

// --- Per-template filter builders -------------------------------------------

/// Classic: forward + reverse + slow-mo tail.
String _classicBoomerang(
  List<String> parts,
  ProcessingConfig config,
  double inputSec,
) {
  parts.add('[v0]split=2[va][vb]');
  parts.add('[va]null[fwd]');
  parts.add('[vb]reverse[rev]');
  parts.add('[fwd][rev]concat=n=2:v=1[bmr]');

  final totalSec = inputSec * 2;
  final tail = config.slowMoTailSeconds;
  if (config.slowMoTailFactor > 1.0 && tail > 0 && totalSec > tail + 0.5) {
    final start = totalSec - tail;
    final f = config.slowMoTailFactor;
    parts.add('[bmr]split=2[bmrA][bmrB]');
    parts.add('[bmrA]trim=0:${start.toStringAsFixed(3)},'
        'setpts=PTS-STARTPTS[firstpart]');
    parts.add('[bmrB]trim=${start.toStringAsFixed(3)}:${totalSec.toStringAsFixed(3)},'
        'setpts=$f*(PTS-STARTPTS)[slowtail]');
    parts.add('[firstpart][slowtail]concat=n=2:v=1[out]');
    return '[out]';
  }
  return '[bmr]';
}

/// Slow cinematic: caly film spowolniony, bez reverse.
String _slowCinematic(List<String> parts, ProcessingConfig config) {
  final f = config.slowMoTailFactor;
  parts.add('[v0]setpts=$f*PTS[out]');
  return '[out]';
}

/// Fast-slow-fast: szybki start -> normal -> slow tail.
String _fastSlowFast(
  List<String> parts,
  ProcessingConfig config,
  double inputSec,
) {
  // Podzial na 3 segmenty z roznym tempem.
  final speedUp = config.speedUpFactor; // np. 1.5
  final fastPart = (inputSec * 0.3).clamp(0.5, 3.0);
  final tailPart = config.slowMoTailSeconds.clamp(0.5, inputSec * 0.4);
  final midStart = fastPart;
  final midEnd = inputSec - tailPart;

  parts.add('[v0]split=3[vA][vB][vC]');
  parts.add('[vA]trim=0:${fastPart.toStringAsFixed(3)},'
      'setpts=(PTS-STARTPTS)/$speedUp[s1]');
  parts.add('[vB]trim=${midStart.toStringAsFixed(3)}:${midEnd.toStringAsFixed(3)},'
      'setpts=PTS-STARTPTS[s2]');
  parts.add('[vC]trim=${midEnd.toStringAsFixed(3)}:${inputSec.toStringAsFixed(3)},'
      'setpts=${config.slowMoTailFactor}*(PTS-STARTPTS)[s3]');
  parts.add('[s1][s2][s3]concat=n=3:v=1[out]');
  return '[out]';
}

/// Freeze + reverse: forward -> freeze N sec -> reverse -> slow tail.
String _freezeReverse(
  List<String> parts,
  ProcessingConfig config,
  double inputSec,
) {
  final freezeDur = config.freezeSeconds;
  // Forward full, freeze from last frame, reverse full, optional slow tail.
  parts.add('[v0]split=3[vA][vB][vC]');

  // Full forward
  parts.add('[vA]null[fwd]');

  // Freeze from last frame: trim last 100ms + setpts to stretch
  final lastMs = (inputSec - 0.1).clamp(0.0, inputSec);
  parts.add('[vB]trim=${lastMs.toStringAsFixed(3)}:${inputSec.toStringAsFixed(3)},'
      'setpts=${(freezeDur * 10).toStringAsFixed(1)}*(PTS-STARTPTS)[frz]');

  // Reverse full
  parts.add('[vC]reverse[rev]');

  parts.add('[fwd][frz][rev]concat=n=3:v=1[bmr]');

  // Opcjonalny slow tail
  final totalSec = inputSec + freezeDur + inputSec;
  final tail = config.slowMoTailSeconds;
  if (config.slowMoTailFactor > 1.0 && tail > 0 && totalSec > tail + 0.5) {
    final start = totalSec - tail;
    final f = config.slowMoTailFactor;
    parts.add('[bmr]split=2[bmrA][bmrB]');
    parts.add('[bmrA]trim=0:${start.toStringAsFixed(3)},'
        'setpts=PTS-STARTPTS[firstpart]');
    parts.add('[bmrB]trim=${start.toStringAsFixed(3)}:${totalSec.toStringAsFixed(3)},'
        'setpts=$f*(PTS-STARTPTS)[slowtail]');
    parts.add('[firstpart][slowtail]concat=n=2:v=1[out]');
    return '[out]';
  }
  return '[bmr]';
}

class VideoProcessingException implements Exception {
  VideoProcessingException(this.message);
  final String message;
  @override
  String toString() => 'VideoProcessingException: $message';
}
