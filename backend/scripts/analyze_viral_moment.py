"""Analizator 'viral moment' - szuka najmocniejszego beat drop / chorus entry.

Metodyka:
1. Wczytujemy audio przez ffmpeg subprocess -> wav -> soundfile (22050 Hz mono).
2. Liczymy 3 cechy na ramki (frame_length=2048, hop_length=512, ~23 ms/hop):
   - RMS energy: glosnosc
   - Spectral flux: zmiana widma (perc. ataki, instrumenty dochodzace)
   - Onset envelope: pochodna logarytmicznego spectrogramu
3. Tempo + beat tracking (autokorelacja onset envelope) - snap do downbeatu.
4. 'Viral score' na okno 3s = rolling mean (onset + flux + energy).
5. Heurystyka: szukamy pozycji gdzie score rosnie maksymalnie po cichym regionie
   (beat drop/chorus wejscie), w przedziale 15-75% dlugosci utworu.
6. Snap do najblizszego beatu zeby ciecia nie wlapywaly sie w srodek frazy.
7. Clamp do [8s, duration-10s].

Zwraca float seconds. Cache per-track w DB (wolajacy zapisze).

**Uwaga: celowo NIE uzywamy librosa** - librosa.feature.rms / onset_strength /
beat_track polegaja na numba JIT ktore na Pi (ARM + specyficzny build
llvmlite) daje SIGSEGV. Pure numpy + scipy.signal = stabilne na x86 i ARM.

CLI (standalone):
    python analyze_viral_moment.py <plik_audio> [--json]

API (Flask):
    from scripts.analyze_viral_moment import analyze_file
    offset = analyze_file(path)

Zaleznosci: numpy, scipy, soundfile (wszystkie transitive librosa deps).
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


def _ensure_ffmpeg_on_path() -> None:
    """Doklada imageio-ffmpeg na PATH jesli nie ma systemowego ffmpeg."""
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
    Nie uzywamy librosa.load bo audioread fallback daje SIGSEGV na Pi.
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
        import soundfile as sf  # noqa: WPS433 (inline - only when needed)
        y, sr = sf.read(tmp_path, dtype="float32", always_2d=False)
        if y.ndim > 1:
            y = y.mean(axis=1)
        if sr != target_sr:
            # Fallback resample przez scipy jesli ffmpeg nie zachowal SR.
            from scipy.signal import resample_poly  # noqa: WPS433
            # resample_poly wymaga int up/down factors
            from math import gcd
            g = gcd(target_sr, sr)
            up = target_sr // g
            down = sr // g
            y = resample_poly(y, up, down).astype(np.float32)
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
# Chorus/drop w pop/dance jest typowo 25-60% utworu. Intro/verse z
# wokalami wpadal wczesniej w poprzednim 15% -> analiza pikowala na
# verse zamiast chorus (user: "slychac jak ktos na poczatku spiewa").
_SEARCH_MIN_FRAC = 0.25
_SEARCH_MAX_FRAC = 0.75

# Clamp output zeby zostawic zapas na nagranie (boomerang 8s + margines).
_OUTPUT_MIN_SEC = 8.0
_OUTPUT_TAIL_MARGIN = 10.0


def _frame_signal(y: np.ndarray, frame_length: int, hop_length: int) -> np.ndarray:
    """Zwraca macierz (n_frames, frame_length) - y pociete na ramki.
    Pure numpy - bez librosa.util.frame (unika numba JIT).
    """
    if len(y) < frame_length:
        # Dla bardzo krotkiego sygnalu padding zerami.
        y = np.pad(y, (0, frame_length - len(y)))
    n_frames = 1 + (len(y) - frame_length) // hop_length
    if n_frames <= 0:
        return np.zeros((0, frame_length), dtype=y.dtype)
    # Strided view - O(1) memory. Korzystamy ze stride_tricks dla szybkosci.
    bytes_per_sample = y.strides[0]
    shape = (n_frames, frame_length)
    strides = (hop_length * bytes_per_sample, bytes_per_sample)
    frames = np.lib.stride_tricks.as_strided(y, shape=shape, strides=strides)
    return frames


def _rms_per_frame(y: np.ndarray, frame_length: int, hop_length: int) -> np.ndarray:
    """RMS energy per frame - pure numpy, zastepuje librosa.feature.rms."""
    frames = _frame_signal(y, frame_length, hop_length)
    # RMS = sqrt(mean(x^2)) per row
    return np.sqrt(np.mean(frames.astype(np.float64) ** 2, axis=1)).astype(np.float32)


def _stft_magnitude(y: np.ndarray, n_fft: int, hop_length: int) -> np.ndarray:
    """STFT magnitude (n_bins, n_frames). Uzywa scipy.signal jako stabilny
    odpowiednik librosa.stft."""
    from scipy.signal import stft as sp_stft  # noqa: WPS433
    # Hanning window, noverlap = n_fft - hop_length
    _, _, Z = sp_stft(
        y,
        fs=1.0,  # nie potrzebujemy real-time freqs tutaj
        window="hann",
        nperseg=n_fft,
        noverlap=n_fft - hop_length,
        nfft=n_fft,
        return_onesided=True,
        padded=True,
        boundary="zeros",
    )
    return np.abs(Z).astype(np.float32)


def _onset_envelope(mag: np.ndarray) -> np.ndarray:
    """Onset strength envelope = sum po binach pozytywnej pochodnej log magnitude.
    Standardowy 'spectral flux' onset detector - zastepuje librosa.onset.onset_strength.
    """
    # Log-magnitude compression (librosa uzywa np. log(1 + gamma*mag)).
    log_mag = np.log1p(10.0 * mag)
    # Pozytywna pochodna - tylko wzrost, bo onset = przyjscie nowego dzwieku.
    diff = np.diff(log_mag, axis=1)
    diff = np.maximum(diff, 0.0)
    # Suma po biny = jeden float per ramke.
    env = np.sum(diff, axis=0)
    # Padding zeby zachowac dlugosc == n_frames magnitude.
    env = np.concatenate([[0.0], env])
    return env.astype(np.float32)


def _estimate_tempo_and_beats(
    onset_env: np.ndarray, sr: int, hop_length: int,
) -> tuple[float, np.ndarray]:
    """Estymacja tempo (BPM) przez autokorelacje onset envelope + beat times.
    Zastepuje librosa.beat.beat_track - prosta wersja bez Dynamic Programming.
    """
    if len(onset_env) < 4:
        return 0.0, np.array([], dtype=np.float32)

    # Autokorelacja - znajdujemy periodicznosc.
    frames_per_sec = sr / hop_length
    # Szukamy BPM w zakresie 60-200 (praktyczne tempo muzyki tanecznej).
    min_lag = max(1, int(frames_per_sec * 60.0 / 200.0))
    max_lag = int(frames_per_sec * 60.0 / 60.0)
    max_lag = min(max_lag, len(onset_env) - 1)
    if max_lag <= min_lag:
        return 0.0, np.array([], dtype=np.float32)

    # Usun DC component - srednia z onset_env.
    oe = onset_env - np.mean(onset_env)
    # np.correlate(a, a, 'full') = autokorelacja, srodek = lag 0.
    # Uzywamy scipy.signal.correlate ktore jest szybsze przez FFT.
    try:
        from scipy.signal import correlate  # noqa: WPS433
        ac = correlate(oe, oe, mode="full", method="fft")
    except Exception:
        ac = np.correlate(oe, oe, mode="full")
    ac = ac[len(ac) // 2:]  # tylko pozytywne lag

    # Peak w przedziale [min_lag, max_lag] = dominujacy okres.
    window = ac[min_lag:max_lag + 1]
    if window.size == 0:
        return 0.0, np.array([], dtype=np.float32)
    peak_offset = int(np.argmax(window))
    period_frames = min_lag + peak_offset
    if period_frames <= 0:
        return 0.0, np.array([], dtype=np.float32)

    bpm = 60.0 * frames_per_sec / period_frames

    # Beat times - rozmieszczamy beats co period_frames, zaczynajac od
    # miejsca gdzie onset jest najsilniejszy w pierwszych 2 okresach.
    first_search_end = min(len(onset_env), 2 * period_frames)
    first_beat_frame = int(np.argmax(onset_env[:first_search_end]))

    beat_frames = []
    frame = first_beat_frame
    while frame < len(onset_env):
        beat_frames.append(frame)
        frame += period_frames

    beat_times = np.array(beat_frames, dtype=np.float32) * hop_length / sr
    return float(bpm), beat_times


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

    y, sr = _load_audio(p, _SAMPLE_RATE)
    duration = float(len(y)) / float(sr)

    if duration < 20.0:
        return {
            "offset_sec": max(_OUTPUT_MIN_SEC, duration * 0.3),
            "duration_sec": duration,
            "confidence": 0.0,
            "tempo_bpm": 0.0,
            "method": "too_short_default",
        }

    # STFT magnitude - podstawa pod flux + onset envelope.
    mag = _stft_magnitude(y, n_fft=_FRAME_LENGTH, hop_length=_HOP_LENGTH)
    onset_env = _onset_envelope(mag)

    # RMS per frame - glosnosc.
    rms = _rms_per_frame(y, frame_length=_FRAME_LENGTH, hop_length=_HOP_LENGTH)

    # Spectral flux = L2 norm z pozytywnej pochodnej magnitude.
    # Podobne do onset_env ale bez log compression - lapie wylacznie "szeroki"
    # atak (drop z basy + hi-hat), kiedy onset_env lapie tez detale.
    diff_mag = np.diff(mag, axis=1)
    diff_mag = np.maximum(diff_mag, 0.0)
    flux = np.sqrt(np.sum(diff_mag ** 2, axis=0))
    flux = np.concatenate([[0.0], flux])

    # Wyrownanie dlugosci.
    min_len = min(len(rms), len(onset_env), len(flux))
    rms = rms[:min_len]
    onset_env = onset_env[:min_len]
    flux = flux[:min_len]

    def _norm(x: np.ndarray) -> np.ndarray:
        lo, hi = float(np.percentile(x, 5)), float(np.percentile(x, 95))
        if hi - lo < 1e-9:
            return np.zeros_like(x)
        return np.clip((x - lo) / (hi - lo), 0.0, 1.0)

    rms_n = _norm(rms)
    onset_n = _norm(onset_env)
    flux_n = _norm(flux)

    energy = 0.45 * onset_n + 0.35 * flux_n + 0.20 * rms_n

    frames_per_sec = sr / _HOP_LENGTH
    win_frames = max(1, int(_SCORE_WINDOW_SEC * frames_per_sec))
    kernel = np.ones(win_frames, dtype=np.float32) / win_frames
    smooth = np.convolve(energy, kernel, mode="same")

    # Beat tracking (local - bez librosa).
    tempo_bpm, beat_times = _estimate_tempo_and_beats(
        onset_env, sr=sr, hop_length=_HOP_LENGTH,
    )

    lookback_frames = int(4.0 * frames_per_sec)
    best_rise = -1.0
    best_frame = -1

    search_start = int(len(smooth) * _SEARCH_MIN_FRAC)
    search_end = int(len(smooth) * _SEARCH_MAX_FRAC)

    for i in range(search_start, search_end):
        lo_idx = max(0, i - lookback_frames)
        window_min = float(np.min(smooth[lo_idx:i + 1]))
        rise = float(smooth[i]) - window_min
        abs_score = rise + 0.3 * float(smooth[i])
        if abs_score > best_rise:
            best_rise = abs_score
            best_frame = i

    if best_frame < 0:
        offset_sec = max(_OUTPUT_MIN_SEC, duration * 0.3)
        confidence = 0.0
    else:
        offset_sec = float(best_frame) * _HOP_LENGTH / sr
        if len(beat_times) > 4:
            downbeats = beat_times[::4]
            if len(downbeats) > 0:
                idx = int(np.argmin(np.abs(downbeats - offset_sec)))
                snapped = float(downbeats[idx])
                if abs(snapped - offset_sec) < 1.0:
                    offset_sec = snapped
        confidence = float(min(1.0, best_rise / 1.5))

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
