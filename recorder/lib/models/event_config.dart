/// Konfig eventu przyslany ze Station.
///
/// Wspolny model uzywany przez StationClient (WS) i NearbyClient (Nearby
/// Connections). Po migracji do Nearby (Etap 3) StationClient zniknie,
/// ale EventConfig zostaje bo to czyste DTO bez zaleznosci transportowych.
class EventConfig {
  EventConfig({
    required this.eventId,
    required this.eventName,
    this.overlayPath,
    this.musicPath,
    this.overlayUrl,
    this.musicUrl,
    this.musicOffsetSec,
    this.musicOffsetMode,
    this.textTop,
    this.textBottom,
    this.resolution,
    this.videoDurationSec,
    this.slowmoFactor,
    this.rotationDir,
    this.rotationSpeed,
    this.stabilize,
    this.zoomLevel,
  });

  final int eventId;
  final String eventName;

  /// Local filesystem path (set by Station when Station==Recorder, or later by
  /// Recorder after downloading from overlayUrl/musicUrl).
  final String? overlayPath;
  final String? musicPath;

  /// Backend URL dla overlay/music. Recorder pobiera do swojego docs cache
  /// gdy te URL-e sa dostarczone (Station na innym urzadzeniu = nie mozemy
  /// polegac na lokalnej sciezce Stationa).
  final String? overlayUrl;
  final String? musicUrl;

  /// Offset (sekundy) skad ma startowac miks muzyki. Null => heurystyka
  /// recordera (30% dlugosci clamp 30-60). Ustawiony przez backend library
  /// (AI viral analysis albo manual w admin panel).
  final double? musicOffsetSec;
  final String? musicOffsetMode; // 'default_30s' | 'ai' | 'custom'
  final String? textTop;
  final String? textBottom;

  // Parametry nagrywania ze Station Settings (nadpisuja lokalne).
  // resolution: 'fullHd' | 'uhd4k' (8K usuniete - za dlugo FFmpeg).
  final String? resolution;
  final int? videoDurationSec;
  final double? slowmoFactor;
  final String? rotationDir; // 'cw' | 'ccw' | 'mixed'
  final int? rotationSpeed;

  /// Czy wlaczyc post-process stabilizacji (FFmpeg deshake). Null = brak
  /// nadpisania (Recorder uzywa ostatniej wartosci w SettingsStore).
  final bool? stabilize;

  /// Zoom aparatu (np 0.6=ultrawide, 1.0=main, 2.0=tele). Recorder clampuje
  /// do zakresu wspieranego przez kamere. Null = brak nadpisania.
  final double? zoomLevel;

  factory EventConfig.fromJson(Map<String, dynamic> j) => EventConfig(
        eventId: (j['event_id'] as num?)?.toInt() ?? 0,
        eventName: j['event_name']?.toString() ?? '',
        overlayPath: j['overlay_path']?.toString(),
        musicPath: j['music_path']?.toString(),
        overlayUrl: j['overlay_url']?.toString(),
        musicUrl: j['music_url']?.toString(),
        musicOffsetSec: (j['music_offset_sec'] as num?)?.toDouble(),
        musicOffsetMode: j['music_offset_mode']?.toString(),
        textTop: j['text_top']?.toString(),
        textBottom: j['text_bottom']?.toString(),
        resolution: j['resolution']?.toString(),
        videoDurationSec: (j['video_duration_s'] as num?)?.toInt(),
        slowmoFactor: (j['slowmo_factor'] as num?)?.toDouble(),
        rotationDir: j['rotation_dir']?.toString(),
        rotationSpeed: (j['rotation_speed'] as num?)?.toInt(),
        stabilize: j['stabilize'] is bool ? j['stabilize'] as bool : null,
        zoomLevel: (j['zoom_level'] as num?)?.toDouble(),
      );

  EventConfig copyWith({String? overlayPath, String? musicPath}) => EventConfig(
        eventId: eventId,
        eventName: eventName,
        overlayPath: overlayPath ?? this.overlayPath,
        musicPath: musicPath ?? this.musicPath,
        overlayUrl: overlayUrl,
        musicUrl: musicUrl,
        musicOffsetSec: musicOffsetSec,
        musicOffsetMode: musicOffsetMode,
        textTop: textTop,
        textBottom: textBottom,
        resolution: resolution,
        videoDurationSec: videoDurationSec,
        slowmoFactor: slowmoFactor,
        rotationDir: rotationDir,
        rotationSpeed: rotationSpeed,
        stabilize: stabilize,
        zoomLevel: zoomLevel,
      );
}
