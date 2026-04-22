#!/bin/bash
# Usuwa stare filmy z Pi SD card po upewnieniu ze sa na Drive.
# Odpalany z crona po backup_to_gdrive.sh (2:30 AM).

set -euo pipefail
LOG=/var/log/akces-booth-cleanup.log
BASE=/home/pi/akces-booth/backend
REMOTE=booth-cloud:AkcesBoothBackup
RETENTION_DAYS=30

ts() { date '+%Y-%m-%d %H:%M:%S'; }
exec >> $LOG 2>&1
echo
echo "[$(ts)] === CLEANUP START (retention ${RETENTION_DAYS} dni) ==="

# Sprawdz czy rclone skonfigurowany (jesli nie - nie kasujemy!)
if ! rclone listremotes 2>/dev/null | grep -q '^booth-cloud:'; then
  echo "[$(ts)] ABORT: booth-cloud niesskonfigurowany, nie kasujemy lokalnie"
  exit 0
fi

# Znajdz filmy starsze niz RETENTION_DAYS
MAPFILE=$(find "$BASE/storage/videos" -type f -name '*.mp4' -mtime +$RETENTION_DAYS 2>/dev/null || true)
if [ -z "$MAPFILE" ]; then
  echo "[$(ts)] Brak plikow starszych niz ${RETENTION_DAYS} dni - nic do kasowania"
  exit 0
fi

COUNT=0
SAVED=0
while IFS= read -r LOCAL; do
  [ -z "$LOCAL" ] && continue
  REL="${LOCAL#$BASE/storage/}"
  DRIVE_PATH="$REMOTE/$REL"
  # Weryfikuj ze plik jest na Drive (rclone lsjson zwraca blad gdy nie ma)
  if rclone lsjson "$DRIVE_PATH" >/dev/null 2>&1; then
    SIZE=$(stat -c%s "$LOCAL")
    rm "$LOCAL"
    COUNT=$((COUNT+1))
    SAVED=$((SAVED+SIZE))
    echo "[$(ts)] Skasowano lokalnie (jest na Drive): $REL"
  else
    echo "[$(ts)] SKIP (jeszcze nie na Drive): $REL"
  fi
done <<< "$MAPFILE"

MB=$((SAVED/1024/1024))
echo "[$(ts)] === CLEANUP OK: $COUNT plikow, zwolniono ${MB} MB ==="
