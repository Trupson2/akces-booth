"""Download piosenek z YouTube przez yt-dlp jako webm (Opus audio only).

Input TSV: <track_number>\t<query>
Output: recorder/assets/music/track_NN.webm

Zaleta Opus/webm:
- najlepsza kompresja per bitrate (Opus ~96kbps = AAC 128kbps jakosc)
- native YouTube audio codec - yt-dlp nie transkoduje (szybciej, bez straty)
- Flutter video_player + ffmpeg_kit obsluguja webm bez problemu

Usage:
    python download_tracks.py <tsv_file> [--out-dir recorder/assets/music]

    python download_tracks.py --from-list
    (czyta _new_tracks.tsv z music dir)
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path


def download_one(query: str, out_path: Path, cookies: str | None = None) -> bool:
    """yt-dlp --audio-format webm - najszybciej bo YT ma webm native."""
    cmd = [
        sys.executable, "-m", "yt_dlp",
        "-f", "bestaudio[ext=webm]/bestaudio",
        "--no-playlist",
        "--match-filter", "duration < 420",  # skip dluzszych niz 7 min
        "--default-search", "ytsearch1",
        "-o", str(out_path.with_suffix(".%(ext)s")),
        "--quiet", "--no-warnings",
        "--no-progress",
        query,
    ]
    if cookies:
        cmd.extend(["--cookies", cookies])
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
        if r.returncode != 0:
            print(f"  FAIL: {r.stderr[:200]}", file=sys.stderr)
            return False
        # Rename do .webm jesli yt-dlp wybral inne (m4a, opus, etc)
        for ext in [".webm", ".opus", ".m4a", ".mp4", ".ogg"]:
            src = out_path.with_suffix(ext)
            if src.exists():
                if src.suffix != ".webm":
                    # Remux do webm bez recomp.
                    remux = [
                        "python", "-c",
                        "import subprocess; subprocess.run(["
                        "'C:/Users/adria/AppData/Local/Programs/Python/Python311/"
                        "Lib/site-packages/imageio_ffmpeg/binaries/"
                        "ffmpeg-win-x86_64-v7.1.exe', "
                        f"'-y', '-i', r'{src}', '-c:a', 'copy', "
                        f"r'{out_path}'])",
                    ]
                    subprocess.run(remux, capture_output=True)
                    try:
                        src.unlink()
                    except OSError:
                        pass
                return True
        return out_path.exists()
    except subprocess.TimeoutExpired:
        print(f"  TIMEOUT: {query}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"  EXC: {e}", file=sys.stderr)
        return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("tsv", nargs="?",
                        help="TSV z 'number\\tquery' lines")
    parser.add_argument("--out-dir",
                        default=str(Path(__file__).resolve().parent.parent.parent
                                    / "recorder" / "assets" / "music"),
                        help="Output katalog (default recorder/assets/music)")
    parser.add_argument("--from-list", action="store_true",
                        help="Uzyj _new_tracks.tsv z out-dir")
    parser.add_argument("--resume", action="store_true",
                        help="Skip tracks ktore juz maja plik")
    args = parser.parse_args()

    out_dir = Path(args.out_dir).resolve()
    if args.from_list:
        tsv_path = out_dir / "_new_tracks.tsv"
    elif args.tsv:
        tsv_path = Path(args.tsv).resolve()
    else:
        print("Podaj TSV albo --from-list", file=sys.stderr)
        return 1

    if not tsv_path.exists():
        print(f"TSV not found: {tsv_path}", file=sys.stderr)
        return 1

    lines = [ln.strip() for ln in tsv_path.read_text(encoding="utf-8").splitlines()
             if ln.strip() and not ln.startswith("#")]
    total = len(lines)
    ok_count = 0
    fail_count = 0
    t_start = time.time()

    for i, line in enumerate(lines, 1):
        parts = line.split("\t", 1)
        if len(parts) != 2:
            print(f"[{i}/{total}] SKIP bad line: {line}")
            continue
        num, query = parts[0].strip(), parts[1].strip()
        target = out_dir / f"track_{num.zfill(2)}.webm"
        if args.resume and target.exists() and target.stat().st_size > 100_000:
            print(f"[{i}/{total}] track_{num}: skip (exists, "
                  f"{target.stat().st_size // 1024} KB)")
            continue
        t0 = time.time()
        print(f"[{i}/{total}] track_{num}: {query}")
        ok = download_one(query, target)
        dt = time.time() - t0
        if ok and target.exists():
            size_mb = target.stat().st_size / 1024 / 1024
            print(f"  OK {size_mb:.1f} MB in {dt:.1f}s")
            ok_count += 1
        else:
            print(f"  FAIL")
            fail_count += 1

    total_time = time.time() - t_start
    print(f"\nDone: {ok_count} ok, {fail_count} fail "
          f"in {total_time:.1f}s ({total_time/60:.1f} min)")
    return 0 if fail_count == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
