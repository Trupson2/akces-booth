/// Glowny stan aplikacji Station - mapa 1:1 na ekran w app.dart.
///
/// Przeplyw typowy:
/// idle -> recording -> processing -> transfer -> preview
///   -> (akceptuj) uploading -> qrDisplay -> thankYou -> idle
///   -> (powtorz)  idle
enum AppState {
  /// "Wejdz na platforme" - glowny ekran, 90% czasu tutaj.
  idle,

  /// Nagrywanie (mock: 8s auto-stop).
  recording,

  /// FFmpeg na OnePlus 13 (mock: 10s).
  processing,

  /// Transfer WiFi OnePlus -> Tab (mock: 5s).
  transfer,

  /// Gosc oglada film i klika akceptuj/powtorz.
  preview,

  /// Upload Tab -> RPi (mock: 5s).
  uploading,

  /// Fullscreen QR (mock: auto-reset po 60s).
  qrDisplay,

  /// "Dziekujemy" (3s) -> idle.
  thankYou,

  /// Cos poszlo nie tak - pokazuje ErrorScreen z opcja "Sprobuj ponownie".
  /// Sesja 8a: timeouty per-state + fallbacki.
  error,
}

extension AppStateX on AppState {
  String get debugName => name;
}
