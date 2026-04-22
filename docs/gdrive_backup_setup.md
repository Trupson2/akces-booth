# Google Drive Backup — setup (5 min, jednorazowo)

Automatyczna kopia zapasowa nagrań + DB + biblioteki ramek/muzyki z Pi
na Twój osobisty Google Drive.

## Co już jest gotowe na Pi

- Skrypt: `/home/pi/akces-booth/scripts/backup_to_gdrive.sh`
- Cron: codziennie o 2:00 w nocy
- Log: `/var/log/akces-booth-backup.log`
- rclone v1.60.1 zainstalowany

## Co musisz zrobić (OAuth w przeglądarce, jednorazowo)

### 1. SSH na Pi jako `pi`

```bash
ssh -i ~/.ssh/pi_key pi@192.168.100.200
```

### 2. Uruchom `rclone config`

```bash
rclone config
```

Wybierz opcje po kolei:

- `n` → **New remote**
- Nazwa: **`gdrive`** (musi być dokładnie ta nazwa, bo skrypt tego używa)
- Storage: wpisz **`drive`** (Google Drive)
- `client_id` — zostaw puste (Enter, użyje domyślnego rclone)
- `client_secret` — zostaw puste (Enter)
- Scope: **`1`** (Full access)
- `service_account_file` — zostaw puste (Enter)
- `Edit advanced config?` — **`n`**
- `Use auto config?` — **`n`** (bo Pi nie ma GUI)
- Rclone pokaże URL i komendę `rclone authorize "drive"`
- Skopiuj tę komendę, **uruchom na swoim laptopie** (nie na Pi)
- W przeglądarce zaloguj się na Twoje Google → zezwól rclone
- W terminalu laptopa dostaniesz token (długi JSON)
- Wklej token z powrotem w terminalu Pi
- `Configure this as a Shared Drive?` — **`n`** (chyba że masz Workspace)
- `Yes this is OK` — **`y`**
- `q` → Quit

### 3. Test połączenia

```bash
rclone listremotes
# Powinno pokazać: gdrive:

rclone mkdir gdrive:AkcesBoothBackup
rclone ls gdrive:AkcesBoothBackup
# Puste, ale bez błędu = działa
```

### 4. Uruchom pierwszy backup ręcznie (sprawdzić że działa)

```bash
/home/pi/akces-booth/scripts/backup_to_gdrive.sh
tail -20 /var/log/akces-booth-backup.log
```

Pierwszy backup może potrwać **10-30 min** (zależnie od tego ile masz już
nagrań w `storage/videos/`). Kolejne będą szybkie (incremental — tylko
nowe pliki).

### 5. Weryfikacja

W przeglądarce → Twój Google Drive → folder **`AkcesBoothBackup/`**
z podfolderami:

- `videos/` — wszystkie MP4
- `db/akces_booth_YYYYMMDD.db` — snapshoty DB (ostatnie 14 dni)
- `library/overlays/` — wygenerowane/uploadowane ramki
- `library/music/` — utwory

## Koszty Drive

- 15 GB **za darmo** (domyślne Google) — starczy na ~750 filmów po 20 MB
- 100 GB = **40 zł/rok** (~3 zł/mc)
- 200 GB = **120 zł/rok** (~10 zł/mc) — sensowne na 4 lata eventów
- 2 TB = **400 zł/rok** (~33 zł/mc)

Dla typowego wesela **200-400 filmów × 20 MB = 4-8 GB/event**.

## Co dalej

Po setupie rclone:

- **Cron działa sam** — każda noc 2:00 synchro
- **Brak sprzętu** (nie trzeba M.2)
- **Dostęp z telefonu/laptopa** przez drive.google.com
- **Pi SD 64GB** wystarczy jako cache (starsze lokalnie czyszczone
  automatycznie po upload do Drive — do dopisania w
  `cleanup_old_local.sh` osobno)

## Debug

Log backupu:
```bash
tail -50 /var/log/akces-booth-backup.log
```

Manual trigger:
```bash
/home/pi/akces-booth/scripts/backup_to_gdrive.sh
```

Status rclone:
```bash
rclone config show gdrive
rclone about gdrive:    # pokaze uzyte/wolne miejsce na Drive
```
