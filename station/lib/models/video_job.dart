/// Reprezentuje pojedyncze nagranie przechodzace przez pipeline.
///
/// Tworzone gdy transfer z OnePlus 13 konczy sie sukcesem. W Sesji 3 wszystko
/// jest zmockowane - `assetPath` wskazuje na `assets/mock_video.mp4` (lub pusto,
/// jesli placeholder).
class VideoJob {
  VideoJob({
    required this.id,
    required this.createdAt,
    this.localFilePath,
    this.assetPath,
    this.shortId,
    this.publicUrl,
  });

  /// UUID / timestamp do identyfikacji.
  final String id;

  /// Kiedy job powstal.
  final DateTime createdAt;

  /// Sciezka do pliku w docs/ (po transferze z OnePlus).
  final String? localFilePath;

  /// Jesli mockowany - sciezka do bundla (np. 'assets/mock_video.mp4').
  final String? assetPath;

  /// Short ID od RPi po udanym uploadzie (np. 'AB3D5F').
  final String? shortId;

  /// URL do filmu na RPi dla QR (np. 'booth.akces360.pl/v/AB3D5F').
  final String? publicUrl;

  VideoJob copyWith({
    String? localFilePath,
    String? assetPath,
    String? shortId,
    String? publicUrl,
  }) {
    return VideoJob(
      id: id,
      createdAt: createdAt,
      localFilePath: localFilePath ?? this.localFilePath,
      assetPath: assetPath ?? this.assetPath,
      shortId: shortId ?? this.shortId,
      publicUrl: publicUrl ?? this.publicUrl,
    );
  }

  /// Mock job dla Sesji 3 (wskazuje na asset mock_video.mp4).
  factory VideoJob.mock() {
    final ts = DateTime.now();
    return VideoJob(
      id: 'mock_${ts.millisecondsSinceEpoch}',
      createdAt: ts,
      assetPath: 'assets/mock_video.mp4',
    );
  }

  /// Mock po upload - nadaje short_id + url.
  VideoJob asUploaded() {
    final shortId = 'MOCK${id.hashCode.abs() % 100000}';
    return copyWith(
      shortId: shortId,
      publicUrl: 'booth.akces360.pl/v/$shortId',
    );
  }
}
