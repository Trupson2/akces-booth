"""Batch analyze wszystkich bundled tracks w recorder/assets/music/.

Wynik: recorder/assets/music/viral_offsets.json (map filename -> offset_sec).
MusicLibrary.loadViralOffsets czyta to przy starcie aplikacji.

Usage (z root repo):
    python backend/scripts/batch_analyze_bundled.py
    python backend/scripts/batch_analyze_bundled.py --force  # re-analyze
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import analyze_viral_moment  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true",
                        help="Re-analyze wszystkie tracks (pomin cache)")
    parser.add_argument(
        "--music-dir",
        default=str(HERE.parent.parent / "recorder" / "assets" / "music"),
        help="Katalog z plikami audio (default: recorder/assets/music)",
    )
    parser.add_argument(
        "--out",
        default=None,
        help="Plik wyjsciowy JSON (default: <music-dir>/viral_offsets.json)",
    )
    args = parser.parse_args()

    music_dir = Path(args.music_dir).resolve()
    out_path = Path(args.out) if args.out else (music_dir / "viral_offsets.json")

    if not music_dir.exists():
        print(f"ERROR: music dir nie istnieje: {music_dir}", file=sys.stderr)
        return 1

    existing: dict[str, float] = {}
    if out_path.exists() and not args.force:
        try:
            existing = json.loads(out_path.read_text())
            if not isinstance(existing, dict):
                existing = {}
        except Exception:
            existing = {}

    audio_exts = {".mp3", ".m4a", ".wav", ".ogg", ".webm", ".flac"}
    files = sorted(
        p for p in music_dir.iterdir()
        if p.is_file() and p.suffix.lower() in audio_exts
    )

    print(f"Znaleziono {len(files)} plikow audio w {music_dir}")
    results: dict[str, float] = dict(existing)
    stats: list[dict] = []
    t_start = time.time()

    for i, f in enumerate(files, 1):
        if f.name in existing and not args.force:
            print(f"[{i}/{len(files)}] {f.name}: cache={existing[f.name]:.1f}s")
            continue
        t0 = time.time()
        try:
            r = analyze_viral_moment.analyze_file(f)
            results[f.name] = float(r["offset_sec"])
            dt = time.time() - t0
            stats.append({"name": f.name, "dt": dt, **r})
            print(f"[{i}/{len(files)}] {f.name}: "
                  f"{r['offset_sec']:.1f}s "
                  f"({r['offset_sec']/r['duration_sec']*100:.0f}%) "
                  f"conf={r['confidence']:.2f} "
                  f"[{dt:.1f}s]")
        except Exception as e:
            print(f"[{i}/{len(files)}] {f.name}: FAIL - {e}", file=sys.stderr)

    out_path.write_text(json.dumps(results, indent=2, sort_keys=True))
    total = time.time() - t_start
    print(f"\nZapisano {len(results)} offsets -> {out_path}")
    print(f"Total time: {total:.1f}s "
          f"({total/max(1, len(files)):.1f}s avg per track)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
