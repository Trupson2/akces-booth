# Runbook operatora — obsługa fotobudki na evencie

Prosta instrukcja "co klikam po kolei" dla dziadka.

---

## Przed eventem (na spokojnie, dzień wcześniej)

### 1. Naładuj sprzęt (wszystkie 4 urządzenia!)

- **Raspberry Pi** — zostawić w domu, podłączyć do prądu i WiFi
- **Samsung Tab A11+** (ekran dotykowy) — ładuj do 100%, weź ładowarkę
- **OnePlus 13** (na fotobudce, nagrywający) — ładuj do 100%, weź ładowarkę
- **Fotobudka ChackTok 360** (platforma obrotowa) — pełny akumulator, weź
  kabel USB-C do ładowania w razie W

### 2. Przygotowanie eventu w panelu admin (na laptopie)

1. Wejdź: **`https://booth.akces360.pl/admin`**
2. Login: `adrian` / hasło: `Akces360Booth!`
3. Kliknij **"+ Nowy event"**
   - Nazwa: np. `Wesele Ania & Tomek`
   - Data: data wesela
   - Tekst górny: co ma się pojawić na filmie u góry (np. `Ania & Tomek`)
   - Tekst dolny: data (np. `15.06.2026`)
   - **Ramka (overlay)**: wybierz z listy (jeśli brak, kliknij "🤖 AI Ramki"
     żeby wygenerować)
   - Zaznacz ☑ **"Ustaw jako aktywny event"**
4. Kliknij **"Zapisz"**

### 3. Wygeneruj ramkę AI (jeśli trzeba)

1. W admin → **"🤖 AI Ramki"**
2. Wybierz styl (np. `Klasyczny`, `Glamour`, `Barbie`)
3. Wpisz nazwę pary (tylko do podpisu w bibliotece, nie trafi na obraz)
4. Kliknij **"Wygeneruj warianty"** → dostaniesz 3 wersje
5. W bibliotece zaznacz ✕ które słabe, zostaw 1
6. W edycji eventu wybierz tę ramkę z dropdownu i zapisz

---

## W dniu eventu (na miejscu, 30 min przed)

### 4. Rozstaw sprzęt

1. Fotobudkę postaw w docelowym miejscu (blisko gniazdka 230V)
2. Włącz ChackTok 360 przyciskiem — zapali się niebieska dioda
3. OnePlus 13 przymocuj w uchwycie na fotobudce (portrait!)
4. Tablet Samsung Tab A11+ połóż na stoliku blisko gości

### 5. WiFi — wszystko musi być w jednej sieci

Opcja **A** — sala ma WiFi:
- Połącz OnePlus i Tablet do tego samego WiFi co Pi (domowe)
- Uwaga: Pi jest w domu — jeśli sala daleko, idź do opcji B

Opcja **B** — hotspot z telefonu:
- Na swoim prywatnym telefonie włącz hotspot (udostępnianie internetu)
- Połącz **Tablet + OnePlus** do tego hotspota
- Pi sam połączy się z domu przez internet (Cloudflare Tunnel)

### 6. Odpal apki

**Tablet (Samsung Tab A11+):**
1. Odpal apkę **"Akces Booth Station"**
2. Sprawdź w prawym górnym: zielona ikona WiFi = OK, czerwona = brak
   połączenia (napraw WiFi)
3. Apka sama wyświetli Idle screen z nazwą eventu, np. `WESELE ANIA & TOMEK`

**OnePlus 13 (Recorder):**
1. Odpal apkę **"Akces Booth Recorder"**
2. W topbarze sprawdź:
   - 🔵 Bluetooth połączony (= fotobudka)
   - 🔋 Bateria — musi być >50%, inaczej podłącz ładowarkę
   - 📱 Station: zielona kropka (= Tablet w tej samej sieci)
3. Pod spodem zobaczysz **"AKTYWNY EVENT: Wesele Ania & Tomek"** — to
   potwierdzenie że Station przesłał konfigurację

### 7. Test próbny (1 nagranie)

1. Na OnePlus kliknij duży zielony **START**
2. Dotknij czerwonego kółka — rozpocznie się 8-sekundowe nagranie
3. Po zakończeniu film automatycznie wędruje na tablet
4. Na tablecie pojawi się QR — zeskanuj go telefonem, sprawdź czy film
   jest OK (portrait, ramka, tekst)
5. Jeśli OK — gotowe na gości

---

## Podczas eventu

### Gość podchodzi do fotobudki

1. Kliknij **"START"** na tablecie (duży przycisk)
2. Tablet pokazuje instrukcje dla gościa (stań na platformie, uśmiech)
3. Fotobudka zaczyna się kręcić, OnePlus nagrywa 8s
4. Po nagraniu tablet pokazuje **QR code**
5. Gość skanuje QR swoim telefonem → otwiera film → może pobrać / udostępnić

### Jeśli coś nie działa

**Nic nie nagrywa się po kliknięciu START:**
- Sprawdź czy OnePlus w Recorder app jest "online" (zielona kropka STATION)
- Jeśli nie, restart Recorder app (zamknij, otwórz ponownie)

**Fotobudka się nie kręci:**
- Sprawdź Bluetooth na OnePlus — ikona musi być zielona
- Wyłącz i włącz fotobudkę przyciskiem

**Film wyszedł zły (np. osoba pomiędzy ornamentami):**
- W admin panelu: Events → Wesele Ania & Tomek → najedź na kartę filmu
  → kliknij czerwony ✕ (usuń) → gość nagrywa jeszcze raz

**Tablet się rozładował:**
- Podłącz ładowarkę, apka sama wróci online po chwili

**Panika (nic nie działa):**
- Zamknij i otwórz ponownie Station na tablecie
- Zamknij i otwórz ponownie Recorder na OnePlus
- W 99% przypadków to załatwia sprawę
- Jeśli nie — zadzwoń do Adriana

---

## Po evencie (wieczorem)

### 8. Zbierz sprzęt

1. Wyłącz fotobudkę ChackTok 360
2. Zabierz tablet + OnePlus + wszystkie ładowarki
3. Sprzęt do ładowania w domu

### 9. Backup automatyczny (nic nie robisz)

- Pi w domu sam robi backup na Twój Google Drive codziennie o 2:00 w nocy
- Tablet i OnePlus trzymają filmy tylko jako cache
- Na stronie `booth.akces360.pl/admin` możesz oglądać wszystkie nagrania
  zawsze (serwowane z Pi, z Drive jako backup)

---

## Ważne numery / linki

- Admin panel: `https://booth.akces360.pl/admin`
- Login: `adrian` / `Akces360Booth!`
- Pi IP lokalne (jeśli awaryjnie trzeba SSH): `192.168.100.200`
- SSH: `ssh -i ~/.ssh/pi_key pi@192.168.100.200`

## Panika-zero — numery awaryjne

Jeśli cały Pi padł przez event (np. zasilanie):
- Pi ma HW watchdog — sam się zresetuje w <1 min
- Po reboocie Pi odpali Flask backend automatycznie (systemd)
- Jeśli po 5 min dalej offline — zadzwoń do Adriana

Adrian: [Twój numer]
