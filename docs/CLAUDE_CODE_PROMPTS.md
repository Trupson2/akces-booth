# Akces Booth - Claude Code Prompts

**Instrukcja:** Każdy prompt = osobna sesja Claude Code. Kopiuj cały blok między `---BEGIN PROMPT---` a `---END PROMPT---` i wklejaj do Claude Code w katalogu projektu.

**Założenie:** Pracujemy **bez dostępu do fotobudki**. Silnik BT jest zmockowany - udaje że działa. Resztę apki (kamera, efekty, upload, QR) rozwijamy normalnie. Gdy zrobisz recon BT, wymienimy tylko jedną klasę.

**Kolejność:** Sesje 1→7 idą sekwencyjnie. Nie przeskakuj.

---

## Przed pierwszą sesją - setup środowiska

**Na Twoim komputerze (jednorazowo):**

```bash
# 1. Zainstaluj Flutter SDK
# Pobierz z https://docs.flutter.dev/get-started/install/windows
# Rozpakuj np. do C:\flutter\
# Dodaj C:\flutter\bin do PATH

# 2. Sprawdź instalację:
flutter doctor

# 3. Zainstaluj Android Studio (dla SDK i emulatora)
# https://developer.android.com/studio

# 4. W Android Studio: SDK Manager → zainstaluj Android SDK Platform 34

# 5. Utwórz katalog projektu:
mkdir C:\projekty\akces-booth
cd C:\projekty\akces-booth

# 6. Uruchom Claude Code w tym katalogu:
claude-code

# 7. Sprawdź że masz telefon Android podpięty przez USB z włączonym USB Debugging
#    LUB uruchom emulator Android w Android Studio
adb devices
# Powinno pokazać urządzenie
```

---

# SESJA 1: Szkielet projektu + UI + mock motor control

**Cel:** Działający szkielet apki z UI do sterowania silnikiem. Silnik jest zmockowany - logi do konsoli zamiast prawdziwego BT. Możesz testować cały flow bez fotobudki.

**Czas:** 2-3h

---BEGIN PROMPT---

Jesteś seniorem Flutter developerem. Buduję aplikację **Akces Booth** - alternatywę dla ChackTok (ChinCom app do fotobudki 360 YCKJNB). Moja firma to Akces 360 - robimy photo booth rental w Polsce.

**Kontekst biznesowy:**
- Tablet Android (docelowo Samsung Galaxy Tab A9+) sterujący fotobudką 360 przez Bluetooth
- Funkcje: sterowanie silnikiem (start/stop/speed/direction), nagrywanie wideo, efekty (slow-mo, AI background removal), delivery przez QR
- Backend na Raspberry Pi 5 (już mam Flask stack - Akces Hub)
- Użytkownik: operator fotobudki na evencie

**Twoje zadanie - SESJA 1:**
Stwórz szkielet Flutter projektu z UI do sterowania silnikiem. **Silnik jest zmockowany** - prawdziwe BT zrobimy w sesji późniejszej gdy będę miał wyniki reverse engineering ChackTok. Teraz potrzebuję działającego UI które loguje komendy do konsoli, żebym mógł rozwijać resztę apki.

**Wymagania techniczne:**

1. **Inicjalizacja projektu:**
   - Utwórz projekt Flutter w katalogu `mobile/` (pod root repo)
   - Nazwa: `akces_booth`
   - Package: `pl.akces360.booth`
   - Target: Android, min SDK 24, target SDK 34
   - Orientacja: landscape (tablet horyzontalny)

2. **Struktura folderów:**
```
mobile/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   └── motor_control_screen.dart
│   ├── services/
│   │   ├── motor_controller.dart         # Abstract interface
│   │   └── mock_motor_controller.dart    # Mock implementation (this session)
│   ├── models/
│   │   └── motor_state.dart
│   ├── widgets/
│   │   ├── motor_control_panel.dart
│   │   └── big_button.dart
│   └── theme/
│       └── app_theme.dart
├── android/ (auto-generated)
└── pubspec.yaml
```

3. **Abstract Motor Controller** (`services/motor_controller.dart`):
   - Interface z metodami: `connect()`, `disconnect()`, `start()`, `stop()`, `setSpeed(int level)`, `reverseDirection()`, `speedUp()`, `speedDown()`
   - Stream/ChangeNotifier do observowania stanu silnika (connected/disconnected, running, speed, direction)
   - Property `isConnected`, `isRunning`, `currentSpeed` (1-10), `direction` (CW/CCW)

4. **Mock Motor Controller** (`services/mock_motor_controller.dart`):
   - Implementuje `MotorController`
   - Każda metoda drukuje do konsoli co by zrobiła (np. `print('[MOCK] START cmd - would send: [0xA5, 0x01, 0x00]')`)
   - Symuluje opóźnienie 100-300ms na połączenie
   - Utrzymuje state internally
   - Zawsze "connected" po `connect()` zwraca true

5. **UI - Motor Control Screen:**
   - **Landscape layout** zoptymalizowany pod tablet
   - Nowoczesny design - gradient background (ciemny, premium feel)
   - Duże przyciski (tablet, operator używa w stresie eventu):
     - START/STOP (największy, ~200x200px, toggle, zielony/czerwony)
     - SPEED UP / SPEED DOWN (pary)
     - REVERSE DIRECTION (toggle CW ↔ CCW, pokaz current direction)
   - **Wizualizacja stanu:**
     - Aktualna prędkość: duża liczba + wskaźnik (1-10)
     - Kierunek: ikona strzałki obrotowej
     - Status połączenia BT: zielona/czerwona kropka
     - "Running"/"Stopped" indicator
   - **Connect button** na górze ekranu - symuluje skanowanie i łączenie
   - **Debug log panel** na dole - wyświetla ostatnie 10 komend (z mock controllera)

6. **Home Screen:**
   - Prosty ekran powitalny z logo "Akces Booth"
   - Przycisk "Rozpocznij sesję" → Motor Control Screen
   - Później dodamy więcej opcji (event management, settings)

7. **Theme:**
   - Primary color: #6366F1 (indygo, premium)
   - Dark mode default
   - Material 3
   - Custom font (użyj Google Fonts - Inter)

8. **Dependencies** (dodaj do pubspec.yaml):
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.0          # State management
  google_fonts: ^6.2.0
  # BT będą w sesji 2, nie dodawaj teraz
```

9. **State management:**
   - Użyj `Provider` + `ChangeNotifier` (prostsze niż Riverpod dla tej skali)
   - `MotorController` extends `ChangeNotifier`
   - `MotorControlScreen` słucha zmian i rebuilduje UI

10. **Czyszczenie:**
    - Usuń domyślny kod demo (MyHomePage, counter itd.)
    - `main.dart` ma tylko runApp, reszta w `app.dart`

11. **Uruchomienie:**
    - Skonfiguruj Android manifest pod landscape only
    - Dodaj icon placeholder
    - Na końcu uruchom `flutter run` i sprawdź że działa na podłączonym urządzeniu LUB emulatorze

**Ważne:**
- NIE dodawaj jeszcze bibliotek BT (flutter_blue_plus itp.) - będą w Sesji 2
- NIE twórz jeszcze kamery, FFmpeg, upload - tylko sterowanie silnikiem mocked
- Pisz CZYSTY kod, komentarze w języku polskim tylko gdzie coś wyjątkowego
- Używaj late final, const gdzie można
- Jeśli którykolwiek krok się nie udaje, PRZERWIJ i zapytaj mnie zamiast zgadywać

**Testing requirement:**
Na końcu sesji pokażesz mi:
1. Że apka się kompiluje i uruchamia (`flutter run` bez błędów)
2. Screenshot/opis UI
3. Że klikanie przycisków drukuje do konsoli mock komendy
4. `git init` + pierwszy commit "feat: sesja 1 - szkielet + mock motor control"

Zaczynaj. Jeśli masz pytania - zadaj przed rozpoczęciem.

---END PROMPT---

---

# SESJA 2: Kamera + nagrywanie wideo

**Cel:** Apka nagrywa wideo z kamery tablet, zapisuje lokalnie. Tryby: normalny, slow-mo, super slow-mo.

**Czas:** 2-3h

---BEGIN PROMPT---

Kontynuujemy projekt **Akces Booth** (Flutter app na tablet Android do fotobudki 360). W Sesji 1 zrobiliśmy szkielet + mock motor control. Teraz dodajemy **nagrywanie wideo**.

**Cel SESJI 2:**
Dodać funkcjonalność nagrywania wideo z kamery tabletu. Tryby: Normal (30fps), Slow-mo (120fps jeśli dostępne), Super Slow-mo (240fps jeśli dostępne). Fallback graceful jeśli urządzenie nie wspiera.

**Wymagania:**

1. **Dodaj dependencies do pubspec.yaml:**
```yaml
camera: ^0.11.0
path_provider: ^2.1.0
permission_handler: ^11.3.0
video_player: ^2.9.0      # Do preview nagranego wideo
```

2. **Uprawnienia Android:**
   - Zaktualizuj `android/app/src/main/AndroidManifest.xml`:
     - `CAMERA`
     - `RECORD_AUDIO`
     - `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` (Scoped Storage dla API 33+)
   - Dodaj `android:requestLegacyExternalStorage="true"` jeśli potrzebne
   - Min SDK sprawdź czy nie trzeba podbić do 26

3. **Nowy service `services/camera_service.dart`:**
   - Klasa `CameraService extends ChangeNotifier`
   - Metody:
     - `Future<void> initialize()` - lista kamer, wybór tylnej, init controller
     - `Future<List<int>> getSupportedFps()` - zwraca listę wspieranych fps
     - `Future<void> startRecording({required RecordingMode mode})` 
     - `Future<String> stopRecording()` - zwraca ścieżkę do pliku MP4
     - `Future<void> dispose()`
   - Enum `RecordingMode { normal, slowMo120, superSlowMo240 }`
   - State: `isInitialized`, `isRecording`, `currentMode`, `recordingDuration` (stream/timer)

4. **Detekcja wsparcia fps:**
   - Użyj `CameraController` z `ResolutionPreset.high` 
   - Dla slow-mo spróbuj `ImageFormatGroup.yuv420` + sprawdź `CameraValue`
   - **UWAGA:** Flutter `camera` package natywnie nie wspiera wysokich fps dobrze - może być potrzebny platform channel do natywnego Android API2. **Na razie zaimplementuj normalnie, 30/60fps. Slow-mo oznacz jako "coming soon" w UI.**
   - Jeśli trafisz na problem z fps - zrób normalne nagrywanie + dokumentację że slow-mo trzeba dodać przez natywny kod (do zrobienia w Sesji 3 razem z FFmpeg)

5. **Nowy screen `screens/recording_screen.dart`:**
   - Pełnoekranowy preview kamery
   - Overlay z kontrolkami:
     - **Mode selector** (chips/segmented): Normal | Slow-mo | Super Slow-mo (z oznaczeniem wspieranych)
     - **Record button** (duży, 100x100, pulsujący gdy recording)
     - **Timer** - wyświetla czas nagrywania (np. "0:05")
     - **Preview ostatniego nagrania** (mały thumbnail w rogu)
   - **Auto-stop:** maksymalny czas nagrywania 15 sekund (realistic dla 360 spin)
   - **Integration z motor:** 
     - Gdy użytkownik klika RECORD → automatycznie startuje mock motor + recording
     - Gdy STOP → zatrzymuje motor + recording
     - UI pokazuje oba statusy razem

6. **Nowy screen `screens/preview_screen.dart`:**
   - Pokazuje ostatnie nagranie
   - Video player (`video_player` package)
   - Przyciski: "Użyj tego filmu" (placeholder na Sesję 3), "Nagraj ponownie" (powrót)
   - Wyświetla metadata: długość, rozmiar pliku, rozdzielczość, fps

7. **Zapis plików:**
   - Użyj `path_provider` → `getApplicationDocumentsDirectory()`
   - Struktura: `{app_docs}/recordings/raw_{timestamp}.mp4`
   - Lista plików w memory (później będzie SQLite)

8. **Navigation flow:**
   ```
   HomeScreen 
     → MotorControlScreen (jeśli chcesz tylko sterować)
     → RecordingScreen (pełny flow: motor + recording)
       → PreviewScreen (po zakończeniu nagrania)
         → powrót do RecordingScreen (kolejne nagranie)
   ```

9. **Permissions flow:**
   - Przy pierwszym uruchomieniu RecordingScreen → pytaj o uprawnienia
   - Jeśli user odmówi → pokaż komunikat z przyciskiem do ustawień aplikacji
   - Użyj `permission_handler` package

10. **Testing scenarios:**
    - Nagraj 5 sekund w trybie Normal → sprawdź czy plik jest zapisany
    - Sprawdź czy motor state zmienia się razem z recording (mock logs)
    - Preview odtwarza nagranie
    - Po zamknięciu apki i ponownym otwarciu - preview jest available (plik na dysku)

**Nie rób:**
- Efektów post-processing (FFmpeg) - to Sesja 3
- Upload do serwera - to Sesja 5
- QR - to Sesja 6

**Na końcu:**
- `flutter run` działa bez crashy
- Nagrywanie działa (przynajmniej Normal mode)
- Preview odtwarza nagrany plik
- Commit "feat: sesja 2 - camera + recording"

Jeśli natrafisz na problem z high-fps recording - NIE próbuj go rozwiązać sam. Zostaw TODO i przejdź dalej - załatwię to w Sesji 3 ze slow-mo w FFmpeg.

Zaczynaj. Pytania najpierw jeśli coś niejasne.

---END PROMPT---

---

# SESJA 3: FFmpeg post-processing (slow-mo, muzyka, overlay)

**Cel:** Obróbka nagranego wideo - slow-mo, dodanie muzyki, logo overlay. Pipeline raw → ready video.

**Czas:** 3-4h (to jest gruba sesja)

---BEGIN PROMPT---

Kontynuujemy **Akces Booth** (Flutter tablet app). Sesje 1-2 done: mamy szkielet, mock motor, recording. Teraz **FFmpeg post-processing**.

**Cel SESJI 3:**
Zbudować pipeline który bierze raw wideo z nagrywania → stosuje efekty (slow-mo, muzyka, logo) → zapisuje gotowy MP4. Pipeline ma być konfigurowalny - użytkownik wybiera presety.

**Wymagania:**

1. **Dependencies:**
```yaml
ffmpeg_kit_flutter_new: ^1.6.0   # Aktualny fork ffmpeg_kit (oryginał porzucony)
# NOTE: Jeśli paczka jest niedostępna, użyj 'ffmpeg_kit_flutter_min' lub innego działającego forka
# Sprawdź https://pub.dev aktualną sytuację, wybierz najbardziej utrzymywany fork
```

**UWAGA:** Oryginalny `ffmpeg_kit_flutter` został porzucony w 2025. Znajdź aktualnie działający fork. Jeśli masz problem - zaproponuj alternatywę (natywne Android MediaCodec + platform channel, lub fork).

2. **Preset assets:**
   Stwórz folder `mobile/assets/music/` i dodaj 3 placeholder pliki (empty MP3, zastąpię je prawdziwymi później):
   - `energetic.mp3` 
   - `chill.mp3`
   - `wedding.mp3`
   
   Stwórz folder `mobile/assets/overlays/` z placeholder PNG (1920x1080 transparent):
   - `logo_akces360.png` (w rogu)
   - `watermark_bottom.png` (dolny pas)

   Dodaj do `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/music/
       - assets/overlays/
   ```

3. **Service `services/video_processor.dart`:**
   
   Klasa `VideoProcessor extends ChangeNotifier` z metodami:
   
   ```dart
   Future<String> processVideo({
     required String inputPath,
     required ProcessingPreset preset,
     void Function(double progress)? onProgress,
   });
   ```
   
   Gdzie `ProcessingPreset` to:
   ```dart
   class ProcessingPreset {
     final SlowMoMode slowMo;       // none, x2, x4
     final String? musicAsset;       // path do muzyki lub null
     final double musicVolume;       // 0.0-1.0
     final bool boomerang;           // czy robić boomerang (forward + reverse)
     final String? overlayAsset;     // path do PNG overlay lub null
     final String? customText;       // np. "Wesele Ani i Tomka 15.04.2026"
     final Duration? trimStart;      // opcjonalny trim
     final Duration? trimEnd;
   }
   ```

4. **FFmpeg commands:**
   
   Stwórz buildery komend dla każdego efektu:
   
   **Slow-mo (2x):**
   ```
   ffmpeg -i input.mp4 -filter_complex "[0:v]setpts=2.0*PTS[v];[0:a]atempo=0.5[a]" -map "[v]" -map "[a]" output.mp4
   ```
   
   **Slow-mo (4x):**
   ```
   setpts=4.0*PTS, atempo=0.5 (cascade 2x - atempo max 0.5 per filter)
   ```
   
   **Boomerang:**
   ```
   ffmpeg -i input.mp4 -filter_complex "[0:v]reverse[r];[0:v][r]concat=n=2:v=1[v]" -map "[v]" -an output.mp4
   ```
   
   **Dodanie muzyki z ducking oryginalnego audio:**
   ```
   ffmpeg -i input.mp4 -i music.mp3 -filter_complex "[0:a]volume=0.3[a0];[1:a]volume=0.7[a1];[a0][a1]amix=inputs=2[aout]" -map 0:v -map "[aout]" output.mp4
   ```
   
   **PNG overlay w rogu:**
   ```
   ffmpeg -i input.mp4 -i logo.png -filter_complex "[0:v][1:v]overlay=W-w-20:20" output.mp4
   ```
   
   **Tekst overlay:**
   ```
   ffmpeg -i input.mp4 -vf "drawtext=text='Wesele Ani i Tomka':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=h-80:box=1:boxcolor=black@0.5:boxborderw=10" output.mp4
   ```
   
   **Pipeline z wieloma efektami:**
   Łącz filtry w jeden complex filter żeby zredukować encoding/decoding (jedna operacja zamiast kilku).

5. **Progress tracking:**
   - FFmpeg kit emituje statistics callbacks (bieżący timestamp)
   - Oblicz progress: `current_ms / total_ms`
   - Wywołuj `onProgress` callback
   - W UI pokaż ProgressBar

6. **Presety (ready-made):**
   Stwórz klasę `ProcessingPresets` z predefiniowanymi:
   - `ProcessingPresets.weddingSlowMo` - 2x slow-mo + wedding.mp3 + logo + "Wesele"
   - `ProcessingPresets.partyEnergetic` - normal speed + energetic.mp3 + logo
   - `ProcessingPresets.boomerangClassic` - boomerang + chill.mp3 + logo
   - `ProcessingPresets.custom` - user defines

7. **Nowy screen `screens/edit_screen.dart`:**
   
   Po nagraniu (z preview_screen) → użytkownik klika "Edytuj" → EditScreen:
   - Podgląd wideo
   - Sekcja "Presety" - 3-4 chip buttons z predefiniowanymi
   - Sekcja "Zaawansowane" (collapsible):
     - Slow-mo: radio buttons (Off, 2x, 4x)
     - Boomerang: toggle
     - Muzyka: dropdown + volume slider
     - Overlay: dropdown + custom text input
   - Przycisk "Przetwórz" → uruchamia VideoProcessor
   - Modal z progress bar podczas przetwarzania
   - Po zakończeniu → nowy screen `ResultScreen` z gotowym wideo

8. **Nowy screen `screens/result_screen.dart`:**
   - Odtwarza gotowe wideo
   - Metadata: rozmiar pliku, długość, zastosowane efekty
   - Przyciski: 
     - "Wyślij do gościa" (placeholder - Sesja 5/6)
     - "Zapisz do galerii"
     - "Nagraj nowe"

9. **File management:**
   - Raw: `{docs}/recordings/raw_{timestamp}.mp4`
   - Processed: `{docs}/recordings/processed_{timestamp}.mp4`
   - Cleanup: usuwaj raw po successful processing (opcjonalne - daj setting)

10. **Error handling:**
    - FFmpeg może zwalić się na różne sposoby (no disk space, codec issues)
    - Pokazuj user-friendly error messages
    - Loguj pełny FFmpeg log do pliku diagnostic (do debugowania później)

11. **Performance considerations:**
    - Tablety mobilne mają ograniczoną moc. Test na 10s wideo, 1080p:
      - Slow-mo 2x bez efektów: ~15-30s przetwarzania
      - Slow-mo 4x + muzyka + overlay: ~30-60s
    - Pokazuj realistic ETA na UI

**Testing scenarios:**
- Nagraj 5s normalne wideo
- Zastosuj preset "Wedding slow-mo"
- Po ~15s masz gotowy MP4 z slow-mo, muzyką i logo
- Odtwórz rezultat - wszystko działa

**Na końcu:**
- Wszystkie 3 efekty (slow-mo, muzyka, overlay) działają niezależnie
- Preset "wedding" produkuje sensowny output
- `flutter run` działa, brak crashy
- Commit "feat: sesja 3 - ffmpeg post-processing"

**Jeśli utkniesz:**
- Na issue z ffmpeg_kit fork - powiedz mi, zdecyduję
- Na performance - zostaw placeholder i idź dalej
- Na Android manifest permissions - fix and continue

Zaczynaj.

---END PROMPT---

---

# SESJA 4: AI Effects (background removal + face detection)

**Cel:** On-device AI efekty bez cloud (RODO + szybkość).

**Czas:** 2-3h

---BEGIN PROMPT---

Kontynuujemy **Akces Booth**. Sesje 1-3 done: szkielet, mock motor, recording, FFmpeg post-processing. Teraz **AI effects on-device**.

**Cel SESJI 4:**
Dodać 2 efekty AI wykonywane lokalnie na tablecie (bez cloud):
1. **Background Removal** - zastąp tło innym kolorem/obrazem
2. **Face Detection + Effect Overlay** - nakładki na twarze (korona, okulary itp.)

**Dlaczego on-device:**
- RODO compliance (dane gości nie opuszczają urządzenia)
- Szybkość (brak upload do API)
- Brak zależności od internetu

**Wymagania:**

1. **Biblioteka - Google MediaPipe:**

   Google MediaPipe to najlepsze rozwiązanie AI on-device. Ma Flutter plugin i działa offline.

   ```yaml
   dependencies:
     google_mlkit_face_detection: ^0.11.0   # Face detection (ML Kit)
     # Dla background removal potrzebujemy MediaPipe Selfie Segmentation
     # Nie ma oficjalnego Flutter plugin, ale są alternatywy:
     # Opcja A: image_segmentation_plus (community)
     # Opcja B: Platform channel do natywnego MediaPipe SDK (lepsze ale trudniejsze)
     # Opcja C: Użyj TensorFlow Lite + model Selfie Segmentation
     tflite_flutter: ^0.11.0  # Dla custom segmentation
     google_mlkit_selfie_segmentation: ^0.10.0  # Jeśli dostępny
     image: ^4.0.0  # Do manipulacji pikselami
   ```

   **Znajdź najlepszą dostępną paczkę** - rynek Flutter AI się zmienia. Jeśli `google_mlkit_selfie_segmentation` działa - użyj go. Jeśli nie - TFLite + model.

2. **Service `services/ai_effects.dart`:**

   ```dart
   class AIEffects extends ChangeNotifier {
     Future<void> initialize();   // Load models
     
     // Background removal - frame by frame
     Future<File> removeBackground({
       required String videoPath,
       required BackgroundReplacement replacement,
       void Function(double)? onProgress,
     });
     
     // Face effects - overlay on detected faces
     Future<File> applyFaceEffect({
       required String videoPath,
       required FaceEffect effect,
       void Function(double)? onProgress,
     });
   }
   
   enum BackgroundReplacement {
     solidBlack, solidWhite, blur, customImage
   }
   
   enum FaceEffect {
     crown, sunglasses, partyHat, devilHorns
   }
   ```

3. **Workflow (background removal):**
   
   MediaPipe Selfie Segmentation nie processuje całego wideo - tylko pojedyncze frames. Więc pipeline:
   
   ```
   1. FFmpeg: video → extract frames (PNG) do temp folder
   2. Dla każdego frame:
      a. MediaPipe: segmentation → mask (alpha channel)
      b. Apply mask: foreground + new background
      c. Zapisz output frame
   3. FFmpeg: compose frames back to video (z oryginalnym audio)
   ```

4. **Workflow (face effects):**

   Podobnie, ale:
   ```
   1. Extract frames
   2. Dla każdego:
      a. ML Kit Face Detection → pozycja twarzy (x, y, width, height)
      b. Nałóż PNG overlay (np. korona) na odpowiednie koordynaty
      c. Zapisz
   3. Compose back
   ```

5. **Asset PNG:**
   Stwórz folder `mobile/assets/face_effects/` z placeholder PNG:
   - `crown.png` - korona (pozycjonuj na czole)
   - `sunglasses.png` - okulary (pozycjonuj na oczach)
   - `party_hat.png` - czapka imprezowa
   - `devil_horns.png` - rogi

   (Placeholder = transparent PNG 200x200, zastąpię prawdziwymi później)

   Dodaj do pubspec.yaml assets.

6. **Face landmark detection:**
   ML Kit Face Detection zwraca landmarks (oczy, nos, usta). Użyj ich do precyzyjnego pozycjonowania:
   - Korona: nad `FaceLandmarkType.leftEye` i `rightEye`, offset up
   - Okulary: między oczami, skala = odległość oczu
   - Czapka: na górze bounding box twarzy
   - Rogi: po bokach czoła

7. **Integration z EditScreen:**
   
   W `screens/edit_screen.dart` z Sesji 3 dodaj nową sekcję "AI Effects":
   - Radio buttons: "Brak" | "Usuń tło" | "Efekty twarzy"
   - Jeśli "Usuń tło" → subselect: kolor/rozmycie/zdjęcie
   - Jeśli "Efekty twarzy" → subselect: korona/okulary/czapka/rogi
   - Toggle: AI effects dodają 30-120s do processing time - ostrzeżenie w UI

8. **Performance:**
   - AI jest WOLNE na mobile. 10s wideo może zająć 2-5 minut.
   - MUST HAVE: ProgressBar z ETA
   - NICE: Option do "low quality fast" (co 2-gi frame) vs "high quality slow" (każdy frame)
   - Jeśli proces trwa > 3 min → pozwól user anulować

9. **Error handling:**
   - Modele ML mogą się nie załadować (za mało RAM, starszy telefon)
   - Graceful fallback: "AI niedostępne na tym urządzeniu, użyj innych efektów"

10. **Memory management:**
    - Frames extraction może zająć sporo miejsca (10s @ 30fps = 300 PNG, kilka GB)
    - Używaj temp folder
    - Usuwaj po zakończeniu

**Testing scenarios:**
- Nagraj 3-5s wideo z osobą (Ty na tle mieszkania)
- Zastosuj "Background removal → solid black"
- Rezultat: Ty na czarnym tle
- Ponów: "Face effect → sunglasses"
- Rezultat: okulary na Twojej twarzy przez całe wideo

**Uwaga o realistyczności:**
To jest hardest sesja. Jeśli napotkasz BLOCKING issue (MediaPipe nie działa, TFLite nie laduje model) - zostaw TODO, wyłącz feature w UI ("Coming soon"), idź dalej. Nie przepalaj czasu - lepiej mieć apkę bez AI ale z resztą działającą, niż utknąć tutaj.

**Na końcu:**
- Minimum jeden z dwóch efektów AI działa na test video
- Progress bar pokazuje postęp
- Commit "feat: sesja 4 - AI effects"

Zaczynaj. Pytania najpierw.

---END PROMPT---

---

# SESJA 5: Backend Flask na Raspberry Pi

**Cel:** API do uploadu filmów i serwowania przez QR links. Integracja z istniejącą infrastrukturą Akces Hub.

**Czas:** 2-3h

**UWAGA:** Ta sesja to osobny projekt, nie Flutter. Pracujesz na Raspberry Pi albo lokalnie i deployujesz. Odpal Claude Code w osobnym katalogu `backend/`.

---BEGIN PROMPT---

Kontekst: Piszę aplikację **Akces Booth** - alternatywę dla ChackTok (apka do fotobudki 360). Mam działający Flutter frontend (Sesje 1-4), teraz potrzebuję **backend na moim Raspberry Pi 5** do uploadowania filmów i serwowania przez QR.

**Moja infrastruktura:**
- Raspberry Pi 5 (8GB RAM, NVMe SSD 500GB) - chodzi 24/7
- Debian-based Linux, Python 3.11
- Mam już inny Flask app "Akces Hub" na porcie 5000
- Ngrok tunneling aktywny
- Cloudflare Tunnel dostępny (chcę użyć dla Akces Booth - stabilniejsze niż ngrok)
- Docelowa domena: `booth.akces360.pl` (subdomena firmowa)

**Cel SESJI 5:**
Zbudować Flask API które:
1. Przyjmuje upload MP4 z apki Flutter
2. Zapisuje pliki na RPi (osobna struktura od Akces Hub)
3. Generuje short URLs (6 znaków base32) dla QR codes
4. Serwuje wideo pod URL-ami (streaming, nie download całego pliku)
5. Galeria HTML dla klienta (organizatora eventu)

**Wymagania:**

1. **Struktura projektu:**
```
backend/
├── app.py                    # Główny entry point
├── config.py                 # Config (DB path, storage path, secrets)
├── models.py                 # SQLite schema
├── api/
│   ├── __init__.py
│   ├── upload.py            # POST /api/upload
│   ├── events.py            # CRUD eventów
│   ├── videos.py            # GET /api/videos/{id}
│   └── share.py             # GET /v/{short_id}, /gallery/{event_id}
├── templates/
│   ├── base.html            # Layout z brandingiem Akces 360
│   ├── watch.html           # Strona odtwarzania (QR link)
│   ├── gallery.html         # Galeria eventu
│   └── landing.html         # Landing z QR widget "zamów fotobudkę"
├── static/
│   ├── css/
│   │   └── style.css        # Nowoczesny CSS (TailwindCSS CDN OK)
│   ├── js/
│   │   └── watch.js         # Video player logic
│   └── img/
│       └── logo.png         # Logo Akces 360 (placeholder)
├── storage/
│   └── videos/
│       └── {event_id}/      # MP4 files tutaj
├── db/
│   └── akces_booth.db       # SQLite (osobna od Akces Hub)
├── scripts/
│   ├── setup.sh             # Initial setup na RPi
│   └── backup.sh            # Backup bazy i plików
├── requirements.txt
└── akces-booth.service      # Systemd service file
```

2. **Dependencies (`requirements.txt`):**
```
Flask==3.0.0
Flask-CORS==4.0.0
python-dotenv==1.0.0
qrcode==7.4.2
Pillow==10.2.0
gunicorn==21.2.0
```

3. **SQLite schema (`models.py`):**

```python
# Tables:
# - events (id, name, date, client_name, logo_path, created_at, is_active)
# - videos (id, event_id, short_id, original_filename, file_path, file_size, duration, created_at, view_count, download_count)
# - upload_sessions (id, event_id, device_id, created_at) - track uploads

# Użyj sqlite3 moduł (bez SQLAlchemy - tak jak w Akces Hub)
# Init function do tworzenia tabel jeśli nie istnieją
```

4. **Config (`config.py`):**

```python
# Load from .env:
# - SECRET_KEY
# - STORAGE_PATH (default: ./storage/videos)
# - DB_PATH (default: ./db/akces_booth.db)
# - MAX_UPLOAD_SIZE (default: 500MB)
# - PORT (default: 5100 - żeby nie kolidowało z Akces Hub na 5000)
# - PUBLIC_BASE_URL (np. https://booth.akces360.pl)
```

5. **Endpoints:**

**POST `/api/upload`**
- Multipart form: `video` (file), `event_id` (int), `device_id` (string), `metadata` (JSON string - slow_mo, effects applied, itp.)
- Validate: plik to MP4, rozmiar < MAX
- Generuj `short_id` (6 znaków base32, unique - sprawdź w bazie)
- Zapisz plik: `{STORAGE_PATH}/{event_id}/{short_id}.mp4`
- Insert do bazy
- Zwróć JSON: `{"short_id": "AB3D5F", "url": "https://booth.akces360.pl/v/AB3D5F", "qr_code_url": "https://booth.akces360.pl/qr/AB3D5F.png"}`

**GET `/v/{short_id}`**
- Render `templates/watch.html` z danymi wideo
- Strona ma: video player, download button, social share buttons, link "zamów fotobudkę Akces 360"
- Incrementuj `view_count`
- Mobile-optimized (większość osób na telefonach)

**GET `/api/videos/{short_id}/stream`**
- Stream MP4 z range requests (HTTP 206) - do video playera
- Content-Type: video/mp4
- Accept-Ranges: bytes

**GET `/api/videos/{short_id}/download`**
- Direct download (Content-Disposition: attachment)
- Inkrementuj `download_count`

**GET `/qr/{short_id}.png`**
- Wygeneruj QR code PNG on-the-fly (lub z cache)
- QR zawiera: `{PUBLIC_BASE_URL}/v/{short_id}`
- Rozmiar 512x512, z logo Akces 360 w środku (opcjonalnie)

**POST `/api/events`**
- Stwórz nowy event
- Body: `{"name": "...", "date": "...", "client_name": "..."}`
- Logo upload osobno (multipart)

**GET `/gallery/{event_id}`**
- Render `templates/gallery.html` z listą wszystkich wideo dla eventu
- Grid view z thumbnailami (generuj thumbnails przez ffmpeg z pierwszej klatki)
- Autoryzacja: prosty access code w URL query `?key=XXX` (per-event secret)
- Możliwość download all jako ZIP

**GET `/` (root)**
- Landing page o Akces Booth
- Brandingowa strona, nie adminka

6. **HTML Templates (Tailwind CDN):**

Użyj Tailwind CSS z CDN (prostota deploymentu na RPi).

**base.html:**
- Navigation z logo Akces 360
- Footer z kontaktem ("Zamów fotobudkę: tel: XXX, email: XXX")
- RWD, dark theme

**watch.html:**
- Hero: video player (pełna szerokość na mobile, 16:9)
- Pod spodem: duży przycisk "Pobierz film" 
- Sekcja social: "Udostępnij na TikTok / Instagram / WhatsApp"
- Sekcja marketing: "Podoba Ci się? Zamów fotobudkę Akces 360 na swój event"
- QR widget u dołu: QR → www.akces360.pl

**gallery.html:**
- Grid thumbnailów (3 kolumny mobile, 6 desktop)
- Hover → preview
- Click → watch.html dla tego wideo
- Download all button

7. **Systemd service (`akces-booth.service`):**
```ini
[Unit]
Description=Akces Booth Flask API
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/akces-booth/backend
ExecStart=/home/pi/akces-booth/backend/venv/bin/gunicorn -w 4 -b 0.0.0.0:5100 app:app
Restart=always
Environment="FLASK_ENV=production"

[Install]
WantedBy=multi-user.target
```

8. **Cloudflare Tunnel config:**
Dodaj do instrukcji setup.sh:
```bash
# Cloudflare tunnel dla booth.akces360.pl
cloudflared tunnel create akces-booth
cloudflared tunnel route dns akces-booth booth.akces360.pl
# /etc/cloudflared/config.yml:
# - hostname: booth.akces360.pl
#   service: http://localhost:5100
```

9. **Security:**
- CORS: tylko localhost + docelowa domena apki (nie * !)
- Rate limiting na upload endpoint (Flask-Limiter)
- API key dla uploadu (prosta weryfikacja header `X-API-Key`)
- Sanityzacja nazw plików
- Max file size 500MB

10. **Testing:**
- Napisz `test_upload.py` - prosty script który wrzuca test MP4 i sprawdza że:
  - HTTP 200
  - Zwrócony short_url działa
  - QR image jest serwowany
- Udokumentuj w README jak uruchomić testy

11. **Deployment instructions (README.md):**
```markdown
## Setup na Raspberry Pi

1. Clone repo
2. python3 -m venv venv && source venv/bin/activate
3. pip install -r requirements.txt
4. cp .env.example .env && edit
5. python app.py  # test
6. sudo cp akces-booth.service /etc/systemd/system/
7. sudo systemctl enable --now akces-booth
8. Setup Cloudflare tunnel (scripts/setup_tunnel.sh)
9. Sprawdź https://booth.akces360.pl
```

**Na końcu:**
- Serwer działa lokalnie (`python app.py` → dostępny na :5100)
- Upload endpoint działa (test manualny curl-em)
- Landing page renderuje się
- README z pełnymi instrukcjami deploymentu
- Commit "feat: sesja 5 - backend flask API"

**Integracja z Akces Hub:**
- NIE ingeruj w Akces Hub (osobna baza, osobny port, osobny systemd)
- Ale: w dokumentacji wspomnij że później można połączyć (unified auth, unified dashboard)

Zaczynaj. Pytania najpierw.

---END PROMPT---

---

# SESJA 6: Uploader + QR flow w apce

**Cel:** Apka Flutter wysyła przetworzone wideo do RPi, otrzymuje short URL, pokazuje QR code pełnoekranowo.

**Czas:** 2h

---BEGIN PROMPT---

Kontynuujemy **Akces Booth**. Sesje 1-5 done: apka ma szkielet, kamerę, FFmpeg, AI, a backend Flask działa na RPi. Teraz łączymy apkę z backendem i zamykamy pętlę QR.

**Cel SESJI 6:**
Po przetworzeniu wideo w EditScreen (Sesja 3) → upload do backend RPi → generowanie QR → fullscreen QR display dla gościa.

**Wymagania:**

1. **Dependencies:**
```yaml
dio: ^5.4.0                  # HTTP client with upload progress
qr_flutter: ^4.1.0           # QR code generation
shared_preferences: ^2.2.0   # Do zapisywania URL backendu i API key
```

2. **Service `services/backend_client.dart`:**

```dart
class BackendClient {
  final String baseUrl;      // np. https://booth.akces360.pl
  final String apiKey;       // dla autoryzacji
  
  BackendClient({required this.baseUrl, required this.apiKey});
  
  Future<UploadResult> uploadVideo({
    required String videoPath,
    required int eventId,
    required String deviceId,
    Map<String, dynamic>? metadata,
    void Function(double progress)? onProgress,
  });
  
  Future<List<Event>> getEvents();
  Future<Event> createEvent({required String name, required DateTime date, String? clientName});
}

class UploadResult {
  final String shortId;
  final String publicUrl;       // https://booth.akces360.pl/v/XXXXX
  final String qrCodeUrl;        // https://booth.akces360.pl/qr/XXXXX.png
}
```

3. **Settings screen:**
Stwórz `screens/settings_screen.dart`:
- Pole: Backend URL (default: https://booth.akces360.pl)
- Pole: API Key
- Przycisk: "Test connection" (GET /api/health)
- Device ID (auto-generated UUID, wyświetlany jako readonly)
- Zapis w SharedPreferences

4. **Nowy screen `screens/qr_display_screen.dart`:**

**Fullscreen, landscape, zoptymalizowany pod prezentację gościowi.**

Layout:
```
┌──────────────────────────────────────────────┐
│                                              │
│    Twój film jest gotowy!                    │
│                                              │
│    ┌─────────────────┐   1. Zeskanuj kod    │
│    │                 │                        │
│    │   [QR CODE]     │   2. Pobierz film    │
│    │   500x500px     │                        │
│    │                 │   3. Udostępnij       │
│    │                 │                        │
│    └─────────────────┘                        │
│                                              │
│    Lub otwórz: booth.akces360.pl/v/AB3D5F   │
│                                              │
│    [Nagraj kolejny film]  [Menu główne]     │
│                                              │
└──────────────────────────────────────────────┘
```

Design:
- Tło: ciemny gradient z subtelnym logo Akces 360
- QR code w białym pudełku (lepiej skanowane)
- Duży tekst, czytelny z 2-3 metrów
- Branding "Akces Booth" w rogu

Features:
- Pokaż również URL tekstowo (fallback)
- Po 60 sekundach bez interakcji → wróć do RecordingScreen (ready na następnego gościa)
- Przycisk kopiowania URL do clipboard (debug)

5. **Aktualizacja `screens/edit_screen.dart`:**

Po kliknięciu "Przetwórz" i zakończeniu pipeline:
- Zamiast przechodzić na ResultScreen (Sesja 3) → automatycznie start uploadu
- Modal: "Wysyłam film do serwera..." z progress bar
- Po successful upload → navigate do QRDisplayScreen z danymi
- Przy error: retry dialog (3 próby) → jeśli dalej fail, zapisz lokalnie z flagą "pending upload"

6. **Offline mode:**

Co jeśli nie ma internetu?
- Plik zapisany lokalnie z metadata
- W tabeli SQLite/Hive: `pending_uploads` (path, event_id, metadata, retry_count)
- Przy uruchomieniu apki: background service próbuje upload pending
- Operator dostaje notyfikację "X filmów czeka na upload" w UI

Użyj `connectivity_plus` do detekcji stanu internetu.

7. **Event integration:**

W apce musimy wybierać event przed nagrywaniem. Stwórz `screens/event_selector_screen.dart`:
- Lista eventów z backendu (GET /api/events)
- Button "Nowy event" → wypełnia formularz → POST /api/events → dodaje do listy
- Zapis current event w AppState (Provider)
- Wszystkie uploady idą do current event

8. **Error handling:**

Scenariusze:
- Network timeout → retry z exponential backoff
- 401 Unauthorized → user widzi "Zły API key, sprawdź Settings"
- 413 Payload Too Large → user widzi "Film za duży, skróć"
- 500 Server Error → "Problem z serwerem, spróbuj później"
- Wszystko logowane do debug log panel w Settings

9. **QR size tuning:**

QR size zależy od dystansu skanowania:
- Dla 0.5m: 300x300px wystarczy
- Dla 1-2m: 500x500px
- Dla 3m+: 800x800px

Domyślnie 500x500. Dodaj setting w Settings screen.

10. **Testing workflow end-to-end:**

Test scenario:
1. Ustaw Backend URL + API Key w Settings
2. Test connection → OK
3. Wybierz/stwórz event
4. Otwórz RecordingScreen → nagraj 5s
5. EditScreen → wybierz preset wedding
6. Przetwarzanie... Upload... QR!
7. Zeskanuj QR telefonem → otwiera się strona watch.html
8. Klik "Pobierz" → MP4 zapisany na telefonie

**Na końcu:**
- Pełny flow end-to-end działa
- Upload ma progress bar
- QR wyświetla się czytelnie
- Offline mode funkcjonuje
- Commit "feat: sesja 6 - uploader + QR display"

Zaczynaj.

---END PROMPT---

---

# SESJA 7: Real BT Motor Controller (PO RECON!)

**WAŻNE:** Tę sesję robisz **DOPIERO PO** zrobieniu reverse engineering ChackTok (patrz RECON.md). Musisz mieć dokumentację protokołu BT przed odpaleniem tego prompta.

**Cel:** Zamiana MockMotorController na RealBTMotorController. Apka prawdziwie steruje fotobudką.

**Czas:** 1-2h

---BEGIN PROMPT---

Kontynuujemy **Akces Booth**. Sesje 1-6 done, apka działa end-to-end z mock motor. Teraz wymieniamy mock na prawdziwą implementację BT.

**WKLEJ TUTAJ WYNIKI RECON:**

```
[NAZWA URZĄDZENIA BT]: ________________
[TYP]: Bluetooth Classic | BLE
[MAC ADDRESS]: ________________
[SERVICE UUID]: ________________
[WRITE CHARACTERISTIC UUID]: ________________  (tylko jeśli BLE)
[NOTIFY CHARACTERISTIC UUID]: ________________  (tylko jeśli BLE, opcjonalne)

PROTOKÓŁ KOMEND:
- START: [bajty w hex]
- STOP: [bajty w hex]  
- SPEED_UP: [bajty w hex]
- SPEED_DOWN: [bajty w hex]
- REVERSE: [bajty w hex]
- SET_SPEED_1: [bajty w hex]
- SET_SPEED_2: [bajty w hex]
... (kolejne prędkości)

CHECKSUM ALGORITHM:
[Opis jak się liczy checksum, jeśli jest]

NOTES:
[Dodatkowe uwagi z recon]
```

**Cel SESJI 7:**
Stworzyć `RealBTMotorController` który komunikuje się z prawdziwą fotobudką przez BT. Zachowaj interface `MotorController` - reszta apki nie wymaga zmian.

**Wymagania:**

1. **Dependencies:**
```yaml
# Dla Classic BT:
flutter_bluetooth_serial: ^0.4.0

# Dla BLE:
flutter_blue_plus: ^1.32.0

# Permissions:
permission_handler: ^11.3.0
```

2. **Permissions Android:**

`android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

3. **Implementacja - wybierz ścieżkę na podstawie RECON:**

**ŚCIEŻKA A: Bluetooth Classic (HC-05 style)**

Stwórz `services/real_classic_motor_controller.dart`:

```dart
class RealClassicMotorController extends MotorController {
  BluetoothConnection? _connection;
  final String _targetMac;
  
  Future<bool> connect() async {
    // Permission check
    // BluetoothConnection.toAddress(_targetMac)
    // Setup listener na input stream (jeśli silnik coś wysyła)
  }
  
  Future<void> _sendCommand(List<int> bytes) async {
    // Loguj: print('[BT] TX: ${hex(bytes)}');
    _connection?.output.add(Uint8List.fromList(bytes));
    await _connection?.output.allSent;
  }
  
  @override
  Future<void> start() => _sendCommand([/* START bytes from RECON */]);
  
  @override
  Future<void> stop() => _sendCommand([/* STOP bytes from RECON */]);
  
  @override
  Future<void> setSpeed(int level) {
    // Użyj checksum algorithm z RECON
    final bytes = _buildSetSpeedCommand(level);
    return _sendCommand(bytes);
  }
  
  List<int> _buildSetSpeedCommand(int level) {
    // Implementuj zgodnie z protokołem z RECON
    // Np:
    // final base = [0xA5, 0x05, level, 0x00];
    // final checksum = _calculateChecksum(base);
    // return [...base, checksum];
  }
  
  int _calculateChecksum(List<int> bytes) {
    // Z RECON
  }
  
  // ... inne metody
}
```

**ŚCIEŻKA B: BLE (HM-10/JDY-08 style)**

Stwórz `services/real_ble_motor_controller.dart`:

```dart
class RealBLEMotorController extends MotorController {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  final String _targetMac;
  final Guid _serviceUuid = Guid('...'); // z RECON
  final Guid _writeCharUuid = Guid('...'); // z RECON
  
  Future<bool> connect() async {
    // Scan, find by MAC, connect
    // Discover services
    // Get write characteristic
  }
  
  Future<void> _sendCommand(List<int> bytes) async {
    await _writeCharacteristic?.write(bytes, withoutResponse: false);
  }
  
  // ... reszta jak wyżej
}
```

4. **Auto-selection w `services/motor_controller_factory.dart`:**

```dart
class MotorControllerFactory {
  static MotorController create({bool useMock = false}) {
    if (useMock) return MockMotorController();
    
    // Zwróć odpowiedni typ na podstawie config
    // Możesz dodać setting w SettingsScreen: "Device type: Mock | Classic BT | BLE"
    return RealClassicMotorController(
      targetMac: '__MAC_FROM_RECON__',
    );
  }
}
```

5. **Device pairing UI:**

W Settings screen dodaj sekcję "Fotobudka":
- Button "Skanuj urządzenia" → pokazuje listę wykrytych BT
- User wybiera swoje urządzenie → MAC jest zapisywany
- Status połączenia (realtime)
- Button "Test command" - wysyła START→czekaj 2s→STOP (sanity check)

6. **Reconnection handling:**

Prawdziwe BT czasem się rozłącza. Implementuj:
- Auto-reconnect przy utracie połączenia (z exponential backoff)
- Visual indicator rozłączenia w UI (czerwona kropka na statusie)
- Kolejka komend jeśli aktualnie disconnected (wykonaj po reconnect)

7. **Error handling:**

- Bluetooth wyłączony → prompt do włączenia
- Permission denied → tłumacz dlaczego potrzebujemy
- Device not found → "Sprawdź czy fotobudka jest włączona i w zasięgu"
- Write timeout → retry 3x, potem rozłącz i reconnect

8. **Testing checklist:**

Z prawdziwą fotobudką:
- [ ] Connect → zielona kropka
- [ ] START → silnik rusza
- [ ] STOP → silnik staje
- [ ] SPEED UP (3x) → przyspieszenie widoczne
- [ ] SPEED DOWN (3x) → zwolnienie
- [ ] REVERSE → zmiana kierunku
- [ ] SET SPEED 1 → najwolniej
- [ ] SET SPEED 10 → najszybciej
- [ ] Wyłącz BT fotobudki → UI pokazuje disconnected
- [ ] Włącz z powrotem → auto-reconnect
- [ ] Nagraj film z prawdziwym silnikiem → pełny flow działa

**Na końcu:**
- Mock zastąpiony real
- Settings ma device selector
- Pełny flow z prawdziwą fotobudką działa
- Commit "feat: sesja 7 - real BT motor controller"

Zaczynaj. Jeśli bajty w RECON wydają się niekompletne lub niespójne - zatrzymaj się i dopytaj, nie zgaduj.

---END PROMPT---

---

# DODATKOWE SESJE (opcjonalne, gdy MVP działa)

## SESJA 8: Event Manager UI + pre-event checklist
Ułatwia operatorowi przygotowanie eventu: wybór logo, muzyki, efektów, zapisywanie template'ów.

## SESJA 9: Testowanie na prawdziwym evencie
Lista bugów + hotfixes.

## SESJA 10: SaaS - system licencji
Integracja z istniejącym licensing z Akces Hub. Multi-tenant. Pricing tiers. Płatności Stripe.

---

# Workflow z Claude Code - Best practices

**1. Jedna sesja = jeden topic**
Nie mieszaj sesji. Skończ Sesję 1 zanim zaczniesz Sesję 2. Git commit po każdej.

**2. Rób przerwy**
Sesja 3 (FFmpeg) może być długa. Zrób przerwę, zrestartuj Claude Code. Context window się zapełnia → jakość odpowiedzi spada.

**3. Test po każdej sesji**
Zawsze `flutter run` i sprawdź że działa na urządzeniu/emulatorze PRZED przejściem do następnej sesji. Bugi się kumulują - łatwiej debugować świeże.

**4. Keep PLAN.md i RECON.md w repo**
```bash
# Dodaj do akces-booth/docs/:
cp PLAN.md docs/
cp RECON.md docs/
# Claude Code może potrzebować kontekstu w późniejszych sesjach
```

**5. Przy problemach**
Jeśli Claude Code zacznie zgadywać / robić głupoty:
- Zatrzymaj
- Powiedz co robisz źle
- Rozpocznij nową sesję z czystym context
- Wklej TYLKO aktualny prompt + ewentualnie plik z błędami

**6. Commits per session**
Każda sesja = osobny commit. Jeśli coś pójdzie nie tak, `git revert` do stanu po poprzedniej sesji.

**7. Backup RPi**
Przed deploymentem backendu → snapshot całej karty SD / SSD RPi. Jeśli coś pójdzie nie tak, rollback.

---

# Czeklista przed rozpoczęciem

- [ ] Flutter SDK zainstalowany
- [ ] Android Studio z SDK 34
- [ ] Emulator Android LUB fizyczny telefon/tablet podpięty USB (USB debugging)
- [ ] Claude Code zainstalowany i działający
- [ ] Git skonfigurowany (użytkownik, email)
- [ ] Folder `akces-booth/` utworzony
- [ ] `PLAN.md` i `RECON.md` pod ręką
- [ ] Dla Sesji 5: RPi z Pythonem 3.11 + SSH dostęp
- [ ] Dla Sesji 7: Zrobiony reverse engineering (patrz RECON.md)

---

# TL;DR

**Bez fotobudki możesz zrobić sesje: 1, 2, 3, 4, 5, 6** (wszystko oprócz Sesji 7).

To jest **~80% apki**. Pozostałe 20% (Sesja 7 = prawdziwe BT) wymaga recon + fotobudki.

**Realistyczny timeline:**
- Tydzień 1: Sesje 1-3 (szkielet, kamera, FFmpeg) = ~8h
- Tydzień 2: Sesje 4-5 (AI, backend) = ~6h  
- Tydzień 3: Sesja 6 (upload+QR) + testy = ~4h
- Gdy masz fotobudkę: Sesja 7 = ~2h

**Total: ~20h pracy z Claude Code** i masz pełną alternatywę do ChackTok.

Powodzenia! 🚀
