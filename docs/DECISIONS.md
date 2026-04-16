# Akces Booth - Master Decision Document

**Data:** 16 kwietnia 2026
**Status:** Finalizacja przed rozpoczęciem rozwoju

---

## 🎯 MISJA PROJEKTU

Zbudować **polską alternatywę dla ChackTok/Snap360/Touchpix** - apkę do sterowania fotobudką 360 z delivery filmów przez QR. Najpierw MVP dla Akces 360, potem walidacja SaaS, potem pełen SaaS dla polskich fotobudkarzy.

---

## 🏗️ ARCHITEKTURA (FINAL)

```
┌─────────────────────────────────────────────┐
│  OnePlus 13 (NA RAMIENIU FOTOBUDKI)          │
│  App: Akces Booth Recorder                   │
│  • Stack: Flutter                            │
│  • Funkcje:                                  │
│    - BLE motor control                       │
│    - Recording 1080p 240fps slow-mo          │
│    - FFmpeg post-processing                  │
│    - WiFi transfer do Station                │
└────────────────┬────────────────────────────┘
                 │ WiFi Direct / LAN
                 ▼
┌─────────────────────────────────────────────┐
│  Samsung Tab A11+ 6/128GB (NA STATYWIE)      │
│  App: Akces Booth Station                    │
│  • Stack: Flutter                            │
│  • Funkcje:                                  │
│    - UI dla gościa (7 stanów)                │
│    - Odbiór filmu z Recorder                 │
│    - Upload na RPi                           │
│    - QR display fullscreen                   │
│    - Content library (ramki, muzyka)         │
│    - Templates eventów                       │
└────────────────┬────────────────────────────┘
                 │ HTTPS
                 ▼
┌─────────────────────────────────────────────┐
│  Raspberry Pi 5 (Twój, z Akces Hub)          │
│  • Apka 1: Akces Booth Backend (port 5100)   │
│    - Flask API                               │
│    - Upload endpoint                         │
│    - QR landing pages                        │
│    - Event galleries                         │
│  • Apka 2: Akces Booth Admin Panel (web)     │
│    - Event management                        │
│    - Content library management              │
│    - AI ramki generation (Imagen 3)          │
│    - Analytics                               │
│  • Domena: booth.akces360.pl                 │
│  • Tunneling: Cloudflare Tunnel              │
└─────────────────────────────────────────────┘
```

**Akces Booth JEST OSOBNY** od Akces Hub:
- Osobna baza SQLite
- Osobny systemd service
- Osobny port (5100 vs 5000)
- Osobna domena
- Wspólne urządzenie (RPi), ale izolowane logicznie

---

## 📦 STACK TECHNICZNY

### Mobile Apps (Recorder + Station)
- **Framework:** Flutter
- **Język:** Dart
- **State management:** Provider + ChangeNotifier
- **BLE:** flutter_blue_plus
- **Camera:** camera package (Android CameraX natywnie)
- **FFmpeg:** ffmpeg_kit_flutter (lub alternatywny działający fork)
- **WiFi transfer:** dio + local server OR WiFi Direct
- **QR:** qr_flutter

### Backend (RPi)
- **Framework:** Flask
- **Język:** Python 3.11
- **DB:** SQLite (osobna od Akces Hub)
- **Port:** 5100
- **Templates:** Jinja2 + Tailwind CSS CDN
- **AI:** Google Gemini API (Imagen 3 do generacji ramek)
- **Hosting:** Cloudflare Tunnel → booth.akces360.pl
- **Service:** systemd (nazwa: akces-booth.service)

---

## 🎨 UX FLOW (zatwierdzone decyzje)

### Start nagrywania
**3 sposoby:** pilot fizyczny, Tab A11+, OnePlus 13 (wszystkie dostępne jednocześnie)

### Timing
- Auto-stop po **8 sekundach** (domyślne, konfigurowalne)
- Możliwość wcześniejszego manualnego stop

### Preview + akceptacja
**TAK** - gość widzi film na Tab A11+, klika:
- ✅ **Akceptuj** → upload + QR
- 🔄 **Powtórz** → kasujemy, wracamy do IDLE

### Wyświetlenie QR
- **Fullscreen** na Tab A11+
- Auto-reset po **60 sekundach**
- Ekran "Dziękujemy! Kolejny gość zapraszamy 🙂" między QR a IDLE

### Podczas PROCESSING
- **Neutralne** komunikaty ("Przetwarzam film... 40%")
- Bez zabawnych tekstów (utrzymujemy profesjonalizm)

### Instrukcja skanowania QR
- **TAK** - z instrukcją dla osób starszych ("Otwórz aparat, skieruj na kod")

### Publikacja social media
- **Zgoda na publikację na Facebook @akces360**
- Checkbox w QR flow
- Post-event: publikacja w batch (nie każdy film od razu)

### Licznik filmów
- **Widoczny na IDLE** ("Dziś: 23 filmy")
- Animacja "+1 film!" po każdym nagraniu
- Buduje social proof (goście widzą że inni już nagrywali)

### Settings lock
- **4-cyfrowy PIN** dostępu do Settings
- Żeby goście nie grzebali w ustawieniach

---

## 🎵 CONTENT MANAGEMENT

### Ramki (overlays)
**Dwa sposoby dodawania:**
1. **Upload PNG** z pliku (Canva / Photoshop zrobione wcześniej)
2. **Generowanie AI** przez Imagen 3 (via Gemini API) w admin panelu web
   - Formularz: para/firma, data, styl, kolorystyka
   - 3-5 wariantów do wyboru
   - Zapisanie wybranych do biblioteki eventu

**Koszt AI:** ~30 PLN/mc (Gemini API, 250 generations)

### Muzyka
**Library na start:**
- 10-15 utworów z **Mixkit.co** (darmowe, commercial OK, bez attribution)
- Możliwość uploadu własnych MP3
- Tagi (wedding, party, chill, corporate) + auto-suggestion per event
- **⚠️ Adrian doprecyzuje po rozmowie z kolegami** jak branża faktycznie robi

### Tekst (drawtext overlay)
- Pole tekstowe w panelu eventu
- FFmpeg drawtext filter
- 2-3 style fontów (serif dla wesel, sans-serif dla corporate)
- Kolor + pozycja (top/center/bottom)

### Templates eventów
**Gotowe presety:**
- Wesele Classic (biało-złote)
- Wesele Boho (pastele)
- Wesele Rustic
- Urodziny Dziecięce
- Urodziny Dorosłe
- Corporate Event
- Custom (własne)

Template = kombinacja (ramka + muzyka + tekst + efekty + parametry silnika)

---

## 🎬 EFEKTY WIDEO

### Slow-motion (kluczowe dla fotobudki 360)
- Natywne 240fps z OnePlus 13
- Post-processing: 2x (domyślne), 4x (opcja)

### Ścieżka wideo (pipeline FFmpeg)
```
Raw video (OnePlus 13)
    ↓
Slow-mo render
    ↓
Audio ducking (oryginał -70%, muzyka -30%)
    ↓
Music mix
    ↓
PNG overlay (ramka)
    ↓
Drawtext (tekst wydarzenia)
    ↓
Final MP4 (H.264, 1080p, 30fps output)
```

### Dodatkowe efekty (later, w fazie 2)
- Boomerang (forward + reverse concat)
- Reverse (odwrócenie)
- AI background removal (MediaPipe)
- AI face effects (nakładki)

---

## ⏱️ TIMELINE MVP

**4 tygodnie total**, ale kod tylko 20-25h:

### Tydzień 1
- Dzień 1-2: **Recon BT** (sam, z Wiresharkiem)
- Dzień 3-4: **Sesja 1** (Recorder: szkielet + BLE motor control)
- Dzień 5-7: **Sesja 2** (Recorder: CameraX + nagrywanie slow-mo)

### Tydzień 2
- Dzień 1-2: **Sesja 3** (Station: szkielet + 7 stanów UI)
- Dzień 3-4: **Sesja 4** (WiFi transfer Recorder ↔ Station)
- Dzień 5-7: **Sesja 5** (Backend Flask + QR delivery)

### Tydzień 3
- Dzień 1-3: **Sesja 6** (FFmpeg pipeline: slow-mo + muzyka + overlay)
- Dzień 4-5: **Sesja 7** (Content library + Templates)
- Dzień 6-7: **Sesja 8** (Admin panel web + Imagen 3 integration)

### Tydzień 4
- Dzień 1-3: **Sesja 9** (Integration + bug fixes)
- Dzień 4-5: **Sesja 10** (Polish: licznik filmów, "dziękujemy", PIN)
- Dzień 6-7: **Testowanie** (home simulation, friends & family)

**Deliverable po 4 tyg:** Działający produkt gotowy do realnego eventu.

---

## ✅ WALIDACJA SaaS (Tydz 3-4, równolegle)

**Cel:** Zanim skończymy MVP, wiemy czy warto skalować.

### Działania
1. **Ankieta Google Forms** (10 pytań) → grupy FB fotobudkarzy
2. **Landing page** `booth.akces360.pl/early-access` z email capture
3. **Follow-up rozmowy** (Zoom/telefon) z 3-5 respondentami
4. **Research konkurencji** (pricing, features, słabości)

### Success metrics
- 50+ odpowiedzi = aktywny rynek
- 30%+ płatnych klientów = walidacja finansowa
- 20+ email subscribers = prospecci
- Real user feedback > nasza teoria

### Scenariusze
- **Pozytywny** → Fazy 2-3 (SaaS features, Stripe, multi-tenant)
- **Negatywny** → MVP zostaje dla Akces 360
- **Mieszany** → Pivot na specyficzną niszę

---

## 💰 COSTS

### Jednorazowo
- Tab A11+ 6/128GB: ~1200 PLN
- Szkło + etui + uchwyt: ~200 PLN
- **Total: ~1400 PLN**

### Miesięcznie
- Prąd RPi: 0 PLN (already running)
- Cloudflare Tunnel: 0 PLN
- Gemini API (ramki AI): ~30 PLN
- Muzyka (Mixkit darmowe): 0 PLN
- **Total: ~30 PLN/mc**

### Vs ChackTok VIP
- ChackTok: ~100 PLN/mc = 1200 PLN/rok
- Akces Booth: ~30 PLN/mc = 360 PLN/rok
- **Oszczędność: 840 PLN/rok** (i kontrola nad produktem)

**ROI MVP:** 1400 PLN / (1200 - 360) = ~1.67 roku breakeven tylko dla Was. Ale to jest fundament dla SaaS gdzie zarabiacie.

---

## 🚀 KROK PO KROKU - CO ROBISZ TERAZ

### Faza 0: Przygotowanie (ten tydzień)

1. **Zamów Tab A11+ WiFi 6/128GB** (kod: SM-X230NZAEEUE)
   - Porównaj ceny: Allegro, Morele, x-kom, Media Expert
   - Faktura VAT na Akces 360
   - Target: 1150-1250 PLN
   - Akcesoria: szkło, etui, uchwyt VESA na statyw

2. **Zapytaj kolegów z branży fotobudkowej** o muzykę
   - Jak rozwiązują licencjonowanie?
   - Skąd biorą utwory?
   - Czy mieli problemy z IG auto-mute?

3. **Reverse engineering BT** (wg RECON.md)
   - 1-2h pracy, sam
   - Wyślij mi wyniki gdy skończysz:
     - Nazwa urządzenia BT
     - Screeny z nRF Connect (services/UUIDs)
     - Plik btsnoop_hci.log
     - Notatnik z timestampami akcji

### Faza 1: Start kodowania (gdy mamy tablet + recon)

4. **Setup developer environment**
   - Flutter SDK
   - Android Studio
   - Claude Code
   - Git repo (utwórz prywatne repo, np. na GitHubie)

5. **Sesja 1 Claude Code**
   - Wrócę do Ciebie z zaktualizowanymi promptami pod MVP
   - Prompty będą bazować na wynikach BT recon (realna architektura)
   - Zaczynamy od Recorder (szkielet + BLE)

---

## 📂 DOKUMENTACJA PROJEKTU

Wszystkie pliki są w `/mnt/user-data/outputs/` (download z tej rozmowy):

1. **PLAN.md** - stary plan z pełną wersją (referencja)
2. **RECON.md** - procedura reverse engineering BT ← **używaj teraz**
3. **WORKFLOW.md** - UX flow + mockupy ekranów
4. **CLAUDE_CODE_PROMPTS.md** - stare prompty (zaktualizuję po recon)
5. **FINAL_PLAN.md** - strategia MVP + walidacja SaaS
6. **DECISIONS.md** - ten dokument (master summary)

---

## ⚡ KEY TAKEAWAYS

1. **MVP-first, not features-first** - 4 tygodnie, nie 6-8
2. **Validate SaaS early** - ankieta równolegle z kodem, decyzje na danych
3. **Leverage existing assets** - OnePlus 13, RPi, Gemini API, Akces Hub patterns
4. **Professional UX** - akceptacja gościa, QR dla seniorów, PIN lock
5. **Content flexibility** - ramki AI + upload, muzyka library + upload, templates
6. **Business-first thinking** - 30 PLN/mc vs ChackTok 100 PLN/mc, reuse licensing
7. **Niezależność** - Akces Booth standalone, nie coupled z Akces Hub

---

## 🎯 DECYZJE NIEROZSTRZYGNIĘTE

Do doprecyzowania w trakcie / po walidacji:

- [ ] Muzyka source (Mixkit vs Epidemic vs custom) - czekamy na Adrian feedback od kolegów
- [ ] Pricing SaaS (49 / 99 / 199 PLN tiers vs freemium) - walidacja pokaże
- [ ] Target market (PL only vs EU vs global) - walidacja pokaże
- [ ] Branding/nazwa finalna (Akces Booth vs SpinHub vs BudkaPL) - ankieta
- [ ] iOS version (po walidacji - ile % prospektów na iOS?)

---

**Status projektu:** ✅ Plan gotowy, czekamy na tablet + recon BT

**Next milestone:** Wyniki reverse engineering → Sesja 1 Claude Code

**Expected MVP delivery:** 4 tygodnie od startu kodowania

---

*"Zbuduj minimum, waliduj z rynkiem, skaluj w oparciu o dane."* - prawda SaaS-owa 🎯
