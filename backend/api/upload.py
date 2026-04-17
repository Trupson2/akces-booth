"""POST /api/upload - odbior MP4 od apki Station."""
from __future__ import annotations

import logging
from pathlib import Path

from flask import Blueprint, current_app, jsonify, request
from werkzeug.utils import secure_filename

import models
from config import Config

log = logging.getLogger(__name__)

upload_bp = Blueprint("upload", __name__)


def _authorized() -> bool:
    key = request.headers.get("X-API-Key") or request.args.get("api_key")
    return key == Config.STATION_API_KEY


@upload_bp.route("/upload", methods=["POST"])
def upload_video():  # type: ignore[no-untyped-def]
    if not _authorized():
        return jsonify({"error": "Unauthorized"}), 401

    event = models.get_active_event(Config.DB_PATH)
    if event is None:
        return jsonify({"error": "No active event. Create one in /admin first."}), 400

    # Raw body albo multipart - wspieramy oba (Station wysyla raw mp4).
    data: bytes | None = None
    original_filename: str | None = None

    if request.files:
        f = request.files.get("video") or next(iter(request.files.values()), None)
        if f is None:
            return jsonify({"error": "No video file in multipart"}), 400
        data = f.read()
        original_filename = secure_filename(f.filename or "upload.mp4")
    else:
        data = request.get_data(cache=False, as_text=False)
        if not data:
            return jsonify({"error": "Empty body"}), 400
        original_filename = secure_filename(
            request.headers.get("X-Filename") or "upload.mp4"
        )

    short_id = models.ensure_unique_short_id(Config.DB_PATH)

    # storage/videos/<event_id>/<short_id>.mp4
    suffix = Path(original_filename).suffix or ".mp4"
    if not suffix.lower() in {".mp4", ".mov", ".webm"}:
        suffix = ".mp4"
    event_dir = Config.STORAGE_PATH / "videos" / str(event["id"])
    event_dir.mkdir(parents=True, exist_ok=True)
    target = event_dir / f"{short_id}{suffix}"
    target.write_bytes(data)

    video_id = models.insert_video(
        Config.DB_PATH,
        event_id=event["id"],
        short_id=short_id,
        original_filename=original_filename,
        file_path=str(target.relative_to(Config.BASE_DIR)) if str(target).startswith(
            str(Config.BASE_DIR)) else str(target),
        file_size=len(data),
    )

    log.info("Uploaded video id=%s short_id=%s size=%d", video_id, short_id, len(data))

    return jsonify({
        "status": "ok",
        "short_id": short_id,
        "public_url": f"{Config.PUBLIC_BASE_URL}/v/{short_id}",
        "qr_code_url": f"{Config.PUBLIC_BASE_URL}/qr/{short_id}.png",
        "file_size": len(data),
    })
