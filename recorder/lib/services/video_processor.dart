import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
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

    final args = _buildArgs(
      inputPath: inputPath,
      outputPath: outputPath,
      config: config,
      actualDuration: actualDuration,
      musicOffsetSec: musicOffsetSec,
      videoDims: dims,
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
  Future<_VideoDims?> _probeVideoDimensions(String path) async {
    try {
      final info = await FFprobeKit.getMediaInformation(path);
      final media = info.getMediaInformation();
      if (media == null) return null;
      final streams = media.getStreams();
      for (final s in streams) {
        final type = s.getType();
        if (type == 'video') {
          final w = s.getWidth();
          final h = s.getHeight();
          if (w != null && h != null && w > 0 && h > 0) {
            return _VideoDims(w, h);
          }
        }
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
  }) {
    final parts = <String>[];
    parts.add('[0:v]format=yuv420p,fps=30[v0]');

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

    // Overlay PNG (opcjonalnie). Doskalowujemy do rozdzielczosci video
    // zachowujac aspect ratio (force_original_aspect_ratio=decrease),
    // reszte paddingujemy transparentnym kanalem alpha, zeby PNG centrowal
    // sie na video niezaleznie od proporcji.
    if (hasOverlay) {
      // Input indices: 0=video, 1=music (jesli jest), 2=overlay (lub 1 gdy brak music).
      final ovIdx = (config.musicPath != null) ? 2 : 1;
      final w = videoDims.width;
      final h = videoDims.height;
      parts.add('[$ovIdx:v]format=rgba,'
          'scale=$w:$h:force_original_aspect_ratio=decrease,'
          'pad=$w:$h:(ow-iw)/2:(oh-ih)/2:color=0x00000000[ovfit]');
      parts.add('$currentLabel[ovfit]overlay=0:0[ov]');
      currentLabel = '[ov]';
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
