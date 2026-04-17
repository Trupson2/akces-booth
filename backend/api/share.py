"""Public-facing routes: watch page, video streaming, download, QR PNG."""
from __future__ import annotations

import io
import logging
from pathlib import Path

import qrcode
from flask import (
    Blueprint, abort, render_template, send_file, send_from_directory,
)
from qrcode.constants import ERROR_CORRECT_H

import models
from config import Config

log = logging.getLogger(__name__)

share_bp = Blueprint("share", __name__)


def _resolve_video_path(video: dict) -> Path | None:
    raw = video.get("file_path") or ""
    p = Path(raw)
    if not p.is_absolute():
        p = Config.BASE_DIR / p
    return p if p.exists() else None


@share_bp.route("/v/<short_id>")
def watch_video(short_id: str):  # type: ignore[no-untyped-def]
    video = models.get_video_by_short_id(Config.DB_PATH, short_id)
    if not video:
        abort(404)
    models.increment_view_count(Config.DB_PATH, video["id"])
    event = models.get_event(Config.DB_PATH, video["event_id"])
    return render_template(
        "public/watch.html",
        video=video,
        event=event,
        public_base=Config.PUBLIC_BASE_URL,
    )


@share_bp.route("/api/videos/<short_id>/stream")
def stream_video(short_id: str):  # type: ignore[no-untyped-def]
    video = models.get_video_by_short_id(Config.DB_PATH, short_id)
    if not video:
        abort(404)
    p = _resolve_video_path(video)
    if p is None:
        abort(404)
    return send_file(str(p), mimetype="video/mp4", conditional=True)


@share_bp.route("/api/videos/<short_id>/download")
def download_video(short_id: str):  # type: ignore[no-untyped-def]
    video = models.get_video_by_short_id(Config.DB_PATH, short_id)
    if not video:
        abort(404)
    p = _resolve_video_path(video)
    if p is None:
        abort(404)
    models.increment_download_count(Config.DB_PATH, video["id"])
    return send_file(
        str(p),
        as_attachment=True,
        download_name=f"akces_booth_{short_id}.mp4",
        mimetype="video/mp4",
    )


@share_bp.route("/qr/<short_id>.png")
def qr_png(short_id: str):  # type: ignore[no-untyped-def]
    video = models.get_video_by_short_id(Config.DB_PATH, short_id)
    if not video:
        abort(404)
    url = f"{Config.PUBLIC_BASE_URL}/v/{short_id}"

    qr = qrcode.QRCode(
        version=None,
        error_correction=ERROR_CORRECT_H,
        box_size=20,
        border=4,
    )
    qr.add_data(url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white").convert("RGB")

    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    buf.seek(0)
    return send_file(buf, mimetype="image/png")


@share_bp.route("/e/<access_key>")
def event_gallery(access_key: str):  # type: ignore[no-untyped-def]
    # Galeria wszystkich filmow eventu po access_key.
    from models import get_conn
    with get_conn(Config.DB_PATH) as conn:
        event_row = conn.execute(
            "SELECT * FROM events WHERE access_key=?", (access_key,)
        ).fetchone()
        if event_row is None:
            abort(404)
        videos = conn.execute(
            "SELECT * FROM videos WHERE event_id=? ORDER BY created_at DESC",
            (event_row["id"],),
        ).fetchall()
    return render_template(
        "public/gallery.html",
        event=dict(event_row),
        videos=[dict(v) for v in videos],
        public_base=Config.PUBLIC_BASE_URL,
    )


# Static storage served directly (overlays thumbnails in admin).
@share_bp.route("/storage/<path:subpath>")
def serve_storage(subpath: str):  # type: ignore[no-untyped-def]
    return send_from_directory(str(Config.STORAGE_PATH), subpath)
