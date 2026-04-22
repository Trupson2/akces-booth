#!/bin/bash
# Nightly backup Akces Booth do Google Drive
# Wymaga: rclone remote o nazwie 'booth-cloud' skonfigurowany (rclone config)
# Cron: codziennie 2:00 AM

set -euo pipefail
LOG=/var/log/akces-booth-backup.log
REMOTE=booth-cloud:AkcesBoothBackup
BASE=/home/pi/akces-booth/backend

ts() { date '+%Y-%m-%d %H:%M:%S'; }

exec >> $LOG 2>&1
echo
echo "[$(ts)] === BACKUP START ==="

# Sprawdzi czy rclone skonfigurowany
if ! rclone listremotes 2>/dev/null | grep -q '^booth-cloud:'; then
  echo "[$(ts)] ERROR: rclone 'booth-cloud' remote niesskonfigurowany."
  echo "[$(ts)] Uruchom: rclone config (jako uzytkownik pi)"
  exit 1
fi

# 1) Videos - incremental sync (tylko nowe/zmienione)
echo "[$(ts)] Sync videos/ ..."
rclone sync "$BASE/storage/videos" "$REMOTE/videos"   --transfers 4 --checkers 8 --min-size 100k   --exclude '*.tmp' --exclude 'processing_*'   --stats 30s --stats-one-line

# 2) DB snapshot - copy z timestamp zeby miec rolling backup
SNAP="akces_booth_$(date +%Y%m%d).db"
echo "[$(ts)] DB snapshot -> $SNAP"
cp "$BASE/db/akces_booth.db" "/tmp/$SNAP"
rclone copyto "/tmp/$SNAP" "$REMOTE/db/$SNAP"
rm "/tmp/$SNAP"

# 3) Library (overlays + music generated/uploaded) - sync incremental
echo "[$(ts)] Sync library (overlays + music)..."
rclone sync "$BASE/storage/overlays" "$REMOTE/library/overlays" --min-size 10k
rclone sync "$BASE/storage/music" "$REMOTE/library/music" --min-size 100k

# 4) Stare DB snapshoty - trzymaj tylko 14 dni
echo "[$(ts)] Cleanup old DB snapshots (>14 dni)..."
rclone delete "$REMOTE/db" --min-age 14d 2>/dev/null || true

echo "[$(ts)] === BACKUP OK ==="
