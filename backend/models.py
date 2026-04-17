"""SQLite schema + CRUD helpers dla Akces Booth."""
from __future__ import annotations

import json
import secrets
import sqlite3
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable, Iterator

SCHEMA = """
CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    event_date DATE,
    client_name TEXT,
    client_contact TEXT,
    event_type TEXT,
    overlay_id INTEGER,
    music_id INTEGER,
    text_top TEXT,
    text_bottom TEXT,
    access_key TEXT UNIQUE,
    is_active INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (overlay_id) REFERENCES library_overlays(id),
    FOREIGN KEY (music_id) REFERENCES library_music(id)
);

CREATE TABLE IF NOT EXISTS videos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id INTEGER NOT NULL,
    short_id TEXT UNIQUE NOT NULL,
    original_filename TEXT,
    file_path TEXT NOT NULL,
    file_size INTEGER,
    duration_seconds REAL,
    metadata TEXT,
    view_count INTEGER DEFAULT 0,
    download_count INTEGER DEFAULT 0,
    publish_to_facebook INTEGER DEFAULT 0,
    published_to_facebook_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (event_id) REFERENCES events(id)
);

CREATE TABLE IF NOT EXISTS library_overlays (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    source TEXT,
    ai_prompt TEXT,
    tags TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS library_music (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    source TEXT,
    tags TEXT,
    duration_seconds REAL,
    license_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS event_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    event_type TEXT,
    overlay_id INTEGER,
    music_id INTEGER,
    default_text_top TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS early_access_signups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    consent INTEGER DEFAULT 1,
    ip TEXT,
    user_agent TEXT,
    hero_variant TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_videos_event ON videos(event_id);
CREATE INDEX IF NOT EXISTS idx_videos_short_id ON videos(short_id);
CREATE INDEX IF NOT EXISTS idx_events_active ON events(is_active);
CREATE INDEX IF NOT EXISTS idx_early_access_email ON early_access_signups(email);
"""

# Bez 0/O/l/1 - latwe do odczytu z QR / wpisania recznie.
_ID_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"


def init_db(db_path: Path | str) -> None:
    Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(str(db_path)) as conn:
        conn.executescript(SCHEMA)
        _migrate(conn)


def _migrate(conn: sqlite3.Connection) -> None:
    """Idempotentne migracje dla istniejacych instalek."""
    cols = {row[1] for row in conn.execute("PRAGMA table_info(videos)").fetchall()}
    if "publish_to_facebook" not in cols:
        conn.execute(
            "ALTER TABLE videos ADD COLUMN publish_to_facebook INTEGER DEFAULT 0"
        )
    if "published_to_facebook_at" not in cols:
        conn.execute(
            "ALTER TABLE videos ADD COLUMN published_to_facebook_at TIMESTAMP"
        )
    # early_access_signups table is in SCHEMA (CREATE IF NOT EXISTS) - nic do migrowania


@contextmanager
def get_conn(db_path: Path | str) -> Iterator[sqlite3.Connection]:
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def generate_short_id(length: int = 6) -> str:
    return "".join(secrets.choice(_ID_ALPHABET) for _ in range(length))


# --- Events --------------------------------------------------------------------

def list_events(db_path: Path) -> list[dict[str, Any]]:
    with get_conn(db_path) as conn:
        rows = conn.execute(
            """
            SELECT e.*, (SELECT COUNT(*) FROM videos v WHERE v.event_id=e.id) AS video_count
            FROM events e
            ORDER BY e.is_active DESC, e.created_at DESC
            """
        ).fetchall()
    return [dict(r) for r in rows]


def get_event(db_path: Path, event_id: int) -> dict[str, Any] | None:
    with get_conn(db_path) as conn:
        row = conn.execute("SELECT * FROM events WHERE id=?", (event_id,)).fetchone()
    return dict(row) if row else None


def get_active_event(db_path: Path) -> dict[str, Any] | None:
    with get_conn(db_path) as conn:
        row = conn.execute(
            "SELECT * FROM events WHERE is_active=1 LIMIT 1"
        ).fetchone()
    return dict(row) if row else None


def create_event(db_path: Path, *, name: str, event_date: str | None = None,
                 client_name: str | None = None, client_contact: str | None = None,
                 event_type: str | None = None, text_top: str | None = None,
                 text_bottom: str | None = None) -> int:
    access_key = generate_short_id(length=10)
    with get_conn(db_path) as conn:
        cur = conn.execute(
            """
            INSERT INTO events (name, event_date, client_name, client_contact,
                                event_type, text_top, text_bottom, access_key)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (name, event_date, client_name, client_contact, event_type,
             text_top, text_bottom, access_key),
        )
        return int(cur.lastrowid or 0)


def update_event(db_path: Path, event_id: int, **fields: Any) -> None:
    if not fields:
        return
    allowed = {
        "name", "event_date", "client_name", "client_contact", "event_type",
        "overlay_id", "music_id", "text_top", "text_bottom",
    }
    safe = {k: v for k, v in fields.items() if k in allowed}
    if not safe:
        return
    columns = ", ".join(f"{k}=?" for k in safe)
    values = list(safe.values()) + [event_id]
    with get_conn(db_path) as conn:
        conn.execute(f"UPDATE events SET {columns} WHERE id=?", values)


def set_active_event(db_path: Path, event_id: int) -> None:
    with get_conn(db_path) as conn:
        conn.execute("UPDATE events SET is_active=0")
        conn.execute("UPDATE events SET is_active=1 WHERE id=?", (event_id,))


def delete_event(db_path: Path, event_id: int) -> None:
    with get_conn(db_path) as conn:
        conn.execute("DELETE FROM videos WHERE event_id=?", (event_id,))
        conn.execute("DELETE FROM events WHERE id=?", (event_id,))


# --- Videos --------------------------------------------------------------------

def insert_video(db_path: Path, *, event_id: int, short_id: str,
                 original_filename: str | None, file_path: str,
                 file_size: int | None = None,
                 duration_seconds: float | None = None,
                 metadata: dict[str, Any] | None = None,
                 publish_to_facebook: bool = False) -> int:
    meta_json = json.dumps(metadata) if metadata else None
    with get_conn(db_path) as conn:
        cur = conn.execute(
            """
            INSERT INTO videos (event_id, short_id, original_filename, file_path,
                                file_size, duration_seconds, metadata,
                                publish_to_facebook)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (event_id, short_id, original_filename, file_path, file_size,
             duration_seconds, meta_json, 1 if publish_to_facebook else 0),
        )
        return int(cur.lastrowid or 0)


def list_videos_pending_publish(db_path: Path) -> list[dict[str, Any]]:
    """Filmy z opt-in FB, ktore jeszcze nie zostaly opublikowane."""
    with get_conn(db_path) as conn:
        rows = conn.execute(
            """
            SELECT v.*, e.name AS event_name
            FROM videos v
            LEFT JOIN events e ON e.id = v.event_id
            WHERE v.publish_to_facebook = 1
              AND v.published_to_facebook_at IS NULL
            ORDER BY v.created_at DESC
            """
        ).fetchall()
    return [dict(r) for r in rows]


def mark_video_published(db_path: Path, video_id: int) -> None:
    with get_conn(db_path) as conn:
        conn.execute(
            "UPDATE videos SET published_to_facebook_at = CURRENT_TIMESTAMP "
            "WHERE id = ?",
            (video_id,),
        )


def unmark_video_publish(db_path: Path, video_id: int) -> None:
    """Wycofanie zgody z panelu (np. gdy operator zdecyduje nie publikowac)."""
    with get_conn(db_path) as conn:
        conn.execute(
            "UPDATE videos SET publish_to_facebook = 0 WHERE id = ?",
            (video_id,),
        )


# --- Early Access signups -------------------------------------------------------

def insert_early_access_signup(
    db_path: Path,
    *,
    email: str,
    consent: bool = True,
    ip: str | None = None,
    user_agent: str | None = None,
    hero_variant: str | None = None,
) -> int:
    """Zapisuje email z landing /early-access. Zwraca id nowego wiersza.

    Email nie ma UNIQUE constraint - jesli ktos zapisze sie dwa razy, traktujemy
    to jako wzmocniony sygnal zainteresowania, nie blad.
    """
    with get_conn(db_path) as conn:
        cur = conn.execute(
            """
            INSERT INTO early_access_signups
                (email, consent, ip, user_agent, hero_variant)
            VALUES (?, ?, ?, ?, ?)
            """,
            (email, 1 if consent else 0, ip, user_agent, hero_variant),
        )
        return int(cur.lastrowid or 0)


def list_early_access_signups(db_path: Path) -> list[dict[str, Any]]:
    with get_conn(db_path) as conn:
        rows = conn.execute(
            "SELECT * FROM early_access_signups ORDER BY created_at DESC"
        ).fetchall()
    return [dict(r) for r in rows]


def count_early_access_signups(db_path: Path) -> int:
    """Do wyswietlenia realnego licznika na landingu, gdy przekroczymy 0."""
    with get_conn(db_path) as conn:
        row = conn.execute(
            "SELECT COUNT(DISTINCT email) AS c FROM early_access_signups"
        ).fetchone()
    return int(row["c"] or 0)


def get_video_by_short_id(db_path: Path, short_id: str) -> dict[str, Any] | None:
    with get_conn(db_path) as conn:
        row = conn.execute(
            "SELECT * FROM videos WHERE short_id=?", (short_id,)
        ).fetchone()
    return dict(row) if row else None


def list_videos_for_event(db_path: Path, event_id: int) -> list[dict[str, Any]]:
    with get_conn(db_path) as conn:
        rows = conn.execute(
            "SELECT * FROM videos WHERE event_id=? ORDER BY created_at DESC",
            (event_id,),
        ).fetchall()
    return [dict(r) for r in rows]


def increment_view_count(db_path: Path, video_id: int) -> None:
    with get_conn(db_path) as conn:
        conn.execute(
            "UPDATE videos SET view_count = view_count + 1 WHERE id=?", (video_id,)
        )


def increment_download_count(db_path: Path, video_id: int) -> None:
    with get_conn(db_path) as conn:
        conn.execute(
            "UPDATE videos SET download_count = download_count + 1 WHERE id=?",
            (video_id,),
        )


def ensure_unique_short_id(db_path: Path) -> str:
    """Generuje short_id nie kolidujacy z istniejacym."""
    for _ in range(20):
        candidate = generate_short_id()
        with get_conn(db_path) as conn:
            row = conn.execute(
                "SELECT 1 FROM videos WHERE short_id=?", (candidate,)
            ).fetchone()
        if row is None:
            return candidate
    raise RuntimeError("Nie udalo sie wygenerowac unikalnego short_id po 20 probach")


# --- Library -------------------------------------------------------------------

def list_overlays(db_path: Path) -> list[dict[str, Any]]:
    with get_conn(db_path) as conn:
        rows = conn.execute(
            "SELECT * FROM library_overlays ORDER BY created_at DESC"
        ).fetchall()
    return [dict(r) for r in rows]


def insert_overlay(db_path: Path, *, name: str, file_path: str,
                   source: str = "upload", ai_prompt: str | None = None,
                   tags: Iterable[str] | None = None) -> int:
    tags_json = json.dumps(list(tags)) if tags else None
    with get_conn(db_path) as conn:
        cur = conn.execute(
            """
            INSERT INTO library_overlays (name, file_path, source, ai_prompt, tags)
            VALUES (?, ?, ?, ?, ?)
            """,
            (name, file_path, source, ai_prompt, tags_json),
        )
        return int(cur.lastrowid or 0)


def delete_overlay(db_path: Path, overlay_id: int) -> None:
    with get_conn(db_path) as conn:
        conn.execute("DELETE FROM library_overlays WHERE id=?", (overlay_id,))


def list_music(db_path: Path) -> list[dict[str, Any]]:
    with get_conn(db_path) as conn:
        rows = conn.execute(
            "SELECT * FROM library_music ORDER BY created_at DESC"
        ).fetchall()
    return [dict(r) for r in rows]


def insert_music(db_path: Path, *, name: str, file_path: str,
                 source: str = "upload", tags: Iterable[str] | None = None,
                 duration_seconds: float | None = None,
                 license_notes: str | None = None) -> int:
    tags_json = json.dumps(list(tags)) if tags else None
    with get_conn(db_path) as conn:
        cur = conn.execute(
            """
            INSERT INTO library_music (name, file_path, source, tags,
                                       duration_seconds, license_notes)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (name, file_path, source, tags_json, duration_seconds, license_notes),
        )
        return int(cur.lastrowid or 0)


def delete_music(db_path: Path, music_id: int) -> None:
    with get_conn(db_path) as conn:
        conn.execute("DELETE FROM library_music WHERE id=?", (music_id,))


# --- Stats ---------------------------------------------------------------------

def daily_stats(db_path: Path) -> dict[str, int]:
    today = datetime.utcnow().date().isoformat()
    with get_conn(db_path) as conn:
        uploads = conn.execute(
            "SELECT COUNT(*) AS c FROM videos WHERE DATE(created_at)=?", (today,)
        ).fetchone()["c"]
        views = conn.execute(
            "SELECT COALESCE(SUM(view_count), 0) AS c FROM videos WHERE DATE(created_at)=?",
            (today,),
        ).fetchone()["c"]
    return {"uploads": int(uploads or 0), "views": int(views or 0)}
