"""Admin panel routing - dashboard, events, library, AI generator."""
from __future__ import annotations

from flask import (
    Blueprint, flash, redirect, render_template, request, url_for,
)

import models
from admin.auth import is_admin, login, logout, require_admin
from config import Config

admin_bp = Blueprint("admin", __name__, template_folder="../templates")


@admin_bp.route("/", methods=["GET"])
@require_admin
def dashboard():  # type: ignore[no-untyped-def]
    import os
    import shutil
    import subprocess
    active = models.get_active_event(Config.DB_PATH)
    videos = (
        models.list_videos_for_event(Config.DB_PATH, active["id"])
        if active else []
    )
    stats = models.daily_stats(Config.DB_PATH)

    # Stats systemowe - disk, uptime, backup status.
    sysinfo: dict[str, str | None] = {}
    try:
        du = shutil.disk_usage(Config.BASE_DIR)
        sysinfo["disk_free_gb"] = f"{du.free / 1024 / 1024 / 1024:.1f}"
        sysinfo["disk_total_gb"] = f"{du.total / 1024 / 1024 / 1024:.1f}"
        sysinfo["disk_used_pct"] = f"{(du.total - du.free) * 100 // du.total}"
    except Exception:
        sysinfo["disk_free_gb"] = None
    try:
        with open("/proc/uptime") as f:
            up = float(f.read().split()[0])
            days = int(up // 86400)
            hours = int((up % 86400) // 3600)
            mins = int((up % 3600) // 60)
            sysinfo["uptime"] = f"{days}d {hours}h {mins}m"
    except Exception:
        sysinfo["uptime"] = None
    try:
        # Ostatnia linia z backup log - "BACKUP OK" lub "BACKUP START"
        log_path = "/var/log/akces-booth-backup.log"
        if os.path.exists(log_path):
            res = subprocess.run(
                ["tail", "-n", "20", log_path],
                capture_output=True, text=True, timeout=2,
            )
            lines = [ln for ln in res.stdout.splitlines() if "===" in ln]
            if lines:
                sysinfo["last_backup"] = lines[-1].strip()
            else:
                sysinfo["last_backup"] = "brak wpisow"
        else:
            sysinfo["last_backup"] = "log nie istnieje (rclone nie skonfigurowany?)"
    except Exception as e:
        sysinfo["last_backup"] = f"blad: {e}"
    try:
        # Sprawdz czy rclone remote 'booth-cloud' jest skonfigurowany.
        res = subprocess.run(
            ["rclone", "listremotes"],
            capture_output=True, text=True, timeout=3,
        )
        sysinfo["rclone_configured"] = "tak" if "booth-cloud:" in res.stdout else "nie (setup pending)"
    except Exception:
        sysinfo["rclone_configured"] = "rclone niezainstalowany"
    # Total videos w DB (wszystkie eventy)
    try:
        import sqlite3
        with sqlite3.connect(str(Config.DB_PATH)) as conn:
            row = conn.execute("SELECT COUNT(*) FROM videos").fetchone()
            sysinfo["total_videos"] = str(row[0]) if row else "0"
    except Exception:
        sysinfo["total_videos"] = None

    return render_template(
        "admin/dashboard.html",
        active_event=active,
        video_count=len(videos),
        stats=stats,
        sysinfo=sysinfo,
        public_base=Config.PUBLIC_BASE_URL,
    )


@admin_bp.route("/login", methods=["GET", "POST"])
def login_page():  # type: ignore[no-untyped-def]
    if is_admin():
        return redirect(url_for("admin.dashboard"))
    if request.method == "POST":
        u = (request.form.get("username") or "").strip()
        p = (request.form.get("password") or "").strip()
        if login(u, p):
            return redirect(url_for("admin.dashboard"))
        flash("Nieprawidlowe dane logowania.", "error")
    return render_template("admin/login.html")


# Alias wymagany przez require_admin (-> url_for("admin.login"))
@admin_bp.route("/login-route", endpoint="login")
def login_alias():  # type: ignore[no-untyped-def]
    return redirect(url_for("admin.login_page"))


@admin_bp.route("/logout")
def do_logout():  # type: ignore[no-untyped-def]
    logout()
    return redirect(url_for("admin.login_page"))


@admin_bp.route("/events", methods=["GET"])
@require_admin
def events_list():  # type: ignore[no-untyped-def]
    events = models.list_events(Config.DB_PATH)
    return render_template("admin/events_list.html", events=events)


@admin_bp.route("/events/new", methods=["GET", "POST"])
@require_admin
def event_new():  # type: ignore[no-untyped-def]
    if request.method == "POST":
        event_id = models.create_event(
            Config.DB_PATH,
            name=request.form["name"],
            event_date=request.form.get("event_date") or None,
            client_name=request.form.get("client_name") or None,
            client_contact=request.form.get("client_contact") or None,
            event_type=request.form.get("event_type") or None,
            text_top=request.form.get("text_top") or None,
            text_bottom=request.form.get("text_bottom") or None,
        )
        if request.form.get("activate") == "on":
            models.set_active_event(Config.DB_PATH, event_id)
        return redirect(url_for("admin.event_edit", event_id=event_id))
    return render_template("admin/event_edit.html", event=None,
                           overlays=models.list_overlays(Config.DB_PATH),
                           music=models.list_music(Config.DB_PATH))


@admin_bp.route("/events/<int:event_id>", methods=["GET", "POST"])
@require_admin
def event_edit(event_id: int):  # type: ignore[no-untyped-def]
    if request.method == "POST":
        fields = {
            "name": request.form.get("name"),
            "event_date": request.form.get("event_date") or None,
            "client_name": request.form.get("client_name") or None,
            "client_contact": request.form.get("client_contact") or None,
            "event_type": request.form.get("event_type") or None,
            "text_top": request.form.get("text_top") or None,
            "text_bottom": request.form.get("text_bottom") or None,
            "overlay_id": int(request.form["overlay_id"]) if request.form.get("overlay_id") else None,
            "music_id": int(request.form["music_id"]) if request.form.get("music_id") else None,
        }
        models.update_event(Config.DB_PATH, event_id, **fields)
        if request.form.get("activate") == "on":
            models.set_active_event(Config.DB_PATH, event_id)
        flash("Zapisano.", "ok")
        return redirect(url_for("admin.event_edit", event_id=event_id))

    event = models.get_event(Config.DB_PATH, event_id)
    videos = models.list_videos_for_event(Config.DB_PATH, event_id) if event else []
    return render_template(
        "admin/event_edit.html",
        event=event,
        videos=videos,
        overlays=models.list_overlays(Config.DB_PATH),
        music=models.list_music(Config.DB_PATH),
    )


@admin_bp.route("/events/<int:event_id>/activate", methods=["POST"])
@require_admin
def event_activate(event_id: int):  # type: ignore[no-untyped-def]
    models.set_active_event(Config.DB_PATH, event_id)
    return redirect(url_for("admin.events_list"))


@admin_bp.route("/events/<int:event_id>/delete", methods=["POST"])
@require_admin
def event_delete(event_id: int):  # type: ignore[no-untyped-def]
    models.delete_event(Config.DB_PATH, event_id)
    return redirect(url_for("admin.events_list"))


@admin_bp.route("/library")
@require_admin
def library():  # type: ignore[no-untyped-def]
    return render_template(
        "admin/library.html",
        overlays=models.list_overlays(Config.DB_PATH),
        music=models.list_music(Config.DB_PATH),
    )


@admin_bp.route("/ai-generator")
@require_admin
def ai_generator_page():  # type: ignore[no-untyped-def]
    return render_template("admin/ai_generator.html")


@admin_bp.route("/early-access-signups")
@require_admin
def early_access_signups():  # type: ignore[no-untyped-def]
    """Lista wszystkich zapisanych na /early-access - dla superadmina."""
    signups = models.list_early_access_signups(Config.DB_PATH)
    total = len(signups)
    with_consent = sum(1 for s in signups if s.get("consent"))
    return render_template(
        "admin/early_access_signups.html",
        signups=signups,
        total=total,
        with_consent=with_consent,
    )


@admin_bp.route("/do-publikacji")
@require_admin
def publish_queue():  # type: ignore[no-untyped-def]
    """Filmy oznaczone przez gosci zgoda na FB @akces360, jeszcze nie opublikowane.

    Publikacja rezna (manualna, batch) - Adrian zatwierdza/pobiera kazdy
    przed wrzuceniem.
    """
    videos = models.list_videos_pending_publish(Config.DB_PATH)
    return render_template(
        "admin/publish_queue.html",
        videos=videos,
        public_base=Config.PUBLIC_BASE_URL,
    )


@admin_bp.route("/do-publikacji/<int:video_id>/mark", methods=["POST"])
@require_admin
def mark_published(video_id: int):  # type: ignore[no-untyped-def]
    models.mark_video_published(Config.DB_PATH, video_id)
    flash("Oznaczone jako opublikowane.", "ok")
    return redirect(url_for("admin.publish_queue"))


@admin_bp.route("/do-publikacji/<int:video_id>/skip", methods=["POST"])
@require_admin
def skip_publish(video_id: int):  # type: ignore[no-untyped-def]
    models.unmark_video_publish(Config.DB_PATH, video_id)
    flash("Usunieto z kolejki publikacji.", "ok")
    return redirect(url_for("admin.publish_queue"))


@admin_bp.route("/videos/<int:video_id>/delete", methods=["POST"])
@require_admin
def delete_video_route(video_id: int):  # type: ignore[no-untyped-def]
    """Usuwa film z DB + plik z dysku. Po usunieciu redirect zwraca
    z powrotem do poprzedniego ekranu (event_edit albo dashboard).
    """
    rec = models.delete_video(Config.DB_PATH, video_id)
    if rec is None:
        flash("Film nie istnial (moze juz usuniety).", "err")
    else:
        flash(f"Usunieto film {rec.get('short_id') or video_id}.", "ok")
    # Wracamy do event_edit jesli znamy event_id, inaczej dashboard.
    event_id = rec.get("event_id") if rec else None
    if event_id:
        return redirect(url_for("admin.event_edit", event_id=event_id))
    return redirect(url_for("admin.dashboard"))
