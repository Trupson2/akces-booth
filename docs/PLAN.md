# Akces Booth - Plan Projektu

**Aplikacja na Android do sterowania fotobudką 360 YCKJNB z delivery filmów przez QR**

Data: 16 kwietnia 2026
Autor: Adrian (Akces 360)

---

## 1. Decyzje architektoniczne (podjęte za Ciebie)

### Stack: **Flutter + Dart**

**Dlaczego Flutter, a nie Kotlin natywnie:**
- Jedno źródło kodu = łatwiej utrzymać samemu
- iOS "za darmo" później (gdyby klienci chcieli)
- Świetny ekosystem pod BLE (`flutter_blue_plus`), kamerę (`camera`), FFmpeg (`ffmpeg_kit_flutter`)
- Hot reload = szybki development z Claude Code
- Ty już ogarniasz Pythona i Flaska - Dart składniowo blisko
- Flutter na Androidzie ma **pełną wydajność natywną** (kompilowany do ARM)

**Dlaczego nie React Native:**
- Kamera i BLE działają gorzej niż we Flutter
- Przy FFmpeg i ciężkim post-processingu RN się dusi

### Urządzenie: **Samsung Galaxy Tab A9+ (11")**
- Cena: ~1000-1200 PLN
- 8GB RAM, Snapdragon 695 - wystarczy pod FFmpeg + slow-mo
- Android 14 = pełne wsparcie BLE + CameraX
- 11" ekran = łatwy touch dla operatora
- Alternatywa budżet: Lenovo Tab M11 (~800 PLN)
- Alternatywa premium: Samsung Galaxy Tab S9 FE (~1800 PLN) jeśli chcesz lepszą kamerę

**Dlaczego nie iPad:** zablokuje Was w ekosystemie Apple + drogo (3000+) + App Store subskrypcja 99$/rok na dystrybucję

### Hosting: **Raspberry Pi 5 (ten od Akces Hub) + ngrok/Cloudflare Tunnel**

**Dlaczego RPi:**
- Już chodzi 24/7, ma NVMe SSD, już masz ngrok
- Zero dodatkowych kosztów (VPS = 20-50 PLN/mc)
- Synergia z Akces Hub - współdzielony stack (Flask, SQLite, systemd)
- Pełna kontrola nad plikami (RODO - dane na Twoim sprzęcie)

**Limit:** jeśli przejdziesz 1000+ filmów/miesiąc albo wiele równoległych eventów → przeskok na Hetzner CX22 (20zł/mc, 40GB SSD)

**Plan awaryjny:** jeśli RPi padnie w trakcie eventu → apka zapisuje lokalnie, synchronizuje po evencie. Gość dostaje QR że film będzie dostępny w ciągu 24h.

### Licencjonowanie: **Tak, ale modułowo (SaaS ready od początku)**

Projektujemy z myślą o multi-tenant, ale MVP tylko dla Akces 360. Dodanie licencjonowania potem = 1 sesja Claude Code, bo masz już system licencji z Akces Hub.

---

## 2. Reverse engineering ChackTok (FAZA 0)

**To robimy zanim cokolwiek napiszemy.** Bez tego nie wiemy jak sterować silnikiem.

### Krok 1: Przygotowanie telefonu (Android)
1. Włącz Opcje deweloperskie (7x tap na Build Number w Ustawieniach)
2. Włącz: **USB Debugging**
3. Włącz: **Enable Bluetooth HCI snoop log**
4. Zainstaluj ChackTok ze Sklepu Play
5. Wyłącz i włącz Bluetooth (aktywacja logu)

### Krok 2: Sparuj z fotobudką i nagraj sesję
1. Uruchom ChackTok, połącz z budką
2. Przejedź przez wszystkie funkcje: start, stop, prędkość góra/dół, zmiana kierunku (CW/CCW)
3. Zrób 3-5 powtórzeń każdej akcji (żeby odróżnić stały pattern od zmiennej)
4. Wyłącz ChackTok

### Krok 3: Zrzut logów
```bash
# Przez adb (USB):
adb bugreport bugreport.zip
# Plik btsnoop_hci.log będzie w: FS/data/misc/bluetooth/logs/
# LUB bezpośrednio:
adb pull /data/misc/bluetooth/logs/ ./bt_logs/
```

### Krok 4: Analiza w Wireshark
1. Otwórz `btsnoop_hci.log` w Wireshark
2. Filtr: `btatt` (dla BLE) lub `rfcomm` (dla Bluetooth Classic/HC-05)
3. Znajdź pakiety Write do charakterystyki - to są komendy do silnika
4. Porównaj pakiety dla różnych akcji → rozszyfrujesz protokół

**Typowe protokoły jakie możemy znaleźć:**
- HC-05/HC-06 (Bluetooth Classic SPP) - zwykły tekst "A1", "B2" itp.
- JDY-08/HM-10 (BLE) - custom GATT service z charakterystyką UART
- Nordic UART Service (0x6E400001-...) - standard BLE dla serial
- Chiński custom protokół - zazwyczaj 4-8 bajtów, XOR checksum

### Krok 5: APK reverse engineering (fallback jeśli BT sniff nie wystarczy)
```bash
# Pobierz APK z telefonu:
adb shell pm path com.chacktok.app
adb pull /data/app/.../base.apk chacktok.apk

# Decompile JADX:
# Pobierz jadx-gui z GitHub
# Otwórz chacktok.apk → szukaj klas z "Bluetooth" w nazwie
# Kluczowe: komendy UUID i format wysyłanych bajtów
```

### Potencjalne scenariusze wyników

| Scenariusz | Prawdopodobieństwo | Akcja |
|---|---|---|
| HC-05 Bluetooth Classic, prosty SPP | 60% | `flutter_bluetooth_serial` + wysyłamy ASCII komendy |
| BLE z Nordic UART Service | 25% | `flutter_blue_plus` + write do charakterystyki |
| Zaszyfrowany protokół (pairing key) | 10% | Trudniej, ale do zrobienia - wydobywamy klucz z APK |
| Własny chip z firmware do zmiany | 5% | Plan B: zostawiamy silnik na pilocie, sterujemy tylko nagrywaniem |

---

## 3. Architektura aplikacji

```
┌─────────────────────────────────────────────────┐
│                TABLET (Android)                  │
│  ┌──────────────────────────────────────────┐   │
│  │           Akces Booth (Flutter)          │   │
│  │                                           │   │
│  │  ┌─────────────┐  ┌─────────────────┐   │   │
│  │  │ Motor BLE   │  │ Camera Capture  │   │   │
│  │  │ Controller  │  │ (CameraX)       │   │   │
│  │  └──────┬──────┘  └────────┬────────┘   │   │
│  │         │                   │             │   │
│  │         └───────┬───────────┘             │   │
│  │                 ▼                          │   │
│  │  ┌──────────────────────────────────┐    │   │
│  │  │  FFmpeg Post-Processor           │    │   │
│  │  │  (slow-mo, overlay, music)       │    │   │
│  │  └──────────────┬───────────────────┘    │   │
│  │                 ▼                          │   │
│  │  ┌──────────────────────────────────┐    │   │
│  │  │  AI Effects (MediaPipe on-device)│    │   │
│  │  │  - Background removal             │    │   │
│  │  │  - Face effects                   │    │   │
│  │  └──────────────┬───────────────────┘    │   │
│  │                 ▼                          │   │
│  │  ┌──────────────────────────────────┐    │   │
│  │  │  Uploader → RPi                   │    │   │
│  │  └──────────────┬───────────────────┘    │   │
│  │                 ▼                          │   │
│  │  ┌──────────────────────────────────┐    │   │
│  │  │  QR Display Screen               │    │   │
│  │  └──────────────────────────────────┘    │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────┬───────────────────────┘
                          │ BLE
              ┌───────────▼────────────┐
              │   Fotobudka YCKJNB     │
              │   Motor Controller     │
              │   (HC-05/JDY-08/etc.)  │
              └────────────────────────┘

                          │ HTTPS
              ┌───────────▼────────────┐
              │  Raspberry Pi 5        │
              │  (Akces Hub stack)     │
              │                         │
              │  ┌──────────────────┐  │
              │  │ Flask API        │  │
              │  │ /api/upload      │  │
              │  │ /api/events      │  │
              │  │ /v/{short_id}    │  │
              │  └──────────────────┘  │
              │  ┌──────────────────┐  │
              │  │ SQLite (videos)  │  │
              │  └──────────────────┘  │
              │  ┌──────────────────┐  │
              │  │ /storage/videos/ │  │
              │  │   (MP4 files)    │  │
              │  └──────────────────┘  │
              │                         │
              │  ┌──────────────────┐  │
              │  │ Cloudflare Tunnel│  │
              │  │ akcesbooth.pl    │  │
              │  └──────────────────┘  │
              └────────────────────────┘

                          │ HTTPS
              ┌───────────▼────────────┐
              │     Telefon gościa     │
              │                         │
              │  1. Skanuje QR          │
              │  2. Otwiera link        │
              │  3. Pobiera MP4         │
              │     ALBO ogląda gallery │
              │     ALBO dostaje SMS    │
              └────────────────────────┘
```

---

## 4. Struktura projektu (monorepo)

```
akces-booth/
├── mobile/                          # Flutter app (tablet)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   ├── event_setup_screen.dart
│   │   │   ├── recording_screen.dart
│   │   │   ├── qr_display_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── services/
│   │   │   ├── motor_controller.dart   # BLE komunikacja z silnikiem
│   │   │   ├── camera_service.dart      # Nagrywanie wideo
│   │   │   ├── video_processor.dart     # FFmpeg pipeline
│   │   │   ├── ai_effects.dart          # MediaPipe (bg removal, face)
│   │   │   ├── uploader.dart            # HTTP upload do RPi
│   │   │   └── qr_generator.dart
│   │   ├── models/
│   │   │   ├── event.dart
│   │   │   ├── video_job.dart
│   │   │   └── effect_template.dart
│   │   └── widgets/
│   │       ├── motor_control_panel.dart
│   │       ├── effect_selector.dart
│   │       └── qr_display.dart
│   ├── android/
│   ├── assets/
│   │   ├── music/                 # Wbudowane utwory (royalty free)
│   │   ├── overlays/              # Template'y nakładek
│   │   └── logos/
│   └── pubspec.yaml
│
├── backend/                         # Flask API na RPi
│   ├── app.py
│   ├── models.py
│   ├── api/
│   │   ├── upload.py
│   │   ├── events.py
│   │   ├── videos.py
│   │   └── share.py
│   ├── templates/
│   │   ├── watch.html             # Strona odtwarzania wideo (QR link)
│   │   ├── gallery.html           # Galeria eventu (dla klienta-organizatora)
│   │   └── landing.html           # Branded landing z logo Akces 360
│   ├── static/
│   ├── storage/
│   │   └── videos/{event_id}/
│   └── requirements.txt
│
├── admin/                           # Panel admina (web) - opcjonalnie osobno
│   └── (jeśli chcemy, może być na tym samym Flasku)
│
└── docs/
    ├── BT_PROTOCOL.md              # Dokumentacja protokołu silnika
    ├── API.md
    └── DEPLOYMENT.md
```

---

## 5. Roadmap - podzielony na sesje Claude Code

**Każda sesja = ~2h pracy z Claude Code. Kolejność jest ważna.**

### SESJA 0: Reverse engineering (bez Claude Code, sam z Wireshark)
**Cel:** Rozszyfrować protokół BT silnika
**Deliverable:** `BT_PROTOCOL.md` z pełną dokumentacją komend

**Zadania:**
- Sniff sesję ChackTok przez btsnoop
- Analiza pakietów w Wireshark
- Jeśli zaszyfrowane: decompile APK w JADX
- Wypisać wszystkie komendy: start, stop, speed 1-10, CW, CCW

### SESJA 1: Szkielet Flutter + BLE motor control
**Cel:** Apka łączy się z fotobudką i steruje silnikiem
**Deliverable:** Working motor control screen

- Setup Flutter project
- `flutter_blue_plus` integracja
- Screen: skanowanie urządzeń, parowanie
- Implementacja komend z `BT_PROTOCOL.md`
- Przyciski: Start/Stop, Speed +/-, Direction toggle
- **Test:** fotobudka reaguje na komendy z apki

### SESJA 2: Camera + podstawowe nagrywanie
**Cel:** Apka nagrywa wideo (bez efektów)
**Deliverable:** Nagrywanie 60/120fps, zapis lokalny

- Package `camera` Flutter
- Permissions (kamera, mikrofon, storage)
- Recording screen z preview
- Tryby: Normal, Slow-mo (120fps), Super slow-mo (240fps jeśli tablet wspiera)
- Synchronizacja: naciśnięcie "Start" → motor start + nagrywanie

### SESJA 3: FFmpeg post-processing
**Cel:** Obróbka wideo (slow-mo, muzyka, overlay)
**Deliverable:** Pipeline: raw video → gotowy klip z muzyką i logo

- `ffmpeg_kit_flutter` setup
- Slow-mo rendering (2x, 4x)
- Boomerang (concat forward + reverse)
- Audio mixing (dodanie muzyki, ducking oryginału)
- PNG overlay (logo Akces 360, watermark eventu)
- Progress bar podczas renderu
- Cache i cleanup plików tymczasowych

### SESJA 4: AI Effects (MediaPipe)
**Cel:** Background removal + face effects on-device
**Deliverable:** Toggle AI w apce

- Google MediaPipe Tasks (Selfie Segmentation)
- Background replacement (statyczny kolor lub obraz)
- Face Detection + overlay (okulary, korona, itp.)
- Wszystko lokalnie na urządzeniu (żaden cloud = szybsze + RODO)
- Performance test: ile trwa na 10s klipie

### SESJA 5: Backend RPi - Flask API
**Cel:** API do uploadu + serwowania filmów
**Deliverable:** Działający endpoint `/api/upload` + `/v/{id}`

- Flask app na RPi (osobny port od Akces Hub, np. 5100)
- Endpointy:
  - POST `/api/upload` - multipart MP4 upload
  - GET `/v/{short_id}` - landing page z odtwarzaczem
  - GET `/api/events` - lista eventów
  - GET `/gallery/{event_id}` - galeria dla organizatora
- SQLite schema: events, videos, sessions
- Generowanie short_id (6 chars, baza32)
- Cloudflare Tunnel setup → `booth.akces360.pl`
- Systemd service (jak Akces Hub)

### SESJA 6: Uploader + QR flow
**Cel:** Apka wysyła film → dostaje short URL → generuje QR
**Deliverable:** Pełny end-to-end flow gość → film

- HTTP client w Flutter (`dio` package)
- Resumable upload (retry on failure)
- QR generation (`qr_flutter`)
- QR Display screen: pełny ekran, big QR, "Next guest" button
- Opcja: SMS/Email delivery (integracja Twilio albo własny SMTP na RPi)

### SESJA 7: Event Manager + UX polishing
**Cel:** Pre-event setup (wybór logo, muzyki, efektów)
**Deliverable:** Operator może przygotować event w 2 min

- Event creation flow (nazwa, data, logo upload, muzyka)
- Template save/load (np. "Wesele standard", "Urodziny dziecięce")
- Pre-recording checklist (BT connection, bateria, storage)
- Operator dashboard: licznik filmów, czas eventu

### SESJA 8: Web Gallery + branding strony
**Cel:** Klient dostaje piękną galerię dla swoich gości
**Deliverable:** akces360.pl-style gallery

- Template Jinja z Twoim brandingiem
- Gallery grid z thumbnailami
- Indywidualne strony wideo z download button
- Social sharing buttons (TikTok, Instagram, WhatsApp)
- QR code widget na końcu strony ("Zeskanuj żeby zamówić fotobudkę!")

### SESJA 9: Testowanie na prawdziwym evencie
**Cel:** Pierwszy real-world test
**Deliverable:** Lista bugów do fixu

- Event pilot (np. rodzinna impreza, friends wedding)
- Stress test: 50+ filmów w jedną noc
- Czas od nagrania do QR (target: <20s)
- Zbieranie feedbacku od gości

### SESJA 10: Bug fixes + SaaS prep (opcjonalne)
**Cel:** Gotowość do sprzedaży innym fotobudkarzom
**Deliverable:** Licensing system (jak Akces Hub)

- License keys z Akces Hub (współdzielenie systemu)
- Multi-tenant separation
- Per-customer branding
- Pricing: 99 PLN/mc lub 999 PLN/rok, early bird 49 PLN/mc

---

## 6. Koszty (szacunek)

### Sprzęt (jednorazowo)
| Pozycja | Koszt |
|---|---|
| Samsung Galaxy Tab A9+ | 1000-1200 PLN |
| Statyw/uchwyt tablet | 50-100 PLN |
| Power bank 20000mAh (już masz?) | 0-150 PLN |
| **SUMA** | **1050-1450 PLN** |

### Miesięczne (bieżące)
| Pozycja | Koszt |
|---|---|
| RPi prąd (już chodzi) | 0 PLN (już w kosztach Akces Hub) |
| Cloudflare Tunnel | 0 PLN (darmowy) |
| Domena booth.akces360.pl | 0 PLN (subdomena) |
| SMS gateway (opcjonalne, ~200 sms/mc) | 20-50 PLN |
| **SUMA** | **20-50 PLN/mc** |

### Porównanie z ChackTok VIP
- ChackTok VIP: ~20-40$/mc = 80-160 PLN/mc wieczność
- **Akces Booth: jednorazowo + 0-50/mc**
- ROI po 3-6 miesiącach używania

---

## 7. Ryzyka i mitygacje

| Ryzyko | Prawdopodobieństwo | Mitygacja |
|---|---|---|
| Protokół BT zaszyfrowany | 15% | Plan B: sterowanie tylko nagrywaniem, silnik na pilocie |
| Tablet się dusi na AI effects | 20% | Downgrade: tylko slow-mo + overlay, bez AI |
| RPi pada w trakcie eventu | 10% | Local cache + async upload, klient dostaje film 24h później |
| Internet na evencie słaby | 40% | Mobile hotspot 5G + offline mode z queue |
| FFmpeg rendering > 30s | 30% | Tryb "low quality fast" + "high quality slow" do wyboru |
| Battery drain przy ciągłym 4G + kamera | Wysokie | Tablet na zasilaniu przez cały event |

---

## 8. Co zrobić PRZED pierwszą sesją z Claude Code

**Checklist przed startem:**

- [ ] Zainstaluj Android Studio (żeby był SDK)
- [ ] Zainstaluj Flutter SDK (`flutter doctor`)
- [ ] Zainstaluj Wireshark
- [ ] Zainstaluj JADX (GUI) - do decompile APK
- [ ] Pobierz ChackTok na telefon
- [ ] Włącz USB Debugging + BT HCI Snoop Log
- [ ] Zrób sesję sniff (wszystkie komendy)
- [ ] Zrób zdjęcia sterownika silnika (chip BT!)
- [ ] Ściągnij APK ChackTok
- [ ] Kup tablet (albo pożycz na test zanim kupisz)
- [ ] Stwórz folder `akces-booth/` w twoim workspace
- [ ] Stwórz subdomenę `booth.akces360.pl` → Cloudflare Tunnel do RPi

---

## 9. Nazewnictwo i branding (do decyzji)

### Opcje nazwy:
1. **Akces Booth** - spójne z Akces Hub, jasne że to Wasze
2. **SpinHub** - bardziej SaaS-owo, międzynarodowo
3. **Akces 360** - branding zgodny z firmą
4. **Twirly / Twirlio** - catchy, premium feel
5. **BudkaPL** - dla polskiego rynku

Moja rekomendacja: **Akces Booth** dla MVP, jeśli idziemy SaaS globalnie to rebranding na **SpinHub** albo **Twirly**.

### Branding dla klientów (organizatorów wesel):
- Landing page: akces360.pl/wesele/{id}
- QR na stronie: "Pobierz swój filmik z wesela"
- Footer: "Fotobudka 360 Akces 360 | Twoje urodziny? Zadzwoń: XXX"

---

## 10. Przewaga konkurencyjna (dlaczego to ma sens)

1. **Brak subskrypcji dla klientów** - jednorazowa opłata albo tania miesięczna (jeśli SaaS)
2. **RODO-friendly** - dane na Waszym RPi w Polsce, nie w USA/Chinach
3. **Branding własny** - klienci Akces 360 widzą Wasze logo, nie ChackTok
4. **Synergia z Akces Hub** - współdzielona infrastruktura (licensing, RPi, monitoring)
5. **Polski support** - rynek PL dla fotobudkarzy nie ma dobrej polskiej alternatywy
6. **Możliwość sprzedaży cross-sell:** Klient który kupił kurs zwrotów → też może kupić fotobudkę jako biznes dodatkowy

---

## 11. Następne kroki

1. **Dziś wieczorem:** Przeczytaj plan, zadaj pytania, doprecyzuj co chcesz zmienić
2. **Jutro rano:** Sniff BT + zdjęcia sterownika (1-2h)
3. **Jutro wieczór:** SESJA 1 z Claude Code (setup + motor control)
4. **W tygodniu:** SESJE 2-4 (camera, FFmpeg, AI)
5. **Weekend:** SESJE 5-6 (backend + QR flow)
6. **Za 2 tygodnie:** MVP gotowy do testu

---

**Pytania otwarte dla Ciebie na wieczór:**

1. Czy masz już jakieś eventy Akces 360 zaplanowane na najbliższy miesiąc do testu?
2. Czy chcesz żeby apka była po polsku tylko, czy multi-język (EN/PL) od razu?
3. Czy klient Akces 360 (organizator) ma też dostawać dostęp do galerii (moje preferred) czy tylko gość dostaje QR?
4. Jakie masz utwory muzyczne licencjonowane, czy korzystamy z royalty-free (Epidemic Sound, YouTube Audio Library)?
5. Czy robimy print template (papier z QR do wydruku na evencie "zeskanuj żeby odebrać film")?
