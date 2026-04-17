"""AI generator ramek overlay.

Flow:
1. Uzytkownik wypelnia formularz (typ eventu, styl, motyw, imiona, data).
2. Gemini 1.5 Pro generuje prompt dla Imagen.
3. Imagen 3 generuje 3 warianty ramek PNG.
4. Zapisujemy w `storage/overlays/ai_*.png` + wpisy w library_overlays.
5. Zwracamy JSON z listą wariantów (id + url).

Jesli Gemini/Imagen niedostepne (brak API key, blad network) - zwracamy blad
z czytelnym komunikatem zeby user wiedzial co fixnac.
"""
from __future__ import annotations

import base64
import logging
import uuid
from pathlib import Path
from typing import Any

from flask import Blueprint, jsonify, request

import models
from admin.auth import require_admin
from config import Config

log = logging.getLogger(__name__)

ai_bp = Blueprint("ai", __name__)


def _have_gemini() -> bool:
    return bool(Config.GEMINI_API_KEY)


def _build_imagen_prompt(*, event_type: str, style: str, theme: str,
                        names: str, event_date: str) -> str:
    """Fallback prompt jesli Gemini nie odpowie - w pewnym skroconym stylu."""
    return (
        f"Transparent PNG 1920x1080 photo booth overlay for {event_type}. "
        f"Style: {style}. Decorative edges only, center 60% empty. "
        f"Names: {names}. Date: {event_date}. Theme: {theme or 'elegant'}. "
        f"Elegant typography, no borders inside central area, suitable for "
        f"professional photo booth rental."
    )


def _refine_prompt_with_gemini(**kwargs: str) -> str:
    """Uses Gemini to craft better Imagen prompt. Fallback on error."""
    fallback = _build_imagen_prompt(**kwargs)
    if not _have_gemini():
        return fallback
    try:
        import google.generativeai as genai
        genai.configure(api_key=Config.GEMINI_API_KEY)
        model = genai.GenerativeModel("gemini-1.5-pro")
        resp = model.generate_content(
            f"""Create a prompt for Imagen 3 to generate a photo booth video overlay frame.

Event type: {kwargs['event_type']}
Style: {kwargs['style']}
Theme: {kwargs.get('theme') or '(none)'}
Names/Brand: {kwargs['names']}
Date: {kwargs['event_date']}

Requirements:
- Transparent PNG 1920x1080 landscape
- Center 60% area must be empty (video will appear there)
- Decorations only on edges: corners, top/bottom borders
- Elegant typography with names
- Style matches {kwargs['style']} aesthetic
- Suitable for professional photo booth rental

Output ONLY the Imagen prompt, no explanation, no markdown."""
        )
        text = (resp.text or "").strip()
        return text or fallback
    except Exception as e:  # noqa: BLE001
        log.warning("Gemini refine failed: %s. Using fallback prompt.", e)
        return fallback


def _generate_images_imagen(prompt: str, count: int = 3) -> list[bytes]:
    """Generuje obrazy przez Imagen 3. Rzuca wyjatek jesli API nie dostepne."""
    if not _have_gemini():
        raise RuntimeError(
            "GEMINI_API_KEY not set - cannot call Imagen API. "
            "Configure .env and restart."
        )

    import google.generativeai as genai
    genai.configure(api_key=Config.GEMINI_API_KEY)

    # Google SDK - Imagen 3 endpoint. SDK ma rozne interfejsy zaleznie od wersji.
    # Probujemy kilka podejsc, bierzemy pierwsze ktore zadziala.
    last_err: Exception | None = None

    # Preferujemy nowy klient `google-genai` jesli zainstalowany.
    try:
        from google import genai as new_genai  # type: ignore[import-not-found]
        client = new_genai.Client(api_key=Config.GEMINI_API_KEY)
        result = client.models.generate_images(
            model="imagen-3.0-generate-002",
            prompt=prompt,
            config={"number_of_images": count, "aspect_ratio": "16:9"},
        )
        images = []
        for gen in result.generated_images or []:
            data = gen.image.image_bytes  # type: ignore[attr-defined]
            images.append(data if isinstance(data, bytes) else bytes(data))
        if images:
            return images
    except ImportError:
        pass
    except Exception as e:  # noqa: BLE001
        last_err = e

    # Fallback: stary google-generativeai (moze nie dzialac dla Imagen).
    try:
        model = genai.GenerativeModel("models/imagen-3.0-generate-001")
        out: list[bytes] = []
        for _ in range(count):
            resp = model.generate_content(prompt)
            for cand in getattr(resp, "candidates", []) or []:
                for part in getattr(cand.content, "parts", []) or []:
                    inline = getattr(part, "inline_data", None)
                    if inline and getattr(inline, "data", None):
                        raw = inline.data
                        if isinstance(raw, str):
                            raw = base64.b64decode(raw)
                        out.append(bytes(raw))
                        break
        if out:
            return out
    except Exception as e:  # noqa: BLE001
        last_err = e

    raise RuntimeError(
        "Imagen 3 generation failed. "
        f"Install `google-genai` lub upewnij sie ze google-generativeai ma Imagen. "
        f"Ostatni blad: {last_err}"
    )


@ai_bp.route("/generate-overlays", methods=["POST"])
@require_admin
def generate_overlays():  # type: ignore[no-untyped-def]
    data: dict[str, Any] = request.get_json(silent=True) or request.form.to_dict()
    event_type = (data.get("event_type") or "wedding").strip()
    style = (data.get("style") or "classic").strip()
    theme = (data.get("theme") or "").strip()
    names = (data.get("names") or "").strip() or "Akces 360"
    event_date = (data.get("date") or "").strip()
    count = int(data.get("count") or 3)
    count = max(1, min(4, count))

    prompt = _refine_prompt_with_gemini(
        event_type=event_type,
        style=style,
        theme=theme,
        names=names,
        event_date=event_date,
    )

    try:
        images = _generate_images_imagen(prompt, count=count)
    except Exception as e:  # noqa: BLE001
        log.error("AI generation failed: %s", e)
        # Zwracamy 200 z error w body - inaczej Cloudflare podmienia 502 na HTML.
        return jsonify({
            "success": False,
            "error": "generation_failed",
            "message": str(e),
            "hint": "Dodaj GEMINI_API_KEY do .env na serwerze i zrestartuj "
                    "akces-booth.service. Klucz dostaniesz w aistudio.google.com.",
            "prompt_used": prompt,
        }), 200

    # Zapisz kazdy wariant do storage + DB.
    results = []
    overlay_dir = Config.STORAGE_PATH / "overlays"
    overlay_dir.mkdir(parents=True, exist_ok=True)
    for i, img_bytes in enumerate(images):
        filename = f"ai_{uuid.uuid4().hex[:10]}.png"
        path = overlay_dir / filename
        path.write_bytes(img_bytes)
        overlay_name = f"{names} {style} v{i+1}".strip()
        overlay_id = models.insert_overlay(
            Config.DB_PATH,
            name=overlay_name,
            file_path=str(path.relative_to(Config.BASE_DIR)),
            source="ai_generated",
            ai_prompt=prompt,
            tags=[event_type, style],
        )
        results.append({
            "id": overlay_id,
            "name": overlay_name,
            "url": f"/storage/overlays/{filename}",
        })

    return jsonify({
        "prompt_used": prompt,
        "variants": results,
    })
