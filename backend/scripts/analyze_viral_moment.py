"""Analizator 'viral moment' - szuka najmocniejszego beat drop / chorus entry.

Metodyka:
1. Wczytujemy audio przez librosa (resample do 22050 Hz mono).
2. Liczymy 3 cechy na ramki (frame_length=2048, hop_length=512, ~23 ms/hop):
   - RMS energy: glosnosc
   - Spectral flux: zmiana widma (perc. ataki, instrumenty dochodzace)
   - Onset strength: globalny oneset envelope
3. Tempo + beat tracking - zeby snap do faktycznego downbeatu.
4. 'Viral score' na okno 3s = rolling mean (onset + flux + energy).
5. Heurystyka: szukamy pozycji gdzie score rosnie maksymalnie po cichym regionie
   (beat drop/chorus wejscie), w przedziale 15-75% dlugosci utworu
   (na koncu juz za pozno, na starcu to zwykle intro).
6. Snap do najblizszego beatu zeby ciecia nie wlapywaly sie w srodek fra.
7. Clamp do [8s, duration-10s] zeby zostawic zapas na boomerang 8s.

Zwraca float seconds. Cache per-track w DB (wolajacy zapisze).

CLI (standalone):
    python analyze_viral_moment.py <plik_audio> [--json]

API (Flask):
    from scripts.analyze_viral_moment import analyze_file
    offset = analyze_file(path)

Zaleznosci: librosa >= 0.10, numpy. Zamontowane w requirements.txt.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

import numpy as np

try:
    import librosa
except ImportError as e:
    print(f"ERROR: librosa nie zainstalowana: {e}", file=sys.stderr)
    print("Zainstaluj: pip install librosa", file=sys.stderr)
    sys.exit(2)


def _ensure_ffmpeg_on_path() -> None:
    """Doklada imageio-ffmpeg na PATH jesli nie ma systemowego ffmpeg.
    librosa.load uzywa audioread ktore woola ffmpeg subprocessem dla .webm/.m4a
    itp. Na Windows dev maszynie user moze nie miec ffmpeg w PATH.
    """
    # Quick check - fast path gdy ffmpeg juz jest.
    for entry in os.environ.get("PATH", "").split(os.pathsep):
        if entry and (Path(entry) / "ffmpeg.exe").exists():
            return
        if entry and (Path(entry) / "ffmpeg").exists():
            return
    try:
        import imageio_ffmpeg  # type: ignore
        exe = imageio_ffmpeg.get_ffmpeg_exe()
        os.environ["PATH"] = str(Path(exe).parent) + os.pathsep + os.environ.get("PATH", "")
    except Exception:
        pass


_ensure_ffmpeg_on_path()


def _ffmpeg_binary() -> str | None:
    """Znajdz sciezke do ffmpeg (systemowy albo imageio_ffmpeg bundled)."""
    from shutil import which
    exe = which("ffmpeg")
    if exe:
        return exe
    try:
        import imageio_ffmpeg  # type: ignore
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return None


def _load_audio(path: Path, target_sr: int) -> tuple[np.ndarray, int]:
    """Laduje audio robustnie. Zawsze via ffmpeg subprocess -> wav -> soundfile.
    Nie uzywamy librosa.load bo jego audioread fallback powoduje SIGSEGV
    na Pi (libsndfile nie wspiera mp3/m4a, audioread natywnie crashuje).
    """
    ff = _ffmpeg_binary()
    if ff is None:
        raise RuntimeError(
            "Nie umiem zdekodowac audio. Zainstaluj ffmpeg albo imageio-ffmpeg."
        )
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_path = tmp.name
    try:
        cmd = [
            ff, "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(path),
            "-ac", "1", "-ar", str(target_sr),
            "-f", "wav", tmp_path,
        ]
        subprocess.run(cmd, check=True, capture_output=True, timeout=60)
        # soundfile czyta wav natywnie (libsndfile - zero subprocess, bez audioread).
        import soundfile as sf  # noqa: WPS433 (inline - only when needed)
        y, sr = sf.read(tmp_path, dtype="float32", always_2d=False)
        if y.ndim > 1:
            y = y.mean(axis=1)
        if sr != target_sr:
            # resample if ffmpeg didnt match (rare - bit zero-pad edge).
            y = librosa.resample(y, orig_sr=sr, target_sr=target_sr)
            sr = target_sr
        return y, sr
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass


# Ramki analizy - balans miedzy rozdzielczoscia a szybkoscia.
_SAMPLE_RATE = 22050
_HOP_LENGTH = 512  # ~23.2 ms @ 22050 Hz
_FRAME_LENGTH = 2048

# Okno 'score' rolling - 3 sek uwzglednia kilka taktow.
_SCORE_WINDOW_SEC = 3.0

# Przedzialy wyszukiwania drop/chorus - procent dlugosci utworu.
_SEARCH_MIN_FRAC = 0.15
_SEARCH_MAX_FRAC = 0.75

# Clamp output zeby zostawic zapas na nagranie (boomerang 8s + margines).
_OUTPUT_MIN_SEC = 8.0
_OUTPUT_TAIL_MARGIN = 10.0


def analyze_file(path: str | Path) -> dict[str, Any]:
    """Analizuje plik audio, zwraca dict z offsetem i diagnostyka.

    Wynik:
        {
            "offset_sec": float,     # timestamp viral moment
            "duration_sec": float,
            "confidence": float,     # 0..1 - jak wyraziste byl pik
            "tempo_bpm": float,
            "method": "onset_rise_after_quiet",
        }

    Rzuca Exception jesli plik bledny.
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Audio not found: {p}")

    # load: zwraca y (audio), sr. mono=True scala do 1-kanalu. Robustny loader -
    # fallback na ffmpeg subprocess dla webm/m4a gdzie soundfile zawiedzie.
    y, sr = _load_audio(p, _SAMPLE_RATE)
    duration = float(librosa.get_duration(y=y, sr=sr))

    if duration < 20.0:
        # Zbyt krotki utwor - zwracamy default, nie ma gdzie szukac.
        return {
            "offset_sec": max(_OUTPUT_MIN_SEC, duration * 0.3),
            "duration_sec": duration,
            "confidence": 0.0,
            "tempo_bpm": 0.0,
            "method": "too_short_default",
        }

    # Cechy na ramki.
    rms = librosa.feature.rms(
        y=y, frame_length=_FRAME_LENGTH, hop_length=_HOP_LENGTH
    )[0]
    onset_env = librosa.onset.onset_strength(
        y=y, sr=sr, hop_length=_HOP_LENGTH
    )
    # Spectral flux = roznica L2 miedzy kolejnymi widmami - charakteryzuje
    # 'przyjscie' nowych instrumentow (wlasciwie co robi onset_strength,
    # ale oba razem daja wyraznie lepsze wyniki przy niektorych gatunkach).
    S = np.abs(librosa.stft(y, n_fft=_FRAME_LENGTH, hop_length=_HOP_LENGTH))
    flux = np.sqrt(np.sum(np.diff(S, axis=1) ** 2, axis=0))
    flux = np.maximum(flux, 0.0)
    # Padding zeby dlugosc sie zgadzala.
    flux = np.concatenate([[0.0], flux])

    # Wyrownanie dlugosci (czasem roznia sie o 1 przez STFT padding).
    min_len = min(len(rms), len(onset_env), len(flux))
    rms = rms[:min_len]
    onset_env = onset_env[:min_len]
    flux = flux[:min_len]

    # Normalizacja kazdej cechy do [0,1] (z-score moglby byc lepszy ale
    # czasem RMS ma outliers - min-max jest bardziej robustny).
    def _norm(x: np.ndarray) -> np.ndarray:
        lo, hi = float(np.percentile(x, 5)), float(np.percentile(x, 95))
        if hi - lo < 1e-9:
            return np.zeros_like(x)
        return np.clip((x - lo) / (hi - lo), 0.0, 1.0)

    rms_n = _norm(rms)
    onset_n = _norm(onset_env)
    flux_n = _norm(flux)

    # Combined 'energy score'. Wagi: onset + flux lepsze przy detekcji drop'a,
    # RMS zabezpiecza przed false positives w cichym podkladzie.
    energy = 0.45 * onset_n + 0.35 * flux_n + 0.20 * rms_n

    # Rolling mean okno _SCORE_WINDOW_SEC.
    frames_per_sec = sr / _HOP_LENGTH
    win_frames = max(1, int(_SCORE_WINDOW_SEC * frames_per_sec))
    # Prosty moving average przez convolve.
    kernel = np.ones(win_frames) / win_frames
    smooth = np.convolve(energy, kernel, mode="same")

    # Beat tracking - uzywamy do snap offsetu do downbeatu.
    tempo, beats = librosa.beat.beat_track(
        onset_envelope=onset_env, sr=sr, hop_length=_HOP_LENGTH
    )
    tempo_bpm = float(tempo) if np.isscalar(tempo) else float(tempo[0])
    beat_times = librosa.frames_to_time(
        beats, sr=sr, hop_length=_HOP_LENGTH
    )

    # Szukamy 'skoku' - dla kazdej ramki liczymy roznice between smooth[i]
    # a minimalnym smooth w oknie 4s przed. Gdzie roznica najwieksza - drop.
    lookback_frames = int(4.0 * frames_per_sec)
    best_rise = -1.0
    best_frame = -1

    search_start = int(len(smooth) * _SEARCH_MIN_FRAC)
    search_end = int(len(smooth) * _SEARCH_MAX_FRAC)

    for i in range(search_start, search_end):
        lo_idx = max(0, i - lookback_frames)
        window_min = float(np.min(smooth[lo_idx:i + 1]))
        rise = float(smooth[i]) - window_min
        # Bonus: wartosc absolutna energia musi byc dostatecznie wysoka
        # (drop po prawdziwej cichej sekcji jest gwoldziem gatunku).
        abs_score = rise + 0.3 * float(smooth[i])
        if abs_score > best_rise:
            best_rise = abs_score
            best_frame = i

    if best_frame < 0:
        # Fallback - zadnego piku nie znalezione, wroc 30% dlugosci.
        offset_sec = max(_OUTPUT_MIN_SEC, duration * 0.3)
        confidence = 0.0
    else:
        offset_sec = librosa.frames_to_time(
            best_frame, sr=sr, hop_length=_HOP_LENGTH
        )
        offset_sec = float(offset_sec)
        # Snap do najblizszego downbeatu (co 4 beaty) jezeli dostepne.
        if len(beat_times) > 4:
            # Prosty downbeat guess - co 4 beat.
            downbeats = beat_times[::4]
            if len(downbeats) > 0:
                idx = int(np.argmin(np.abs(downbeats - offset_sec)))
                snapped = float(downbeats[idx])
                # Tylko snapujemy jesli blisko (< 1s), inaczej beat tracker
                # moze przegapic downbeat i odciagnac nas daleko.
                if abs(snapped - offset_sec) < 1.0:
                    offset_sec = snapped
        # Confidence = znormalizowany rise w oknie 0..1.
        confidence = float(min(1.0, best_rise / 1.5))

    # Clamp - minimum 8s (intro ma cos do pokazania), max tail margin.
    max_allowed = max(_OUTPUT_MIN_SEC, duration - _OUTPUT_TAIL_MARGIN)
    offset_sec = float(np.clip(offset_sec, _OUTPUT_MIN_SEC, max_allowed))

    return {
        "offset_sec": round(offset_sec, 2),
        "duration_sec": round(duration, 2),
        "confidence": round(confidence, 3),
        "tempo_bpm": round(tempo_bpm, 1),
        "method": "onset_rise_after_quiet",
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Analyze viral moment in audio")
    parser.add_argument("path", help="Path to audio file (mp3/m4a/wav/ogg/webm)")
    parser.add_argument(
        "--json", action="store_true",
        help="Output machine-readable JSON (default: human-readable)",
    )
    args = parser.parse_args(argv)

    try:
        result = analyze_file(args.path)
    except Exception as e:
        err = {"error": str(e)}
        print(json.dumps(err) if args.json else f"ERROR: {e}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(result))
    else:
        print(f"File: {args.path}")
        print(f"  duration:   {result['duration_sec']:.1f}s")
        print(f"  tempo:      {result['tempo_bpm']:.0f} BPM")
        print(f"  viral at:   {result['offset_sec']:.2f}s "
              f"({result['offset_sec']/result['duration_sec']*100:.0f}% utworu)")
        print(f"  confidence: {result['confidence']:.2f}")
        print(f"  method:     {result['method']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
