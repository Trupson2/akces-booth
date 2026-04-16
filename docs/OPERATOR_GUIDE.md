# Akces Booth - Operator Guide

**Dla kogo:** Adrian + dziadkowie (operatorzy fotobudki)
**Kiedy:** Przed każdym eventem + w trakcie
**Aktualizacja:** Na bieżąco po każdym evencie

---

## 🎒 PAKUNEK NA EVENT (checklista transportowa)

### Sprzęt główny
- [ ] Fotobudka YCKJNB (platforma + ramię)
- [ ] Pilot do fotobudki (z bateriami!)
- [ ] **OnePlus 13** (Recorder) + ładowarka USB-C
- [ ] **Samsung Tab A11+** (Station) + ładowarka USB-C
- [ ] **Stary telefon jako hotspot** + ładowarka + karta SIM z data

### Akcesoria
- [ ] Statyw do tableta
- [ ] Uchwyt do telefonu na ramię fotobudki
- [ ] Power bank 20000mAh PD (min 2 szt - jeden dla Tab, drugi dla telefonu-hotspot)
- [ ] Kable USB-C długie (2m+) × 3
- [ ] Wentylator USB mini (dla OnePlus 13 jeśli się grzeje)
- [ ] Listwa zasilająca 5-gniazdkowa + przedłużacz 5m

### Backup / awaryjne
- [ ] Bateria zapasowa do pilota (AAA × 2)
- [ ] Zapasowy telefon z ChackTok (fallback gdy nasza apka padnie)
- [ ] Kartka papieru + pisak (do zapisywania problemów)

### Dokumenty klienta
- [ ] Umowa
- [ ] Logo klienta (na pendrive jeśli trzeba wrzucić last minute)
- [ ] Numer telefonu klienta (na sytuacje awaryjne)

---

## 🏠 CHECKLIST PRZED WYJAZDEM Z DOMU

### Dzień przed eventem (wieczorem)

- [ ] **Ładowanie wszystkiego**:
  - OnePlus 13 → 100%
  - Tab A11+ → 100%
  - Telefon-hotspot → 100%
  - Power banki → 100%

- [ ] **Test sprzętu w domu**:
  - Uruchom apki, sprawdź połączenia BT + WiFi
  - Nagraj 1 testowy film
  - Sprawdź czy QR otwiera się na telefonie
  - Czy plik leci do RPi (sprawdź w admin panelu)

- [ ] **Sprawdź RPi**:
  - Odwiedź `booth.akces360.pl` z telefonu
  - Odwiedź `/admin/` - sprawdź że aktywny event jest poprawny
  - Czy jest wystarczająco wolnego miejsca (`df -h`)?

- [ ] **Sprawdź event w admin panelu**:
  - Nazwa eventu poprawna?
  - Ramka przypisana?
  - Muzyka przypisana?
  - Tekst (imiona, data)?
  - Aktywny (is_active=1)?

- [ ] **Sprawdź kartę SIM hotspot**:
  - Jest pakiet danych?
  - Ile GB zostało?
  - Czy internet działa (ping z tableta)?

### Rano w dniu eventu (2h przed wyjazdem)

- [ ] Jeszcze raz ładuj wszystko (topping up)
- [ ] Zabierz wszystko ze sprzętu z checklisty
- [ ] Sprawdź Google Maps - zjazdy, korki
- [ ] Zadzwoń do klienta - potwierdzenie adresu, godziny, preferencji

---

## 🎪 SETUP NA MIEJSCU (15-20 min)

### Krok 1: Rozstaw sprzęt
1. Fotobudka na środku wyznaczonego miejsca (sprawdź z klientem gdzie)
2. Statyw z Tab A11+ obok, ~1-2m od fotobudki
3. Stary telefon-hotspot w kieszeni / na statywie (obok Tab)
4. Power banki podpięte gdzie się da

### Krok 2: Włącz po kolei
1. Telefon-hotspot → WŁĄCZ HOTSPOT 
   - Nazwa sieci: `AkcesBooth` (stała nazwa, żeby Tab się auto-łączył)
   - Hasło: `akces2026` (cokolwiek stałego)
2. Tab A11+ → poczekaj aż się połączy z hotspotem (top-right: ikona WiFi)
3. OnePlus 13 → poczekaj aż się połączy z hotspotem
4. Fotobudka: włącz zasilanie silnika

### Krok 3: Sprawdź połączenia
1. Tab A11+ / Akces Booth Station
   - Status powinien być: 🔵✅ BT, 📡✅ Recorder, 📶✅ Internet
   - Jeśli którekolwiek ❌ → troubleshooting (niżej)
2. OnePlus 13 / Akces Booth Recorder
   - Status: 📡✅ Tablet, 🔵✅ Silnik
3. Test click START → motor powinien ruszyć, nagrywanie start

### Krok 4: Test nagrania (sam, bez gości)
1. Zrób 1 testowy film
2. Sprawdź że przechodzi cały pipeline
3. Sprawdź że QR się generuje
4. Zeskanuj QR swoim telefonem, sprawdź że film się otwiera
5. Pobierz film
6. Sprawdź w admin panelu że film jest w bazie

**Jeśli test nie przechodzi - NIE RÓB EVENTU Z NIM, użyj ChackTok jako backup.**

### Krok 5: Gotowość
- Ustaw Tab A11+ w trybie IDLE ("Wejdź na platformę")
- Ukryj kable za fotobudką (estetyka)
- Przygotuj instrukcję wizualną dla gości (opcjonalnie: karteczka "3 kroki")
- Stań obok, poczekaj na gości

---

## ⏱️ PODCZAS EVENTU

### Każdy gość - twoja rola
1. Gość podchodzi → zachęć: "Wejdź na platformę, zrobimy film 360!"
2. Gość wchodzi
3. **Klikasz START** (z pilota lub tableta)
4. Czekasz 8s + post-processing
5. Gość ogląda swój film na Tab, klika Akceptuj lub Powtórz
6. Jeśli Akceptuj → wyświetla się QR → gość skanuje → ma film
7. Auto-reset po 60s → gotowe na następnego

### Co monitorujesz
- **Bateria Tab A11+** (min 20%, jeśli niżej - podłącz do power banku)
- **Bateria OnePlus 13** (min 30%, jeśli niżej - podłącz)
- **Bateria telefonu-hotspota** (min 30%)
- **Licznik filmów** (jeśli "Dziś: 50 filmów" i dalej idzie - fajnie)
- **Data użyta** (check telefon-hotspot co godzinę, czy nie kończy się pakiet)

### Co robisz gdy przerwa
- Mała przerwa: podładuj urządzenia
- Duża przerwa: sprawdź czy wszystkie połączenia dalej działają
- Kolacja gości: sprawdź kartę SIM, może upgrade pakietu

---

## 🔧 TROUBLESHOOTING - co zrobić gdy X

### Problem: Tab A11+ pokazuje "Station nie połączona z Recorder"
1. Sprawdź czy OnePlus 13 ma włączone WiFi
2. Sprawdź czy oba są na tej samej sieci (`AkcesBooth`)
3. Zrestartuj obie apki
4. Jeśli dalej - zrestartuj hotspot

### Problem: Silnik fotobudki nie reaguje
1. Sprawdź czy pilot działa (naciśnij ręcznie)
2. Jeśli pilot ok → problem z BT → restart Recorder
3. Jeśli pilot nie działa → bateria pilota / silnika?
4. Ostateczność: **użyj tylko pilota ręcznie + ChackTok**

### Problem: Film nie uploaduje się na RPi
1. Sprawdź internet na Tab (otwórz przeglądarkę, wejdź na dowolną stronę)
2. Jeśli internet ok → problem z RPi → sprawdź `booth.akces360.pl` z telefonu
3. Jeśli RPi offline → **Station przełącza w tryb offline** (film zapisany lokalnie, QR z lokalnym URL)
4. Gość ściąga film z Tab, po evencie dossync się na RPi

### Problem: OnePlus 13 się przegrzewa
1. Wyłącz hotspot (jeśli na nim działa) - przełącz na telefon-hotspot
2. Mini wentylator USB blisko telefonu
3. Power bank + zasilanie cały czas (żeby nie doładowywał w pośpiechu)
4. Ostateczność: 15 min przerwy, pozwól mu ostygnąć

### Problem: Tab A11+ padła bateria
1. Power bank podłącz natychmiast
2. Tab A11+ ładuje się podczas użycia (może być wolniej ale działa)
3. Ostateczność: wyłącz na chwilę, podładuj do 30%, restart

### Problem: Gość nie umie zeskanować QR
1. Pomóż mu: "Otwórz aparat w telefonie... skieruj na kod... stuknij w link"
2. Alternatywa: na Tab jest też URL tekstowy, może go przepisać
3. Alternatywa 2: "Dam ci film na WhatsApp" (weź numer, po evencie wyślesz)

### Problem: Wszystko pada totalnie
1. Spokój, nie panikuj
2. Przełącz na ChackTok (który masz jako backup)
3. Reszta eventu z ChackTok (klient zadowolony, wyjaśnisz później że mieliśmy upgrade)
4. Po evencie: debugowanie, naprawy

---

## 📊 PO EVENCIE

### Natychmiast (na miejscu)
- [ ] Sprawdź że wszystkie filmy są na RPi (admin panel: liczba = liczba filmów z eventu)
- [ ] Jeśli brakuje → sprawdź lokalny cache na Tab → sync manually

### Dzień po evencie
- [ ] Napisz klientowi: "Dziękujemy za event. Link do galerii: booth.akces360.pl/gallery/XXX"
- [ ] Sprawdź statystyki w admin panelu (ile pobrań, najpopularniejsze filmy)
- [ ] Zapisz feedback od klienta

### Po tygodniu
- [ ] Backup filmów na zewnętrzny dysk
- [ ] Usunięcie eventu z aktywnych (is_active=0)
- [ ] Refleksja: co zadziałało, co nie, co poprawić

---

## 📞 NUMERY AWARYJNE

- **Sam siebie** (backup plan): ChackTok zainstalowany, gotowy do uruchomienia
- **Klient eventu**: (zapisz w telefonie)
- **Support Claude** (ja): nowa rozmowa, załącz logs

---

## 🎓 TIPS OD WETERANÓW (lessons learned)

- **Zawsze przyjeżdżaj 1h wcześniej** - setup + test zajmuje 20 min, bufor na problemy = 40 min
- **Miej zapasową kartę SIM** - gdy pakiet wyczerpie się w połowie eventu
- **Power banki zawsze podłączone** - nie ładuj w pośpiechu między gośćmi
- **Gdy coś pada, uśmiechaj się** - goście nie wiedzą że miało być lepiej
- **Ciche sygnały z klientem** - jeśli klient dyskretnie mówi "wszystko ok?" - bądź szczery
- **Dokumentuj problemy** - zapisz na kartce co poszło źle, napraw w przyszłości

**Udanych eventów! 🎉**
