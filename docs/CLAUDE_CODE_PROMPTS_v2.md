# Akces Booth - Claude Code Prompts (MVP v2)

**Architektura:** 2 apki Flutter (Recorder + Station) + Backend Flask + Admin Panel Web
**Scope:** MVP z content library, AI ramkami i templates
**Timeline:** ~25h pracy rozłożone na 10 sesji

**Instrukcja użycia:**
- Każdy prompt między `---BEGIN PROMPT---` a `---END PROMPT---` wklejasz do Claude Code
- Sesje idą **sekwencyjnie** - nie przeskakuj
- Po każdej sesji: `flutter run` / `python app.py` → test → git commit → następna sesja
- Jeśli Claude Code zgaduje / robi głupoty → STOP, napisz do mnie, rozpoczynamy nową sesję z czystym context

---

## 🎯 PRZED PIERWSZĄ SESJĄ - Setup środowiska (jednorazowo)

```bash
# 1. Zainstaluj Flutter SDK
# https://docs.flutter.dev/get-started/install/windows
# Rozpakuj do C:\flutter\ i dodaj C:\flutter\bin do PATH

# 2. Zainstaluj Android Studio + SDK 34
# https://developer.android.com/studio

# 3. Sprawdź instalację
flutter doctor

# 4. Utwórz strukturę projektu
mkdir C:\projekty\akces-booth
cd C:\projekty\akces-booth
git init
mkdir recorder station backend admin-panel docs

# 5. Skopiuj dokumenty do docs/
# DECISIONS.md, WORKFLOW.md, BT_PROTOCOL.md (po recon)

# 6. Podłącz Tab A11+ przez USB (USB debugging ON)
adb devices
# Powinno pokazać urządzenie
```

---

# 📱 SESJA 1: Recorder - szkielet + BLE Motor Control

**Cel:** Apka na OnePlus 13 łączy się z fotobudką i steruje silnikiem.
**Czas:** 2-3h
**Prerequisite:** BT_PROTOCOL.md z RECON.md musi być gotowy!

---BEGIN PROMPT---

Jesteś seniorem Flutter developerem. Pracujemy nad projektem **Akces Booth** - system fotobudki 360 dla Akces 360 (polska firma rentalowa).

**Kontekst biznesowy (krótko):**
Budujemy alternatywę dla ChackTok. Architektura: 2 apki Flutter komunikujące się przez WiFi + backend Flask na Raspberry Pi. Dziś robimy **Apkę 1: Recorder** która chodzi na OnePlus 13 zamontowanym na ramieniu fotobudki.

**Pełna specyfikacja projektu w:** `docs/DECISIONS.md`, `docs/WORKFLOW.md`, `docs/BT_PROTOCOL.md`

**Cel SESJI 1:**
Szkielet Flutter projektu **Recorder** z działającym sterowaniem silnikiem BLE.

**Wymagania:**

### 1. Inicjalizacja projektu

```bash
cd recorder
flutter create --org pl.akces360.booth --project-name akces_booth_recorder .
```

Dostosuj konfigurację:
- Tylko Android (usuń iOS, web, linux, macos, windows)
- Min SDK 26 (Android 8.0), target 34
- Orientacja: landscape only (telefon na ramieniu obraca się)
- Package: `pl.akces360.booth.recorder`

### 2. Struktura folderów

```
recorder/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── screens/
│   │   ├── home_screen.dart          # Główny ekran operatora
│   │   └── bt_setup_screen.dart      # Parowanie fotobudki
│   ├── services/
│   │   └── motor_controller.dart     # BLE komunikacja z fotobudką
│   ├── models/
│   │   └── motor_state.dart          # Enum stanów silnika
│   ├── widgets/
│   │   ├── status_indicator.dart     # Kropki status (BT, bateria itd.)
│   │   └── big_button.dart           # Duże przyciski dla operatora
│   └── theme/
│       └── app_theme.dart            # Akces 360 branding
├── android/
└── pubspec.yaml
```

### 3. Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_blue_plus: ^1.32.0
  permission_handler: ^11.3.0
  provider: ^6.1.0
  google_fonts: ^6.2.0
  shared_preferences: ^2.2.0
```

### 4. Permissions (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

### 5. Motor Controller (services/motor_controller.dart)

**⚠️ UWAGA: Zajrzyj do `docs/BT_PROTOCOL.md` żeby dowiedzieć się dokładnych komend BT.**

Jeśli protokół to **Bluetooth Classic (HC-05 style):**
- Użyj alternative package: `flutter_bluetooth_serial` albo implementuj przez platform channel
- Komendy wysyłane jako ASCII string przez RFCOMM

Jeśli protokół to **BLE (HM-10/JDY-08 style):**
- Użyj `flutter_blue_plus`
- Write do konkretnej characteristic UUID
- Format bajtów jak w BT_PROTOCOL.md

```dart
// Klasa bazowa
abstract class MotorController extends ChangeNotifier {
  bool get isConnected;
  bool get isRunning;
  int get currentSpeed;        // 1-10
  Direction get direction;     // clockwise / counterClockwise
  
  Future<List<BluetoothDevice>> scanDevices();
  Future<bool> connect(BluetoothDevice device);
  Future<void> disconnect();
  Future<void> start();
  Future<void> stop();
  Future<void> setSpeed(int level);
  Future<void> reverseDirection();
  Future<void> speedUp();
  Future<void> speedDown();
}

enum Direction { clockwise, counterClockwise }

// Implementacja zgodnie z protokołem
class RealMotorController extends MotorController {
  // Implementacja na podstawie BT_PROTOCOL.md
  // Metoda _sendCommand(List<int> bytes) loguje hex do konsoli
  // Checksum calculation z BT_PROTOCOL.md
}
```

### 6. BT Setup Screen (screens/bt_setup_screen.dart)

UI do parowania:
- "Skanuj urządzenia" button
- Lista wykrytych BT devices (filtr po nazwie z RECON)
- Kliknięcie urządzenia → próba połączenia
- Status: "Łączenie...", "Połączono ✅", "Błąd - spróbuj ponownie"
- Po udanym połączeniu → zapisz MAC w SharedPreferences
- Auto-connect przy następnym uruchomieniu

### 7. Home Screen (screens/home_screen.dart)

Layout landscape dla telefonu:

```
┌─────────────────────────────────────────────┐
│  AKCES BOOTH RECORDER          🔵✅ 🔋 67% │
├─────────────────────────────────────────────┤
│                                              │
│  📡 Tablet: Oczekiwanie (Sesja 3)           │
│  🔵 Silnik: Połączony (YCKJNB-XXXX)         │
│  🔋 Bateria: 67%                             │
│  💾 Wolne: 45 GB                             │
│                                              │
│  ┌────────────────────────┐                 │
│  │                        │                 │
│  │   ▶ TEST START         │                 │
│  │                        │                 │
│  └────────────────────────┘                 │
│                                              │
│  [Test Speed +/-]  [Reverse]  [Stop]        │
│                                              │
│  Speed: ████░░░ 6/10                        │
│  Direction: → Clockwise                      │
│                                              │
│  Ostatnie komendy:                           │
│  • 17:34:25  START                           │
│  • 17:34:33  STOP                            │
│  • 17:34:41  SET_SPEED 7                     │
│                                              │
└─────────────────────────────────────────────┘
```

### 8. Theme

```dart
class AppTheme {
  static const primary = Color(0xFF6366F1);     // indigo
  static const background = Color(0xFF0F172A);  // dark slate
  static const surface = Color(0xFF1E293B);
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  
  static TextTheme get textTheme => GoogleFonts.interTextTheme(
    ThemeData.dark().textTheme,
  );
}
```

### 9. Main entry (main.dart)

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const AkcesBoothRecorder());
}
```

### 10. Testing requirement

Na końcu sesji pokaż mi:
1. `flutter run` działa na prawdziwym OnePlus 13 (lub emulatorze)
2. Screenshot z UI
3. Że skanowanie BT działa (widać fotobudkę w liście)
4. Że połączenie BT i wysyłanie komend działa (silnik reaguje!)
5. `git commit` "feat: sesja 1 - recorder szkielet + BLE motor control"

**Jeśli natrafisz na problem z BT:**
- NIE zgaduj bajtów
- NIE próbuj "podobnego protokołu"
- STOP, napisz do Adriana, pokaż mu co robisz
- Może BT_PROTOCOL.md jest niekompletny - wtedy trzeba doprecyzować

**Nie rób w tej sesji:**
- ❌ Kamery (Sesja 2)
- ❌ FFmpeg (Sesja 6)
- ❌ WiFi communication ze Station (Sesja 4)

Zaczynaj. Pytania najpierw jeśli niejasne.

---END PROMPT---

---

# 📱 SESJA 2: Recorder - Camera + Recording

**Cel:** OnePlus 13 nagrywa wideo (240fps slow-mo) zsynchronizowane z silnikiem.
**Czas:** 2-3h

---BEGIN PROMPT---

Kontynuujemy **Akces Booth Recorder** (Flutter app na OnePlus 13). Sesja 1 done: mamy szkielet i sterowanie silnikiem BLE. Teraz dodajemy **nagrywanie wideo**.

**Cel SESJI 2:**
Apka nagrywa wideo z tylnej kamery OnePlus 13. Tryby: Normal (30fps), Slow-mo (120fps), Super Slow-mo (240fps - natywnie wspierane przez OP13).

**Kluczowe:** Recording musi być **zsynchronizowany** z silnikiem - klik START triggeruje motor + recording jednocześnie.

**Wymagania:**

### 1. Dependencies

```yaml
camera: ^0.11.0
path_provider: ^2.1.0
video_player: ^2.9.0
permission_handler: ^11.3.0
```

### 2. Permissions Android

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
```

Dodaj w `<application>`:
```xml
android:requestLegacyExternalStorage="true"
```

Min SDK w build.gradle bump up do 26 (jeśli nie jest).

### 3. Camera Service (services/camera_service.dart)

```dart
class CameraService extends ChangeNotifier {
  CameraController? _controller;
  RecordingMode _currentMode = RecordingMode.normal;
  bool _isInitialized = false;
  bool _isRecording = false;
  String? _lastRecordingPath;
  DateTime? _recordingStartTime;
  
  // Getters
  CameraController? get controller => _controller;
  RecordingMode get currentMode => _currentMode;
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  Duration get recordingDuration => 
    _recordingStartTime == null 
      ? Duration.zero 
      : DateTime.now().difference(_recordingStartTime!);
  
  Future<void> initialize() async {
    // Żądaj permissions
    // Znajdź back camera
    // Init CameraController z ResolutionPreset.high
    // Ustaw fps na podstawie trybu
  }
  
  Future<void> setMode(RecordingMode mode) async {
    // Re-initialize controller z odpowiednim fps
    // NORMAL: 30fps
    // SLOW_MO_120: 120fps (wszystko 1080p)
    // SUPER_SLOW_MO_240: 240fps (wszystko 1080p)
  }
  
  Future<void> startRecording() async {
    if (!_isInitialized || _isRecording) return;
    
    // Generate output path
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _lastRecordingPath = '${dir.path}/recordings/raw_$timestamp.mp4';
    
    await _controller!.startVideoRecording();
    _isRecording = true;
    _recordingStartTime = DateTime.now();
    notifyListeners();
  }
  
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    
    final xFile = await _controller!.stopVideoRecording();
    // Move file to our recordings directory
    final newPath = _lastRecordingPath!;
    await File(xFile.path).rename(newPath);
    
    _isRecording = false;
    _recordingStartTime = null;
    notifyListeners();
    
    return newPath;
  }
  
  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    super.dispose();
  }
}

enum RecordingMode { normal, slowMo120, superSlowMo240 }
```

### 4. Native fps support dla OnePlus 13

Flutter `camera` package ma ograniczenia przy wysokich fps. Dla OnePlus 13 z 240fps:

**Opcja A (prosta):** Użyj tylko trybu SLOW_MO_120 (120fps) - Flutter camera to wspiera.

**Opcja B (zaawansowana):** Platform channel do natywnego Android Camera2 API.

**Dla MVP:** Start od Opcji A. Jeśli 120fps wygląda OK przy slow-mo 2x → zostajemy. Jeśli klient wymaga super slow-mo → dopieszczamy w fazie 2 przez platform channel.

**Dodaj TODO w kodzie:**
```dart
// TODO: Implement 240fps via platform channel when needed
// OnePlus 13 natively supports 240fps but Flutter camera package
// doesn't expose it. Requires native Android Camera2 API binding.
```

### 5. Recording Screen (screens/recording_screen.dart)

**Fullscreen camera preview z overlay kontrolek:**

```
┌─────────────────────────────────────────────┐
│  [Camera Live Preview pełny ekran]          │
│                                              │
│                                              │
│         ┌──────────────────────┐            │
│         │                      │            │
│         │  [CAMERA PREVIEW]    │            │
│         │                      │            │
│         │                      │            │
│         └──────────────────────┘            │
│                                              │
│  Mode: [Normal] [Slow-mo] [Super Slow-mo]  │
│                                              │
│       ┌─────────────────┐                   │
│       │    🔴 REC       │                   │ ← pulsing gdy recording
│       │                 │                   │
│       └─────────────────┘                   │
│                                              │
│  Timer: 5.3s / 8.0s (auto-stop)             │
│                                              │
└─────────────────────────────────────────────┘
```

**Integration z MotorController:**

```dart
Future<void> _startFullFlow() async {
  // Trigger motor START przez MotorController
  await motorController.start();
  
  // Trigger camera recording
  await cameraService.startRecording();
  
  // Auto-stop po 8 sekundach (configurable)
  _autoStopTimer = Timer(Duration(seconds: 8), _stopFullFlow);
}

Future<void> _stopFullFlow() async {
  _autoStopTimer?.cancel();
  
  // Stop camera first (dokończ nagranie)
  final videoPath = await cameraService.stopRecording();
  
  // Then stop motor
  await motorController.stop();
  
  // Navigate do Preview Screen
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => PreviewScreen(videoPath: videoPath!),
  ));
}
```

### 6. Preview Screen (screens/preview_screen.dart)

Po zakończeniu nagrania:
- Video player (video_player package)
- Loop playback
- Metadata: długość, rozmiar pliku, rozdzielczość, fps
- Buttons:
  - "Nagraj ponownie" → powrót do RecordingScreen (usuń plik)
  - "Użyj tego filmu" → TODO: wyślij do Station (Sesja 4)
- Na razie drugi przycisk tylko pokazuje: "Transfer będzie w Sesji 4"

### 7. File management

```
{app_documents}/recordings/
    ├── raw_1713...23.mp4
    ├── raw_1713...41.mp4
    └── raw_1713...58.mp4
```

**Cleanup policy:**
- Po pomyślnym wysłaniu do Station (Sesja 4) → usuń raw
- Przy "nagraj ponownie" → usuń raw
- Lista plików w memory (persistent w Sesji 7 via SQLite)

### 8. Permissions flow

Pierwsze uruchomienie RecordingScreen:
```dart
Future<bool> _requestPermissions() async {
  final camera = await Permission.camera.request();
  final mic = await Permission.microphone.request();
  
  if (camera.isGranted && mic.isGranted) return true;
  
  if (camera.isPermanentlyDenied || mic.isPermanentlyDenied) {
    // Pokaż dialog "Go to Settings"
    await openAppSettings();
  }
  
  return false;
}
```

### 9. Testing scenarios

Test na OnePlus 13 (NIE emulator - kamera musi być prawdziwa):
- [ ] Uruchomienie apki → pyta o permissions
- [ ] Wejście do RecordingScreen → widzisz preview kamery
- [ ] Zmiana trybu Normal → Slow-mo 120 → Super Slow-mo 240 (jeśli support)
- [ ] Klik RECORD → motor rusza + nagrywanie startuje razem
- [ ] Auto-stop po 8s → motor staje + nagrywanie kończy
- [ ] Preview pokazuje plik, odtwarza się w pętli
- [ ] "Nagraj ponownie" → plik usunięty, powrót do recording
- [ ] Po zamknięciu apki i ponownym otwarciu - poprzednie nagrania dostępne

### 10. Na końcu

- `flutter run` bez crashy
- Recording działa w trybie Normal (minimum)
- Slow-mo 120fps działa
- Integration motor + camera sync OK
- Commit "feat: sesja 2 - camera + recording"

**Jeśli 240fps nie działa** (Flutter camera limitation):
- Zostaw TODO, ogranicz UI do 120fps
- Idź dalej
- Addressujemy przez platform channel w fazie 2

Zaczynaj.

---END PROMPT---

---

# 📱 SESJA 3: Station - Szkielet + UI 7 stanów

**Cel:** Tab A11+ ma pełny flow UI zgodnie z WORKFLOW.md (IDLE → RECORDING → PROCESSING → TRANSFER → PREVIEW → UPLOADING → QR_DISPLAY → THANK_YOU).
**Czas:** 3h

---BEGIN PROMPT---

Startujemy **Apkę 2: Station** - druga część Akces Booth, chodzi na Samsung Galaxy Tab A11+ na statywie obok fotobudki. To jest **interfejs dla gościa**.

**Pełna specyfikacja UX w `docs/WORKFLOW.md`** - przeczytaj przed kodowaniem, tam są mockupy każdego ekranu.

**Cel SESJI 3:**
Szkielet projektu Station + **wszystkie 8 stanów UI** z przepływami między nimi. Wszystkie stany zmockowane - później podepniemy prawdziwą logikę (WiFi receive, upload, QR generation).

**Wymagania:**

### 1. Utworzenie projektu

```bash
cd station
flutter create --org pl.akces360.booth --project-name akces_booth_station .
```

Konfiguracja:
- Tylko Android
- Min SDK 26, target 34
- **Orientacja: landscape only**
- Package: `pl.akces360.booth.station`

### 2. Struktura

```
station/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── screens/
│   │   ├── idle_screen.dart           # "Wejdź na platformę 👋"
│   │   ├── recording_screen.dart      # "🔴 NAGRYWAM..."
│   │   ├── processing_screen.dart     # "⏳ Przetwarzam... 40%"
│   │   ├── transfer_screen.dart       # "📡 Odbieram film..."
│   │   ├── preview_screen.dart        # [Video] + Akceptuj/Powtórz
│   │   ├── uploading_screen.dart      # "☁️ Wysyłam..."
│   │   ├── qr_display_screen.dart     # Fullscreen QR
│   │   ├── thank_you_screen.dart      # "Dziękujemy! 🙂"
│   │   ├── settings_screen.dart       # PIN protected
│   │   └── bt_setup_screen.dart       # Parowanie fotobudki
│   ├── services/
│   │   ├── app_state_machine.dart     # Master state controller
│   │   ├── motor_controller.dart      # BLE (copy from Recorder)
│   │   └── mock_services.dart         # Mocki dla Sesji 3
│   ├── models/
│   │   ├── app_state.dart             # Enum stanów
│   │   └── video_job.dart             # Model pracy (film + metadata)
│   ├── widgets/
│   │   ├── animated_counter.dart      # "+1 film!" licznik
│   │   ├── status_indicator.dart      # Kropki BT/WiFi/Recorder
│   │   ├── qr_widget.dart             # QR code display
│   │   └── big_action_button.dart     # Duże przyciski
│   └── theme/
│       └── app_theme.dart
```

### 3. Dependencies

```yaml
flutter:
  sdk: flutter
provider: ^6.1.0
flutter_blue_plus: ^1.32.0
permission_handler: ^11.3.0
shared_preferences: ^2.2.0
google_fonts: ^6.2.0
qr_flutter: ^4.1.0
video_player: ^2.9.0
```

### 4. App State Machine (kluczowe!)

```dart
enum AppState {
  idle,           // "Wejdź na platformę"
  recording,      // Nagrywanie (0-8s)
  processing,     // FFmpeg na OnePlus 13
  transfer,       // WiFi transfer z OnePlus → Tab
  preview,        // Gość ogląda + decyduje
  uploading,      // Tab → RPi
  qrDisplay,      // Fullscreen QR
  thankYou,       // "Dziękujemy!" (3s)
}

class AppStateMachine extends ChangeNotifier {
  AppState _state = AppState.idle;
  VideoJob? _currentJob;
  double _progress = 0.0;
  
  AppState get state => _state;
  VideoJob? get currentJob => _currentJob;
  double get progress => _progress;
  
  // Transitions
  Future<void> startRecording() async {
    _state = AppState.recording;
    notifyListeners();
    
    // TODO Sesja 4: trigger motor + recorder via WiFi
    // Mock: wait 8s, then move to processing
    await Future.delayed(Duration(seconds: 8));
    _moveTo(AppState.processing);
  }
  
  Future<void> _moveTo(AppState newState) async {
    _state = newState;
    notifyListeners();
    
    // Mock timing dla MVP
    switch (newState) {
      case AppState.processing:
        await _mockProgress(Duration(seconds: 10));
        _moveTo(AppState.transfer);
        break;
      case AppState.transfer:
        await _mockProgress(Duration(seconds: 5));
        _currentJob = VideoJob.mock();  // Załaduje test video
        _moveTo(AppState.preview);
        break;
      // preview → czeka na user input
      case AppState.uploading:
        await _mockProgress(Duration(seconds: 5));
        _moveTo(AppState.qrDisplay);
        break;
      case AppState.qrDisplay:
        await Future.delayed(Duration(seconds: 60));
        _moveTo(AppState.thankYou);
        break;
      case AppState.thankYou:
        await Future.delayed(Duration(seconds: 3));
        _reset();
        break;
      default:
        break;
    }
  }
  
  // From PREVIEW
  void acceptVideo() {
    _moveTo(AppState.uploading);
  }
  
  void rejectVideo() {
    _currentJob = null;
    _reset();
  }
  
  // Manual "Next guest" na QR screen
  void nextGuest() {
    _moveTo(AppState.thankYou);
  }
  
  void _reset() {
    _currentJob = null;
    _progress = 0;
    _state = AppState.idle;
    notifyListeners();
  }
  
  Future<void> _mockProgress(Duration total) async {
    final steps = 20;
    for (int i = 0; i <= steps; i++) {
      _progress = i / steps;
      notifyListeners();
      await Future.delayed(total ~/ steps);
    }
  }
}
```

### 5. Master Widget (app.dart)

```dart
class AkcesBoothStation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStateMachine(),
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Consumer<AppStateMachine>(
          builder: (context, machine, child) {
            switch (machine.state) {
              case AppState.idle: return IdleScreen();
              case AppState.recording: return RecordingScreen();
              case AppState.processing: return ProcessingScreen();
              case AppState.transfer: return TransferScreen();
              case AppState.preview: return PreviewScreen();
              case AppState.uploading: return UploadingScreen();
              case AppState.qrDisplay: return QrDisplayScreen();
              case AppState.thankYou: return ThankYouScreen();
            }
          },
        ),
      ),
    );
  }
}
```

### 6. IDLE Screen (najważniejszy - 90% czasu tutaj)

**Zgodnie z WORKFLOW.md mockupem.** Kluczowe elementy:

- Centralny ogromny przycisk **"▶ START NAGRANIA"**
- Pod spodem: "Dziś: 23 filmy" (licznik, nawet jeśli placeholder)
- W rogach: status indicators (BT/WiFi/Recorder)
- Footer: logo Akces 360 + małe "Ustawienia" (długie przytrzymanie → PIN → Settings)
- Brandingowa animacja tła (subtle, ~10% intensywności)

### 7. Każdy ekran - szczegóły

**Implementuj wszystkie 8 ekranów** zgodnie z mockupami w WORKFLOW.md:

- **IdleScreen:** opisany wyżej
- **RecordingScreen:** progress bar 0-8s, "🔴 NAGRYWAM", duży STOP button
- **ProcessingScreen:** progress bar + "Przetwarzam film... 40%"
- **TransferScreen:** "📡 Odbieram film z kamery..." + progress
- **PreviewScreen:** video autoplay loop + "Akceptuj / Powtórz" buttons
- **UploadingScreen:** "☁️ Wysyłam na serwer..." + progress
- **QrDisplayScreen:** fullscreen QR (mock 'booth.akces360.pl/v/MOCK12') + instrukcja + countdown
- **ThankYouScreen:** "Dziękujemy! Kolejny gość zapraszamy 🙂" (3s)

### 8. Mock video dla Preview

Na razie PreviewScreen odtwarza **statyczny mock video** (assets/mock_video.mp4). Dodaj do assets:
```yaml
flutter:
  assets:
    - assets/mock_video.mp4
```

Pobierz mały sample MP4 (np. ~5-10MB, 5-sekundowy) - możesz wygenerować ffmpeg z color gradient, albo wrzuć jakiś test:
```bash
# Prosty test MP4 do mockup
ffmpeg -f lavfi -i testsrc=duration=5:size=1920x1080:rate=30 -c:v libx264 assets/mock_video.mp4
```

### 9. Theme (spójny z Recorder)

Skopiuj `theme/app_theme.dart` z Recorder. Zachowaj consistency kolorów.

### 10. Testing scenarios

Na końcu:
- [ ] `flutter run` na Tab A11+ (lub emulator landscape)
- [ ] IdleScreen się wyświetla
- [ ] Klik START → automatyczny przepływ przez wszystkie ekrany (mock timing)
- [ ] Po 8s RECORDING → PROCESSING (10s) → TRANSFER (5s) → PREVIEW
- [ ] PREVIEW: klik AKCEPTUJ → UPLOADING (5s) → QR (60s) → THANK YOU (3s) → IDLE
- [ ] PREVIEW: klik POWTÓRZ → IDLE od razu
- [ ] QR: klik "Następny gość" → skip reszty
- [ ] Transitions są płynne (Flutter animations)

**Commit:** "feat: sesja 3 - station szkielet + 8 stanów UI"

**NIE RÓB w tej sesji:**
- ❌ WiFi connection do Recorder (Sesja 4)
- ❌ Prawdziwego uploadu (Sesja 5)
- ❌ Prawdziwego QR (Sesja 6)
- ❌ Settings PIN (Sesja 9)
- ❌ Content library (Sesja 7)

Pytania przed rozpoczęciem? Jeśli nie - zaczynaj.

---END PROMPT---

---

# 📱 SESJA 4: WiFi Communication Recorder ↔ Station

**Cel:** Apki Recorder i Station rozmawiają ze sobą przez WiFi. Station triggeruje recording, Recorder wysyła film.
**Czas:** 2-3h

---BEGIN PROMPT---

Kontynuujemy **Akces Booth**. Sesje 1-3 done: Recorder ma BLE + kamerę, Station ma UI 8 stanów z mockami. Teraz łączymy obie apki przez **WiFi**.

**Cel SESJI 4:**
Station wysyła komendę START → Recorder rusza silnik + nagrywa → po zakończeniu wysyła film do Station przez WiFi.

**Architektura komunikacji:**

Dwa urządzenia muszą być na **tej samej sieci WiFi** (hotspot telefonu, router w Waszym domu, albo WiFi Direct).

**Model:** Recorder = WiFi **client**, Station = **server** (serveruje endpoint do którego Recorder wysyła plik).

Dlaczego tak:
- Station ma stabilny ekran z informacjami dla gościa → niech będzie stały serwer
- Recorder jest "worker" - wywołuje API Station kiedy trzeba
- Prosty model: HTTP + WebSocket dla real-time updates

**Wymagania:**

### 1. Station: HTTP Server (lokalny)

Dependencies:
```yaml
shelf: ^1.4.0
shelf_router: ^1.1.0
shelf_web_socket: ^2.0.0
web_socket_channel: ^2.4.0
network_info_plus: ^5.0.0    # Dowiedz się IP urządzenia
```

**`services/local_server.dart`** w projekcie Station:

```dart
class LocalServer {
  HttpServer? _server;
  WebSocketChannel? _recorderChannel;
  final int port = 8080;
  
  Future<void> start() async {
    final router = Router();
    
    // WebSocket endpoint dla real-time communication
    router.get('/ws', webSocketHandler((WebSocketChannel channel) {
      _recorderChannel = channel;
      channel.stream.listen(_handleMessage);
    }));
    
    // HTTP endpoint do uploadu gotowego pliku
    router.post('/upload', (Request req) async {
      final video = await req.readAsBytes();
      final filename = req.headers['X-Filename'] ?? 'video.mp4';
      
      // Zapisz plik lokalnie na Tab
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/received/$filename');
      await file.writeAsBytes(video);
      
      // Powiadom AppStateMachine że film gotowy
      AppStateMachine.instance.onVideoReceived(file.path);
      
      return Response.ok('{"status":"ok"}');
    });
    
    _server = await shelf_io.serve(router, '0.0.0.0', port);
    print('Station server running on port $port');
  }
  
  void sendToRecorder(Map<String, dynamic> message) {
    _recorderChannel?.sink.add(jsonEncode(message));
  }
  
  void _handleMessage(dynamic data) {
    final message = jsonDecode(data);
    // Handle: progress updates, state changes, errors
    switch (message['type']) {
      case 'recording_progress':
        // Update UI
        break;
      case 'processing_progress':
        // Update processing bar
        break;
      case 'error':
        // Show error
        break;
    }
  }
  
  Future<String> getLocalIP() async {
    final info = NetworkInfo();
    return await info.getWifiIP() ?? '0.0.0.0';
  }
}
```

### 2. Recorder: WiFi Client

Dependencies:
```yaml
web_socket_channel: ^2.4.0
dio: ^5.4.0
```

**`services/station_client.dart`** w projekcie Recorder:

```dart
class StationClient {
  WebSocketChannel? _channel;
  String _stationIP = '';
  final _dio = Dio();
  
  Future<bool> connect(String ip) async {
    _stationIP = ip;
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://$ip:8080/ws'),
      );
      _channel!.stream.listen(_handleStationMessage);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  void _handleStationMessage(dynamic data) {
    final message = jsonDecode(data);
    switch (message['type']) {
      case 'start_recording':
        // Trigger full flow: motor + camera
        _onStartRequested();
        break;
      case 'stop_recording':
        _onStopRequested();
        break;
    }
  }
  
  void sendProgress(String type, double progress) {
    _channel?.sink.add(jsonEncode({
      'type': type,  // 'recording_progress', 'processing_progress'
      'progress': progress,
    }));
  }
  
  Future<bool> uploadVideo(String videoPath) async {
    try {
      final file = File(videoPath);
      final bytes = await file.readAsBytes();
      
      final response = await _dio.post(
        'http://$_stationIP:8080/upload',
        data: bytes,
        options: Options(
          headers: {
            'Content-Type': 'video/mp4',
            'X-Filename': basename(videoPath),
          },
        ),
        onSendProgress: (sent, total) {
          sendProgress('upload_progress', sent / total);
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
```

### 3. Discovery: jak Recorder znajduje Station?

**Opcja A: Manualny setup (MVP)**
- W Station Settings: wyświetl "Station IP: 192.168.1.45" (przycisk "Skopiuj")
- W Recorder Setup: wpisz IP Station ręcznie, zapisz
- Auto-connect przy starcie apki

**Opcja B: mDNS/Bonjour (ładne, ale skomplikowane)**
- `bonsoir` package
- Zostawiamy na fazę 2

**Dla MVP: Opcja A.** Dodaj:

**Station Settings:**
```
🔗 INFORMACJA DLA RECORDER
Station IP: 192.168.1.45
Station Port: 8080
Pełny URL: ws://192.168.1.45:8080/ws

[📋 Skopiuj]  [🔄 Odśwież IP]
```

**Recorder Setup:**
```
🎯 PODŁĄCZ DO STATION
Station IP: [192.168.1.45       ]
Port:       [8080                ]

[Testuj połączenie]  [Zapisz]
```

### 4. Pełny flow (jak to działa razem)

**T=0:** Użytkownik klika START na Station
```
Station → WebSocket → Recorder: {"type": "start_recording"}
```

**T=0:** Recorder odbiera, triggeruje:
```
Recorder:
  1. MotorController.start()    // Silnik rusza
  2. CameraService.startRecording()  // Nagrywanie
  
Recorder → Station: {"type": "recording_started"}
Station: zmienia stan na RECORDING, pokazuje timer
```

**T=5:** Recorder co 1s wysyła progress:
```
Recorder → Station: {"type": "recording_progress", "progress": 0.625}
```

**T=8:** Auto-stop w Recorder:
```
Recorder:
  1. CameraService.stopRecording() → videoPath
  2. MotorController.stop()
  
Recorder → Station: {"type": "recording_stopped"}
Station: zmienia stan na PROCESSING
```

**T=8-18:** Recorder robi FFmpeg (w Sesji 6, teraz tylko czekamy):
```
Recorder → Station: {"type": "processing_progress", "progress": 0.4}
...
Recorder → Station: {"type": "processing_done"}
```

**T=18-23:** Recorder wysyła plik:
```
Recorder → HTTP POST /upload → Station
Station: odbiera plik, AppStateMachine.onVideoReceived(path)
Station: zmienia stan na PREVIEW, loaduje video
```

### 5. Aktualizacja AppStateMachine w Station

```dart
class AppStateMachine extends ChangeNotifier {
  // ... istniejące pola
  final StationServer _server = StationServer();
  
  Future<void> initialize() async {
    await _server.start();
    // Listen for messages from recorder
  }
  
  Future<void> startRecording() async {
    _state = AppState.recording;
    notifyListeners();
    
    // Teraz WYSYŁAMY do Recorder
    _server.sendToRecorder({'type': 'start_recording'});
    
    // Timeout safety
    _timeoutTimer = Timer(Duration(seconds: 60), () {
      _handleTimeout();
    });
  }
  
  void onRecordingProgress(double progress) {
    _progress = progress;
    notifyListeners();
  }
  
  void onRecordingStopped() {
    _state = AppState.processing;
    _progress = 0;
    notifyListeners();
  }
  
  void onProcessingProgress(double progress) {
    _progress = progress;
    notifyListeners();
  }
  
  void onVideoReceived(String path) {
    _currentJob = VideoJob(videoPath: path);
    _state = AppState.preview;
    notifyListeners();
  }
}
```

### 6. Aktualizacja Recorder's HomeScreen

**Dodaj:**
- Status: "Połączono z Station ✅" (lub czerwone ❌)
- Auto-connect przy starcie
- Retry loop jeśli Station nieosiągalny (co 5s)

### 7. Error handling

Scenariusze:
- Station offline → Recorder pokazuje "Szukam Station..." co 5s
- Upload fail → retry 3x, potem user alert
- Timeout recording → auto-reset oba urządzenia

### 8. Testing

Test na **obu urządzeniach w tej samej WiFi:**

- [ ] Station startuje server → widzi swoje IP w Settings
- [ ] Recorder wpisuje IP → testuje połączenie → ✅
- [ ] Klik START na Station → Recorder dostaje komendę
- [ ] Silnik rusza + kamera nagrywa (jeśli masz fotobudkę) / mock recording
- [ ] Progress bar na Station aktualizuje się
- [ ] Po auto-stop: PROCESSING screen na Station
- [ ] Po transfer: PREVIEW screen na Station z prawdziwym filmem
- [ ] Video player odtwarza plik otrzymany z Recorder

**Commit:** "feat: sesja 4 - wifi communication"

**Następny raz:** Sesja 5 - backend Flask na RPi.

Zaczynaj.

---END PROMPT---

---

# 🐍 SESJA 5: Backend Flask na Raspberry Pi + Admin Panel

**Cel:** Serwer na RPi do uploadu filmów + admin panel web do zarządzania eventami i ramkami AI.
**Czas:** 3h

**UWAGA:** Odpal Claude Code w osobnym katalogu `backend/`. To nie Flutter projekt.

---BEGIN PROMPT---

Startujemy **backend** dla Akces Booth. To **osobny projekt** w stacku Python Flask, chodzi na Raspberry Pi 5 (użytkownik ma już RPi od Akces Hub).

**Kontekst:**
- Raspberry Pi 5, 8GB RAM, NVMe SSD, Debian-based Linux, Python 3.11
- Istniejący Akces Hub na porcie 5000 (nie ingerujemy!)
- Akces Booth = OSOBNY projekt, osobna baza, osobny port 5100
- Cloudflare Tunnel: `booth.akces360.pl`
- Już ma skonfigurowany Gemini API (do Akces Hub trends)

**Cel SESJI 5:**
Backend Flask który:
1. Przyjmuje upload MP4 z apki Station
2. Generuje short URL dla QR
3. Serwuje landing page z odtwarzaczem
4. Admin panel web: CRUD events + content library + AI ramki przez Imagen 3

**Wymagania:**

### 1. Struktura projektu

```
backend/
├── app.py                        # Main Flask app
├── config.py                     # Konfiguracja (.env)
├── models.py                     # SQLite schema + helpers
├── api/
│   ├── __init__.py
│   ├── upload.py                 # POST /api/upload
│   ├── share.py                  # GET /v/{short_id}
│   ├── events.py                 # CRUD events
│   ├── library.py                # Content library (ramki, muzyka)
│   └── ai.py                     # Imagen 3 AI ramki
├── admin/
│   ├── __init__.py
│   ├── routes.py                 # Admin panel routing
│   └── auth.py                   # Simple session auth
├── templates/
│   ├── base.html                 # Layout z Tailwind CDN
│   ├── public/
│   │   ├── watch.html            # QR landing (dla gości)
│   │   ├── gallery.html          # Galeria eventu
│   │   └── landing.html          # Akces 360 brand landing
│   └── admin/
│       ├── dashboard.html        # Panel admin
│       ├── events_list.html      # Lista eventów
│       ├── event_edit.html       # Edycja eventu
│       ├── library.html          # Biblioteka (ramki/muzyka)
│       └── ai_generator.html     # Generowanie ramek AI
├── static/
│   ├── css/style.css             # Custom CSS (Tailwind CDN)
│   ├── js/
│   │   ├── watch.js              # Video player
│   │   ├── admin.js
│   │   └── ai_generator.js
│   └── img/logo_akces360.png
├── storage/
│   ├── videos/{event_id}/        # MP4 files
│   ├── overlays/                 # Ramki PNG (uploaded + AI generated)
│   └── music/                    # Muzyka MP3
├── db/
│   └── akces_booth.db            # SQLite
├── scripts/
│   ├── setup.sh                  # Initial RPi setup
│   └── backup.sh
├── akces-booth.service           # Systemd
├── .env.example
├── requirements.txt
└── README.md
```

### 2. Dependencies

```
Flask==3.0.0
Flask-Session==0.6.0
python-dotenv==1.0.0
qrcode[pil]==7.4.2
Pillow==10.2.0
gunicorn==21.2.0
google-generativeai==0.5.0
```

### 3. Config (.env.example)

```bash
SECRET_KEY=change-me-to-random-string
STORAGE_PATH=./storage
DB_PATH=./db/akces_booth.db
MAX_UPLOAD_SIZE=524288000  # 500MB
PORT=5100
PUBLIC_BASE_URL=https://booth.akces360.pl

# Gemini API (reuse from Akces Hub .env)
GEMINI_API_KEY=xxx

# Admin panel auth
ADMIN_USERNAME=adrian
ADMIN_PASSWORD=zmien-na-mocne-haslo

# API key dla Station upload (prosta autoryzacja)
STATION_API_KEY=random-key-for-station
```

### 4. SQLite schema (models.py)

```python
import sqlite3
from pathlib import Path

SCHEMA = """
CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    event_date DATE,
    client_name TEXT,
    client_contact TEXT,
    event_type TEXT,  -- wedding, birthday, corporate, other
    overlay_id INTEGER,    -- FK to library_overlays
    music_id INTEGER,      -- FK to library_music
    text_top TEXT,         -- np. "Wesele Ania & Tomek"
    text_bottom TEXT,      -- np. "15.04.2026"
    access_key TEXT UNIQUE, -- dla gallery access
    is_active INTEGER DEFAULT 0,  -- only 1 active at a time
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS videos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id INTEGER NOT NULL,
    short_id TEXT UNIQUE NOT NULL,  -- 6-char base32
    original_filename TEXT,
    file_path TEXT NOT NULL,
    file_size INTEGER,
    duration_seconds REAL,
    metadata TEXT,  -- JSON: effects applied, etc.
    view_count INTEGER DEFAULT 0,
    download_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (event_id) REFERENCES events(id)
);

CREATE TABLE IF NOT EXISTS library_overlays (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    source TEXT,  -- 'upload' or 'ai_generated'
    ai_prompt TEXT,  -- if AI generated, store prompt
    tags TEXT,  -- JSON array
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS library_music (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    source TEXT,  -- 'mixkit', 'upload', 'custom'
    tags TEXT,  -- JSON: ['wedding', 'romantic']
    duration_seconds REAL,
    license_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS event_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    event_type TEXT,
    overlay_id INTEGER,
    music_id INTEGER,
    default_text_top TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_videos_event ON videos(event_id);
CREATE INDEX IF NOT EXISTS idx_videos_short_id ON videos(short_id);
CREATE INDEX IF NOT EXISTS idx_events_active ON events(is_active);
"""

def init_db(db_path):
    conn = sqlite3.connect(db_path)
    conn.executescript(SCHEMA)
    conn.commit()
    conn.close()

# Helper functions
def get_active_event():
    # Return currently active event (is_active=1)
    pass

def generate_short_id():
    # 6 znaków base32 (łatwe do odczytu, bez 0/O/l/1)
    import secrets, string
    alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
    return ''.join(secrets.choice(alphabet) for _ in range(6))
```

### 5. API Endpoints

**POST /api/upload** (wywołany przez Station po akceptacji):
```python
@app.route('/api/upload', methods=['POST'])
def upload_video():
    # Verify API key
    if request.headers.get('X-API-Key') != STATION_API_KEY:
        return jsonify({'error': 'Unauthorized'}), 401
    
    # Get active event
    event = get_active_event()
    if not event:
        return jsonify({'error': 'No active event'}), 400
    
    # Save file
    video = request.files['video']
    short_id = generate_short_id()  # Ensure unique
    
    ext = Path(video.filename).suffix or '.mp4'
    file_path = f"storage/videos/{event['id']}/{short_id}{ext}"
    Path(f"storage/videos/{event['id']}").mkdir(parents=True, exist_ok=True)
    video.save(file_path)
    
    # Insert into DB
    video_id = insert_video(
        event_id=event['id'],
        short_id=short_id,
        original_filename=video.filename,
        file_path=file_path,
        file_size=os.path.getsize(file_path),
    )
    
    return jsonify({
        'short_id': short_id,
        'public_url': f"{PUBLIC_BASE_URL}/v/{short_id}",
        'qr_code_url': f"{PUBLIC_BASE_URL}/qr/{short_id}.png",
    })
```

**GET /v/{short_id}** (strona odtwarzania dla gościa):
```python
@app.route('/v/<short_id>')
def watch_video(short_id):
    video = get_video_by_short_id(short_id)
    if not video:
        abort(404)
    
    increment_view_count(video['id'])
    event = get_event(video['event_id'])
    
    return render_template('public/watch.html',
        video=video,
        event=event,
    )
```

**GET /api/videos/{short_id}/stream** (streaming MP4):
```python
@app.route('/api/videos/<short_id>/stream')
def stream_video(short_id):
    video = get_video_by_short_id(short_id)
    return send_file(video['file_path'],
        mimetype='video/mp4',
        conditional=True,  # HTTP 206 range support
    )
```

**GET /api/videos/{short_id}/download**:
```python
@app.route('/api/videos/<short_id>/download')
def download_video(short_id):
    video = get_video_by_short_id(short_id)
    increment_download_count(video['id'])
    return send_file(video['file_path'],
        as_attachment=True,
        download_name=f"wesele_film_{short_id}.mp4",
    )
```

**GET /qr/{short_id}.png** (QR on-the-fly):
```python
@app.route('/qr/<short_id>.png')
def qr_code(short_id):
    url = f"{PUBLIC_BASE_URL}/v/{short_id}"
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_H,
        box_size=20,
        border=4,
    )
    qr.add_data(url)
    qr.make(fit=True)
    img = qr.make_image(fill_color='black', back_color='white')
    
    # Opcjonalnie: wstaw logo w środku (pil manipulation)
    
    buffer = io.BytesIO()
    img.save(buffer, format='PNG')
    buffer.seek(0)
    
    return send_file(buffer, mimetype='image/png')
```

### 6. Admin Panel

**Auth (`admin/auth.py`):**
Prosta sesja - login / logout. Na razie single user (Adrian).

**Login page:**
```
POST /admin/login
  body: username, password
  → session['admin'] = True
  → redirect /admin/
```

**Middleware:**
```python
def require_admin(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get('admin'):
            return redirect('/admin/login')
        return f(*args, **kwargs)
    return decorated
```

**Dashboard (`templates/admin/dashboard.html`):**
```html
<h1>Akces Booth Admin</h1>
<div class="grid grid-cols-3 gap-4">
  <div class="card">
    <h2>Aktywny Event</h2>
    <p>{{ active_event.name }}</p>
    <p>{{ active_event.video_count }} filmów</p>
  </div>
  <div class="card">
    <h2>Dzisiejsze statystyki</h2>
    <p>Video uploaded: {{ today_uploads }}</p>
    <p>Views: {{ today_views }}</p>
  </div>
  <div class="card">
    <h2>Quick Actions</h2>
    <a href="/admin/events/new">➕ Nowy event</a>
    <a href="/admin/library">📦 Biblioteka</a>
    <a href="/admin/ai-generator">🤖 AI Ramki</a>
  </div>
</div>
```

**Events list + edit:**
- Tabela eventów z checkboxem "aktywny"
- Tylko jeden event może być aktywny
- Edycja: przypisz ramkę, muzykę, tekst, szablon

**Biblioteka (library.html):**
```html
<div class="grid grid-cols-2 gap-8">
  <!-- Overlays -->
  <div>
    <h2>Ramki</h2>
    <button>+ Upload PNG</button>
    <button>🤖 Generuj AI</button>
    <div class="grid grid-cols-3 gap-2">
      {% for overlay in overlays %}
        <div class="card">
          <img src="{{ overlay.file_path }}" class="w-full h-32 object-contain">
          <p>{{ overlay.name }}</p>
          <small>Source: {{ overlay.source }}</small>
          <button>Użyj</button>
          <button>Usuń</button>
        </div>
      {% endfor %}
    </div>
  </div>
  
  <!-- Music -->
  <div>
    <h2>Muzyka</h2>
    <button>+ Upload MP3</button>
    <ul>
      {% for track in music %}
        <li>
          <button>▶</button>
          {{ track.name }}
          <small>{{ track.tags }}</small>
          <button>Usuń</button>
        </li>
      {% endfor %}
    </ul>
  </div>
</div>
```

### 7. AI Generator (kluczowy moduł!)

**Endpoint `/admin/ai-generator`:**

```python
@admin_bp.route('/ai-generator', methods=['GET', 'POST'])
@require_admin
def ai_generator():
    if request.method == 'GET':
        return render_template('admin/ai_generator.html')
    
    # POST - generuj ramki
    event_type = request.form['event_type']  # wedding, birthday, etc.
    style = request.form['style']  # classic, boho, modern
    theme = request.form['theme']  # tekst opisowy
    couple_or_name = request.form['names']  # "Ania & Tomek" lub "Firma XYZ"
    event_date = request.form['date']
    
    # Gemini generuje prompt dla Imagen 3
    gemini = genai.GenerativeModel('gemini-1.5-pro')
    prompt_response = gemini.generate_content(f"""
    Create a prompt for Imagen 3 to generate a photo booth video overlay frame.
    
    Event type: {event_type}
    Style: {style}
    Theme: {theme}
    Names/Brand: {couple_or_name}
    Date: {event_date}
    
    Requirements for the overlay:
    - Transparent PNG 1920x1080 landscape
    - Center area empty (where video will appear, ~60% of canvas)
    - Decorations on edges: corners, top/bottom borders
    - Elegant typography with names
    - Style matches {style} aesthetic
    - Suitable for professional photo booth rental
    
    Output ONLY the Imagen prompt, no explanation.
    """)
    
    imagen_prompt = prompt_response.text.strip()
    
    # Generuj 3 warianty
    imagen = genai.GenerativeModel('imagen-3.0-generate-001')
    variants = []
    
    for i in range(3):
        image_response = imagen.generate_content(
            imagen_prompt,
            generation_config={'number_of_images': 1},
        )
        
        # Zapisz PNG do storage
        image_data = image_response.candidates[0].content.parts[0].inline_data.data
        filename = f"ai_{uuid.uuid4().hex[:8]}.png"
        path = f"storage/overlays/{filename}"
        
        with open(path, 'wb') as f:
            f.write(image_data)
        
        variants.append({
            'id': insert_overlay(name=f"{couple_or_name} v{i+1}", path=path, source='ai_generated', prompt=imagen_prompt),
            'path': path,
        })
    
    return jsonify({'variants': variants})
```

**UWAGA:** Imagen 3 API może mieć inny interface - sprawdź dokumentację Google GenAI SDK w momencie pisania kodu. Jeśli nie działa, fallback: **generate_images()** z Vertex AI Python SDK.

**UI dla AI Generator:**
```html
<form method="POST">
  <label>Typ eventu:</label>
  <select name="event_type">
    <option value="wedding">Wesele</option>
    <option value="birthday">Urodziny</option>
    <option value="corporate">Firmowy</option>
  </select>
  
  <label>Styl:</label>
  <select name="style">
    <option value="classic">Klasyczny (biało-złoty)</option>
    <option value="boho">Boho (pastele)</option>
    <option value="rustic">Rustykalny</option>
    <option value="modern">Nowoczesny (minimalistyczny)</option>
  </select>
  
  <label>Motyw (opcjonalnie):</label>
  <input type="text" name="theme" placeholder="np. lawenda, polne kwiaty">
  
  <label>Imiona / Firma:</label>
  <input type="text" name="names" placeholder="Ania & Tomek">
  
  <label>Data:</label>
  <input type="date" name="date">
  
  <button type="submit">🤖 Wygeneruj 3 warianty</button>
</form>

<div id="results">
  <!-- 3 warianty po POST -->
</div>
```

### 8. Public Landing (`watch.html`)

```html
<!DOCTYPE html>
<html>
<head>
  <title>Twój film z fotobudki - {{ event.name }}</title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gradient-to-br from-purple-900 to-black text-white">
  <div class="max-w-2xl mx-auto p-4">
    <div class="text-center mb-4">
      <h1 class="text-3xl font-bold">🎉 Twój film jest gotowy!</h1>
      <p class="text-lg text-purple-200">{{ event.name }}</p>
    </div>
    
    <div class="bg-black rounded-lg overflow-hidden">
      <video controls autoplay loop class="w-full">
        <source src="/api/videos/{{ video.short_id }}/stream" type="video/mp4">
      </video>
    </div>
    
    <div class="mt-6 flex flex-col gap-3">
      <a href="/api/videos/{{ video.short_id }}/download"
         class="bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-4 rounded-lg text-center text-xl">
        ⬇ Pobierz film
      </a>
      
      <div class="grid grid-cols-3 gap-2">
        <button onclick="share('whatsapp')" class="bg-green-600 py-3 rounded">WhatsApp</button>
        <button onclick="share('instagram')" class="bg-pink-600 py-3 rounded">Instagram</button>
        <button onclick="share('facebook')" class="bg-blue-600 py-3 rounded">Facebook</button>
      </div>
    </div>
    
    <div class="mt-12 text-center border-t border-white/20 pt-6">
      <p class="text-purple-200">Podobała Ci się fotobudka?</p>
      <p class="font-bold text-xl mt-2">Zamów Akces 360 na swój event!</p>
      <a href="https://akces360.pl" class="bg-white text-black px-6 py-3 rounded-lg mt-3 inline-block">
        akces360.pl
      </a>
    </div>
  </div>
</body>
</html>
```

### 9. Deployment (scripts/setup.sh)

```bash
#!/bin/bash
# Initial setup na Raspberry Pi

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install deps
pip install -r requirements.txt

# Create directories
mkdir -p storage/videos storage/overlays storage/music db

# Initialize DB
python -c "from models import init_db; init_db('db/akces_booth.db')"

# Copy systemd service
sudo cp akces-booth.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable akces-booth
sudo systemctl start akces-booth

# Cloudflare tunnel (osobno, jeśli nie masz)
echo "Setup Cloudflare tunnel manually:"
echo "cloudflared tunnel create akces-booth"
echo "cloudflared tunnel route dns akces-booth booth.akces360.pl"
```

**akces-booth.service:**
```ini
[Unit]
Description=Akces Booth Flask API
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/akces-booth/backend
Environment="PATH=/home/pi/akces-booth/backend/venv/bin"
ExecStart=/home/pi/akces-booth/backend/venv/bin/gunicorn -w 4 -b 0.0.0.0:5100 --timeout 120 app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 10. Testing checklist

- [ ] `python app.py` uruchamia się lokalnie
- [ ] `curl http://localhost:5100/` zwraca landing page
- [ ] `curl -X POST http://localhost:5100/api/upload -H "X-API-Key: xxx" -F "video=@test.mp4"` działa
- [ ] Visit `/v/SHORTID` → widać video player
- [ ] `/qr/SHORTID.png` → QR code generuje się
- [ ] `/admin/login` → login działa
- [ ] `/admin/events/new` → tworzenie eventu
- [ ] `/admin/ai-generator` → GET pokazuje formularz, POST próbuje generować (nawet jeśli API fail)

**Commit:** "feat: sesja 5 - backend flask + admin panel"

**NIE rób w tej sesji:**
- ❌ Deployment na prawdziwy RPi (mogę poinstruować oddzielnie)
- ❌ Cloudflare tunnel (osobna sekcja)
- ❌ Stripe / płatności (Faza 3)

**Pytania przed rozpoczęciem?**

---END PROMPT---

---

# 🎬 SESJA 6: FFmpeg Post-Processing (Recorder)

**Cel:** Po nagraniu Recorder stosuje efekty: slow-mo, muzyka, ramka PNG, tekst.
**Czas:** 3h (najtrudniejsza sesja)

---BEGIN PROMPT---

Kontynuujemy **Akces Booth Recorder**. Mamy kamerę nagrywającą i WiFi do Station. Teraz dodajemy **FFmpeg post-processing** - slow-mo + muzyka + ramka + tekst.

**Kontekst:**
- Nagrywanie z Sesji 2 daje raw MP4 (1080p 120fps)
- Potrzebujemy zamienić to na gotowy film z efektami przed wysłaniem do Station
- OnePlus 13 ma Snapdragon 8 Elite - szybki, pipeline powinien iść <15s dla 8s video

**Cel SESJI 6:**
Pipeline FFmpeg który bierze raw → gotowy MP4 z efektami.

**Wymagania:**

### 1. Dependencies

```yaml
ffmpeg_kit_flutter_new: ^1.6.0
```

**⚠️ UWAGA:** Oryginalny `ffmpeg_kit_flutter` został porzucony przez autorów w 2025. Sprawdź w pub.dev aktualnie działający fork. Alternatywy:
- `ffmpeg_kit_flutter_new` (community fork)
- `ffmpeg_kit_flutter_min` (lightweight)
- `flutter_ffmpeg` (starszy)

**Jeśli żaden fork nie działa** → zaimplementuj natywnie przez platform channel + Android MediaCodec. Ale zacznij od prób z forkami.

### 2. Video Processor Service

`services/video_processor.dart`:

```dart
class VideoProcessor extends ChangeNotifier {
  double _progress = 0.0;
  String _currentStage = '';
  bool _isProcessing = false;
  
  Future<String> processVideo({
    required String inputPath,
    required ProcessingConfig config,
    void Function(double progress, String stage)? onProgress,
  }) async {
    _isProcessing = true;
    notifyListeners();
    
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.mp4';
    
    // Build complex filter chain
    final filterChain = _buildFilterChain(config);
    final audioMix = _buildAudioMix(config);
    
    // Execute FFmpeg
    final command = [
      '-i', inputPath,
      if (config.musicPath != null) '-i', config.musicPath!,
      if (config.overlayPath != null) '-i', config.overlayPath!,
      '-filter_complex', filterChain,
      '-map', '[vout]',
      '-map', audioMix,
      '-c:v', 'libx264',
      '-preset', 'fast',
      '-crf', '23',
      '-c:a', 'aac',
      '-b:a', '128k',
      '-y',
      outputPath,
    ];
    
    await FFmpegKit.executeWithArgumentsAsync(
      command,
      (session) async {
        // Completion
        final returnCode = await session.getReturnCode();
        _isProcessing = false;
        notifyListeners();
      },
      (log) {
        // Log output
        print('FFmpeg: ${log.getMessage()}');
      },
      (statistics) {
        // Progress
        final time = statistics.getTime();
        final duration = config.expectedDuration.inMilliseconds;
        final progress = (time / duration).clamp(0.0, 1.0);
        _progress = progress;
        onProgress?.call(progress, _currentStage);
        notifyListeners();
      },
    );
    
    return outputPath;
  }
  
  String _buildFilterChain(ProcessingConfig config) {
    final filters = <String>[];
    
    // Video manipulation
    String videoStream = '[0:v]';
    
    // Slow motion
    if (config.slowMoFactor > 1.0) {
      filters.add('${videoStream}setpts=${config.slowMoFactor}*PTS[slow]');
      videoStream = '[slow]';
    }
    
    // PNG overlay (ramka)
    if (config.overlayPath != null) {
      filters.add('${videoStream}[2:v]overlay=0:0[ov]');
      videoStream = '[ov]';
    }
    
    // Text overlay
    if (config.textTop != null || config.textBottom != null) {
      final drawtext = <String>[];
      if (config.textTop != null) {
        drawtext.add('drawtext=text=\'${_escapeText(config.textTop!)}\''
          ':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=40'
          ':box=1:boxcolor=black@0.5:boxborderw=10');
      }
      if (config.textBottom != null) {
        drawtext.add('drawtext=text=\'${_escapeText(config.textBottom!)}\''
          ':fontcolor=white:fontsize=36:x=(w-text_w)/2:y=h-80'
          ':box=1:boxcolor=black@0.5:boxborderw=10');
      }
      filters.add('${videoStream}${drawtext.join(",")}[vout]');
    } else {
      filters.add('${videoStream}copy[vout]');
    }
    
    return filters.join(';');
  }
  
  String _buildAudioMix(ProcessingConfig config) {
    if (config.musicPath == null) {
      // Slow down original audio to match video
      if (config.slowMoFactor > 1.0) {
        // atempo filter, cascade if > 2x
        return '[0:a]atempo=${1.0 / config.slowMoFactor}[aout]';
      }
      return '[0:a]';
    }
    
    // Mix original (ducked) + music
    return '[0:a]volume=0.2[a0];'
           '[1:a]volume=0.7[a1];'
           '[a0][a1]amix=inputs=2[aout]';
  }
  
  String _escapeText(String text) {
    // FFmpeg drawtext special chars
    return text
      .replaceAll('\\', '\\\\')
      .replaceAll(':', '\\:')
      .replaceAll("'", "\\'");
  }
}

class ProcessingConfig {
  final double slowMoFactor;          // 1.0 (none), 2.0, 4.0
  final String? musicPath;
  final String? overlayPath;
  final String? textTop;
  final String? textBottom;
  final Duration expectedDuration;
  
  ProcessingConfig({
    this.slowMoFactor = 1.0,
    this.musicPath,
    this.overlayPath,
    this.textTop,
    this.textBottom,
    required this.expectedDuration,
  });
}
```

### 3. Integration z flow

Po zatrzymaniu nagrywania (Sesja 2):

```dart
Future<void> _onRecordingStopped(String rawVideoPath) async {
  // Send processing_started to Station
  stationClient.sendProgress('recording_stopped', 1.0);
  
  // Get config from Station (event-specific)
  final config = await stationClient.requestConfig();
  
  // Process
  final outputPath = await videoProcessor.processVideo(
    inputPath: rawVideoPath,
    config: ProcessingConfig(
      slowMoFactor: config['slow_mo_factor'] ?? 2.0,
      musicPath: config['music_path'],
      overlayPath: config['overlay_path'],
      textTop: config['text_top'],
      textBottom: config['text_bottom'],
      expectedDuration: Duration(seconds: 16),  // 8s input * 2x slow-mo
    ),
    onProgress: (progress, stage) {
      stationClient.sendProgress('processing_progress', progress);
    },
  );
  
  // Clean up raw
  await File(rawVideoPath).delete();
  
  // Send to Station
  stationClient.sendProgress('transfer_started', 0.0);
  await stationClient.uploadVideo(outputPath);
  stationClient.sendProgress('transfer_done', 1.0);
  
  // Clean up processed
  await File(outputPath).delete();
}
```

### 4. Config sync Station → Recorder

Station ma config z eventu. Recorder potrzebuje go dostać przed processing.

**Dodaj endpoint w Station local server:**
```dart
// W StationServer
router.get('/config', (req) async {
  final event = await getActiveEvent();
  return Response.ok(jsonEncode({
    'slow_mo_factor': event.slowMoFactor,
    'overlay_path': event.overlayPath,
    'music_path': event.musicPath,
    'text_top': event.textTop,
    'text_bottom': event.textBottom,
  }));
});
```

**Ale czekaj - pliki overlay/music są na RPi, nie na Tab!**

**Rozwiązanie:**
- Station pobiera aktywny event z RPi (API /api/events/active)
- Station pre-fetchuje overlay.png i music.mp3 z RPi do cache Tab
- Recorder przy starcie eventu dostaje **lokalne ścieżki na Tab** (albo ściąga bezpośrednio)

**Uproszczenie dla MVP:**
- Station cachuje pliki w swoim storage
- Wysyła pliki do Recorder **jednorazowo** gdy aktywny event się zmienia
- Recorder cachuje je w /tmp i używa przy każdym nagraniu

**Implementacja - w LocalServer na Station:**
```dart
// Station dostaje event z RPi, pre-fetcha pliki
// Następnie sendsAssets do Recorder przez WebSocket
_channel.sink.add(jsonEncode({
  'type': 'event_config',
  'slow_mo_factor': 2.0,
  'overlay_url': 'http://192.168.1.45:8080/assets/overlay.png',
  'music_url': 'http://192.168.1.45:8080/assets/music.mp3',
  'text_top': 'Wesele Ania & Tomek',
  'text_bottom': '15.04.2026',
}));
```

Recorder ściąga pliki raz, cachuje, używa.

### 5. Testing

- [ ] Nagraj 5s video w Recorder
- [ ] Apka robi pipeline: slow-mo 2x + muzyka + overlay + tekst
- [ ] Wynikowy MP4 otwiera się i ma wszystkie efekty
- [ ] Progress bar w Station aktualizuje się real-time
- [ ] Po processing plik leci do Station

**Commit:** "feat: sesja 6 - ffmpeg post-processing"

**Jeśli FFmpeg kit nie działa na OnePlus 13:**
- STOP, napisz do Adriana
- Może trzeba natywny Android MediaCodec
- Nie tracimy 4h na debugowanie packagu - to pewnie ich bug

Zaczynaj.

---END PROMPT---

---

# 📦 SESJA 7: Station - Content Library + Event Sync

**Cel:** Station pobiera content (ramki/muzyka) z RPi i wyświetla aktywny event.
**Czas:** 2h

---BEGIN PROMPT---

**Kontekst:** Station ma UI + WiFi communication z Recorder + endpoint w backend do eventów. Teraz **synchronizujemy** - Station wie który event jest aktywny i ma dostęp do jego zasobów.

**Cel SESJI 7:**
Station pobiera aktywny event z RPi backend, cachuje pliki lokalnie, wysyła config do Recorder.

**Wymagania:**

### 1. Backend Client w Station

`services/backend_client.dart`:

```dart
class BackendClient {
  final String baseUrl;  // https://booth.akces360.pl
  final String apiKey;
  final _dio = Dio();
  
  Future<Event?> getActiveEvent() async {
    final response = await _dio.get(
      '$baseUrl/api/events/active',
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    if (response.statusCode == 200) {
      return Event.fromJson(response.data);
    }
    return null;
  }
  
  Future<String> downloadAsset(String url, String cacheKey) async {
    final dir = await getApplicationDocumentsDirectory();
    final cachePath = '${dir.path}/cache/$cacheKey';
    
    if (await File(cachePath).exists()) {
      return cachePath;  // Already cached
    }
    
    await Directory(dirname(cachePath)).create(recursive: true);
    await _dio.download(url, cachePath);
    return cachePath;
  }
  
  Future<UploadResult> uploadVideo(String localPath, int eventId) async {
    final formData = FormData.fromMap({
      'video': await MultipartFile.fromFile(localPath),
      'event_id': eventId,
    });
    
    final response = await _dio.post(
      '$baseUrl/api/upload',
      data: formData,
      options: Options(headers: {'X-API-Key': apiKey}),
      onSendProgress: (sent, total) {
        // Update AppStateMachine progress
        AppStateMachine.instance.onUploadProgress(sent / total);
      },
    );
    
    return UploadResult.fromJson(response.data);
  }
}
```

### 2. Event Manager

`services/event_manager.dart`:

```dart
class EventManager extends ChangeNotifier {
  Event? _activeEvent;
  String? _cachedOverlayPath;
  String? _cachedMusicPath;
  int _videoCount = 0;
  
  Event? get activeEvent => _activeEvent;
  int get videoCount => _videoCount;
  
  Future<void> syncWithBackend() async {
    final backend = BackendClient(...);
    final event = await backend.getActiveEvent();
    
    if (event == null) {
      _activeEvent = null;
      notifyListeners();
      return;
    }
    
    // Download overlay PNG (if changed)
    if (event.overlayUrl != null) {
      _cachedOverlayPath = await backend.downloadAsset(
        event.overlayUrl!,
        'overlay_${event.overlayId}.png',
      );
    }
    
    // Download music MP3
    if (event.musicUrl != null) {
      _cachedMusicPath = await backend.downloadAsset(
        event.musicUrl!,
        'music_${event.musicId}.mp3',
      );
    }
    
    _activeEvent = event;
    _videoCount = event.videoCount;
    notifyListeners();
    
    // Push config to Recorder
    _sendConfigToRecorder();
  }
  
  void _sendConfigToRecorder() {
    if (_activeEvent == null) return;
    
    StationServer.instance.sendToRecorder({
      'type': 'event_config',
      'slow_mo_factor': _activeEvent!.slowMoFactor,
      'overlay_path': _cachedOverlayPath,
      'music_path': _cachedMusicPath,
      'text_top': _activeEvent!.textTop,
      'text_bottom': _activeEvent!.textBottom,
    });
  }
  
  void onVideoUploaded() {
    _videoCount++;
    notifyListeners();  // Triggers "+1 film!" animation
  }
}
```

### 3. Aktualizacja IDLE Screen

Pokazujemy info o aktywnym evencie:

```dart
class IdleScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AppStateMachine, EventManager>(
      builder: (context, machine, eventMgr, _) {
        if (eventMgr.activeEvent == null) {
          return _NoActiveEventScreen();  // "Skonfiguruj event w admin panelu"
        }
        
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Subtle header z event name
                Text(eventMgr.activeEvent!.name),
                SizedBox(height: 40),
                
                // Big welcome
                Text('👋 Wejdź na platformę!'),
                SizedBox(height: 60),
                
                // BIG START button
                BigActionButton(
                  label: '▶ START NAGRANIA',
                  onPressed: machine.startRecording,
                ),
                SizedBox(height: 40),
                
                // Video counter (animated)
                AnimatedCounter(
                  value: eventMgr.videoCount,
                  suffix: 'filmów',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

### 4. Animated Counter

`widgets/animated_counter.dart`:

```dart
class AnimatedCounter extends StatefulWidget {
  final int value;
  final String suffix;
  
  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  int _lastValue = 0;
  late AnimationController _controller;
  late Animation<double> _scale;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.3)
      .chain(CurveTween(curve: Curves.elasticOut))
      .animate(_controller);
  }
  
  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value > _lastValue) {
      _controller.forward(from: 0).then((_) => _controller.reverse());
      _lastValue = widget.value;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, _) => Transform.scale(
        scale: _scale.value,
        child: Text(
          'Dziś: ${widget.value} ${widget.suffix}',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}
```

### 5. Po udanym uploadzie - "+1 film!"

W AppStateMachine po upload success:
```dart
void onUploadComplete(UploadResult result) {
  EventManager.instance.onVideoUploaded();  // Triggers counter animation
  
  // Move to QR display
  _moveTo(AppState.qrDisplay);
  _currentJob!.qrUrl = result.qrCodeUrl;
  _currentJob!.publicUrl = result.publicUrl;
}
```

### 6. QR Screen update

Pokazuje prawdziwy QR (zamiast mocku):

```dart
class QrDisplayScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final job = context.watch<AppStateMachine>().currentJob;
    if (job == null) return SizedBox();
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🎉 Twój film jest gotowy!', style: ...),
            SizedBox(height: 40),
            
            // QR z prawdziwym URL
            Container(
              padding: EdgeInsets.all(20),
              color: Colors.white,
              child: QrImageView(
                data: job.publicUrl,
                version: QrVersions.auto,
                size: 500,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
            SizedBox(height: 30),
            
            Text('📱 Otwórz aparat telefonu', style: ...),
            Text('i skieruj go na kod', style: ...),
            SizedBox(height: 10),
            Text(job.publicUrl.replaceFirst('https://', ''),
              style: TextStyle(color: Colors.white54),
            ),
            SizedBox(height: 40),
            
            // Countdown
            _CountdownTimer(
              duration: Duration(seconds: 60),
              onComplete: () => context.read<AppStateMachine>().moveToThankYou(),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 7. Auto-sync on startup

`main.dart` w Station:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Initial sync with backend
  await EventManager.instance.syncWithBackend();
  
  // Start local WiFi server for Recorder
  await StationServer.instance.start();
  
  runApp(AkcesBoothStation());
}

// Polling every 30s
Timer.periodic(Duration(seconds: 30), (_) {
  EventManager.instance.syncWithBackend();
});
```

### 8. Testing

- [ ] Admin panel: stwórz event, assign ramkę + muzykę
- [ ] Station: automatically syncs, pobiera overlay + music
- [ ] IDLE screen: pokazuje event name + video counter
- [ ] Start recording → motor + recording z właściwą konfiguracją
- [ ] Upload: po akceptacji plik leci na RPi
- [ ] QR: prawdziwy short_id z backend
- [ ] Po upload: counter animuje "+1 film!"
- [ ] Nowy event w admin panelu → Station auto-switch (30s polling)

**Commit:** "feat: sesja 7 - content library + event sync"

Zaczynaj.

---END PROMPT---

---

# ✨ SESJA 8: Integration Testing + Bug Fixes

**Cel:** End-to-end flow działa płynnie na prawdziwym sprzęcie.
**Czas:** 2-3h

---BEGIN PROMPT---

Wszystkie komponenty osobno działają. Teraz łączymy w całość i fix-ujemy bugi.

**Cel SESJI 8:**
End-to-end flow od startu nagrywania po QR display - bez crashów, płynnie.

**Wymagania:**

### Integration test scenarios

**Scenariusz A: Happy Path**
1. Oba urządzenia włączone, na tej samej sieci WiFi
2. Backend działa na RPi (booth.akces360.pl)
3. Aktywny event w admin panelu ("Test Event 2026")
4. Station pokazuje IDLE z "Test Event 2026" + "Dziś: 0 filmów"
5. Recorder pokazuje "Połączono ze Station ✅"
6. Klik START na Station
7. Silnik rusza, Recorder nagrywa 8s (z sync motorem)
8. Auto-stop, Recorder startuje FFmpeg
9. Station: PROCESSING → TRANSFER → PREVIEW z filmem
10. Gość klika AKCEPTUJ
11. Upload na RPi, QR się wyświetla
12. Skanowanie QR telefonem → otwiera się watch page z video
13. Pobranie filmu na telefonie
14. Station: QR → THANK_YOU (3s) → IDLE z "+1 film!"

**Scenariusz B: Edge cases**
- [ ] Bluetooth odłączony w trakcie - detection + user message
- [ ] WiFi padł w trakcie transferu - retry + fallback
- [ ] RPi offline - error handling
- [ ] Gość klika POWTÓRZ - cleanup i restart
- [ ] Station zrestartowana w trakcie - pending uploads queue
- [ ] Bateria telefonu spadła <15% - ostrzeżenie
- [ ] Pełny dysk - ostrzeżenie

**Debug toolkit:**
- Status panel dostępny przez long-press na logo Akces 360:
  - WiFi IP Station
  - Recorder IP
  - Ostatnie 20 log entries
  - Pending uploads count
  - BT connection status
  - Bateria obu urządzeń

**Wymagane fixes:**

1. **Timeout safety:**
   Każdy stan ma max timeout (np. PROCESSING max 30s, TRANSFER max 60s). Po timeout → error screen z opcją "Spróbuj ponownie".

2. **Reconnect resilience:**
   BT i WiFi auto-reconnect po rozłączeniu (exponential backoff: 1s, 2s, 5s, 10s, 30s).

3. **Error messages:**
   User-friendly, po polsku, z akcją do podjęcia:
   - "Brak połączenia z fotobudką" + [Sprawdź BT]
   - "Station niedostępna" + [Sprawdź WiFi]
   - "Serwer chwilowo niedostępny - film zapisany lokalnie"

4. **Graceful degradation:**
   Jeśli nie ma internetu → Station serwuje film **lokalnie** przez HTTP:
   ```
   QR URL: http://192.168.1.45:8080/local/AB3D5F
   ```
   Gość może pobrać film bezpośrednio z Tab. Gdy internet wraca, film synchronizuje się z RPi.

5. **Logging:**
   Wszystko logowane do `logs/booth_YYYY-MM-DD.log`. Rotacja co tydzień. Format:
   ```
   [2026-04-16 19:34:52] [INFO] [Recorder] Motor connected to YCKJNB-1234
   [2026-04-16 19:34:58] [DEBUG] [Station] Received video from Recorder (28MB)
   [2026-04-16 19:35:03] [WARN] [Station] Upload retry 1/3 for job XYZ
   ```

**Testing checklist:**
- [ ] 10 kolejnych nagrań bez restartu apki
- [ ] Przerwanie WiFi w różnych momentach
- [ ] Niska bateria test
- [ ] Brak aktywnego eventu test
- [ ] Pełny dysk test
- [ ] Różne event configs (short slow-mo / long slow-mo / bez muzyki / bez ramki)

**Commit:** "fix: sesja 8 - integration + bug fixes"

Jeśli znajdziesz coś niespodziewanego - zapisz jako TODO, nie naprawiaj wszystkiego naraz.

---END PROMPT---

---

# 🔐 SESJA 9: Settings + PIN + Nice-to-haves

**Cel:** Ekran Settings z PIN lockiem + "Dziękujemy" ekran + drobne polishing.
**Czas:** 2h

---BEGIN PROMPT---

Mamy działający end-to-end flow. Teraz dodajemy brakujące elementy UX z WORKFLOW.md.

**Cel SESJI 9:**
- Settings screen z 4-cyfrowym PIN
- ThankYou screen (już jest - dopieść)
- Instrukcja "otwórz aparat" na QR screen
- Facebook integration (zgoda na publikację)

**Wymagania:**

### 1. PIN-protected Settings

**Access:**
- Long press (3 sekundy) na logo Akces 360 w IDLE footer
- → Pokazuje keypad do wpisania PIN
- Po wpisaniu 4 cyfr → sprawdzenie → Settings lub "Błędny PIN"

**Storage:** SharedPreferences (hash SHA256, nie plain text)

**Initial setup:**
Przy pierwszym uruchomieniu apki: "Ustaw PIN dla Settings" (4 cyfry).

### 2. Settings Screen

Zgodnie z mockupem w WORKFLOW.md. Sekcje:
- **Bieżący event** (sync z backend)
- **Muzyka domyślna** (fallback gdy event nie ma)
- **Parametry nagrywania** (długość, slow-mo factor, kierunek, prędkość)
- **Połączenia** (BT, Recorder, Internet) + test button
- **Dzisiejsze statystyki** (liczba filmów, bateria Recorder, wolny dysk)
- **Zmień PIN**
- **Wyloguj** (usunięcie sesji)

### 3. Aktualizacja QR Screen

Dodaj animowaną instrukcję dla osób starszych:

```
┌─────────────────────────────────┐
│  1️⃣ Otwórz aparat w telefonie  │
│     [📷 animacja telefonu]       │
│                                  │
│  2️⃣ Skieruj go na kod          │
│     [📱 → 🔲 animacja]           │
│                                  │
│  3️⃣ Stuknij w link który wyskoczy│
│     [👆 animacja]                │
└─────────────────────────────────┘
```

Use case: starsi goście którzy nie wiedzą co to QR. Animacja lottie albo proste Flutter animations.

### 4. Facebook Integration (opt-in)

**W QR Screen dodaj checkbox:**
```
☐ Zgadzam się na publikację filmu na
  Facebook: @akces360
```

Jeśli zaznaczony:
- Backend oznacza video jako `publish_to_facebook=true`
- W admin panelu nowa sekcja "Do publikacji" gdzie Adrian widzi wszystkie oznaczone filmy
- **Publikacja manualna** (batch) - nie automatyczna (bezpieczniej, zatwierdzasz każdy)

### 5. Thank You Screen

Dopieścić zgodnie z WORKFLOW.md:
```
┌─────────────────────────────────┐
│                                  │
│        🎉 Dziękujemy!           │
│                                  │
│      Kolejny gość zapraszamy :)  │
│                                  │
│      [wielka grafika taniec]     │
│                                  │
│                                  │
└─────────────────────────────────┘
```

3 sekundy, płynne przejście do IDLE z fade.

### 6. Loading states polishing

Wszystkie "Przetwarzam..." "Wysyłam..." "Odbieram..." mają:
- Skeleton/shimmer effect jeśli progres nie jest natychmiastowy
- Progress bar z konkretnymi %
- Ikony/emoji zgodnie z WORKFLOW.md

### 7. Testing

- [ ] Pierwszy start apki → setup PIN
- [ ] Long press na logo → PIN keypad
- [ ] Zły PIN 3x → lockout na 30s (security)
- [ ] Dobry PIN → Settings
- [ ] Wszystkie sekcje Settings działają
- [ ] Test połączenia w Settings - poprawnie pokazuje status
- [ ] QR screen - animacja instrukcji odtwarza się
- [ ] Checkbox Facebook - zapisuje się do metadata video
- [ ] Thank you screen - 3s, płynny fade

**Commit:** "feat: sesja 9 - settings + PIN + polishing"

---END PROMPT---

---

# 🎬 SESJA 10: Real-world Testing + Deployment

**Cel:** Apka deployed na RPi, symulacja eventu w domu, bug fixes.
**Czas:** 2h + testowanie

---BEGIN PROMPT---

**Cel SESJI 10:**
Finalne deploymenty + test na prawdziwym sprzęcie + dokumentacja.

**Wymagania:**

### 1. Deployment backend na Raspberry Pi

```bash
# Na RPi:
cd /home/pi/
git clone <repo-url> akces-booth
cd akces-booth/backend

# Setup
./scripts/setup.sh

# Verify
sudo systemctl status akces-booth
curl http://localhost:5100/

# Cloudflare tunnel
cloudflared tunnel create akces-booth
cloudflared tunnel route dns akces-booth booth.akces360.pl
sudo cloudflared service install

# Verify
curl https://booth.akces360.pl/
```

### 2. Build APK z obu apek

```bash
# Recorder
cd recorder
flutter build apk --release
# Output: build/app/outputs/apk/release/app-release.apk
# Install na OnePlus 13: adb install app-release.apk

# Station
cd ../station
flutter build apk --release
# Install na Tab A11+
```

### 3. Symulacja eventu w domu

**Setup:**
- Tab A11+ na statywie (może być improwizowany)
- OnePlus 13 w dłoni (jeszcze nie na fotobudce jeśli nie masz)
- Lub: telefon jako proxy za fotobudkę - uda_j że kręci

**Test flow:**
1. Admin panel: stwórz event "Test - Urodziny domowe"
2. Upload ramki (prosty PNG z Canva) + muzyka (Mixkit download)
3. Przypisz do eventu + aktywuj
4. Na Station: widać event + counter 0
5. Na Recorder: połączone
6. Klik START → motor mock (tylko recording) lub real
7. Zakończ: PROCESSING → TRANSFER → PREVIEW → AKCEPTUJ → QR
8. Zeskanuj QR swoim telefonem
9. Pobierz film
10. Sprawdź czy ma wszystkie efekty (slow-mo, muzyka, ramka, tekst)

### 4. Performance metrics

Zmierz:
- [ ] Total time: START → QR display (target: <60s)
- [ ] FFmpeg processing (target: <15s dla 8s video)
- [ ] WiFi transfer (target: <10s dla 30MB)
- [ ] Upload do RPi (target: <15s)

Jeśli coś jest powyżej target → optymalizacja albo TODO.

### 5. Dokumentacja operatora

Napisz `docs/OPERATOR_GUIDE.md`:
- Setup przed eventem (krok po kroku)
- Checklist podczas eventu
- Troubleshooting (co zrobić gdy X)
- Jak dodać nowy event
- Jak wygenerować ramki AI

### 6. Known issues list

`docs/KNOWN_ISSUES.md`:
- Lista bugów znalezionych ale nie naprawionych (MVP scope)
- Priorytety na Fazę 2

### 7. Backup script

```bash
# Daily backup of RPi data
scripts/backup.sh:
  - DB dump → /backups/YYYY-MM-DD.sql
  - Storage archive → /backups/YYYY-MM-DD.tar.gz
  - Upload do external storage (e.g. GDrive)
```

### 8. Monitoring (light)

Opcjonalne - prosty health check:
```python
# Cron co 5 min:
curl -f https://booth.akces360.pl/api/health || alert-adrian
```

**Commit:** "chore: sesja 10 - deployment + docs"

---END PROMPT---

---

# 📝 USAGE TIPS

## Kolejność sesji
1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10

Nie przeskakuj. Każda sesja buduje na poprzednich.

## Git workflow
```bash
# Po każdej sesji:
git add .
git commit -m "feat: sesja X - opis"
git push

# Jeśli coś pójdzie źle:
git revert HEAD  # Rollback do poprzedniej sesji
```

## Claude Code best practices

1. **Nowa sesja = nowy context** - nie mieszaj 2-3 sesji w jednym chat
2. **Zacznij od `cd <folder>`** - upewnij się że Claude Code jest w odpowiednim projekcie
3. **Wklej pełny prompt** - od `---BEGIN PROMPT---` do `---END PROMPT---`
4. **Przed commit test** - zawsze `flutter run` / `python app.py` przed git commit
5. **Pytania jak się pojawią** - stop, pytaj mnie zamiast pozwalać Claude Code zgadywać

## Jeśli coś się psuje

**Claude Code zgaduje / robi głupoty:**
- STOP
- Powiedz mi co się dzieje
- Nowa sesja z czystym context
- Wklej TYLKO konkretny fragment do naprawy

**Flutter errors:**
- 99% problemów: restart IDE / `flutter clean` / `flutter pub get`
- `flutter doctor` → napraw co pokazuje

**Package incompatibilities:**
- `ffmpeg_kit_flutter` mogą być problemy
- Alternative forks albo platform channel

## Po zakończeniu MVP

**Faza 2 (feedback-driven):**
- Na podstawie walidacji SaaS dodajemy features
- Stripe integration
- Multi-tenant
- iOS (jeśli walidacja pokazała)

**Deadline:** 4 tygodnie = działający produkt gotowy do testowania na Akces 360 eventach.

---

# 💪 POWODZENIA!

Masz pełny, szczegółowy plan. 10 sesji, każda ~2-3h. Total ~25h pracy.

**Pamiętaj:**
- Recon BT **przed** Sesją 1 (patrz RECON.md)
- Tab A11+ zamówiony **przed** Sesją 3
- Backup RPi **przed** deployment Sesji 5

**Napisz jeśli utknąłeś.** Jestem tutaj. 🚀
