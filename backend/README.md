# Akces Booth — Backend

Flask backend dla fotobudki Akces Booth. Chodzi na Raspberry Pi 5 (port `5100`),
osobno od Akces Hub (port `5000`).

## Funkcje

- **POST /api/upload** — Station wysyla gotowy mp4 po akceptacji.
- **GET /v/{short_id}** — landing page dla goscia (watch + download + share).
- **GET /qr/{short_id}.png** — QR on-the-fly.
- **GET /e/{access_key}** — galeria calego eventu.
- **GET /api/videos/{id}/stream** — streaming MP4 z Range request.
- **Admin panel** (`/admin`) — CRUD eventy, biblioteka ramek i muzyki,
  AI generator ramek (Gemini + Imagen 3).

## Struktura

```
backend/
├── app.py            # Flask main + blueprint registration
├── config.py         # .env loader
├── models.py         # SQLite schema + CRUD helpers
├── api/
│   ├── upload.py     # POST /api/upload (Station)
│   ├── share.py      # /v/, /qr/, /api/videos/stream, /e/
│   ├── events.py     # CRUD events
│   ├── library.py    # CRUD overlays + music
│   └── ai.py         # /api/ai/generate-overlays (Gemini + Imagen 3)
├── admin/
│   ├── auth.py       # session + @require_admin
│   └── routes.py     # admin panel HTML pages
├── templates/        # Jinja2 (Tailwind CDN)
├── static/           # CSS + JS + IMG
├── storage/          # videos / overlays / music (gitignored)
├── db/               # SQLite (gitignored)
├── scripts/setup.sh  # initial RPi setup
├── akces-booth.service  # systemd
└── .env.example
```

## Lokalne uruchomienie

```bash
cd backend
python3 -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# Edytuj .env - ustaw SECRET_KEY, ADMIN_PASSWORD, STATION_API_KEY, GEMINI_API_KEY
python app.py
```

- Landing: http://localhost:5100/
- Admin: http://localhost:5100/admin/ (login: jak w `.env`)
- Health: http://localhost:5100/healthz

## Deployment na Raspberry Pi

```bash
git clone ... /home/pi/akces-booth
cd /home/pi/akces-booth/backend
bash scripts/setup.sh
# Edytuj .env, potem:
sudo bash scripts/setup.sh    # instaluje systemd
sudo systemctl start akces-booth
sudo systemctl status akces-booth
```

Logi: `journalctl -u akces-booth -f`

## Cloudflare Tunnel (opcjonalnie)

Zeby `booth.akces360.pl` wskazywal na lokalny :5100:

```bash
cloudflared tunnel create akces-booth
cloudflared tunnel route dns akces-booth booth.akces360.pl

# ~/.cloudflared/config.yml:
#   tunnel: <TUNNEL_ID>
#   ingress:
#     - hostname: booth.akces360.pl
#       service: http://localhost:5100
#     - service: http_status:404

cloudflared tunnel run akces-booth
```

## Integracja z apka Station

W apce Station (Flutter) ustaw:
- URL uploadu: `https://booth.akces360.pl/api/upload` (lub `http://rpi-local-ip:5100/api/upload`)
- Header `X-API-Key: <STATION_API_KEY z .env>`
- Body: raw mp4 (`Content-Type: video/mp4`)
- Header `X-Filename: <orig.mp4>` (opcjonalny)

Odpowiedz (200 OK):
```json
{
  "short_id": "AB3D5F",
  "public_url": "https://booth.akces360.pl/v/AB3D5F",
  "qr_code_url": "https://booth.akces360.pl/qr/AB3D5F.png"
}
```

## AI Generator ramek

Wymaga `GEMINI_API_KEY` w `.env`. Endpoint `/api/ai/generate-overlays` uzywa
**Gemini 1.5 Pro** do napisania prompta i **Imagen 3** do wygenerowania 3 wariantow
overlayow (ramek PNG 1920x1080).

SDK prefereowane:
1. `google-genai` (nowy client, zalecany dla Imagen 3).
2. `google-generativeai` (fallback).

Jesli generacja fail → endpoint zwraca 502 z czytelnym bledem + uzytym promptem
(zeby mozna bylo recznie wygenerowac w Vertex AI Studio).

## Backup

```bash
bash scripts/backup.sh   # -> backups/akces_booth_<TS>.tar.gz, trzymamy 14 ostatnich
```

Cron:
```
0 3 * * * cd /home/pi/akces-booth/backend && bash scripts/backup.sh
```

## TODO kolejnych sesji

- **Sesja 6** — FFmpeg post-processing (slow-mo + muzyka) **na OnePlus** przed uploadem
- **Sesja 7** — Real BLE motor driver (YCKJNB reverse engineering)
- **Sesja 8** — WiFi Direct zamiast WiFi lokalnego (fallback offline)
- **Sesja 9** — Settings PIN na Station, event templates, gallery QR code
