"""Akces Booth - Flask backend.

Chodzi osobno od Akces Hub (port 5100 vs 5000). Baza: SQLite w `db/`.
Zeby uruchomic lokalnie:

    pip install -r requirements.txt
    cp .env.example .env
    python app.py

Gunicorn (produkcja) - patrz `akces-booth.service`.
"""
from __future__ import annotations

import logging
from pathlib import Path

from flask import Flask, render_template
from flask_session import Session

from config import Config
from extensions import limiter
import models
from api.upload import upload_bp
from api.share import share_bp
from api.events import events_bp
from api.library import library_bp
from api.ai import ai_bp
from api.early_access import early_access_bp
from admin.routes import admin_bp


def create_app() -> Flask:
    Config.ensure_dirs()
    models.init_db(Config.DB_PATH)

    app = Flask(__name__, static_folder="static", template_folder="templates")
    app.config.from_object(Config)
    app.config["MAX_CONTENT_LENGTH"] = Config.MAX_UPLOAD_SIZE
    app.config["SESSION_TYPE"] = Config.SESSION_TYPE
    app.config["SESSION_FILE_DIR"] = Config.SESSION_FILE_DIR
    app.config["SESSION_PERMANENT"] = Config.SESSION_PERMANENT
    app.config["SECRET_KEY"] = Config.SECRET_KEY

    Session(app)

    # Rate limiting - inicjalizujemy globalny limiter (pattern z extensions.py).
    limiter.init_app(app)

    logging.basicConfig(
        level=getattr(logging, Config.LOG_LEVEL, logging.INFO),
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )
    app.logger.setLevel(Config.LOG_LEVEL)

    # Blueprints
    app.register_blueprint(upload_bp, url_prefix="/api")
    app.register_blueprint(share_bp)  # /v/<id>, /qr/<id>.png, streaming
    app.register_blueprint(events_bp, url_prefix="/api/events")
    app.register_blueprint(library_bp, url_prefix="/api/library")
    app.register_blueprint(ai_bp, url_prefix="/api/ai")
    app.register_blueprint(early_access_bp)  # /early-access + /api/early-access/signup
    app.register_blueprint(admin_bp, url_prefix="/admin")

    @app.route("/")
    def landing() -> str:
        return render_template("public/landing.html")

    @app.route("/healthz")
    def healthz() -> dict[str, str]:
        return {"status": "ok", "app": "akces_booth_backend"}

    @app.errorhandler(404)
    def not_found(_):  # type: ignore[no-untyped-def]
        return render_template("public/404.html"), 404

    @app.errorhandler(413)
    def too_large(_):  # type: ignore[no-untyped-def]
        return ("Plik za duzy (max "
                f"{Config.MAX_UPLOAD_SIZE // (1024*1024)} MB)"), 413

    @app.errorhandler(429)
    def rate_limited(_):  # type: ignore[no-untyped-def]
        """Custom JSON response dla rate-limit (signup endpoint) + HTML fallback."""
        from flask import jsonify, request
        if request.path.startswith("/api/"):
            return jsonify({
                "ok": False,
                "error": "rate_limit",
                "message": "Zbyt wiele prob - sprobuj za minute.",
            }), 429
        return "Zbyt wiele zapytan - sprobuj pozniej.", 429

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host=Config.HOST, port=Config.PORT, debug=True)
