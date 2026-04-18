"""SMTP notyfikacje dla zdarzen backend (signup early-access, bledy, itd.).

Filozofia: fail-safe. Jesli SMTP nie skonfigurowany albo padl - nie blokujemy
requestu, tylko logujemy. Zadne zdarzenie biznesowe nie zalezy od wyslania
maila.

Wywolywane w tle (threading) zeby nie powstrzymywac HTTP response. Prosty
`threading.Thread(daemon=True)` - kolejki (Celery/RQ) to przerost jak na
1-10 maili dziennie.
"""
from __future__ import annotations

import logging
import smtplib
import threading
from email.message import EmailMessage

from config import Config

log = logging.getLogger(__name__)


def _send_sync(subject: str, body: str, to: str | None = None) -> bool:
    """Wysle mail synchronicznie. Nie wolaj z handlera HTTP - uzyj send_async."""
    host = Config.SMTP_HOST
    port = Config.SMTP_PORT
    user = Config.SMTP_USER
    password = Config.SMTP_PASSWORD
    from_addr = Config.SMTP_FROM or user
    to_addr = to or Config.NOTIFY_TO or from_addr

    if not host or not user or not password:
        log.info("SMTP not configured - skipping notify '%s'", subject)
        return False
    if not to_addr:
        log.warning("SMTP: brak adresata (NOTIFY_TO/to pusty) - skip '%s'", subject)
        return False

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = from_addr
    msg["To"] = to_addr
    msg.set_content(body)

    try:
        if Config.SMTP_USE_TLS:
            with smtplib.SMTP(host, port, timeout=15) as s:
                s.ehlo()
                s.starttls()
                s.ehlo()
                s.login(user, password)
                s.send_message(msg)
        else:
            # SSL 465 albo bez szyfrowania (zwykle Gmail wymaga TLS na 587).
            with smtplib.SMTP_SSL(host, port, timeout=15) as s:
                s.login(user, password)
                s.send_message(msg)
        log.info("SMTP sent '%s' -> %s", subject, to_addr)
        return True
    except Exception as e:
        log.exception("SMTP send failed '%s' -> %s: %s", subject, to_addr, e)
        return False


def send_async(subject: str, body: str, to: str | None = None) -> None:
    """Fire-and-forget. Bezpieczne do wolania z requesta HTTP."""
    t = threading.Thread(
        target=_send_sync,
        args=(subject, body, to),
        daemon=True,
        name=f"notifier-{subject[:20]}",
    )
    t.start()


def notify_new_signup(
    *, email: str, consent: bool, ip: str | None, user_agent: str | None,
    hero_variant: str | None, signup_id: int,
) -> None:
    """Powiadomienie po kazdym signupie na /early-access.

    Wysylane asynchronicznie - nawet jesli SMTP wisi 30s, gosc nie czeka.
    """
    subject = f"[Akces Booth] Nowy zapis early-access: {email}"
    body = f"""Nowy zapis na liscie early-access Akces Booth.

Email:         {email}
Zgoda na info: {'TAK' if consent else 'nie'}
Wariant hero:  {hero_variant or 'safe'}
IP:            {ip or 'brak'}
User-Agent:    {(user_agent or 'brak')[:200]}
Signup ID:     {signup_id}

---
Lista wszystkich zapisanych:
{Config.PUBLIC_BASE_URL}/admin/early-access-signups

Landing:
{Config.PUBLIC_BASE_URL}/early-access/
"""
    send_async(subject, body)
