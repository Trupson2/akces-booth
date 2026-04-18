"""CRUD dla eventow - uzywane przez admin panel + zewnetrzne narzedzia."""
from __future__ import annotations

from flask import Blueprint, jsonify, request

import models
from admin.auth import require_admin
from config import Config

events_bp = Blueprint("events", __name__)


@events_bp.route("/", methods=["GET"])
@require_admin
def list_events_api():  # type: ignore[no-untyped-def]
    return jsonify(models.list_events(Config.DB_PATH))


@events_bp.route("/active", methods=["GET"])
def active_event_api():  # type: ignore[no-untyped-def]
    """Publicznie dostepne (dla Station). Zwraca aktywny event +
    URLs overlay/music (jesli przypisane) + licznik filmow."""
    e = models.get_active_event(Config.DB_PATH)
    if e is None:
        return jsonify({"active": False}), 200

    videos = models.list_videos_for_event(Config.DB_PATH, e["id"])
    video_count = len(videos)

    overlay_url = None
    if e.get("overlay_id"):
        overlay_url = f"{Config.PUBLIC_BASE_URL}/api/events/overlay/{e['overlay_id']}"

    music_url = None
    music_offset_sec: float | None = None
    music_offset_mode: str | None = None
    if e.get("music_id"):
        music_url = f"{Config.PUBLIC_BASE_URL}/api/events/music/{e['music_id']}"
        track = models.get_music(Config.DB_PATH, int(e["music_id"]))
        if track:
            music_offset_sec = models.resolve_music_offset(track)
            music_offset_mode = track.get("offset_mode") or "default_30s"

    return jsonify({
        "active": True,
        "event": {
            "id": e["id"],
            "name": e["name"],
            "event_date": e.get("event_date"),
            "event_type": e.get("event_type"),
            "text_top": e.get("text_top"),
            "text_bottom": e.get("text_bottom"),
            "access_key": e.get("access_key"),
            "overlay_id": e.get("overlay_id"),
            "music_id": e.get("music_id"),
            "overlay_url": overlay_url,
            "music_url": music_url,
            "music_offset_sec": music_offset_sec,
            "music_offset_mode": music_offset_mode,
            "video_count": video_count,
        },
    })


@events_bp.route("/overlay/<int:overlay_id>", methods=["GET"])
def serve_overlay(overlay_id: int):  # type: ignore[no-untyped-def]
    """Publiczny serwis overlay PNG - dla Station cache."""
    from flask import send_file, abort
    from pathlib import Path as _Path
    overlays = models.list_overlays(Config.DB_PATH)
    for ov in overlays:
        if ov["id"] == overlay_id:
            p = _Path(ov["file_path"])
            if not p.is_absolute():
                p = Config.BASE_DIR / p
            if p.exists():
                return send_file(str(p))
            break
    abort(404)


@events_bp.route("/music/<int:music_id>", methods=["GET"])
def serve_music(music_id: int):  # type: ignore[no-untyped-def]
    """Publiczny serwis music MP3 - dla Station cache."""
    from flask import send_file, abort
    from pathlib import Path as _Path
    tracks = models.list_music(Config.DB_PATH)
    for t in tracks:
        if t["id"] == music_id:
            p = _Path(t["file_path"])
            if not p.is_absolute():
                p = Config.BASE_DIR / p
            if p.exists():
                return send_file(str(p))
            break
    abort(404)


@events_bp.route("/", methods=["POST"])
@require_admin
def create_event_api():  # type: ignore[no-untyped-def]
    data = request.get_json(silent=True) or request.form.to_dict()
    name = (data.get("name") or "").strip()
    if not name:
        return jsonify({"error": "name required"}), 400
    event_id = models.create_event(
        Config.DB_PATH,
        name=name,
        event_date=data.get("event_date") or None,
        client_name=data.get("client_name") or None,
        client_contact=data.get("client_contact") or None,
        event_type=data.get("event_type") or None,
        text_top=data.get("text_top") or None,
        text_bottom=data.get("text_bottom") or None,
    )
    return jsonify({"id": event_id}), 201


@events_bp.route("/<int:event_id>", methods=["PATCH"])
@require_admin
def update_event_api(event_id: int):  # type: ignore[no-untyped-def]
    data = request.get_json(silent=True) or request.form.to_dict()
    models.update_event(Config.DB_PATH, event_id, **data)
    return jsonify({"status": "ok"})


@events_bp.route("/<int:event_id>/activate", methods=["POST"])
@require_admin
def activate_event_api(event_id: int):  # type: ignore[no-untyped-def]
    models.set_active_event(Config.DB_PATH, event_id)
    return jsonify({"status": "ok"})


@events_bp.route("/<int:event_id>", methods=["DELETE"])
@require_admin
def delete_event_api(event_id: int):  # type: ignore[no-untyped-def]
    models.delete_event(Config.DB_PATH, event_id)
    return jsonify({"status": "ok"})


@events_bp.route("/<int:event_id>/videos", methods=["GET"])
@require_admin
def event_videos_api(event_id: int):  # type: ignore[no-untyped-def]
    return jsonify(models.list_videos_for_event(Config.DB_PATH, event_id))
