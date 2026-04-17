#!/bin/bash
# Initial setup Akces Booth Backend na Raspberry Pi 5.
# Uruchom z katalogu backend/.
set -e

echo "🚀 Akces Booth Backend setup"

# Sanity: Python 3.11+
if ! command -v python3 &> /dev/null; then
  echo "❌ python3 not found. Install: sudo apt install python3 python3-venv python3-pip"
  exit 1
fi

# Virtual env
if [ ! -d "venv" ]; then
  echo "📦 Creating venv..."
  python3 -m venv venv
fi

source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Dirs
mkdir -p storage/videos storage/overlays storage/music db db/sessions

# .env
if [ ! -f ".env" ]; then
  echo "📋 Copying .env.example → .env (edit it!)"
  cp .env.example .env
  echo "❗ Edit .env before starting: SECRET_KEY, ADMIN_PASSWORD, STATION_API_KEY, GEMINI_API_KEY"
fi

# DB init (idempotentne)
python3 -c "from models import init_db; from config import Config; init_db(Config.DB_PATH); print('✅ DB ready at', Config.DB_PATH)"

# Systemd (opcjonalne - uruchom z sudo)
if [ -f "akces-booth.service" ] && [ "$(id -u)" = "0" ]; then
  cp akces-booth.service /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable akces-booth
  echo "✅ Systemd service installed. Start: sudo systemctl start akces-booth"
else
  echo "ℹ️  Systemd service NIE zainstalowany. Uruchom: sudo bash scripts/setup.sh"
  echo "ℹ️  Albo recznie: sudo cp akces-booth.service /etc/systemd/system/"
fi

echo ""
echo "✨ Setup complete."
echo "Start dev: python3 app.py"
echo "Start prod: sudo systemctl start akces-booth"
