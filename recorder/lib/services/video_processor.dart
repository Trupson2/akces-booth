import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

    final args = _buildArgs(
      inputPath: inputPath,
      outputPath: outputPath,
      config: config,
      actualDuration: actualDuration,
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

    // Poczekaj na zakonczenie sesji (pool).
    while (true) {
      final state = await session.getState();
      if (state.name == 'COMPLETED' || state.name == 'FAILED') break;
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

  /// Buduje liste argumentow FFmpeg.
  List<String> _buildArgs({
    required String inputPath,
    required String outputPath,
    required ProcessingConfig config,
    required Duration actualDuration,
  }) {
    final args = <String>['-y', '-i', inputPath];

    // Music input (optional)
    final hasMusic = config.musicPath != null &&
        File(config.musicPath!).existsSync();
    if (hasMusic) {
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

  /// Filter chain - boomerang + slow-mo tail.
  String _buildFilterComplex(
    ProcessingConfig config, {
    required bool hasOverlay,
    required Duration actualDuration,
  }) {
    final parts = <String>[];

    // Split video do zmiennej [v0]
    parts.add('[0:v]format=yuv420p,fps=30[v0]');

    String currentLabel;

    if (config.boomerang) {
      // Forward + Reverse concat.
      parts.add('[v0]split=2[va][vb]');
      parts.add('[va]null[fwd]');
      parts.add('[vb]reverse[rev]');
      parts.add('[fwd][rev]concat=n=2:v=1[bmr]');
      currentLabel = '[bmr]';
    } else {
      currentLabel = '[v0]';
    }

    // Slow-mo na ogonie (uzywamy ACTUAL duration, nie declared).
    final actualSec = actualDuration.inMilliseconds / 1000.0;
    final totalDurSec = config.boomerang ? actualSec * 2 : actualSec;
    final tailSec = config.slowMoTailSeconds;
    final canDoSlowMo = config.slowMoTailFactor > 1.0 &&
        tailSec > 0 &&
        totalDurSec > tailSec + 0.5; // musi zostac >0.5s na firstpart

    if (canDoSlowMo) {
      final tailStart = totalDurSec - tailSec;
      final factor = config.slowMoTailFactor;

      parts.add('${currentLabel}split=2[bmrA][bmrB]');
      parts.add(
          '[bmrA]trim=0:${tailStart.toStringAsFixed(3)},setpts=PTS-STARTPTS[firstpart]');
      parts.add(
          '[bmrB]trim=${tailStart.toStringAsFixed(3)}:${totalDurSec.toStringAsFixed(3)},setpts=$factor*(PTS-STARTPTS)[slowtail]');
      parts.add('[firstpart][slowtail]concat=n=2:v=1[slowed]');
      currentLabel = '[slowed]';
    }

    // Overlay PNG (opcjonalnie)
    if (hasOverlay) {
      // overlay = index 2 jesli jest music (idx 1), inaczej 1
      final ovIdx = (config.musicPath != null) ? 2 : 1;
      parts.add(
          '[$ovIdx:v]scale2ref=w=iw:h=ih[ovscaled][vbase]');
      parts.add('[vbase]$currentLabel[vbase2]');
      // Faktyczny overlay po scale2ref - skomplikowane, dla MVP prosty overlay
      // bez scale2ref. Zakladamy ze overlay ma ta sama rozdzielczosc co video.
      parts.removeLast();
      parts.removeLast();
      parts.add('$currentLabel[$ovIdx:v]overlay=0:0[ov]');
      currentLabel = '[ov]';
    }

    // Final rename do [vout]
    parts.add('${currentLabel}null[vout]');

    return parts.join(';');
  }
}

class VideoProcessingException implements Exception {
  VideoProcessingException(this.message);
  final String message;
  @override
  String toString() => 'VideoProcessingException: $message';
}
