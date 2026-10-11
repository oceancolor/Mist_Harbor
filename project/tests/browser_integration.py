"""Exercise the integrated four-location Web build in an isolated browser profile."""
from __future__ import annotations

import functools
import json
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / ".codebuddy" / "artifacts" / "integration"


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass


def run(base: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    results = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True, args=["--enable-unsafe-swiftshader"])
        context = browser.new_context(viewport={"width": 1440, "height": 900})
        page = context.new_page()
        errors = []
        report = {"passed": False, "locations": results, "errors": errors}
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)

        def state():
            return json.loads(page.evaluate("window.harborState"))

        def click(key):
            snap = state()
            x, y, w, h = snap["buttons"][key]
            rect = page.locator("canvas").bounding_box()
            assert rect is not None, "canvas bounds unavailable"
            vw, vh = snap["viewport"]
            page.mouse.click(rect["x"] + (x + w / 2) * rect["width"] / vw,
                             rect["y"] + (y + h / 2) * rect["height"] / vh)
            page.wait_for_timeout(600)

        try:
            for location in ["quanzhou", "santorini", "seychelles", "cape-cod"]:
                response = page.goto(f"{base}/index.html?qa=1&nomenu=1&seed=240910&location={location}",
                                     wait_until="networkidle", timeout=120000)
                assert response.status == 200
                page.wait_for_function("(name) => window.harborState && JSON.parse(window.harborState).location === name", arg=location, timeout=120000)
                page.wait_for_timeout(2500)
                snap = state()
                assert snap["cells"] > 0 and snap["faces"] > 0, f"empty scene: {location}"
                assert snap["terrain_metrics"]["surfaces"] == 1, "terrain must stay batched"
                page.screenshot(path=str(OUT / f"{location}-day.png"))
                phases = {snap["phase"]}
                for _ in range(3):
                    expected = (state()["phase"] + 1) % 4
                    click("night")
                    page.wait_for_function("(phase) => JSON.parse(window.harborState).phase === phase", arg=expected, timeout=20000)
                    phases.add(state()["phase"])
                assert phases == {0, 1, 2, 3}, f"missing daylight phase: {location} {phases}"
                page.screenshot(path=str(OUT / f"{location}-dawn.png"))
                results.append({"location": location, "cells": snap["cells"], "assets": len(snap["assets"]),
                                "terrain": snap["terrain_metrics"], "draw_calls": snap["draw_calls"],
                                "generation": snap.get("generation", {})})
            page.goto(f"{base}/index.html?qa=1&nomenu=1&seed=240910&location=quanzhou", wait_until="networkidle", timeout=120000)
            page.wait_for_function("window.harborState && JSON.parse(window.harborState).location === 'quanzhou'", timeout=120000)
            page.wait_for_timeout(1500)
            click("category-建筑")
            page.wait_for_function("JSON.parse(window.harborState).category === '建筑' && 'item-wood' in JSON.parse(window.harborState).buttons", timeout=10000)
            click("item-wood")
            page.wait_for_function("JSON.parse(window.harborState).selected === 'wood'", timeout=10000)
            before = state()["placed"]
            for x, y in [(720, 450), (800, 520), (610, 460), (850, 400), (690, 510)]:
                page.mouse.move(x, y)
                page.wait_for_timeout(400)
                page.mouse.click(x, y)
                page.wait_for_timeout(1800)
                if state()["placed"] > before:
                    break
            page.wait_for_function("(n) => JSON.parse(window.harborState).placed === n", arg=before + 1, timeout=20000)
            click("undo")
            page.wait_for_function("(n) => JSON.parse(window.harborState).placed === n && JSON.parse(window.harborState).redo > 0", arg=before, timeout=20000)
            click("redo")
            page.wait_for_function("(n) => JSON.parse(window.harborState).placed === n", arg=before + 1, timeout=20000)
            click("save")
            page.wait_for_function("!JSON.parse(window.harborState).dirty", timeout=10000)
            saved = state()
            page.wait_for_timeout(1500)
            page.reload(wait_until="networkidle", timeout=120000)
            page.wait_for_function("window.harborState", timeout=120000)
            loaded = state()
            assert loaded["seed"] == saved["seed"] and loaded["placed"] == saved["placed"], "saved island regenerated"
            assert loaded["generator_version"] == saved["generator_version"], "generator version lost"
            assert not errors, f"browser errors: {errors[:5]}"
            report.update({"passed": True, "save_restored": True, "last_edit_metrics": saved["terrain_metrics"]})
            print(json.dumps(report, ensure_ascii=False))
        finally:
            (OUT / "browser-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
            context.close()
            browser.close()


def main() -> None:
    server = ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Handler, directory=str(ROOT / "build")))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        run(f"http://127.0.0.1:{server.server_port}")
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == "__main__":
    main()
