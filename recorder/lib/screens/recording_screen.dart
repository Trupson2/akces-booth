import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/recording_mode.dart';
import '../models/recording_resolution.dart';
import '../services/camera_service.dart';
import '../services/motor_controller.dart';
import '../services/effect_templates.dart';
import '../services/music_library.dart';
import '../services/nearby_client.dart';
import '../services/processing_config.dart';
import '../services/video_processor.dart';
import '../theme/app_theme.dart';
import 'preview_screen.dart';

/// Maksymalna dlugosc nagrania (auto-stop). 16s = 1 pelen obrot motoru 360,
/// wystarczajaco zeby classicBoomerang/freezeReverse daly ~32s final clip z
/// reversem. Szybciej niz 16s = niepelny obrot, film sie ucina.
const Duration _kMaxRecording = Duration(seconds: 16);

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key, this.autoStart = false});

  /// True gdy ekran zostal otwarty przez WS start ze Station -
  /// od razu startujemy nagrywanie po inicjalizacji kamery.
  final bool autoStart;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _autoStopTimer;
  Timer? _uiTimer;
  late final AnimationController _pulse;

  bool _lastFpsDegraded = false;
  bool _lastResDegraded = false;

  /// Cache-owane w initState - dispose() nie moze uzywac context.read
  /// (widget juz jest disposed, mounted=false).
  NearbyClient? _stationClient;
  BuildContext? _cachedContext;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    final camera = context.read<CameraService>();
    _lastFpsDegraded = camera.highFpsDegraded;
    _lastResDegraded = camera.resolutionDegraded;
    camera.addListener(_onCameraChange);

    // Sluchamy komend ze Station (auto-start/stop). Nadpisujemy globalny
    // handler z app.dart - ten zostanie przywrocony w dispose.
    // Cache-ujemy referencje dla dispose (context juz nie bedzie valid).
    final client = context.read<NearbyClient>();
    _stationClient = client;
    _cachedContext = context;
    client.onStartRequested = () {
      if (!mounted) return;
      if (!context.read<CameraService>().isRecording) {
        _toggleRecord();
      }
    };
    client.onStopRequested = () {
      if (!mounted) return;
      if (context.read<CameraService>().isRecording) {
        _stopRecording();
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!camera.isInitialized &&
          camera.status != CameraInitStatus.initializing) {
        await camera.initialize();
      }
      // autoStart: po initialize kamery automatycznie startujemy record.
      if (widget.autoStart && mounted) {
        // Maly delay zeby UI zdazyl sie odswiezyc i permissions wrocily.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        final cam = context.read<CameraService>();
        if (cam.isInitialized && !cam.isRecording) {
          _toggleRecord();
        }
      }
    });
  }

  void _onCameraChange() {
    final camera = context.read<CameraService>();
    if (camera.highFpsDegraded && !_lastFpsDegraded) {
      _showDegradeSnack(
        '${camera.mode.fps} fps nie wspierane - zapisujemy 30 fps. '
        'TODO (sesja 6): prawdziwe slow-mo przez platform channel.',
      );
    }
    if (camera.resolutionDegraded && !_lastResDegraded) {
      _showDegradeSnack(
        '${camera.resolution.label} nie wspierane - fallback na nizsza rozdzielczosc.',
      );
    }
    _lastFpsDegraded = camera.highFpsDegraded;
    _lastResDegraded = camera.resolutionDegraded;
  }

  void _showDegradeSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.amber.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  void dispose() {
    // Wyczysc dangling callbacki zanim widget zniknie - inaczej gdy Station
    // wysle kolejne start_recording po zamknieciu RecordingScreen, callback
    // odpali context.read na disposed widgecie = Null check crash apki.
    _stationClient?.onStartRequested = null;
    _stationClient?.onStopRequested = null;
    // Ponownie zainstaluj globalny handler z root navigator context zeby
    // drugi start_recording ze Station otworzyl nowy RecordingScreen.
    // _cachedContext z initState moze byc juz disposed (jak RecordingScreen
    // zostal popped z navigatora) - wtedy context.read rzuca i handler
    // nigdy sie nie reinstaluje -> drugie nagranie nie rusza.
    final rootCtx = rootNavigatorKey.currentContext;
    if (rootCtx != null) {
      try {
        installGlobalStartHandler(rootCtx);
      } catch (e) {
        debugPrint('[RecordingScreen] reinstall handler err: $e');
      }
    }
    context.read<CameraService>().removeListener(_onCameraChange);
    _autoStopTimer?.cancel();
    _uiTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    final camera = context.read<CameraService>();
    final motor = context.read<MotorController>();
    final client = context.read<NearbyClient>();

    if (camera.isRecording) {
      await _stopRecording();
      return;
    }

    // Dynamiczny czas nagrania: bierzemy z event_config (Station Settings)
    // albo fallback na _kMaxRecording const. Synchronizujemy z motorem
    // zeby krecil dokladnie tyle samo ile nagranie.
    final cfgDurSec = client.lastEventConfig?.videoDurationSec;
    final effectiveDuration = cfgDurSec != null && cfgDurSec >= 3 && cfgDurSec <= 30
        ? Duration(seconds: cfgDurSec)
        : _kMaxRecording;
    motor.setRecordingDuration(effectiveDuration);

    // START: motor + camera RÓWNOLEGLE zeby zsynchronizowac.
    // Przed fix: motor.start czekal na BLE ACK (200-500ms), POTEM kamera
    // - przez ten czas motor juz krecil ale nagranie nie zaczete.
    // Teraz Future.wait = oba startuja w tym samym ticku.
    try {
      await Future.wait([
        motor.start(),
        camera.startRecording(),
      ]);
    } catch (e) {
      client.sendError('start: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udalo sie rozpoczac: $e')),
        );
      }
      return;
    }

    client.sendRecordingStarted();

    // Odtwarzamy UI timer (rebuild co 100ms) + wysylamy progress co 200ms.
    _uiTimer?.cancel();
    int tick = 0;
    _uiTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {});
      tick++;
      if (tick % 2 == 0) {
        final elapsed = camera.recordingDuration.inMilliseconds;
        final total = effectiveDuration.inMilliseconds;
        client.sendRecordingProgress((elapsed / total).clamp(0.0, 1.0));
      }
    });

    // Auto-stop po effectiveDuration (z event_config albo default 16s).
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(effectiveDuration, _stopRecording);
  }

  Future<void> _stopRecording() async {
    _autoStopTimer?.cancel();
    _uiTimer?.cancel();
    _autoStopTimer = null;
    _uiTimer = null;

    final camera = context.read<CameraService>();
    final motor = context.read<MotorController>();
    final client = context.read<NearbyClient>();
    final processor = context.read<VideoProcessor>();
    // Zbieramy MusicLibrary przed await zeby nie uzywac context across async.
    final musicLib = context.read<MusicLibrary>();

    // STOP: motor najpierw (fire-and-forget, hardware decelerata 2-3s),
    // kamera rownolegle (dispose encodera 1-2s). Bez unawaited motor
    // czekal na zakonczenie camera stopRecording i fotobudka krecila
    // jeszcze 2-3s dodatkowo.
    unawaited(motor.stop());
    final rawPath = await camera.stopRecording();
    client.sendRecordingStopped();

    if (rawPath == null) return;

    // Post-processing: losowy template + losowa muzyka.
    String finalPath = rawPath;
    try {
      client.sendProcessingProgress(0.0);
      final picker = RandomEffectPicker();

      // Jesli Station przyslala event_config - laczymy jego muzyke z pula
      // (priorytet na event-specific) + overlay/text z eventu.
      final eventCfg = client.lastEventConfig;
      final musicPool = <String>[
        if (eventCfg?.musicPath != null) eventCfg!.musicPath!,
        ...musicLib.availablePaths,
      ];

      // Tylko fastSlowFast (2026-04-23 feedback):
      // - classicBoomerang / freezeReverse WYJEBANE: robily reverse =
      //   "chodzi w tyl" gdy tancerka schodzi, dziwny efekt.
      // - slowCinematic WYJEBANE: slowmo na CALYM filmiku - user: "efekt
      //   spowalnienia jest na caly filmik".
      // - fastSlowFast: 3 segmenty - szybki intro + normal + slowmo finale.
      //   Slow-mo TYLKO na ostatnich 30% = "dramatyczna klatka" zamiast
      //   ciagnacego sie slow-mo. Single template = predictable output.
      const spinTemplates = <EffectTemplate>[
        EffectTemplate.fastSlowFast,
      ];
      final params = picker.pick(
        musicPool: musicPool,
        allowedTemplates: spinTemplates,
      );
      // Viral offset: jesli picker wzial event-specific track, uzyj offsetu
      // z admina (AI/manual). Bundled tracks korzystaja z pre-analyzed JSON
      // ktory MusicLibrary wystawia przez viralOffsetFor(path).
      double? musicOffset;
      if (eventCfg?.musicPath != null &&
          params.musicPath == eventCfg!.musicPath &&
          eventCfg.musicOffsetSec != null) {
        musicOffset = eventCfg.musicOffsetSec;
      } else if (params.musicPath != null) {
        musicOffset = musicLib.viralOffsetFor(params.musicPath!);
      }
      // inputDuration = faktyczny czas nagrania (event_config albo default).
      final actualDur = client.lastEventConfig?.videoDurationSec;
      final recordingDur = actualDur != null && actualDur >= 3 && actualDur <= 30
          ? Duration(seconds: actualDur)
          : _kMaxRecording;
      var config = ProcessingConfig.fromRandom(
        params: params,
        inputDuration: recordingDur,
      );
      // Dodajemy overlay + text z event config (jesli dostarczone)
      // oraz offset muzyki (AI viral).
      config = ProcessingConfig(
        template: config.template,
        slowMoTailFactor: config.slowMoTailFactor,
        slowMoTailSeconds: config.slowMoTailSeconds,
        speedUpFactor: config.speedUpFactor,
        freezeSeconds: config.freezeSeconds,
        musicPath: config.musicPath,
        musicOffsetSec: musicOffset,
        overlayPath: eventCfg?.overlayPath,
        textTop: eventCfg?.textTop,
        textBottom: eventCfg?.textBottom,
        stabilize: eventCfg?.stabilize ?? false,
        inputDuration: config.inputDuration,
      );
      debugPrint('[RecordingScreen] Random effect: ${params.debugSignature} '
          'event=${eventCfg?.eventName ?? "none"}');
      finalPath = await processor.process(
        inputPath: rawPath,
        config: config,
        onProgress: (p, _) => client.sendProcessingProgress(p),
      );
      // Sprzataj raw (mamy boomerang).
      try {
        await File(rawPath).delete();
      } catch (_) {}
    } on VideoProcessingException catch (e) {
      debugPrint('Boomerang fail: $e - wysylam raw');
      // Fallback - uzywamy raw jak processing padnie.
      finalPath = rawPath;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Efekty fail: ${e.message.split("\n").first}'),
            backgroundColor: Colors.amber.shade800,
          ),
        );
      }
    }
    client.sendProcessingDone();

    // Real mode: jesli Station online, wysylamy plik przez Nearby (BT +
    // WiFi Direct auto-upgrade dla wiekszych MP4). Potem wracamy do Home.
    // Mock mode / no Station: idziemy do lokalnego PreviewScreen.
    if (client.isConnected) {
      final ok = await client.sendFileToStation(
        File(finalPath),
        shortName: p.basename(finalPath),
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wyslano do Station. Gosc oglada na tablecie.'),
          ),
        );
        Navigator.of(context).maybePop();
      } else {
        // Upload fail - pokaz lokalnie zeby uratowac film.
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PreviewScreen(videoPath: finalPath),
          ),
        );
      }
    } else {
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PreviewScreen(videoPath: finalPath),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<CameraService>(
        builder: (context, camera, _) {
          // Dynamic max duration z event_config (Station Settings).
          final cfgDur = context.read<NearbyClient>().lastEventConfig?.videoDurationSec;
          final maxDur = cfgDur != null && cfgDur >= 3 && cfgDur <= 30
              ? Duration(seconds: cfgDur)
              : _kMaxRecording;
          return SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildPreviewOrPlaceholder(camera),
                _TopBar(camera: camera),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _BottomControls(
                    camera: camera,
                    isRecording: camera.isRecording,
                    elapsed: camera.recordingDuration,
                    max: maxDur,
                    onToggle: _toggleRecord,
                    pulse: _pulse,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewOrPlaceholder(CameraService camera) {
    switch (camera.status) {
      case CameraInitStatus.permissionDenied:
      case CameraInitStatus.permissionPermanentlyDenied:
        return _PermissionDeniedView(
          permanently:
              camera.status == CameraInitStatus.permissionPermanentlyDenied,
          onRetry: () => camera.initialize(),
          onOpenSettings: () => camera.openSystemSettings(),
        );
      case CameraInitStatus.error:
        return _ErrorView(
          message: camera.errorMessage ?? 'Blad kamery',
          onRetry: () => camera.initialize(),
        );
      case CameraInitStatus.idle:
      case CameraInitStatus.requestingPermission:
      case CameraInitStatus.initializing:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text(
                'Inicjalizacja kamery...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      case CameraInitStatus.ready:
        final ctrl = camera.controller;
        if (ctrl == null || !ctrl.value.isInitialized) {
          return const SizedBox.shrink();
        }
        // Camera preview w portrait - ctrl.value.aspectRatio zwraca sensor w/h
        // (landscape 16:9 = 1.77), w portrait viewport invertujemy do 9:16.
        // Stack: kamera + overlay PNG (ramka z eventu) jesli jest przypisana.
        // IgnorePointer zeby taps leciały do kamery/UI pod spodem.
        // Consumer<NearbyClient> zeby reaktywnie rebuild gdy Station
        // wrzuci nowy overlay_url i Recorder go sciagnie.
        return Consumer<NearbyClient>(
          builder: (ctx, client, _) {
            final cfg = client.lastEventConfig;
            final overlayPath = cfg?.overlayPath;
            final hasOverlay = overlayPath != null &&
                File(overlayPath).existsSync();
            final textTop = cfg?.textTop?.trim();
            final textBottom = cfg?.textBottom?.trim();
            final hasTextTop = textTop != null && textTop.isNotEmpty;
            final hasTextBottom = textBottom != null && textBottom.isNotEmpty;
            // Sensor kamery OP13 jest landscape (aspect ~1.777). W portrait
            // orientation chcemy pokazac preview WYPELNIAJACE ekran bez
            // stretchingu - FittedBox cover obcina boki landscape streama
            // zeby pasowal do portrait viewport. Tak operator widzi to co
            // faktycznie znajdzie sie w finalnym portrait MP4 (po transpose).
            final sensorAspect = ctrl.value.aspectRatio;
            // Styl tekstu symuluje finalny drawtext FFmpeg: bialy bold +
            // pol-przezroczyste czarne tlo + cien. Fontsize 18sp ~
            // h*0.032 po scale do preview AspectRatio.
            TextStyle textStyle() => const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 2,
                      offset: Offset(1, 1),
                    ),
                  ],
                );
            Widget textBox(String s) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(s, style: textStyle()),
                );
            return Center(
              child: AspectRatio(
                // Oryginalny hack - portrait viewport dla landscape sensor
                // streama. Nie-idealne (content moze byc squeezed) ale
                // user potwierdzil ze w tym ukladzie preview "jest git".
                // MP4 output niezalezny - FFmpeg transpose=1 robi portrait.
                aspectRatio: 1 / sensorAspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(ctrl),
                    if (hasOverlay)
                      IgnorePointer(
                        child: Image.file(
                          File(overlayPath),
                          fit: BoxFit.fill,
                        ),
                      ),
                    // Text overlay - symulacja FFmpeg drawtext, zeby
                    // operator widzial jak finalny film bedzie wygladal.
                    if (hasTextTop)
                      Positioned(
                        top: 12,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Center(child: textBox(textTop)),
                        ),
                      ),
                    if (hasTextBottom)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Center(child: textBox(textBottom)),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.camera});
  final CameraService camera;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundBtn(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              if (camera.isInitialized) _StatusBadges(camera: camera),
              const Spacer(),
            ],
          ),
          if (!camera.isRecording && camera.isInitialized) ...[
            const SizedBox(height: 10),
            _ModeChips(camera: camera),
            const SizedBox(height: 8),
            _ResolutionChips(camera: camera),
          ],
        ],
      ),
    );
  }
}

class _StatusBadges extends StatelessWidget {
  const _StatusBadges({required this.camera});
  final CameraService camera;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            '${camera.mode.fps}fps',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (camera.highFpsDegraded) ...[
            const SizedBox(width: 4),
            const Icon(Icons.warning_amber_rounded,
                size: 12, color: Colors.amber),
          ],
          Container(
            width: 1,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white24,
          ),
          const Icon(Icons.high_quality_rounded,
              size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            camera.resolution.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (camera.resolutionDegraded) ...[
            const SizedBox(width: 4),
            const Icon(Icons.warning_amber_rounded,
                size: 12, color: Colors.amber),
          ],
        ],
      ),
    );
  }
}

class _ModeChips extends StatelessWidget {
  const _ModeChips({required this.camera});
  final CameraService camera;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: RecordingMode.values.map((m) {
            final selected = m == camera.mode;
            return GestureDetector(
              onTap: () => camera.setMode(m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (m.isBeta) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'BETA',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ResolutionChips extends StatelessWidget {
  const _ResolutionChips({required this.camera});
  final CameraService camera;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: RecordingResolution.values.map((r) {
            final selected = r == camera.resolution;
            return GestureDetector(
              onTap: () => camera.setResolution(r),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r.label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (r.isHeavy) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.bolt_rounded,
                        size: 12,
                        color: selected
                            ? Colors.white
                            : Colors.amber.withValues(alpha: 0.9),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.camera,
    required this.isRecording,
    required this.elapsed,
    required this.max,
    required this.onToggle,
    required this.pulse,
  });

  final CameraService camera;
  final bool isRecording;
  final Duration elapsed;
  final Duration max;
  final VoidCallback onToggle;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    final double fraction =
        (elapsed.inMilliseconds / max.inMilliseconds).clamp(0.0, 1.0);
    final bool canTap = camera.isInitialized;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isRecording
              ? _RecordingTimer(elapsed: elapsed, fraction: fraction, max: max)
              : _IdleHint(mode: camera.mode),
          const SizedBox(height: 14),
          _RecordButton(
            recording: isRecording,
            disabled: !canTap,
            pulse: pulse,
            onTap: onToggle,
          ),
        ],
      ),
    );
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint({required this.mode});
  final RecordingMode mode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Nacisnij aby nagrac',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${mode.label} • auto-stop 8s',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}

class _RecordingTimer extends StatelessWidget {
  const _RecordingTimer({
    required this.elapsed,
    required this.fraction,
    required this.max,
  });

  final Duration elapsed;
  final double fraction;
  final Duration max;

  @override
  Widget build(BuildContext context) {
    final sec = (elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    final total = max.inSeconds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${sec}s / ${total}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.error),
          ),
        ),
      ],
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.recording,
    required this.disabled,
    required this.pulse,
    required this.onTap,
  });

  final bool recording;
  final bool disabled;
  final AnimationController pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, child) {
          final scale = recording ? 0.95 + (pulse.value * 0.1) : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: disabled
                      ? Colors.white30
                      : (recording ? AppTheme.error : Colors.white),
                  width: 4,
                ),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: recording ? 34 : 72,
                  height: recording ? 34 : 72,
                  decoration: BoxDecoration(
                    color: disabled
                        ? Colors.grey
                        : (recording ? AppTheme.error : AppTheme.error),
                    borderRadius:
                        BorderRadius.circular(recording ? 8 : 40),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.permanently,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final bool permanently;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt_outlined,
              size: 64, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            permanently
                ? 'Uprawnienia do kamery zablokowane'
                : 'Potrzebujemy dostepu do kamery i mikrofonu',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            permanently
                ? 'Wlacz uprawnienia w Ustawieniach aplikacji.'
                : 'Bez tych uprawnien nie nagramy nic.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: permanently ? onOpenSettings : onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                child: Text(permanently ? 'Otworz ustawienia' : 'Udziel zgody'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          const Text(
            'Blad kamery',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Sprobuj ponownie'),
          ),
        ],
      ),
    );
  }
}

