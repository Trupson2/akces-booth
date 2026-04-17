"""Sesja admin - single-user login (na Sesje 5)."""
from __future__ import annotations

from functools import wraps
from typing import Any, Callable

from flask import jsonify, redirect, request, session, url_for

from config import Config


def is_admin() -> bool:
    return bool(session.get("admin"))


def login(username: str, password: str) -> bool:
    if username == Config.ADMIN_USERNAME and password == Config.ADMIN_PASSWORD:
        session["admin"] = True
        session.permanent = True
        return True
    return False


def logout() -> None:
    session.pop("admin", None)


def require_admin(fn: Callable[..., Any]) -> Callable[..., Any]:
    @wraps(fn)
    def wrapper(*args: Any, **kwargs: Any) -> Any:
        if not is_admin():
            # Jesli XHR/JSON, zwroc 401 zamiast redirect.
            if (request.is_json
                    or request.headers.get("X-Requested-With") == "XMLHttpRequest"
                    or request.path.startswith("/api/")):
                return jsonify({"error": "Unauthorized"}), 401
            return redirect(url_for("admin.login"))
        return fn(*args, **kwargs)
    return wrapper
