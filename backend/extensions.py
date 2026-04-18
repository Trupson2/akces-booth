"""Flask extensions - zaladowane globalnie, init w create_app().

Wzorzec: zgodny z zaleceniami Flask-Limiter, pozwala dekorowac routes
w blueprintach bez kolekcji przez current_app.
"""
from __future__ import annotations

from flask import request
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address


def _rate_limit_key() -> str:
    """Klucz rate-limit per-klient.

    Honoruje CF-Connecting-IP (Cloudflare Tunnel) - bez tego wszystkie requesty
    wygladalyby jak jeden IP (tunelu) i limit bylby trafiany natychmiast.
    """
    return request.headers.get("CF-Connecting-IP") or get_remote_address()


# Globalny Limiter - inicjalizacja przez limiter.init_app(app) w create_app().
# Config (storage, strategy) ustawiamy w app.config (Flask-Limiter preferuje
# tak gdy uzywany jest init_app pattern, nie konstruktor).
# Default: 200/hour per IP dla calej app. Per-route nadpisuje dekoratorem.
limiter = Limiter(
    key_func=_rate_limit_key,
    default_limits=["200 per hour"],
    headers_enabled=True,  # dodaje X-RateLimit-* do responses - debug friendly
)
