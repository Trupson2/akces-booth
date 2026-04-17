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
    e = models.get_active_event(Config.DB_PATH)
    if e is None:
        return jsonify({"active": False}), 200
    return jsonify({"active": True, "event": e})


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
