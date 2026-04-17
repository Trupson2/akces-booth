#!/bin/bash
# Backup DB + storage do tar.gz (timestamped).
set -e

STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_DIR:-./backups}"
mkdir -p "$BACKUP_DIR"

OUT="$BACKUP_DIR/akces_booth_${STAMP}.tar.gz"
echo "📦 Creating $OUT"
tar -czf "$OUT" db/akces_booth.db storage/

# Rotacja: trzymamy ostatnie 14.
ls -1t "$BACKUP_DIR"/akces_booth_*.tar.gz 2>/dev/null | tail -n +15 | xargs -r rm -f

echo "✅ Done."
