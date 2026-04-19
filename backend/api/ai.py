"""AI generator ramek overlay.

Flow:
1. Uzytkownik wypelnia formularz (typ eventu, styl, motyw, imiona, data).
2. Gemini 2.5 Pro generuje prompt dla image model.
3. gemini-2.5-flash-image generuje N wariantow ramek PNG.
4. Post-process: doskalowanie do 1080x1920 portrait + cutout transparentnego
   centrum (Gemini daje RGB bez alphy, my go robimy RGBA z dziura).
5. Zapisujemy w `storage/overlays/ai_*.png` + wpisy w library_overlays.
6. Zwracamy JSON z lista wariantow.

Uzywamy nowego `google-genai` pakietu (starszy `google-generativeai`
zostal zdeprecjonowany w pazdzierniku 2025).
"""
from __future__ import annotations

import base64
import io
import logging
import uuid
from pathlib import Path
from typing import Any

from flask import Blueprint, jsonify, request

import models
from admin.auth import require_admin
from config import Config

try:
    from PIL import Image, ImageDraw, ImageFilter
    _HAVE_PIL = True
except ImportError:
    _HAVE_PIL = False

log = logging.getLogger(__name__)

ai_bp = Blueprint("ai", __name__)

# Modele Google AI (stan na listopad 2025)
TEXT_MODEL = "gemini-2.5-flash"           # szybki, do pisania promptow
IMAGE_MODEL = "gemini-2.5-flash-image"    # generuje obrazy (Imagen 3 deprecated)


def _have_gemini() -> bool:
    return bool(Config.GEMINI_API_KEY)


def _build_imagen_prompt(*, event_type: str, style: str, theme: str,
                        names: str, event_date: str) -> str:
    """Fallback prompt jesli Gemini nie odpowie."""
    return (
        f"Transparent PNG 1920x1080 photo booth overlay for {event_type}. "
        f"Style: {style}. Decorative edges only, center 60% empty. "
        f"Names: {names}. Date: {event_date}. Theme: {theme or 'elegant'}. "
        f"Elegant typography, no borders inside central area."
    )


def _refine_prompt_with_gemini(**kwargs: str) -> str:
    """Uzywa Gemini do napisania lepszego prompta dla image modelu."""
    fallback = _build_imagen_prompt(**kwargs)
    if not _have_gemini():
        return fallback
    try:
        from google import genai  # type: ignore[import-not-found]

        client = genai.Client(api_key=Config.GEMINI_API_KEY)
        resp = client.models.generate_content(
            model=TEXT_MODEL,
            contents=(
                "Create a detailed prompt for an AI image generator to produce "
                "a photo booth video overlay frame.\n\n"
                f"Event type: {kwargs['event_type']}\n"
                f"Style: {kwargs['style']}\n"
                f"Theme: {kwargs.get('theme') or '(none)'}\n"
                f"Names/Brand: {kwargs['names']}\n"
                f"Date: {kwargs['event_date']}\n\n"
                "Requirements:\n"
                "- Transparent PNG 1920x1080 landscape\n"
                "- Center 60% area must be empty (video appears there)\n"
                "- Decorations only on edges: corners, top/bottom borders\n"
                "- Elegant typography with names clearly visible\n"
                f"- Style matches {kwargs['style']} aesthetic\n"
                "- Suitable for professional photo booth rental\n\n"
                "Output ONLY the image generation prompt, no explanation, no markdown."
            ),
        )
        text = (resp.text or "").strip()
        return text or fallback
    except Exception as e:  # noqa: BLE001
        log.warning("Gemini refine failed: %s. Using fallback prompt.", e)
        return fallback


def _generate_images(prompt: str, count: int = 3) -> list[bytes]:
    """Generuje obrazy przez gemini-2.5-flash-image.

    Raise RuntimeError jesli niedostepne.
    """
    if not _have_gemini():
        raise RuntimeError(
            "GEMINI_API_KEY not set - cannot call image API. "
            "Configure .env and restart."
        )

    from google import genai  # type: ignore[import-not-found]

    client = genai.Client(api_key=Config.GEMINI_API_KEY)
    images: list[bytes] = []
    last_err: Exception | None = None

    # Gemini 2.5 flash image generuje 1 obraz per request. Wywolamy N razy.
    for i in range(count):
        try:
            resp = client.models.generate_content(
                model=IMAGE_MODEL,
                contents=prompt,
            )
            # Zbieraj inline image data z kandydatow
            for cand in resp.candidates or []:
                if not cand.content or not cand.content.parts:
                    continue
                for part in cand.content.parts:
                    inline = getattr(part, "inline_data", None)
                    if inline is None:
                        continue
                    data = inline.data
                    if isinstance(data, str):
                        data = base64.b64decode(data)
                    images.append(bytes(data))
                    break
                if len(images) > i:
                    break
        except Exception as e:  # noqa: BLE001
            last_err = e
            log.warning("Image gen %d/%d fail: %s", i + 1, count, e)

    if not images:
        raise RuntimeError(
            f"Image generation failed - zero outputs. Ostatni blad: {last_err}"
        )
    return images


def make_frame_transparent(
    png_bytes: bytes,
    *,
    out_width: int = 1080,
    out_height: int = 1920,
    center_width_frac: float = 0.60,
    center_height_frac: float = 0.55,
    feather_px: int = 40,
) -> bytes:
    """Post-process ramki: resize do portrait output dims, wycina transparentne
    centrum (zeby video bylo widoczne przez srodek) z feathered edge (zeby
    przejscie nie bylo ostre).

    - out_width/out_height: rozdzielczosc docelowa (1080x1920 portrait dla video)
    - center_*_frac: jaka czesc powierzchni zostaje transparentna
    - feather_px: promien Gaussian blur na krawedzi maski (smooth)
    """
    if not _HAVE_PIL:
        log.warning("PIL not available - zwracam oryginal bez post-processingu")
        return png_bytes

    img = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    img = img.resize((out_width, out_height), Image.Resampling.LANCZOS)

    # Alpha mask: bialy = opaque, czarny = transparent.
    mask = Image.new("L", (out_width, out_height), 255)
    draw = ImageDraw.Draw(mask)
    cw = int(out_width * center_width_frac)
    ch = int(out_height * center_height_frac)
    x0 = (out_width - cw) // 2
    y0 = (out_height - ch) // 2
    draw.rectangle([x0, y0, x0 + cw, y0 + ch], fill=0)

    # Feather edge przez Gaussian blur zeby przejscie bylo miekkie
    # (bez tego video "odcina" sie ostra krawedzia od ramki).
    if feather_px > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(radius=feather_px))

    img.putalpha(mask)
    out = io.BytesIO()
    # optimize=True powoduje '_idat has no attribute fileno' z BytesIO na
    # niektorych Pillow + Python 3.13. Bez optimize dziala stabilnie.
    img.save(out, format="PNG")
    return out.getvalue()


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
        images = _generate_images(prompt, count=count)
    except Exception as e:  # noqa: BLE001
        log.error("AI generation failed: %s", e)
        # 200 OK z error body - Cloudflare nie podmienia na HTML page.
        return jsonify({
            "success": False,
            "error": "generation_failed",
            "message": str(e),
            "hint": "Sprawdz GEMINI_API_KEY w .env. Klucz z aistudio.google.com. "
                    "Uzywamy modelu " + IMAGE_MODEL + ".",
            "prompt_used": prompt,
        }), 200

    # Zapisz kazdy wariant do storage + DB.
    results = []
    overlay_dir = Config.STORAGE_PATH / "overlays"
    overlay_dir.mkdir(parents=True, exist_ok=True)
    for i, img_bytes in enumerate(images):
        filename = f"ai_{uuid.uuid4().hex[:10]}.png"
        path = overlay_dir / filename
        # Gemini daje RGB PNG - my doskalowujemy do 1080x1920 portrait
        # i robimy transparentne centrum, zeby bylo to realne "ramka" a nie
        # nieprzezroczysty prostokat zakrywajacy video.
        try:
            processed = make_frame_transparent(img_bytes)
        except Exception as e:  # noqa: BLE001
            log.warning("Post-processing failed, saving raw: %s", e)
            processed = img_bytes
        path.write_bytes(processed)
        overlay_name = f"{names} {style} v{i+1}".strip()
        # Zapisujemy path relative do BASE_DIR jesli mozliwe, inaczej absolute.
        try:
            rel_path = str(path.resolve().relative_to(Config.BASE_DIR.resolve()))
        except ValueError:
            rel_path = str(path)
        overlay_id = models.insert_overlay(
            Config.DB_PATH,
            name=overlay_name,
            file_path=rel_path,
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
        "success": True,
        "prompt_used": prompt,
        "variants": results,
    })
