"""Library - overlays (PNG ramki) i music (MP3)."""
from __future__ import annotations

import uuid
from pathlib import Path

from flask import Blueprint, jsonify, request
from werkzeug.utils import secure_filename

import models
from admin.auth import require_admin
from config import Config

library_bp = Blueprint("library", __name__)


@library_bp.route("/overlays", methods=["GET"])
@require_admin
def list_overlays_api():  # type: ignore[no-untyped-def]
    return jsonify(models.list_overlays(Config.DB_PATH))


@library_bp.route("/overlays", methods=["POST"])
@require_admin
def upload_overlay_api():  # type: ignore[no-untyped-def]
    f = request.files.get("file")
    if f is None or not f.filename:
        return jsonify({"error": "file required"}), 400
    name = request.form.get("name") or f.filename
    safe = secure_filename(f.filename)
    ext = Path(safe).suffix.lower()
    if ext not in {".png", ".jpg", ".jpeg", ".webp"}:
        return jsonify({"error": "Unsupported image format"}), 400
    filename = f"ov_{uuid.uuid4().hex[:10]}{ext}"
    dest = Config.STORAGE_PATH / "overlays" / filename
    dest.parent.mkdir(parents=True, exist_ok=True)
    f.save(str(dest))
    overlay_id = models.insert_overlay(
        Config.DB_PATH,
        name=name,
        file_path=str(dest.relative_to(Config.BASE_DIR)),
        source="upload",
    )
    return jsonify({"id": overlay_id, "file_path": str(dest)}), 201


@library_bp.route("/overlays/<int:overlay_id>", methods=["DELETE"])
@require_admin
def delete_overlay_api(overlay_id: int):  # type: ignore[no-untyped-def]
    models.delete_overlay(Config.DB_PATH, overlay_id)
    return jsonify({"status": "ok"})


@library_bp.route("/music", methods=["GET"])
@require_admin
def list_music_api():  # type: ignore[no-untyped-def]
    return jsonify(models.list_music(Config.DB_PATH))


@library_bp.route("/music", methods=["POST"])
@require_admin
def upload_music_api():  # type: ignore[no-untyped-def]
    f = request.files.get("file")
    if f is None or not f.filename:
        return jsonify({"error": "file required"}), 400
    name = request.form.get("name") or f.filename
    safe = secure_filename(f.filename)
    ext = Path(safe).suffix.lower()
    if ext not in {".mp3", ".m4a", ".wav", ".ogg"}:
        return jsonify({"error": "Unsupported audio format"}), 400
    filename = f"mus_{uuid.uuid4().hex[:10]}{ext}"
    dest = Config.STORAGE_PATH / "music" / filename
    dest.parent.mkdir(parents=True, exist_ok=True)
    f.save(str(dest))
    music_id = models.insert_music(
        Config.DB_PATH,
        name=name,
        file_path=str(dest.relative_to(Config.BASE_DIR)),
        source="upload",
    )
    return jsonify({"id": music_id, "file_path": str(dest)}), 201


@library_bp.route("/music/<int:music_id>", methods=["DELETE"])
@require_admin
def delete_music_api(music_id: int):  # type: ignore[no-untyped-def]
    models.delete_music(Config.DB_PATH, music_id)
    return jsonify({"status": "ok"})
