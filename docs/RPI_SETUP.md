# RPi Setup - Auto-Restart + Monitoring

**Cel:** Raspberry Pi 5 działa 24/7, auto-restart po padzie prądu, alert gdy coś nie działa.

**Czas:** 15-20 min total

---

## 1. Auto-restart po padzie prądu (10 min)

### Sprawdź aktualny EEPROM config

```bash
sudo rpi-eeprom-config
```

Pokaże coś w stylu:
```
[all]
BOOT_UART=1
POWER_OFF_ON_HALT=1
BOOT_ORDER=0xf14
```

### Modyfikacja

```bash
sudo rpi-eeprom-config --edit
```

Otworzy się nano. Ustaw:

```
[all]
BOOT_UART=1
POWER_OFF_ON_HALT=0        # 0 = RPi włącza się po powrocie prądu
WAKE_ON_GPIO=1             # Opcjonalnie: wake przez GPIO
BOOT_ORDER=0xf14
PSU_MAX_CURRENT=5000       # Dla RPi 5 z official PSU
```

**Save:** Ctrl+O → Enter → Ctrl+X

**Apply:**
```bash
sudo reboot
```

Po reboocie sprawdź:
```bash
sudo rpi-eeprom-config | grep POWER_OFF
# Powinno pokazać: POWER_OFF_ON_HALT=0
```

### Test

**Prawdziwy test:** wyciągnij zasilanie RPi na 30s, podłącz ponownie. RPi powinien sam się włączyć bez naciskania power button.

⚠️ **UWAGA:** Upewnij się że masz szybki SSD i że boot nie przekracza 60s. Jeśli przekracza - sprawdź logi (`journalctl -b`).

---

## 2. Systemd auto-restart serwisów (5 min)

### Akces Hub service

Sprawdź obecny plik:
```bash
cat /etc/systemd/system/akces-hub.service
```

Upewnij się że masz:
```ini
[Service]
Type=simple
Restart=always          # Restart jeśli proces padnie
RestartSec=10           # Czekaj 10s przed restart
StartLimitInterval=0    # Nie limituj restartów
```

Jeśli nie - dodaj i reload:
```bash
sudo systemctl daemon-reload
sudo systemctl restart akces-hub
```

### Akces Booth service

Po Sesji 5 będziesz miał `akces-booth.service`. Upewnij się że ma te same `Restart=always` lines.

### Sprawdź status

```bash
sudo systemctl status akces-hub
sudo systemctl status akces-booth
# Oba powinny być: active (running)
```

### Test auto-restart

```bash
# Manualnie zabij proces:
sudo pkill -f gunicorn

# Poczekaj 10-15s, sprawdź:
sudo systemctl status akces-booth
# Powinno być znowu: active (running) - z nowym PID
```

---

## 3. UptimeRobot Monitoring (5 min, darmowe)

### Krok po kroku:

1. Zarejestruj się na https://uptimerobot.com (darmowy plan: 50 monitorów)
2. Dodaj monitor:
   - **Monitor Type:** HTTPS
   - **Friendly Name:** Akces Booth
   - **URL:** https://booth.akces360.pl/api/health
   - **Monitoring Interval:** 5 minut
3. Dodaj drugi monitor:
   - **Friendly Name:** Akces Hub
   - **URL:** https://hub.akces360.pl (lub Twoja domena)
   - **Monitoring Interval:** 5 minut

### Alert Contacts

Dodaj sposoby powiadomień:
- **Email:** Twój email (zawsze włączone)
- **Telegram:** utwórz bot via @BotFather, dodaj token - powiadomienia na Twój Telegram
- **SMS:** tylko w plan płatny (5 USD/mc) - opcjonalne

### Health endpoint w Akces Booth

Backend Flask musi mieć endpoint `/api/health`:

```python
@app.route('/api/health')
def health():
    try:
        # Test DB connection
        conn = sqlite3.connect(DB_PATH)
        conn.execute('SELECT 1')
        conn.close()
        
        # Test storage access
        storage_ok = os.path.exists(STORAGE_PATH)
        
        # Test disk space (warn if <5GB free)
        stat = shutil.disk_usage(STORAGE_PATH)
        free_gb = stat.free / (1024**3)
        
        return jsonify({
            'status': 'ok',
            'db': 'ok',
            'storage': 'ok' if storage_ok else 'warning',
            'disk_free_gb': round(free_gb, 2),
            'timestamp': datetime.utcnow().isoformat(),
        })
    except Exception as e:
        return jsonify({'status': 'error', 'error': str(e)}), 500
```

### Jak działa

- Co 5 min UptimeRobot pinguje `booth.akces360.pl/api/health`
- Jeśli HTTP 200 + `status: ok` → wszystko ok
- Jeśli timeout, HTTP 5xx, lub error → alert do Ciebie (email + Telegram)
- Notyfikacja przychodzi w ciągu 5-10 min od problemu

**Scenariusz użycia:**
- Pada prąd w domu
- UPS trzyma RPi przez 10 min
- Pad wrócił → RPi restartuje się (dzięki POWER_OFF_ON_HALT=0)
- Serwisy startują → health endpoint działa
- UptimeRobot wykrywa downtime 5-10 min → alert na Twój telefon
- **Wiesz że coś się działo**, nawet jeśli automatyka to naprawiła

---

## 4. Backup automatyczny (opcjonalne, 30 min)

### Backup script

`/home/pi/scripts/daily_backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR=/mnt/external-ssd/backups
DATE=$(date +%Y-%m-%d)

# Create directory
mkdir -p $BACKUP_DIR/$DATE

# Dump SQLite databases
cp /home/pi/akces-hub/db/*.db $BACKUP_DIR/$DATE/
cp /home/pi/akces-booth/db/*.db $BACKUP_DIR/$DATE/

# Archive storage (videos, overlays, music)
tar -czf $BACKUP_DIR/$DATE/booth-storage.tar.gz \
  /home/pi/akces-booth/storage/

# Delete backups older than 30 days
find $BACKUP_DIR -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \;

# Log
echo "$(date): Backup completed" >> /var/log/akces-backup.log
```

Uprawnienia:
```bash
chmod +x /home/pi/scripts/daily_backup.sh
```

### Cron job

```bash
crontab -e
```

Dodaj:
```
# Backup codziennie o 3:00 rano
0 3 * * * /home/pi/scripts/daily_backup.sh
```

### Opcjonalnie: upload do chmury

Użyj `rclone` żeby wrzucić do Google Drive / Dropbox:
```bash
# W script po tar:
rclone copy $BACKUP_DIR/$DATE gdrive:akces-backups/$DATE/
```

---

## 5. Monitoring disk space (opcjonalne, 5 min)

### Script

`/home/pi/scripts/check_disk.sh`:

```bash
#!/bin/bash
USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

if [ $USAGE -gt 85 ]; then
  # Send alert via Telegram bot
  curl -s "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d "chat_id=$CHAT_ID" \
    -d "text=⚠️ ALERT: RPi disk usage at ${USAGE}%! Clean up needed."
fi
```

### Cron co godzinę

```
0 * * * * /home/pi/scripts/check_disk.sh
```

---

## 6. Log rotation (important, 2 min)

Żeby logi nie zżerały dysku:

```bash
sudo nano /etc/logrotate.d/akces-booth
```

Zawartość:
```
/home/pi/akces-booth/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0644 pi pi
}
```

Test:
```bash
sudo logrotate -f /etc/logrotate.d/akces-booth
```

---

## 🎯 CHECKLIST FINALNY

Po ukończeniu setup:

- [ ] RPi auto-restart po power loss działa (test manual)
- [ ] Systemd services mają `Restart=always`
- [ ] UptimeRobot pokazuje zielony status (up)
- [ ] Health endpoint `/api/health` zwraca 200
- [ ] Alert Telegram/email działa (test manual)
- [ ] Backup script uruchamia się w cron
- [ ] Log rotation skonfigurowana

---

## 📞 Gdy coś się psuje - flow akcji

1. **Dostajesz alert** z UptimeRobot (Telegram/email)
2. **Sprawdzasz** - może automatyka już to naprawiła?
   - Odwiedź `booth.akces360.pl` → jeśli działa, RPi się sam zrestartował
3. **Jeśli nadal down** - logujesz się przez SSH
4. **Diagnoza**:
   ```bash
   ssh pi@raspberrypi.local
   systemctl status akces-booth
   journalctl -u akces-booth -n 50  # ostatnie 50 linii
   df -h  # wolne miejsce
   ```
5. **Naprawa** - restart service / cleanup / inne
6. **Post-mortem** - zapisz co się stało, popraw na przyszłość

---

## 💡 Jak się czujesz z tym setupem

Po wdrożeniu wszystkich 6 elementów:
- RPi **sam sobie radzi** w 95% przypadków
- Ty **wiesz o problemach zanim klient** się dowie
- Twoje dane są **bezpieczne** dzięki backupom
- Możesz **spać spokojnie** nawet gdy RPi się pieni

To jest **enterprise-grade setup** dla 20-letniego foundera. Większość firm ma gorszą infrastrukturę. 💪
