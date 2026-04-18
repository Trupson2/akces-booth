"""Library - overlays (PNG ramki) i music (MP3)."""
from __future__ import annotations

import logging
import sys
import threading
import uuid
from pathlib import Path

from flask import Blueprint, jsonify, request
from werkzeug.utils import secure_filename

import models
from admin.auth import require_admin
from config import Config

library_bp = Blueprint("library", __name__)
log = logging.getLogger(__name__)


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


def _resolve_music_path(track: dict) -> Path:
    p = Path(track["file_path"])
    if not p.is_absolute():
        p = Config.BASE_DIR / p
    return p


def _run_analysis(music_id: int, abs_path: str) -> None:
    """Worker thread - analizuje i zapisuje do DB. Log tylko (bez UI)."""
    # Import inline - librosa jest heavy, nie chcemy go ladowac na starcie
    # aplikacji jesli admin nigdy analizy nie wywola.
    try:
        scripts_dir = Config.BASE_DIR / "scripts"
        if str(scripts_dir) not in sys.path:
            sys.path.insert(0, str(scripts_dir))
        import analyze_viral_moment  # type: ignore
        result = analyze_viral_moment.analyze_file(abs_path)
        models.set_music_viral_offset(
            Config.DB_PATH, music_id, result["offset_sec"]
        )
        log.info(
            "viral analysis music_id=%d: offset=%.2fs "
            "confidence=%.2f tempo=%.0f",
            music_id, result["offset_sec"],
            result["confidence"], result["tempo_bpm"],
        )
    except Exception as e:  # noqa: BLE001
        log.exception("viral analysis failed music_id=%d", music_id)
        models.set_music_analysis_status(
            Config.DB_PATH, music_id, "failed", error=str(e)[:500]
        )


@library_bp.route("/music/<int:music_id>/analyze", methods=["POST"])
@require_admin
def analyze_music_api(music_id: int):  # type: ignore[no-untyped-def]
    """Kickstarts AI viral analysis. Wraca natychmiast (202), praca w tle."""
    track = models.get_music(Config.DB_PATH, music_id)
    if track is None:
        return jsonify({"error": "music not found"}), 404

    path = _resolve_music_path(track)
    if not path.exists():
        return jsonify({"error": f"file missing: {path}"}), 404

    # Zapis 'pending' natychmiast, dzieki czemu UI moze pokazac spinner.
    models.set_music_analysis_status(Config.DB_PATH, music_id, "pending")

    t = threading.Thread(
        target=_run_analysis,
        args=(music_id, str(path)),
        name=f"viral-analyze-{music_id}",
        daemon=True,
    )
    t.start()
    return jsonify({"status": "pending"}), 202


@library_bp.route("/music/<int:music_id>/offset-mode", methods=["POST"])
@require_admin
def set_music_mode_api(music_id: int):  # type: ignore[no-untyped-def]
    """Ustaw tryb startu piosenki: default_30s / ai / custom.
    Body JSON: {"mode": "...", "custom_offset_sec": float?}.
    """
    data = request.get_json(silent=True) or request.form.to_dict()
    mode = (data.get("mode") or "").strip()
    custom_raw = data.get("custom_offset_sec")
    custom_offset: float | None = None
    if custom_raw not in (None, ""):
        try:
            custom_offset = float(custom_raw)
        except (TypeError, ValueError):
            return jsonify({"error": "invalid custom_offset_sec"}), 400
    if mode not in {"default_30s", "ai", "custom"}:
        return jsonify({"error": "invalid mode"}), 400
    if mode == "custom" and (custom_offset is None or custom_offset < 0):
        return jsonify({"error": "custom mode requires custom_offset_sec >= 0"}), 400

    track = models.get_music(Config.DB_PATH, music_id)
    if track is None:
        return jsonify({"error": "music not found"}), 404

    try:
        models.set_music_offset_mode(
            Config.DB_PATH, music_id,
            mode=mode, custom_offset_sec=custom_offset,
        )
    except ValueError as e:
        return jsonify({"error": str(e)}), 400

    updated = models.get_music(Config.DB_PATH, music_id)
    return jsonify({
        "status": "ok",
        "offset_mode": updated["offset_mode"] if updated else mode,
        "custom_offset_sec": updated["custom_offset_sec"] if updated else custom_offset,
        "effective_offset_sec": models.resolve_music_offset(updated or {}),
    })


@library_bp.route("/music/<int:music_id>", methods=["GET"])
@require_admin
def get_music_api(music_id: int):  # type: ignore[no-untyped-def]
    """Pojedynczy utwor - do polling'u status po analyze."""
    track = models.get_music(Config.DB_PATH, music_id)
    if track is None:
        return jsonify({"error": "music not found"}), 404
    track["effective_offset_sec"] = models.resolve_music_offset(track)
    return jsonify(track)
