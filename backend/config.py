"""Konfiguracja aplikacji - zaladowana z .env."""
from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()


def _env(name: str, default: str | None = None, *, required: bool = False) -> str | None:
    val = os.environ.get(name, default)
    if required and not val:
        raise RuntimeError(f"Missing required env var: {name}")
    return val


def _int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


class Config:
    SECRET_KEY = _env("SECRET_KEY", "dev-secret-change-me")

    # Storage
    BASE_DIR = Path(__file__).resolve().parent
    STORAGE_PATH = Path(_env("STORAGE_PATH", str(BASE_DIR / "storage")) or "storage")
    DB_PATH = Path(_env("DB_PATH", str(BASE_DIR / "db" / "akces_booth.db")) or "db/akces_booth.db")

    MAX_UPLOAD_SIZE = _int("MAX_UPLOAD_SIZE", 524_288_000)  # 500 MB

    # Network
    PORT = _int("PORT", 5100)
    HOST = _env("HOST", "0.0.0.0") or "0.0.0.0"
    PUBLIC_BASE_URL = (_env("PUBLIC_BASE_URL", "http://localhost:5100") or "").rstrip("/")

    # AI
    GEMINI_API_KEY = _env("GEMINI_API_KEY")

    # Auth
    ADMIN_USERNAME = _env("ADMIN_USERNAME", "adrian") or "adrian"
    ADMIN_PASSWORD = _env("ADMIN_PASSWORD", "change-me") or "change-me"
    STATION_API_KEY = _env("STATION_API_KEY", "dev-station-key") or "dev-station-key"

    LOG_LEVEL = _env("LOG_LEVEL", "INFO") or "INFO"

    # Session
    SESSION_TYPE = "filesystem"
    SESSION_FILE_DIR = str(BASE_DIR / "db" / "sessions")
    SESSION_PERMANENT = False

    @classmethod
    def ensure_dirs(cls) -> None:
        """Tworzy brakujace katalogi (storage, db, sessions)."""
        for p in [
            cls.STORAGE_PATH,
            cls.STORAGE_PATH / "videos",
            cls.STORAGE_PATH / "overlays",
            cls.STORAGE_PATH / "music",
            cls.DB_PATH.parent,
            Path(cls.SESSION_FILE_DIR),
        ]:
            p.mkdir(parents=True, exist_ok=True)
