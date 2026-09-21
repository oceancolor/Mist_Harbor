"""Capture the screenshots the course chapters reference.

The Web export already exists (python tools/dev.py export-web); this script serves
it, drives a real Chromium through Playwright and writes every shot listed in
course/media/shots.json to course/media/shots/<chapter>/.

Usage:
  python tools/course_capture.py                 # capture every chapter
  python tools/course_capture.py --chapter 01    # only chapter 01
  python tools/course_capture.py --list          # show the shot plan

Steps understood in shots.json:
  {"wait": 1200}                     pause
  {"key": "N"}                       keyboard press
  {"click": "progress"}              click a UI button exposed by qa_snapshot
  {"category": "自然"}                switch build category
  {"select": "barrel"}               select a material
  {"place": [[720, 420], [660, 480]]} click canvas points (places pieces)
  {"wheel": -600}                    scroll the canvas (zoom the camera)
  {"resize": [820, 1100]}            set the browser viewport (tablet shots)
  {"shot": "01-game-first-run.png"}  write the screenshot
  {"manual": true, "shot": "..."}    cannot be automated (terminal etc.), reported only
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
PLAN = ROOT / "course" / "media" / "shots.json"
OUT = ROOT / "course" / "media" / "shots"
VIDEO = ROOT / "course" / "media" / "video"
PORT = 8190


def load_plan() -> dict:
    if not PLAN.is_file():
        raise SystemExit(f"missing shot plan: {PLAN}")
    return json.loads(PLAN.read_text(encoding="utf-8"))


def serve(directory: Path, port: int) -> subprocess.Popen:
    return subprocess.Popen(
        [sys.executable, "-m", "http.server", str(port), "--bind", "127.0.0.1", "--directory", str(directory)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


def capture(plan: dict, only: str | None, url: str, record: bool = False) -> None:
    from playwright.sync_api import sync_playwright

    import shutil
    import tempfile

    scratch = tempfile.mkdtemp(prefix="harbor-video-") if record else ""
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=["--enable-unsafe-swiftshader"])
        context_kwargs: dict = {"viewport": {"width": 1440, "height": 900}, "device_scale_factor": 1}
        if record:
            context_kwargs["record_video_dir"] = scratch
            context_kwargs["record_video_size"] = {"width": 1280, "height": 800}
        context = browser.new_context(**context_kwargs)
        page = None
        if not record:
            page = context.new_page()
            page.goto(url, wait_until="networkidle", timeout=90000)
            page.wait_for_function("!!window.harborState", timeout=90000)
            page.wait_for_timeout(2500)
            print("game ready")

        def state():
            return json.loads(page.evaluate("window.harborState"))

        wanted = {value.strip() for value in only.split(",")} if only else set()
        for chapter, steps in sorted(plan.items()):
            if wanted and chapter not in wanted:
                continue
            target = OUT / chapter
            target.mkdir(parents=True, exist_ok=True)
            if record and page is None:
                # Playwright records one video per page, so each chapter gets a
                # fresh page (and therefore a fresh clip of its own steps).
                page = context.new_page()
                page.goto(url, wait_until="networkidle", timeout=90000)
                page.wait_for_function("!!window.harborState", timeout=90000)
                page.wait_for_timeout(2500)
            written: list[str] = []
            for step in steps:
                if "wait" in step:
                    page.wait_for_timeout(int(step["wait"]))
                if "key" in step:
                    page.keyboard.press(str(step["key"]))
                    page.wait_for_timeout(700)
                if "category" in step:
                    page.keyboard.press("Escape")
                    snap = state()
                    x, y, w, h = snap["buttons"]["category-" + str(step["category"])]
                    _click_ui(page, snap, x, y, w, h)
                    page.wait_for_timeout(500)
                if "select" in step:
                    snap = state()
                    key = "item-" + str(step["select"])
                    if key in snap["buttons"]:
                        x, y, w, h = snap["buttons"][key]
                        _click_ui(page, snap, x, y, w, h)
                        page.wait_for_timeout(400)
                if "click" in step:
                    snap = state()
                    key = str(step["click"])
                    if key in snap["buttons"]:
                        x, y, w, h = snap["buttons"][key]
                        _click_ui(page, snap, x, y, w, h)
                        page.wait_for_timeout(600)
                if "resize" in step:
                    width, height = int(step["resize"][0]), int(step["resize"][1])
                    page.set_viewport_size({"width": width, "height": height})
                    page.wait_for_timeout(int(step.get("wait", 800)) or 800)
                if "wheel" in step:
                    page.mouse.move(720, 450)
                    page.mouse.wheel(0, int(step["wheel"]))
                    page.wait_for_timeout(800)
                if "place" in step:
                    box = page.locator("canvas").bounding_box()
                    for point in step["place"]:
                        page.mouse.move(box["x"] + point[0], box["y"] + point[1])
                        page.wait_for_timeout(300)
                        page.mouse.click(box["x"] + point[0], box["y"] + point[1])
                        page.wait_for_timeout(500)
                if "shot" in step:
                    if step.get("manual"):
                        print(f"  [{chapter}] manual (not automated): {step['shot']}")
                        continue
                    page.screenshot(path=str(target / step["shot"]), full_page=True)
                    written.append(step["shot"])
            if record:
                _save_clip(page, chapter)
                page = None
            else:
                print(f"[{chapter}] {len(written)} shot(s) -> {target}")
        browser.close()
    if scratch:
        shutil.rmtree(scratch, ignore_errors=True)


def _save_clip(page, chapter: str) -> None:
    """Finalise the recorded clip for one chapter (close page, then save)."""
    video = page.video
    page.close()
    clip_dir = VIDEO / chapter
    clip_dir.mkdir(parents=True, exist_ok=True)
    clip = clip_dir / f"{chapter}-demo.webm"
    try:
        video.save_as(str(clip))
        size = clip.stat().st_size if clip.is_file() else 0
        print(f"[{chapter}] video -> {clip} ({size} bytes)", flush=True)
    except Exception as exc:  # noqa: BLE001 - reporting only
        print(f"[{chapter}] video save failed: {exc}", flush=True)


def _click_ui(page, snap: dict, x: float, y: float, w: float, h: float) -> None:
    box = page.locator("canvas").bounding_box()
    vw, vh = snap["viewport"]
    page.mouse.click(box["x"] + (x + w / 2) * box["width"] / vw,
                     box["y"] + (y + h / 2) * box["height"] / vh)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chapter", help="capture chapter keys, e.g. 01 or 01,02,03")
    parser.add_argument("--video", action="store_true",
                        help="also record each chapter's steps as a webm clip")
    parser.add_argument("--list", action="store_true", help="print the plan and exit")
    args = parser.parse_args()

    plan = load_plan()
    if args.list:
        for chapter, steps in sorted(plan.items()):
            shots = [s["shot"] for s in steps if "shot" in s]
            print(f"{chapter}: {', '.join(shots) if shots else '(no shots)'}")
        return
    if not (BUILD / "index.html").is_file():
        raise SystemExit("no Web export found; run: python tools/dev.py export-web")

    server = serve(BUILD, PORT)
    try:
        time.sleep(1.5)
        capture(plan, args.chapter, f"http://127.0.0.1:{PORT}/index.html?qa=1", record=args.video)
    finally:
        server.terminate()


if __name__ == "__main__":
    main()
