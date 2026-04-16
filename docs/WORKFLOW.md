# Akces Booth - Pełny Workflow & UX Spec

**Cel:** Dokładna specyfikacja tego jak apka się zachowuje w każdym stanie. To jest nasz "brief" dla Claude Code - na podstawie tego napiszemy kod.

---

## Decyzje UX (potwierdzone przez Adriana)

| # | Pytanie | Decyzja |
|---|---|---|
| 1 | Jak odpala nagrywanie? | **Wszystkie 3 opcje: pilot fizyczny, Tab A11+, OnePlus 13** |
| 2 | Auto/manual stop? | **Auto-stop po 8s + wcześniejszy manualny** |
| 3 | Podgląd + akceptacja? | **TAK - gość widzi i klika "Akceptuj/Powtórz"** |
| 4 | Auto-reset QR? | **TAK - po 60s** |
| 5 | Gdzie gość widzi film? | **Tab A11+** |
| 6 | Start - wygoda? | **Obie opcje (pilot + tablet)** |

---

## Dwie apki - przypomnienie architektury

**Apka 1: Akces Booth Recorder** - chodzi na OnePlus 13 na ramieniu
- Sterowanie silnikiem BLE
- Nagrywanie wideo (240fps slow-mo)
- FFmpeg post-processing
- Wysyłanie filmu do Tab A11+ przez WiFi

**Apka 2: Akces Booth Station** - chodzi na Tab A11+ na statywie
- Interfejs dla gościa (start, podgląd, akceptacja, QR)
- Odbiera film z OnePlus 13
- Upload na Raspberry Pi
- Generowanie QR + wyświetlanie fullscreen

**Komunikacja:** Obie apki łączą się przez **WiFi Direct** (bezpośrednio peer-to-peer, bez routera) albo **lokalny WiFi** (oba urządzenia na tej samej sieci).

---

## STATE DIAGRAM (Tab A11+ Station)

```
                   ┌─────────────────────┐
                   │   [STATE: IDLE]     │
                   │                     │
                   │  "Wejdź na          │
                   │   platformę 👋"     │
                   │                     │
                   │  [START NAGRANIA]   │ ← duży przycisk
                   │                     │
                   │  Status: BT✅ WiFi✅ │ ← gdzieś w rogu
                   └──────────┬──────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
        (klik pilot)   (klik tablet)   (klik telefon)
              │               │               │
              └───────────────┼───────────────┘
                              │
                              ▼
                   ┌─────────────────────┐
                   │ [STATE: RECORDING]  │
                   │                     │
                   │   🔴 REC            │
                   │   ▓▓▓▓▓░░░  5/8s   │ ← progress bar
                   │                     │
                   │   [STOP TERAZ]      │ ← opcjonalny early stop
                   └──────────┬──────────┘
                              │
                    auto po 8s LUB manual stop
                              │
                              ▼
                   ┌─────────────────────┐
                   │ [STATE: PROCESSING] │
                   │                     │
                   │  ⏳ Przetwarzam     │
                   │   ▓▓▓░░░░  40%     │
                   │                     │
                   │  Efekty, muzyka...  │
                   └──────────┬──────────┘
                              │
                      FFmpeg zakończony
                              │
                              ▼
                   ┌─────────────────────┐
                   │ [STATE: TRANSFER]   │
                   │                     │
                   │  📡 Wysyłam do      │
                   │     tableta...      │
                   │     ▓▓▓▓▓▓▓░  80%  │
                   └──────────┬──────────┘
                              │
                         Transfer done
                              │
                              ▼
                   ┌─────────────────────┐
                   │ [STATE: PREVIEW]    │
                   │                     │
                   │  [▶ VIDEO AUTOPLAY] │
                   │                     │
                   │  Jak Ci się podoba? │
                   │                     │
                   │  [✅ Akceptuj]      │
                   │  [🔄 Powtórz]       │
                   └──────┬──────┬───────┘
                          │      │
                   Akceptuj      Powtórz
                          │      │
                          │      └──────► powrót do IDLE
                          │                (skasowanie filmu)
                          ▼
                   ┌─────────────────────┐
                   │ [STATE: UPLOADING]  │
                   │                     │
                   │  ☁️ Wysyłam na      │
                   │     serwer...       │
                   │     ▓▓▓▓▓▓▓▓░ 90%  │
                   └──────────┬──────────┘
                              │
                      Upload zakończony
                              │
                              ▼
                   ┌─────────────────────┐
                   │ [STATE: QR_DISPLAY] │
                   │                     │
                   │  🎉 Twój film!      │
                   │                     │
                   │   ┌──────────┐      │
                   │   │   [QR]   │      │ ← 500x500px
                   │   └──────────┘      │
                   │                     │
                   │  Skanuj i zabierz   │
                   │                     │
                   │  ⏱ Auto-reset 45s   │ ← countdown
                   │  [Następny gość →]  │
                   └──────────┬──────────┘
                              │
                   auto po 60s LUB manual
                              │
                              ▼
                       powrót do IDLE
```

---

## STATE DIAGRAM (OnePlus 13 Recorder)

OnePlus 13 jest "silent worker" - głównie wykonuje komendy z Tab A11+. Ale też ma swoje UI (dla Ciebie operatora).

```
                   ┌─────────────────────┐
                   │   [STATE: READY]    │
                   │                     │
                   │  Motor: Połączony   │
                   │  Tablet: Połączony  │
                   │  Bateria: 85%       │
                   │                     │
                   │  [START RĘCZNIE]    │ ← big button
                   │                     │
                   │  [Ustawienia]       │
                   └──────────┬──────────┘
                              │
                    Start (skądkolwiek)
                              │
                              ▼
                   ┌─────────────────────┐
                   │ [STATE: RECORDING]  │
                   │                     │
                   │ Kamera: LIVE PREVIEW│
                   │ 🔴 REC 240fps       │
                   │                     │
                   │ Motor: Obraca (6/10)│
                   │                     │
                   │ [STOP]              │
                   └──────────┬──────────┘
                              │
                         Stop (auto/manual)
                              │
                              ▼
                   ┌─────────────────────┐
                   │ [STATE: PROCESSING] │
                   │                     │
                   │ FFmpeg:             │
                   │ ▓▓▓▓░░░░ 50%       │
                   │                     │
                   │ - Slow-mo 2x        │
                   │ - Muzyka ✓          │
                   │ - Logo overlay ✓    │
                   └──────────┬──────────┘
                              │
                              ▼
                   ┌─────────────────────┐
                   │ [STATE: SENDING]    │
                   │                     │
                   │ Wysyłam do tableta  │
                   │ ▓▓▓▓▓▓▓▓ 100%      │
                   └──────────┬──────────┘
                              │
                              ▼
                         powrót do READY
```

---

## SCREENS Tab A11+ Station (mockupy)

### Screen 1: IDLE (główny ekran, 90% czasu tutaj)

```
╔═══════════════════════════════════════════════════╗
║                                                   ║
║                                          🔵 ⚡  📶 ║ ← status dots
║                                                   ║
║                                                   ║
║                                                   ║
║              ┌──────────────────┐                 ║
║              │                  │                 ║
║              │    👋 Hej!       │                 ║
║              │                  │                 ║
║              │  Wejdź na        │                 ║
║              │  platformę       │                 ║
║              │                  │                 ║
║              └──────────────────┘                 ║
║                                                   ║
║                                                   ║
║      ┌─────────────────────────────────┐          ║
║      │                                 │          ║
║      │      ▶  START NAGRANIA         │          ║ ← duży przycisk, cały width
║      │                                 │          ║
║      └─────────────────────────────────┘          ║
║                                                   ║
║                                                   ║
║    [Akces 360 logo]            [⚙️ Ustawienia]    ║ ← footer
╚═══════════════════════════════════════════════════╝

🔵 = Bluetooth (zielony = connected)
⚡ = Recorder (zielony = OnePlus 13 online)
📶 = Internet (zielony = może uploadować)
```

### Screen 2: RECORDING

```
╔═══════════════════════════════════════════════════╗
║                                                   ║
║                                                   ║
║                 🔴 NAGRYWAM                       ║
║                                                   ║
║                                                   ║
║         ┌────────────────────────────┐            ║
║         │ ▓▓▓▓▓▓░░░░░░░░░░░░░░░░░ │ ← progress
║         └────────────────────────────┘            ║
║                    5s / 8s                        ║
║                                                   ║
║                                                   ║
║            Uśmiechnij się! 😊                     ║
║                                                   ║
║                                                   ║
║         ┌────────────────────────┐                ║
║         │   ⏹  STOP TERAZ       │                ║ ← early stop
║         └────────────────────────┘                ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
```

### Screen 3: PROCESSING

```
╔═══════════════════════════════════════════════════╗
║                                                   ║
║                                                   ║
║               ⏳ Magia w toku...                  ║
║                                                   ║
║                                                   ║
║         ┌────────────────────────────┐            ║
║         │ ▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░ │ ← progress
║         └────────────────────────────┘            ║
║                    40%                            ║
║                                                   ║
║                                                   ║
║      • Slow motion 2x          ✅                 ║
║      • Muzyka dodana           ✅                 ║
║      • Logo Akces 360          ⏳                 ║
║      • Finalny render          ⏳                 ║
║                                                   ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
```

### Screen 4: PREVIEW (kluczowy ekran!)

```
╔═══════════════════════════════════════════════════╗
║                                                   ║
║   ┌─────────────────────────────────────────┐    ║
║   │                                         │    ║
║   │                                         │    ║
║   │       [VIDEO PREVIEW AUTOPLAY]          │    ║
║   │          16:9, full width                │    ║ ← ~60% wysokości
║   │          zapętla się                     │    ║
║   │                                         │    ║
║   │                                         │    ║
║   └─────────────────────────────────────────┘    ║
║                                                   ║
║          Jak Ci się podoba? 😊                    ║
║                                                   ║
║                                                   ║
║   ┌──────────────────┐  ┌──────────────────┐     ║
║   │                  │  │                  │     ║
║   │  ✅ AKCEPTUJ     │  │  🔄 POWTÓRZ      │     ║
║   │                  │  │                  │     ║
║   └──────────────────┘  └──────────────────┘     ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
```

### Screen 5: QR DISPLAY (finał)

```
╔═══════════════════════════════════════════════════╗
║                                                   ║
║               🎉 Twój film jest gotowy!          ║
║                                                   ║
║                                                   ║
║               ┌─────────────────────┐             ║
║               │                     │             ║
║               │                     │             ║
║               │     [QR CODE]       │             ║ ← 500x500px
║               │                     │             ║
║               │                     │             ║
║               └─────────────────────┘             ║
║                                                   ║
║           📱 Zeskanuj aparatem telefonu          ║
║                                                   ║
║        booth.akces360.pl/v/AB3D5F                 ║
║                                                   ║
║                                                   ║
║     ⏱ Następny gość za: 45s                       ║
║                                                   ║
║         [⏭ Następny gość →]                       ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
```

---

## Interakcje - co się dzieje kiedy

### Scenariusz 1: Gość wchodzi i nagrywamy

```
t=0s    Tab A11+ pokazuje IDLE: "Wejdź na platformę"
t=3s    Gość stoi na platformie
t=5s    Ty klikasz START (pilot albo tablet albo OnePlus)
         │
         ├─► Tab A11+: IDLE → RECORDING
         ├─► OnePlus 13: komenda do silnika "START", kamera startuje
         ├─► Silnik fotobudki rusza (BLE)
         │
t=5-13s  Nagrywanie (8s)
         Tab pokazuje timer + progress
         Gość może zrobić wcześniejszy stop
         │
t=13s    Auto-stop
         │
         ├─► OnePlus 13 zatrzymuje nagrywanie
         ├─► Silnik zatrzymuje się
         ├─► OnePlus 13 startuje FFmpeg
         ├─► Tab A11+: RECORDING → PROCESSING
         │
t=13-23s FFmpeg processing (Snapdragon 8 Elite jest szybki)
         Tab pokazuje progress bar + "co się dzieje"
         │
t=23s    OnePlus 13 zaczyna wysyłać film do tabletu (WiFi)
         Tab A11+: PROCESSING → TRANSFER
         │
t=23-28s Transfer filmu (~30MB, WiFi lokalny, ~5s)
         │
t=28s    Tab dostał film
         Tab A11+: TRANSFER → PREVIEW
         Film autoplay
         │
t=28-45s Gość ogląda swój film, zapętla się, decyduje
         │
t=45s    Gość klika AKCEPTUJ
         │
         ├─► Tab A11+: PREVIEW → UPLOADING
         ├─► Upload do RPi (~5-10s dla 30MB)
         │
t=50s    Upload done, RPi zwraca short_id
         Tab generuje QR z URL
         Tab A11+: UPLOADING → QR_DISPLAY
         │
t=50-110s Gość skanuje QR, pobiera film, odchodzi
          Countdown 60s → 0s
         │
t=110s   Auto-reset
         Tab A11+: QR_DISPLAY → IDLE
         Ready for next guest
```

**Total: ~110 sekund = 1:50 na jednego gościa**
**Throughput: ~32 gości/godzinę**

### Scenariusz 2: Gość klika "Powtórz"

```
t=28s    Tab A11+: PREVIEW
t=35s    Gość klika POWTÓRZ (nie podoba się film)
         │
         ├─► Plik usuwany z tabletu
         ├─► Plik usuwany z OnePlus 13
         │
t=35s    Tab A11+: PREVIEW → IDLE
         Gotowy na nową próbę tego samego gościa
```

### Scenariusz 3: Błąd (WiFi padł w trakcie uploadu)

```
t=50s    Upload się rozpoczyna
t=55s    Network error
         │
         ├─► Retry 3x w tle
         ├─► Tab pokazuje: "Problem z uploadem, próbuję ponownie..."
         │
t=75s    Nadal fail
         │
         ├─► Zapis do kolejki "pending_uploads" lokalnie
         ├─► Generujemy QR z LOCALNYM URL: http://192.168.x.x:8000/temp/XXX
         ├─► Tab pokazuje QR (gość odbiera film lokalnie, z tableta!)
         ├─► W tle: retry upload co 30s
         │
t=hours  Internet wraca → pliki lecą na RPi → gość może też później pobrać z URL
```

---

## Ekran konfiguracji (Settings) - dostęp z footera IDLE

```
╔═══════════════════════════════════════════════════╗
║  ⬅ Wróć                          ⚙️ USTAWIENIA   ║
╠═══════════════════════════════════════════════════╣
║                                                   ║
║  🎬 BIEŻĄCY EVENT                                 ║
║  ┌───────────────────────────────────┐           ║
║  │ ▶ Wesele Ania & Tomek             │           ║
║  │   15.04.2026 • 23 filmy            │           ║
║  └───────────────────────────────────┘           ║
║  [+ Nowy event]  [📂 Wszystkie eventy]           ║
║                                                   ║
║                                                   ║
║  🎵 MUZYKA (domyślna)                             ║
║  ( ) Wesele Classical                             ║
║  (●) Energetic Party                              ║
║  ( ) Chill Vibe                                   ║
║  ( ) Własna (upload mp3)                          ║
║                                                   ║
║                                                   ║
║  ⚙️ PARAMETRY NAGRYWANIA                          ║
║  Długość filmu:     [ 8 sekund ▼]                ║
║  Slow-motion:       [ 2x        ▼]                ║
║  Kierunek:          [ Zmienny   ▼]                ║
║  Prędkość obrotu:   [ 7/10      ▼]                ║
║                                                   ║
║                                                   ║
║  🔗 POŁĄCZENIA                                    ║
║  🔵 Fotobudka BT:   YCKJNB-XXXX ✅ (5m)           ║
║  ⚡ OnePlus 13:     192.168.1.45 ✅              ║
║  📶 Internet:       booth.akces360.pl ✅          ║
║  [Test połączenia]                                ║
║                                                   ║
║                                                   ║
║  📊 DZISIEJSZY EVENT                              ║
║  Nagrano:  23 filmów                              ║
║  Bateria OnePlus: 67% 🔋                          ║
║  Dysk wolny: 18 GB                                ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
```

---

## OnePlus 13 UI (minimalistyczne)

Operator głównie używa tabletu. OnePlus ma prosty ekran "worker mode":

```
╔═══════════════════════════════╗
║       AKCES BOOTH RECORDER    ║
║                               ║
║    📡 Tablet: ✅ Połączony    ║
║    🔵 Silnik: ✅ Gotowy       ║
║    🔋 Bateria: 67%            ║
║    💾 Wolne: 45 GB            ║
║                               ║
║    ┌─────────────────────┐    ║
║    │                     │    ║
║    │  ▶ START RĘCZNIE    │    ║
║    │                     │    ║
║    └─────────────────────┘    ║
║                               ║
║    [Test kamery]              ║
║    [Test silnika]             ║
║    [Ustawienia]               ║
║                               ║
║    Dziś: 23 filmy             ║
║                               ║
╚═══════════════════════════════╝
```

Podczas nagrywania OnePlus pokazuje **tylko preview kamery** + progress.
Po zakończeniu wraca do tego ekranu.

---

## Kluczowe wnioski z tego flow

1. **Ty klikasz tylko START** - reszta dzieje się sama
2. **Gość ma kontrolę nad akceptacją** - nie musisz zatwierdzać każdego filmu
3. **Auto-reset po 60s** - nie musisz klikać "następny"
4. **Throughput: 32 gości/godzinę** - na 4h wesele = ~130 filmów
5. **Offline fallback** - nawet bez internetu gość dostaje film (z tabletu lokalnie)

---

## Pytania które jeszcze pozostały

<!-- Ja doprecyzuję w następnej wiadomości -->

1. Czy chcesz **ekran "Zapraszamy"** pomiędzy auto-resetem a IDLE? (np. "Dziękujemy, kolejny gość zapraszamy")
2. Czy podczas PROCESSING chcesz żeby wyświetlały się **zabawne komunikaty** ("Dodaję magię...", "Polerujemy pixele...")?
3. Czy na QR screen chcesz **podpowiedź dla gościa** jak zeskanować (animacja?)?
4. Czy gość ma być pytany o **zgodę na publikację** (jeśli chcesz filmy wrzucać na IG Akces 360)?
5. Czy chcesz **licznik gości na evencie** widoczny dla klienta (pokazujący statystyki)?
6. Czy **hasło do ekranu Settings** - żeby goście nie grzebali?
