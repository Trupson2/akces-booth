"""Landing page /early-access — Claude Design JSX + email signup + RODO.

Serwuje statyczny HTML/JSX z `backend/static/early-access/` pod czystym
URL-em /early-access/, plus POST endpoint do kolekcjonowania zapisów.
"""
from __future__ import annotations

import logging
import re
from pathlib import Path

from flask import (
    Blueprint, abort, jsonify, render_template, request, send_from_directory,
)

import models
from config import Config

log = logging.getLogger(__name__)

early_access_bp = Blueprint("early_access", __name__)

LANDING_DIR = Config.BASE_DIR / "static" / "early-access"

_EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


@early_access_bp.route("/early-access/")
def landing():  # type: ignore[no-untyped-def]
    """Serwuj Landing Page.html z Claude Design (renamed index.html).

    Werkzeug automatycznie robi 308 redirect z /early-access -> /early-access/,
    co jest potrzebne zeby <base href> + relative JSX paths dzialaly,
    i zeby anchor linki #problem / #faq scrollowaly zamiast robic pelny reload.
    """
    target = LANDING_DIR / "index.html"
    if not target.exists():
        abort(404)
    return send_from_directory(str(LANDING_DIR), "index.html")


@early_access_bp.route("/early-access/<path:filename>")
def landing_asset(filename: str):  # type: ignore[no-untyped-def]
    """Serwuj assety (components/*.jsx, frames/*.jsx, scraps/*).

    Wazne: Flask domyslnie serwuje .jsx jako application/octet-stream, co
    blokuje Babel Standalone transpile. Wymuszamy text/babel dla .jsx.
    """
    if ".." in filename:
        abort(404)
    response = send_from_directory(str(LANDING_DIR), filename)
    if filename.endswith(".jsx"):
        response.headers["Content-Type"] = "text/babel; charset=utf-8"
    return response


@early_access_bp.route("/api/early-access/signup", methods=["POST"])
def signup():  # type: ignore[no-untyped-def]
    """JSON body: {email, consent, hero_variant?}. Zwraca 200 lub 400."""
    payload = request.get_json(silent=True) or {}
    email = (payload.get("email") or "").strip().lower()
    consent = bool(payload.get("consent", True))
    hero_variant = (payload.get("hero_variant") or "").strip()[:20] or None

    if not email or not _EMAIL_RE.match(email) or len(email) > 255:
        return jsonify({"ok": False, "error": "invalid_email"}), 400

    ip = request.headers.get("CF-Connecting-IP") or request.remote_addr
    ua = (request.headers.get("User-Agent") or "")[:500] or None

    try:
        signup_id = models.insert_early_access_signup(
            Config.DB_PATH,
            email=email,
            consent=consent,
            ip=ip,
            user_agent=ua,
            hero_variant=hero_variant,
        )
        log.info("Early-access signup id=%s email=%s variant=%s",
                 signup_id, email, hero_variant)
        return jsonify({"ok": True, "id": signup_id})
    except Exception as e:
        log.exception("Early-access signup failed: %s", e)
        return jsonify({"ok": False, "error": "internal"}), 500


@early_access_bp.route("/polityka-prywatnosci")
def privacy_policy():  # type: ignore[no-untyped-def]
    return render_template(
        "public/privacy_policy.html",
        public_base=Config.PUBLIC_BASE_URL,
    )
