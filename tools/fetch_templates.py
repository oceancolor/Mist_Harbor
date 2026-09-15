"""Resumable chunked downloader for Godot export templates.

GitHub release downloads are large (~1.2 GB) and a single command would exceed the
shell timeout, so this downloads byte ranges and resumes from the current file size.
Run it repeatedly until it reports "complete".

Usage:
  python tools/fetch_templates.py [--url URL] [--dest PATH]
                                  [--chunk-mb 128] [--budget-seconds 90]
"""
from __future__ import annotations

import argparse
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_URL = "https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_export_templates.tpz"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=DEFAULT_URL)
    parser.add_argument("--dest", default=str(Path(__file__).resolve().parents[1] / ".codebuddy" / "local" / "godot-4.7-templates.tpz"))
    parser.add_argument("--chunk-mb", type=int, default=128)
    parser.add_argument("--budget-seconds", type=int, default=90)
    args = parser.parse_args()

    dest = Path(args.dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    started = time.time()
    offset = dest.stat().st_size if dest.is_file() else 0
    chunk = args.chunk_mb * 1024 * 1024
    total = None

    with dest.open("ab") as stream:
        while time.time() - started < args.budget_seconds:
            request = urllib.request.Request(args.url, headers={
                "Range": f"bytes={offset}-{offset + chunk - 1}",
                "User-Agent": "curl/8",
            })
            try:
                with urllib.request.urlopen(request, timeout=120) as response:
                    if response.status == 416:  # range beyond EOF -> done
                        break
                    content_range = response.headers.get("Content-Range")
                    if content_range and "/" in content_range:
                        total = int(content_range.split("/")[-1])
                    data = response.read()
            except urllib.error.HTTPError as exc:
                print(f"HTTP {exc.code}: {exc.reason}")
                raise SystemExit(1)
            if not data:
                break
            stream.write(data)
            stream.flush()
            offset += len(data)
            percent = f"{offset / total * 100:5.1f}%" if total else "  ?  "
            print(f"{percent}  {offset / 1048576:.0f} MB"
                  + (f" / {total / 1048576:.0f} MB" if total else ""))
            if total and offset >= total:
                break

    print("complete" if total and offset >= total else f"paused at {offset} bytes; run again to continue")


if __name__ == "__main__":
    main()
