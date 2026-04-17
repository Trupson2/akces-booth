import 'dart:typed_data';

/// Protokol BLE fotobudki "360 Controller" (YCKJNB).
///
/// Reverse-engineered z ChackTok apki (com.youfan.chacktok) w Sesji BLE Recon.
/// Protokol: zwykly GATT write na charakterystyke FFF1 w serwisie FFF0.
/// Zero szyfrowania, zero custom SMP, zero magii.
///
/// **Struktura komendy (12 bajtow):**
/// ```
/// [0]  0xAA   header
/// [1]  0xCC   header 2
/// [2]  switchByte  - 0x11 CW start, 0x22 CCW start, 0x33 STOP/lock
/// [3]  speedByte   - speed 1-8 * 17 (= 0x11, 0x22, ... 0x88)
/// [4]  0x22   stala (mode)
/// [5]  minByte     - time / 60
/// [6]  secByte     - time % 60
/// [7]  0x11   stala (flag)
/// [8]  0x00   padding
/// [9]  checksum    - sum(bytes[2..8]) & 0xFF
/// [10] 0xCC   footer
/// [11] 0xAA   footer 2
/// ```
///
/// **Uwagi:**
/// - ChackTok dolicza +3 sekundy do duration (bufor na acceleration) przed wyslaniem.
/// - Max speed w ChackTok UI = 8. Na eventach zalecane 3-5.
/// - Device name prefix: "360 Controller" (np. "360 Controller_O275").
class BoothProtocol {
  BoothProtocol._();

  /// Service UUID - zawiera charakterystyke do pisania komend.
  static const String serviceUuid = '0000FFF0-0000-1000-8000-00805F9B34FB';

  /// Write+Notify charakterystyka.
  static const String writeCharUuid = '0000FFF1-0000-1000-8000-00805F9B34FB';

  /// Prefix nazwy urzadzenia - filtr przy skanie BLE.
  static const String deviceNamePrefix = '360 Controller';

  // Switch byte values.
  static const int switchStartCw = 0x11;
  static const int switchStartCcw = 0x22;
  static const int switchStop = 0x33;

  // Constants in frame.
  static const int headerLo = 0xAA;
  static const int headerHi = 0xCC;
  static const int byteMode = 0x22; // [4]
  static const int byteFlag = 0x11; // [7]

  /// Speed: 1-8. Kodowane jako `speed * 17` (0x11).
  static const int minSpeed = 1;
  static const int maxSpeed = 8;

  /// Bufor dodawany do duration (ChackTok tak robi).
  static const int durationBufferSeconds = 3;

  /// Zbuduj 12-bajtowa komende.
  ///
  /// [switchByte] - [switchStartCw], [switchStartCcw] albo [switchStop].
  /// [speed] - 1..8 (clampowane).
  /// [durationSeconds] - 0..999 (clampowane). Bez bufora; bufora nie dolicza
  /// sama funkcja, zeby uzytkownik mial pelna kontrole.
  static Uint8List build({
    required int switchByte,
    required int speed,
    required int durationSeconds,
  }) {
    final s = speed.clamp(minSpeed, maxSpeed);
    final d = durationSeconds.clamp(0, 999);
    final int minutes = d ~/ 60;
    final int seconds = d % 60;

    final bytes = Uint8List(12);
    bytes[0] = headerLo;
    bytes[1] = headerHi;
    bytes[2] = switchByte & 0xFF;
    bytes[3] = (s * 17) & 0xFF;
    bytes[4] = byteMode;
    bytes[5] = minutes & 0xFF;
    bytes[6] = seconds & 0xFF;
    bytes[7] = byteFlag;
    bytes[8] = 0x00;

    int sum = 0;
    for (int i = 2; i <= 8; i++) {
      sum += bytes[i];
    }
    bytes[9] = sum & 0xFF;
    bytes[10] = headerHi;
    bytes[11] = headerLo;
    return bytes;
  }

  /// Wygodne wrappery.
  static Uint8List startCw({
    required int speed,
    required int durationSeconds,
  }) =>
      build(
        switchByte: switchStartCw,
        speed: speed,
        durationSeconds: durationSeconds,
      );

  static Uint8List startCcw({
    required int speed,
    required int durationSeconds,
  }) =>
      build(
        switchByte: switchStartCcw,
        speed: speed,
        durationSeconds: durationSeconds,
      );

  /// STOP: switch=0x33. Speed/duration moga byc dowolne - ChackTok wysyla
  /// ostatnio uzywane, my wysylamy takie same dla spojnosci logow.
  static Uint8List stopCmd({
    int speed = 1,
    int durationSeconds = 0,
  }) =>
      build(
        switchByte: switchStop,
        speed: speed,
        durationSeconds: durationSeconds,
      );

  /// "AA CC 11 55 22 00 0B 11 00 9E CC AA" format dla logow.
  static String toHex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}
