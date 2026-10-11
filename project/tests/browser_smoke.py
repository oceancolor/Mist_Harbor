"""Real browser interaction checks for the sample; no backend task completion."""
from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

PROJECT = Path(__file__).resolve().parents[1]


def preview_url(base: str) -> str:
    parts = urlsplit(base)
    if parts.scheme not in {"http", "https"} or not parts.netloc:
        raise ValueError("Preview must be an HTTP(S) URL, not a local file")
    query = [(key, value) for key, value in parse_qsl(parts.query, keep_blank_values=True)
             if key not in {"qa", "nomenu", "learning", "seed", "location"}]
    query.extend([("qa", "1"), ("nomenu", "1"), ("learning", "1"), ("seed", "240910"), ("location", "quanzhou")])
    return urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment))


def artifact_directory(value: str | None = None) -> Path:
    return Path(value).expanduser().resolve() if value else PROJECT / ".codebuddy" / "artifacts" / "browser"


def expected_model_count() -> int:
    """Derive the GLB count from the build palette so new assets never break the check."""
    palette = json.loads((PROJECT / "data" / "palette.json").read_text(encoding="utf-8"))
    items = {item["id"]: item for item in palette["items"]}
    location = json.loads((PROJECT / "data/locations/quanzhou/palette.json").read_text(encoding="utf-8"))
    items.update({item["id"]: item for item in location["items"]})
    return sum(1 for item in items.values() if str(item.get("mesh", "cube")) != "cube"
               and not str(item.get("mesh", "")).startswith("proc:"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default=os.environ.get("HARBOR_PREVIEW", "http://127.0.0.1:8184/index.html"))
    parser.add_argument("--artifacts", default=os.environ.get("HARBOR_ARTIFACTS"))
    parser.add_argument("--insecure", action="store_true", help="Only for a known self-signed development preview")
    args = parser.parse_args()
    try:
        url = preview_url(args.base)
    except ValueError as exc:
        parser.error(str(exc))
    from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout

    out = artifact_directory(args.artifacts)
    out.mkdir(parents=True, exist_ok=True)
    expected_models = expected_model_count()
    checks = []
    logs = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=["--enable-unsafe-swiftshader"])
        try:
            page = browser.new_page(viewport={"width": 1440, "height": 900}, device_scale_factor=1,
                                    ignore_https_errors=args.insecure)
            page.on("pageerror", lambda error: logs.append(str(error)))
            page.on("console", lambda message: logs.append(message.text) if message.type == "error" else None)
            page.goto(url, wait_until="networkidle", timeout=90000)
            page.wait_for_function("!!window.harborState", timeout=90000)
            page.wait_for_timeout(2500)

            def state():
                return json.loads(page.evaluate("window.harborState"))

            def check(label, predicate):
                deadline = time.monotonic() + 8
                result = predicate() if callable(predicate) else bool(predicate)
                while not result and callable(predicate) and time.monotonic() < deadline:
                    page.wait_for_timeout(150)
                    result = predicate()
                checks.append({"label": label, "ok": bool(result)})
                print(("PASS " if result else "FAIL ") + label, flush=True)

            def click(key):
                page.wait_for_function("(key) => !!JSON.parse(window.harborState).buttons[key]", arg=key, timeout=20000)
                snap = state()
                x, y, w, h = snap["buttons"][key]
                rect = page.locator("canvas").bounding_box()
                vw, vh = snap["viewport"]
                page.mouse.click(rect["x"] + (x + w / 2) * rect["width"] / vw,
                                 rect["y"] + (y + h / 2) * rect["height"] / vh)
                page.wait_for_timeout(450)

            check(f"{expected_models} actual Blender GLB modules loaded",
                  lambda: len(state()["assets"]) == expected_models)
            check("Real terrain faces rendered", lambda: state()["faces"] > 500)
            page.mouse.move(1100, 640)
            page.wait_for_timeout(4000)
            page.screenshot(path=str(out / "mist-harbor-desktop.png"), full_page=True)
            click("category-建筑")
            click("item-cottage")
            before = state()["placed"]
            placed = False
            for x, y in [(720, 420), (660, 480), (810, 410), (740, 520), (900, 480)]:
                page.mouse.move(x, y)
                page.wait_for_timeout(350)
                page.mouse.click(x, y)
                try:
                    page.wait_for_function("(n) => JSON.parse(window.harborState).placed > n", arg=before, timeout=6000)
                    placed = True
                    break
                except PlaywrightTimeout:
                    print("No placement at", x, y, "pick=", state()["pick"], flush=True)
            check("Canvas click places one building", lambda: placed and state()["placed"] == before + 1)
            if placed:
                check("One click creates one undo command", lambda: state()["undo"] == 1)
                click("undo")
                check("GUI undo removes new building", lambda: state()["placed"] == before)
                click("redo")
                check("GUI redo restores building", lambda: state()["placed"] == before + 1)
            click("rotate")
            check("Rotation button changes orientation", lambda: state()["rotation"] == 1)
            click("category-自然")
            check("Nature category uses Quanzhou growth material", lambda: state()["selected"] == "zayton")
            click("category-建筑")
            click("item-lamp")
            check("Lamp is selectable as a built material", lambda: state()["selected"] == "lamp")
            click("demolish")
            check("Demolition mode enabled", lambda: state()["demolish"])
            page.keyboard.press("b")
            check("Keyboard returns to building", lambda: not state()["demolish"])
            click("night")
            check("Day advances to sunset", lambda: state()["phase"] == 2)
            click("night")
            check("Day/night toggles", lambda: state()["night"])
            page.mouse.move(1100, 640)
            page.wait_for_timeout(1000)
            page.screenshot(path=str(out / "mist-harbor-night.png"), full_page=True)
            click("night")
            check("Daylight restored", lambda: not state()["night"])
            click("help")
            check("Help overlay opens", lambda: state()["modal"])
            page.keyboard.press("Escape")
            check("Escape closes overlay", lambda: not state()["modal"])
            click("progress")
            check("Progress dialog opens", lambda: state()["modal"])
            page.keyboard.press("Escape")
            check("Progress dialog closes", lambda: not state()["modal"])
            yaw = state()["camera"][0]
            page.mouse.move(800, 420)
            page.mouse.down(button="right")
            page.mouse.move(855, 445, steps=10)
            page.mouse.up(button="right")
            check("Right drag orbits camera", lambda: abs(state()["camera"][0] - yaw) > 0.1)
            zoom = state()["camera"][2]
            page.mouse.wheel(0, -160)
            check("Wheel zoom works", lambda: state()["camera"][2] < zoom)
            click("center")
            click("save")
            check("Browser save acknowledged", lambda: state()["stats"]["saved"] == 1 and not state()["dirty"])
            saved = state()["placed"]
            # user:// in the Web export is flushed to IndexedDB asynchronously.
            page.wait_for_timeout(5000)
            page.reload(wait_until="networkidle", timeout=90000)
            page.wait_for_function("!!window.harborState", timeout=90000)
            check("Refresh restores persisted world", lambda: state()["placed"] == saved and state()["stats"]["saved"] == 1)
            page.set_viewport_size({"width": 1024, "height": 768})
            page.wait_for_timeout(1800)
            page.screenshot(path=str(out / "mist-harbor-tablet.png"), full_page=True)
            check("Tablet viewport fitted", lambda: state()["viewport"][0] <= 1440)
            check("No browser or Godot errors", not logs)
            print("ERRORS", json.dumps(logs, ensure_ascii=False), flush=True)
            (out / "mist-harbor-browser-probe.json").write_text(
                json.dumps({"state": state(), "checks": checks, "errors": logs}, ensure_ascii=False, indent=2),
                encoding="utf-8")
        finally:
            if not page.is_closed():
                page.screenshot(path=str(out / "mist-harbor-last-state.png"), full_page=True)
                (out / "mist-harbor-last-state.json").write_text(json.dumps(state(), ensure_ascii=False, indent=2), encoding="utf-8")
            browser.close()
    print("BROWSER_RESULT", sum(c["ok"] for c in checks), "/", len(checks), flush=True)
    return 0 if checks and all(c["ok"] for c in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
