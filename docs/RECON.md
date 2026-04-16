# RECON - Reverse Engineering ChackTok BT Protocol

**Cel:** Rozszyfrować dokładny protokół komunikacji BT między ChackTok a fotobudką YCKJNB, żeby napisać własną apkę sterującą silnikiem.

**Czas:** 1-2h (zależnie od tempa)
**Trudność:** Średnia (nic nie wymaga programowania na tym etapie)
**Potrzebne:** Android telefon, kabel USB, komputer, ChackTok zainstalowany

---

## FAZA 1: Przygotowanie (15 min)

### 1.1 Na telefonie Android

Włącz Opcje Deweloperskie:
1. Ustawienia → Informacje o telefonie → Numer kompilacji
2. Stuknij 7 razy aż zobaczysz "Jesteś deweloperem"
3. Wróć do Ustawień → System → Opcje programistyczne

Włącz w Opcjach programistycznych:
- [ ] **Debugowanie USB** (USB Debugging)
- [ ] **Włącz rejestr snoopowania HCI Bluetooth** (Enable Bluetooth HCI snoop log)
- [ ] **Nie usypiaj ekranu** (Stay awake)

⚠️ **Ważne:** Po włączeniu HCI snoop log **wyłącz i włącz Bluetooth** na telefonie - inaczej log się nie zacznie nagrywać.

### 1.2 Na komputerze

Pobierz i zainstaluj:
- [ ] **ADB (Android Debug Bridge)** - https://developer.android.com/tools/releases/platform-tools
  - Rozpakuj np. do `C:\platform-tools\`
  - Dodaj do PATH albo pracuj z tego folderu
- [ ] **Wireshark** - https://www.wireshark.org/download.html
- [ ] **JADX-GUI** - https://github.com/skylot/jadx/releases (ściągnij `jadx-gui-X.X.X-with-jre-win.zip`)
- [ ] **nRF Connect** na telefon - Sklep Play (Nordic Semiconductor)

Sprawdź ADB:
```bash
adb version
# Powinno pokazać: Android Debug Bridge version X.X.X
```

### 1.3 Połączenie telefonu z komputerem

1. Podłącz telefon USB
2. Na telefonie: wyskoczy "Zezwolić na debugowanie USB?" → **Tak, zawsze**
3. Sprawdź:
```bash
adb devices
# Powinno pokazać: <serial_number>  device
```

Jeśli nie pokazuje → sterowniki USB dla Twojego telefonu (Google "Samsung USB driver" albo podobne dla Twojej marki).

---

## FAZA 2: BT Scan (10 min)

**Cel:** Zidentyfikować typ urządzenia BT w fotobudce.

### 2.1 Test systemowy (Bluetooth Classic?)

1. Wyłącz BT na telefonie
2. Włącz fotobudkę (sam silnik)
3. Włącz BT na telefonie
4. Ustawienia → Bluetooth → "Sparuj nowe urządzenie"
5. Obserwuj listę

**Zapisz do notatnika:**
```
NAZWA URZĄDZENIA: _______________________
MAC ADDRESS: _______________________  (jeśli widoczny przy nazwie, jak nie to nRF Connect pokaże)
PIN DO PAROWANIA: _______________________  (jeśli zapytał)
```

Typowe wyniki:
- `HC-05` lub `HC-06` → Bluetooth Classic, PIN `1234` lub `0000`
- `JDY-31` → BT Classic
- `JDY-08`, `HM-10`, `BT05` → **BLE**, prawdopodobnie nie pojawi się tutaj - przejdź do 2.2
- Własna nazwa np. `ChackTok-XXXX`, `Booth360` → może być classic LUB BLE

### 2.2 Test BLE (nRF Connect)

1. Otwórz nRF Connect na telefonie
2. Zakładka **SCANNER** → naciśnij **SCAN**
3. Szukaj urządzenia które pojawia się/znika gdy włączasz/wyłączasz fotobudkę

**Zrób screena listy** i zapisz:
```
NAZWA BLE: _______________________
MAC: _______________________
RSSI: _______________________  (siła sygnału - info czy blisko)
```

4. Kliknij **CONNECT** na urządzeniu (jeśli udało się znaleźć)
5. Po połączeniu zobaczysz **GATT Services** - listę UUID-ów usług
6. **Zrób screena listy services** 

Najciekawsze serwisy których szukamy:
- `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` → **Nordic UART Service** (jackpot, łatwy protokół)
- `0000FFE0-0000-1000-8000-00805F9B34FB` → **HM-10 / CC2541** (jackpot, ASCII komendy)
- `0000FFF0-0000-1000-8000-00805F9B34FB` → **JDY-08** albo podobny (jackpot)
- Custom UUID (nie z listy powyżej) → **trzeba będzie sniffować**

### 2.3 Zapisz wynik recon fazy BT

Stwórz plik `BT_SCAN_RESULTS.md` z:
- Screenami nRF Connect
- Nazwą urządzenia
- MAC address
- Listą services/UUID
- Czy to Classic czy BLE

---

## FAZA 3: HCI Snoop - kluczowa faza (30 min)

**Cel:** Nagrać wszystkie komendy BT które ChackTok wysyła do fotobudki.

### 3.1 Przygotowanie do nagrywania

1. Sprawdź że HCI snoop log jest włączony (Opcje deweloperskie)
2. **Wyłącz BT na telefonie → włącz BT** (restart, żeby log zaczął świeże nagrywanie)
3. Zamknij wszystkie apki w tle
4. Włącz fotobudkę

### 3.2 Sesja nagraniowa z ChackTok

**WAŻNE:** Rób wszystko **powoli** i **w określonej kolejności**. Między każdą akcją **czekaj 3-5 sekund** (żeby łatwiej odczytać pakiety w logu). Zapisuj czas każdej akcji!

Otwórz notatnik, wpisz kolejność akcji + timestamp:

```
[t=0]    Uruchamiam ChackTok
[t=+5]   Klikam Connect → wybieram fotobudkę → połączono
[t=+15]  Klikam START (silnik rusza)
[t=+20]  Klikam STOP
[t=+25]  Klikam START
[t=+30]  Klikam SPEED UP (raz)
[t=+35]  Klikam SPEED UP (raz)
[t=+40]  Klikam SPEED UP (raz)  <-- 3x żeby zobaczyć wzorzec
[t=+45]  Klikam SPEED DOWN (raz)
[t=+50]  Klikam SPEED DOWN (raz)
[t=+55]  Klikam REVERSE (zmiana kierunku)
[t=+60]  Klikam REVERSE (z powrotem)
[t=+65]  Ustawiam speed na 5 (slider/input jeśli jest)
[t=+70]  Ustawiam speed na 10 (max)
[t=+75]  Ustawiam speed na 1 (min)
[t=+80]  Klikam STOP
[t=+85]  Klikam Disconnect
[t=+90]  Zamykam ChackTok
```

**Wskazówka:** Nagraj to **wideo telefonem innym** albo patrz na zegarek i notuj - dzięki temu potem wiesz "pakiet o godzinie 17:34:25 = klik SPEED UP".

### 3.3 Wyciągnięcie pliku logu

```bash
# Jest kilka możliwych lokalizacji w zależności od telefonu:

# Opcja A - najprostsza:
adb pull /sdcard/btsnoop_hci.log ./btsnoop_hci.log

# Opcja B - Samsung/nowsze Androidy:
adb pull /data/log/bt/btsnoop_hci.log ./btsnoop_hci.log

# Opcja C - przez bugreport (zawsze działa ale duży plik):
adb bugreport bugreport.zip
# Po rozpakowaniu szukaj pliku btsnoop_hci.log w FS/data/misc/bluetooth/logs/

# Jeśli żadna nie działa, spróbuj root path:
adb shell su -c "cp /data/misc/bluetooth/logs/btsnoop_hci.log /sdcard/"
adb pull /sdcard/btsnoop_hci.log
```

Jeśli nic nie wychodzi → **potrzebny root** albo używamy alternatywy z sekcji 5.

---

## FAZA 4: Analiza w Wireshark (30 min)

### 4.1 Otwarcie logu

1. Otwórz Wireshark
2. File → Open → `btsnoop_hci.log`
3. Zobaczysz morze pakietów (może być 5000+)

### 4.2 Filtrowanie - Bluetooth Classic (HC-05)

Jeśli z Fazy 2 wynikło że to Classic BT:

```
Filter: btrfcomm || btspp
```

Szukaj pakietów typu:
- `RFCOMM UIH channel=X` - to są pakiety z danymi
- Kliknij w pakiet → rozwiń dolny panel → znajdź **Data** (surowe bajty)

**Przykład:** jeśli widzisz pakiet z bajtami `41 31 0D 0A` to jest to ASCII `A1\r\n` - klasyczna komenda HC-05.

### 4.3 Filtrowanie - BLE

Jeśli to BLE:

```
Filter: btatt
```

Szukaj pakietów typu:
- `Write Request` albo `Write Command` - to są komendy wysyłane do fotobudki
- `Handle: 0x00XX` - handle charakterystyki
- `Value: XX XX XX XX` - dane komendy

### 4.4 Mapowanie komend

Teraz to co najciekawsze. Porównaj timestamp z Twojego notatnika z timestampem pakietu.

**Przykład wyniku:**

```
[t=17:34:25] Klikam START
Wireshark pokazuje pakiet o czasie 17:34:25.123:
  Handle: 0x0012
  Value: A5 01 00 00 5A
  
[t=17:34:30] Klikam STOP
Pakiet o 17:34:30.456:
  Handle: 0x0012
  Value: A5 02 00 00 59

[t=17:34:35] Klikam START
Pakiet o 17:34:35.789:
  Handle: 0x0012
  Value: A5 01 00 00 5A   <-- TEN SAM co pierwszy START! Potwierdzony pattern.

[t=17:34:40] Klikam SPEED UP
Handle: 0x0012
Value: A5 03 01 00 5F

[t=17:34:45] Klikam SPEED UP
Value: A5 03 01 00 5F    <-- Ten sam! Czyli SPEED UP to względna komenda

[t=17:34:55] Klikam REVERSE
Value: A5 04 00 00 5C

[t=17:35:05] Ustawiam speed=5
Value: A5 05 05 00 50    <-- Tutaj widać że 3-ci bajt = prędkość!

[t=17:35:10] Ustawiam speed=10
Value: A5 05 0A 00 5F

[t=17:35:15] Ustawiam speed=1
Value: A5 05 01 00 54
```

### 4.5 Rozszyfrowanie protokołu

Z powyższego przykładu (fikcyjnego) możemy wywnioskować:

```
Format komendy: [HEADER] [CMD] [PARAM1] [PARAM2] [CHECKSUM]

HEADER: A5 (zawsze)
CMD:
  01 = START
  02 = STOP
  03 = SPEED UP (relative)
  04 = REVERSE (toggle)
  05 = SET SPEED (absolute, param1 = value 1-10)
PARAM1: dla SET SPEED to wartość prędkości
CHECKSUM: prawdopodobnie XOR poprzednich bajtów albo suma modulo

Sprawdzenie XOR dla START: A5 ^ 01 ^ 00 ^ 00 = A4  -- NIE 5A, więc nie XOR
Sprawdzenie suma: A5 + 01 + 00 + 00 = A6, modulo 256 = A6  -- też nie 5A
Sprawdzenie NOT sumy: ~(A5+01) = ~A6 = 59... może tak?
  Test na STOP: ~(A5+02) = ~A7 = 58  <-- Pakiet ma 59. Różnica 1.
  Więc może: checksum = 0xFF - (sum & 0xFF) + 1 = 256 - sum
  Dla START: 256 - A6 = 5A ✓
  Dla STOP:  256 - A7 = 59 ✓
  Dla SPEED_UP: 256 - A9 = 57... ale pakiet ma 5F. Nie pasuje.
  
  Hmm, trzeba więcej analizy. Ale IDEĘ masz.
```

**Rzeczywistość:** Po 30 min analizy z Claude Code masz pełną dokumentację protokołu.

### 4.6 Zapis wyników

Stwórz plik `BT_PROTOCOL.md`:

```markdown
# YCKJNB Fotobudka - BT Protocol

## Device Info
- Type: BLE / Classic
- Service UUID: xxx
- Write Characteristic UUID: xxx
- Device name: xxx

## Commands

| Action | Hex Bytes | ASCII | Description |
|---|---|---|---|
| START | A5 01 00 00 5A | - | Uruchamia silnik |
| STOP | A5 02 00 00 59 | - | Zatrzymuje silnik |
| ... | | | |

## Checksum Algorithm
[opis jaki checksum i jak się liczy]

## Notes
[uwagi dodatkowe]
```

---

## FAZA 5: Fallback - JADX APK decompilation (30 min)

**Kiedy użyć:** Jeśli HCI snoop nie zadziałał LUB protokół jest niejasny LUB zaszyfrowany.

### 5.1 Wyciągnięcie APK z telefonu

```bash
# Znajdź package:
adb shell pm list packages | grep -i chacktok
# Powinno pokazać np. package:com.chacktok.app albo com.yckjnb.chacktok

# Znajdź ścieżkę:
adb shell pm path com.chacktok.app
# Zwróci: package:/data/app/xxx/base.apk

# Pobierz APK:
adb pull /data/app/xxx/base.apk ./chacktok.apk
```

### 5.2 Decompilation w JADX

1. Uruchom `jadx-gui.exe`
2. File → Open → wybierz `chacktok.apk`
3. JADX zdekompiluje cały kod (może zająć minutę)

### 5.3 Szukanie kluczowych klas

W lewym panelu masz drzewo klas. Szukaj:

**Po nazwach klas:**
- `BluetoothHelper`, `BtManager`, `BLEService`
- `MotorController`, `DeviceController`
- `CommandSender`, `ProtocolParser`

**Po stringach (Ctrl+Shift+F):**
- Wyszukaj `write` → metody wysyłające dane
- Wyszukaj `byte[]` → tablice bajtów (często to komendy)
- Wyszukaj `A5` albo `0xA5` → jeśli zgadłeś header w Wireshark
- Wyszukaj `UUID` → znajdziesz service/characteristic UUIDs

**Po UUID-ach z Fazy 2:**
- Jeśli znasz UUID z nRF Connect, wyszukaj go w kodzie

### 5.4 Co znajdziesz

Przykład tego co zobaczysz w dekompilowanym kodzie:

```java
public class MotorController {
    private static final byte HEADER = (byte) 0xA5;
    private static final byte CMD_START = 0x01;
    private static final byte CMD_STOP = 0x02;
    private static final byte CMD_SET_SPEED = 0x05;
    
    public byte[] buildStartCommand() {
        byte[] cmd = new byte[5];
        cmd[0] = HEADER;
        cmd[1] = CMD_START;
        cmd[2] = 0x00;
        cmd[3] = 0x00;
        cmd[4] = calculateChecksum(cmd);
        return cmd;
    }
    
    private byte calculateChecksum(byte[] data) {
        int sum = 0;
        for (int i = 0; i < data.length - 1; i++) {
            sum += data[i] & 0xFF;
        }
        return (byte) ((0x100 - (sum & 0xFF)) & 0xFF);
    }
}
```

**JACKPOT.** Masz pełną dokumentację protokołu z pierwszej ręki. Kopiujesz, adaptujesz do Dart/Flutter, koniec.

### 5.5 Jeśli kod jest zobfuskowany

Zobaczysz klasy typu `a.a.a.b()` zamiast normalnych nazw. Wtedy:
1. Szukaj po stringach (UUIDs, magic bytes)
2. Szukaj klas które implementują `BluetoothGattCallback`
3. Kompiluj po metodzie `onCharacteristicWrite` - tam są komendy

Trudniej ale do zrobienia. Z Claude Code który dostanie dekompilowany kod poradzi sobie w 10 minut.

---

## FAZA 6: Podsumowanie i deliverables

Po zakończeniu full recon powinieneś mieć:

- [ ] `BT_SCAN_RESULTS.md` - co to za urządzenie (Classic/BLE, UUID, MAC)
- [ ] `btsnoop_hci.log` - zapisany log do referencji
- [ ] `BT_PROTOCOL.md` - pełna dokumentacja komend
- [ ] Opcjonalnie: `chacktok.apk` + screeny z JADX (jeśli faza 5)
- [ ] Notatnik z sesji nagraniowej (timestampy akcji)
- [ ] Zdjęcia wnętrza fotobudki / pilota (jeśli masz dostęp)

**Wyślij mi to wszystko** (albo wklej wyniki) gdy będziesz gotowy - a wtedy siadamy do SESJI 1 w Claude Code i piszemy pierwszą wersję apki Flutter sterującej silnikiem.

---

## FAQ / Troubleshooting

**Q: HCI snoop log jest pusty**
A: Upewnij się że po włączeniu opcji w dev settings zrobiłeś restart BT (wyłącz/włącz). Niektóre telefony wymagają reboota całego urządzenia.

**Q: Wireshark pokazuje 0 pakietów**
A: Prawdopodobnie zły filtr. Spróbuj bez filtra, zobacz czy są jakieś pakiety w ogóle. Jeśli nie - plik jest uszkodzony albo pusty.

**Q: Nie mogę wyciągnąć APK - "Permission denied"**
A: Potrzebujesz roota LUB - alternatywa: pobierz APK z APKMirror/APKPure (wyszukaj "ChackTok").

**Q: W JADX wszystko jest "a.a.a" (zobfuskowane)**
A: Normalne dla chińskich apek. Użyj funkcji "Search → Find" z magic bytes albo UUID z Fazy 2.

**Q: Widzę w pakietach tylko dziwne binarne dane, nie ASCII**
A: To znaczy protokół jest binarny (nie text-based). Normalka. Patrz czy są powtarzalne wzorce w bajtach dla tych samych akcji.

**Q: Co jeśli ChackTok używa szyfrowania?**
A: Rzadko w chińskich apkach tej klasy. Ale jeśli tak - klucz jest w APK (JADX to znajdzie). Szukaj `AES`, `encrypt`, `Cipher`.

---

**Powodzenia! Jak skończysz - wyślij mi wyniki i ruszamy z kodowaniem.**
