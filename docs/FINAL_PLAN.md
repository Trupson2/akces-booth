# Akces Booth - Realny Plan SaaS (MVP + Walidacja)

**Strategia:** Build tylko co potrzebne, waliduj rynek równolegle, skaluj w oparciu o dane.

**Timeline:** 6 tygodni total (zamiast 6 tygodni "wishlist")

---

## TYDZIEŃ 1-3: MVP dla Akces 360

**Cel:** Działający produkt dla WAS, testowany na rodzinie/Kurs Zwroty community.

### Scope MVP (absolutne minimum):

#### Apka Recorder (OnePlus 13)
- [x] Sterowanie silnikiem BLE (po reverse engineering)
- [x] Nagrywanie kamerą natywnie (Android CameraX, 240fps slow-mo)
- [x] **Post-processing: tylko slow-mo rendering** (bez muzyki, bez logo - w fazie 2)
- [x] WiFi transfer filmu do tableta

#### Apka Station (Tab A11+)
- [x] **3 stany:** IDLE → RECORDING → QR_DISPLAY (bez preview, bez akceptacji)
- [x] Auto-upload na RPi
- [x] QR fullscreen + "Zeskanuj aparatem"
- [x] Auto-reset 60s

#### Backend (Flask na RPi)
- [x] `/api/upload` endpoint
- [x] `/v/{short_id}` landing page (basic, z video player)
- [x] QR generator

### Co ODPADA z MVP:
- ❌ FFmpeg muzyka/logo/overlay
- ❌ AI effects (background removal, face)
- ❌ Preview z akceptacją gościa
- ❌ Event manager (jeden zahardkodowany event)
- ❌ Licznik "+1 film"
- ❌ PIN do Settings
- ❌ Ekran "Dziękujemy"
- ❌ Facebook integration
- ❌ Licensing system
- ❌ Multi-tenant

**Dlaczego:** Każda z tych rzeczy to 2-4h pracy. Łącznie ~30h. Zero z nich nie jest potrzebne do **nagrania i dostarczenia filmu gościowi**. Dodamy w Fazie 2 na podstawie feedback.

### Sesje Claude Code (MVP):

| Sesja | Cel | Czas |
|-------|-----|------|
| 0 | Reverse engineering ChackTok BT | 2h (sam, Wireshark) |
| 1 | Recorder: szkielet + BLE motor control | 2-3h |
| 2 | Recorder: CameraX + slow-mo recording | 2-3h |
| 3 | Station: szkielet + WiFi receiver | 2h |
| 4 | Station: UI 3 stany (IDLE/REC/QR) | 2h |
| 5 | Backend Flask na RPi + landing page | 2h |
| 6 | Integration + QR flow end-to-end | 2h |
| 7 | Testowanie + bug fixing | 2h |

**Total: ~15h pracy** (vs 60h poprzedniego planu)

### Deliverable po 3 tygodniach:
Działający setup który nagrywa, przesyła, wyświetla QR. **Możesz zrobić demo na Kurs Zwroty live**, pokazać kolegom z grupy FB, testować u rodziny.

---

## TYDZIEŃ 3-4: Walidacja SaaS (równolegle)

**Cel:** Zanim zainwestujemy w SaaS features, sprawdzamy czy ludzie zapłacą.

### Działania (nie-techniczne):

#### 1. Ankieta w grupach FB
Znajdź 3-5 polskich grup fotobudkarzy na Facebooku. Przykłady:
- "Fotobudki 360 Polska"
- "Fotobudki - Wymiana Doświadczeń"
- "Branża Eventowa Polska"
- Plus grupy z którymi masz kontakt przez Kurs Zwroty

**Pytania ankiety (Google Forms, max 10 pytań):**

1. Jaką apką sterujesz fotobudką? (ChackTok / Snap360 / Touchpix / Inne)
2. Ile płacisz za subskrypcję / mc? (lub rocznie)
3. Co Cię najbardziej frustruje w obecnej apce?
4. Czy zmieniłbyś apkę jeśli miałaby lepsze X?
5. Co byłby "must have" w nowej apce? (multiple choice)
   - Polska wersja językowa
   - Lepsze muzyki licencjonowane
   - Tańsza subskrypcja
   - Better QR delivery
   - Automatyczne wysyłanie na FB/IG
   - Własne branding/logo
   - Integracja z systemem rental (CRM)
6. Ile byłbyś gotów zapłacić za nową apkę? (zakresy: 30/50/80/100+ PLN/mc)
7. Jakiego urządzenia używasz (iPad/iPhone/Android/tablet)?
8. Ile eventów robisz w miesiącu?
9. Gdzie szukasz info o fotobudkach? (YT, FB, Instagram...)
10. Kontakt: zgoda na info gdy apka będzie gotowa? (opcjonalny email)

#### 2. Analiza konkurencji (1h research)
Zrób screeny / zapisz:
- ChackTok pricing tiers
- Snap360 pricing (pro vs diamond)
- Touchpix pricing
- Feature comparison matrix

#### 3. Landing page "coming soon"
Prosta strona `booth.akces360.pl/landing` z:
- Hero: "Polska alternatywa dla ChackTok - mniejsza cena, lepszy support"
- Screens prototypu (mockupy z WORKFLOW.md wystarczą)
- "Zapisz się na early access" - formularz email
- Social proof (po ankiecie): "X% fotobudkarzy szuka alternatywy dla ChackTok"

### Success metrics walidacji:
- **50+ odpowiedzi** na ankietę = rynek jest aktywny
- **30%+ gotowych zapłacić 50+ PLN/mc** = walidacja cenowa
- **20+ email subscribers** na landing = realni prospecti
- **3-5 follow-up rozmów** z respondentami (Zoom/telefon)

### Scenariusze wyników:

**Scenariusz A: Walidacja pozytywna** → Idziemy w Fazę 3 (SaaS features)
**Scenariusz B: Walidacja negatywna** → MVP zostaje dla Akces 360, nie tracimy więcej czasu
**Scenariusz C: Mieszane sygnały** → Pivotujemy na specyficzną niszę (np. tylko polski rynek, tylko wesela)

---

## TYDZIEŃ 5-6: SaaS features (data-driven)

**Cel:** Dodajemy tylko te features które walidacja pokazała jako ważne.

### Priorytety (przykład - realny po ankiecie):

**Prawdopodobnie TOP 3 z ankiety:**
1. Polska wersja (łatwe)
2. Tańsza subskrypcja (model pricing)
3. Lepsze muzyki licencjonowane

### Sesje Claude Code (SaaS):

| Sesja | Cel | Czas |
|-------|-----|------|
| 8 | FFmpeg: muzyka + logo + overlay (jeśli w TOP 3) | 3h |
| 9 | Licensing system (z Akces Hub reuse) | 2h |
| 10 | Multi-tenant: każdy klient = osobny event/branding | 2h |
| 11 | Stripe integration (płatności) | 2h |
| 12 | Landing / pricing page + Facebook Ads | 2h |
| 13 | Feature X z ankiety (elastyczne) | 2h |

**Total: ~13h pracy** (realistyczne)

---

## Finalny timeline

```
Tydzień 1:  [========] MVP Recorder (BT recon + apka)
Tydzień 2:  [========] MVP Station + Backend
Tydzień 3:  [====]     Bug fixing + testowanie u rodziny
            [====]     WALIDACJA: ankieta, research konkurencji
Tydzień 4:  [========] WALIDACJA: follow-up, analiza danych
Tydzień 5:  [========] SaaS features (co potwierdziła ankieta)
Tydzień 6:  [====]     Polish + Stripe + pricing
            [====]     Launch prep: landing, Facebook Ads
```

**6 tygodni, ale z różnym rozłożeniem:**
- **Kod: ~28h** (sensowniejsze niż 60h losowych features)
- **Walidacja: ~15h** (non-coding, ale kluczowe dla biznesu)
- **Launch prep: ~10h**

---

## Kluczowe decyzje biznesowe

### Model pricing (do walidacji)
**Przykłady jakie rozważyć:**
- **Freemium:** 10 filmów / mc za 0 PLN, potem 49 PLN/mc unlimited
- **Jednorazowo:** 499 PLN dożywotnio (konkurencyjnie vs ChackTok 100/mc)
- **Tiered:** Basic 49 / Pro 99 / Agency 199 PLN/mc (jak Snap360)

Walidacja Ci powie co ludzie preferują.

### Target market (do walidacji)
**Opcje:**
- Polska tylko (lokalny support, język = przewaga)
- Międzynarodowo (ale konkurujesz z Touchpix/Snap360 global)
- Nisza (np. tylko eventy weselne, tylko corporate)

### Branding
- **"Akces Booth"** - związek z Akces 360/Hub, Polish roots
- **"SpinHub"** - globalny feel, SaaS-y
- **"BudkaPL"** - hiper-lokalny, polski rynek

Przetestuj w ankiecie którą nazwę wolą.

---

## Co robimy ZARAZ (ten tydzień)

### Krok 1: Reverse engineering (1-2h)
Bez tego nie ruszymy apki. Wykonaj recon z `RECON.md` - sniff BT + nagraj sesję ChackTok. To można zrobić samodzielnie, nie potrzebujesz Claude Code.

### Krok 2: Ankieta (2-3h)
Stwórz Google Form. Zacznij od próbnej wersji na 5 znajomych, fix-uj pytania, potem wrzuć do grup FB.

### Krok 3: Zamówienie Tab A11+
Kup. Tydzień 1 MVP mogę zacząć nawet bez niego (emulator).

### Krok 4: Pierwsza sesja Claude Code
Gdy masz wyniki recon → SESJA 1 (szkielet Recorder + BLE).

---

## Kluczowa zasada: każda decyzja w oparciu o dane

**Złe pytanie:** "Co jeszcze dorzucić do apki?"
**Dobre pytanie:** "Co mówią użytkownicy / klienci / rynek?"

Flutter vs Kotlin? Decyzja na podstawie: ile % respondentów ankiety ma iOS?
Muzyka vs AI effects? Decyzja na podstawie: co bardziej frustruje w ChackTok?
Pricing? Decyzja na podstawie: co odpowiedzieli w ankiecie?

To jest dojrzałe podejście SaaS. **Widzę że masz to wbudowane** (sposób jak iterujesz Akces Hub), i warto przenieść do fotobudki.

---

## Podsumowanie

- **6 tygodni zamiast 6 tygodni** - ten sam czas, ale 50% kodu + 50% walidacji
- **Mniej ryzyko** - nie budujemy SaaS który nikt nie kupi
- **Więcej pewności** - decyzje na podstawie danych, nie zgadywania
- **Akces 360 dostaje MVP** w 3 tygodnie (używacie od razu)
- **SaaS prep** zaczyna się z walidacją, nie ze spekulacją

To jest plan zgodny z jak **naprawdę** buduje się SaaS-y. 🎯
