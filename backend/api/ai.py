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
                        names: str, event_date: str) -> str:  # noqa: ARG001
    """Fallback prompt jesli Gemini nie odpowie.

    WAZNE: ramki generujemy BEZ TEKSTU. Gemini image model notorycznie
    przekreca pisownie ("Adriany" -> "Adriana", itp.). Tekst wypisujemy
    na video w Recorderze przez FFmpeg drawtext z text_top/text_bottom
    eventu - gwarantowana poprawna pisownia.
    """
    # names/event_date CELOWO IGNORUJEMY w prompcie - Gemini jak je zobaczy
    # to wepcha na obraz mimo "no text". Tekst dokleja Recorder FFmpeg drawtext.
    return (
        f"Transparent PNG 1080x1920 portrait photo booth overlay for {event_type}. "
        f"Style: {style}. Theme: {theme or 'elegant'}. "
        f"Decorative border at the edges (top, bottom, corners, sides) - "
        f"LIGHT to MEDIUM thickness, ornaments occupy only 6-9%% of image "
        f"width on each side. Keep it airy and delicate, not heavy or chunky. "
        f"Center area 70%% width x 75%% height COMPLETELY EMPTY (video there). "
        f"IMPORTANT: NO TEXT, NO WORDS, NO LETTERS, NO NAMES, NO DATES anywhere "
        f"on the image - pure decorative ornaments only (flowers, swirls, "
        f"geometric patterns). Delicate, refined ornaments - thinner rather "
        f"than thicker. No inner frame lines crossing center."
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
                f"Theme: {kwargs.get('theme') or '(none)'}\n\n"
                # CELOWO nie przekazujemy names/event_date do Gemini - gdyby
                # zobaczyl te dane, wepchnalby je na obraz mimo instrukcji
                # "no text" (AI image modele reaguja na obecnosc danych w
                # promcie). Tekst na video dokleja Recorder przez FFmpeg
                # drawtext - pisownia gwarantowana poprawna.
                "CRITICAL requirements:\n"
                "- Transparent PNG 1080x1920 PORTRAIT orientation (taller than wide)\n"
                "- Decorative border on all 4 edges, LIGHT to MEDIUM thickness -\n"
                "  occupies only 6-9%% of image width on each side. Delicate,\n"
                "  airy, refined ornaments. NOT heavy, NOT chunky, NOT thick walls.\n"
                "- Center area 70%% width x 75%% height must be COMPLETELY EMPTY\n"
                "  (video will appear there - do not put anything in the middle)\n"
                "- Decorations: ornate corners + flowing side borders + top/bottom bands\n"
                "- *** ABSOLUTELY NO TEXT, NO WORDS, NO LETTERS, NO NAMES, NO DATES ***\n"
                "  on the image. Text will be added separately by the video processor.\n"
                "  The frame must be PURELY DECORATIVE - flowers, swirls, geometric\n"
                "  patterns, borders. NOT A SINGLE CHARACTER anywhere.\n"
                f"- Style matches {kwargs['style']} aesthetic\n"
                "- NO central ornaments crossing video area, NO inner rectangle frame lines\n"
                "- Output orientation: PORTRAIT / vertical (phone aspect 9:16)\n\n"
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


def _remove_bg_floodfill(
    img: "Image.Image",
    *,
    threshold: int = 200,
    feather_px: int = 4,
) -> "Image.Image":
    """Usuwa jasne tlo connected z brzegami (flood-fill od 4 rogow).
    Chroni jasne detale wewnatrz kompozycji (rozowe roze, srebrne ornamenty)
    bo liczy tylko connected component dotykajacy brzegu.

    threshold: min RGB (per channel) zeby pixel byl uznany za "biel".
    feather_px: Gaussian blur mask bg na granicy (smooth edge blend).
    """
    try:
        import numpy as np  # noqa: WPS433
        from scipy.ndimage import label  # noqa: WPS433
    except ImportError:
        log.warning("numpy/scipy not available - skipping bg floodfill")
        return img

    arr = np.array(img)
    if arr.ndim != 3 or arr.shape[2] != 4:
        return img
    r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    bright = (r >= threshold) & (g >= threshold) & (b >= threshold)
    labeled, _n = label(bright)
    # Flood-fill od CALYCH krawedzi + pixeli juz transparentnych (cutout
    # centrum zrobiony wczesniej w make_frame_transparent). Uzywamy obu
    # zrodel seeds: edge daje tlo connected z brzegiem, alpha=0 daje tlo
    # sasiadujace z cutoutem (biale paski tuz przy krawedzi wideo).
    edge_labels = np.concatenate([
        labeled[0, :],
        labeled[-1, :],
        labeled[:, 0],
        labeled[:, -1],
    ])
    bg_labels: set[int] = {int(x) for x in np.unique(edge_labels) if x > 0}
    # Seed z juz-transparentnych pixeli (cutout): dowolny bright label
    # stykajacy sie z alpha=0 = tlo.
    transparent_mask = (a == 0)
    transparent_labels = np.unique(labeled[transparent_mask])
    bg_labels.update(int(x) for x in transparent_labels if x > 0)
    if not bg_labels:
        return img
    bg_mask = np.isin(labeled, list(bg_labels))

    # Feather na granicy bg: blur maski bg, odejmuj od alpha.
    bg_mask_u8 = (bg_mask.astype(np.uint8) * 255)
    if feather_px > 0:
        bg_mask_img = Image.fromarray(bg_mask_u8, mode="L").filter(
            ImageFilter.GaussianBlur(radius=feather_px)
        )
        bg_mask_u8 = np.array(bg_mask_img)
    bg_norm = bg_mask_u8.astype(np.float32) / 255.0

    new_alpha = (a.astype(np.float32) * (1.0 - bg_norm)).clip(0, 255).astype(np.uint8)
    arr[..., 3] = new_alpha
    return Image.fromarray(arr, mode="RGBA")


def make_frame_transparent(
    png_bytes: bytes,
    *,
    out_width: int = 1080,
    out_height: int = 1920,
    center_width_frac: float = 0.50,
    center_height_frac: float = 0.50,
    feather_px: int = 16,
    white_key: bool = False,
    white_brightness: int = 252,
    white_saturation: float = 0.03,
    bg_floodfill: bool = True,
    bg_threshold: int = 220,
    bg_feather_px: int = 4,
) -> bytes:
    """Post-process ramki: resize do portrait output + transparentne centrum +
    opcjonalny color-key bieli (Gemini zwraca RGB z bialym tlem wokol
    ornamentow, bez chroma key bialy kwadrat otacza ornamenty na calej ramce).

    - out_width/out_height: rozdzielczosc docelowa (1080x1920 portrait dla video)
    - center_*_frac: jaka czesc powierzchni kwadratu w srodku jest cut transparent
    - feather_px: promien Gaussian blur na krawedzi kwadratu (smooth)
    - white_key: gdy True, jasne + nie-nasycone pixele (bialo/kremowe tlo) daja
      alpha=0 zostawiajac tylko nasycone ornamenty (zloto/srebro/kolory)
    - white_brightness: min RGB max-channel uznane za "bialy" (0-255)
    - white_saturation: max saturation (0-1) uznana za "bialy" (0.12 = bardzo
      malo nasycone)
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

    # Color-key bieli: usun bialo/kremowe tlo zostawiajac tylko ornamenty.
    if white_key:
        try:
            import numpy as np  # noqa: WPS433 (inline import - scipy heavy)
            arr = np.array(img)  # shape (H, W, 4) uint8
            r = arr[..., 0].astype(np.int16)
            g = arr[..., 1].astype(np.int16)
            b = arr[..., 2].astype(np.int16)
            max_ch = np.maximum(np.maximum(r, g), b)
            min_ch = np.minimum(np.minimum(r, g), b)
            # Saturation w przyblizeniu HSV: (max-min)/max
            sat = np.where(max_ch > 0,
                           (max_ch - min_ch) / np.maximum(max_ch, 1),
                           0)
            white_mask = (max_ch >= white_brightness) & (sat <= white_saturation)
            # Wyzeruj alpha tam gdzie white (pamieta ze alpha byla z putalpha
            # powyzej - teraz dodatkowo wycinamy bialo-kremowe tlo).
            arr[..., 3] = np.where(white_mask, 0, arr[..., 3]).astype(np.uint8)
            img = Image.fromarray(arr, mode="RGBA")
        except ImportError:
            log.warning("numpy not available - skipping white key")
        except Exception as e:  # noqa: BLE001
            log.warning("white key failed: %s", e)

    # Flood-fill od rogow: usuwa bialo/jasne tlo connected z brzegiem,
    # chroni rozane/srebrne detale wewnatrz kompozycji. Dziala po cutout
    # centrum + feather, nie interferuje z alpha srodka.
    if bg_floodfill:
        img = _remove_bg_floodfill(
            img, threshold=bg_threshold, feather_px=bg_feather_px,
        )

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
