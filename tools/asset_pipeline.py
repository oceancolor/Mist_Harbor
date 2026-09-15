"""Mist Harbor asset pipeline: remote Blender pilot -> Godot project.

Flow for one asset:
  tools/art/<id>.py  --submit-->  web-cb-blender-pilot  --artifacts-->  GLB + preview
      -> project/assets/models/<id>.glb
      -> project/art/previews/<id>.png      (art/ is excluded from export)
      -> project/art/provenance/<id>.json   (task id, hashes, triangles)
      -> project/assets/models/manifest.json entry (bounds/triangles/bytes)
      -> Godot headless import (creates the .import sidecar)
      -> optional: register the kind in project/data/palette.json

Usage:
  python tools/asset_pipeline.py list
  python tools/asset_pipeline.py build --id barrel [--version N] [--category 建筑]
         [--name 木桶] [--color b07d4f] [--tip "码头边的木桶"] [--height N]
         [--no-register] [--no-import] [--timeout 300]

Credentials: .codebuddy/local/pilot.json (gitignored, see tools/pilot.example.json)
or env PILOT_BLENDER_URL / PILOT_BLENDER_TOKEN.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from hashlib import sha256
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "project"
MODELS = PROJECT / "assets" / "models"
MANIFEST = MODELS / "manifest.json"
PALETTE = PROJECT / "data" / "palette.json"
ART = PROJECT / "art"
PREVIEWS = ART / "previews"
PROVENANCE = ART / "provenance"
PILOT_CONFIG = ROOT / ".codebuddy" / "local" / "pilot.json"
TERMINAL_STATES = {"succeeded", "failed", "cancelled", "timed_out"}


def fail(message: str) -> "NoReturn":  # type: ignore[valid-type]
    print(f"asset-pipeline: {message}", file=sys.stderr)
    raise SystemExit(1)


# --------------------------------------------------------------------------- MCP


class Pilot:
    """Minimal streamable-HTTP MCP client (stdlib only)."""

    def __init__(self, url: str, token: str) -> None:
        self.url = url
        self.token = token
        self.session = ""

    def _post(self, payload: dict) -> list[dict]:
        data = json.dumps(payload).encode("utf-8")
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        }
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        if self.session:
            headers["Mcp-Session-Id"] = self.session
        request = urllib.request.Request(self.url, data=data, headers=headers, method="POST")
        with urllib.request.urlopen(request, timeout=120) as response:
            raw = response.read().decode("utf-8")
            returned = response.headers.get("mcp-session-id")
            if returned:
                self.session = returned
            content_type = response.headers.get("content-type", "")
        # Notifications are accepted with an empty body.
        if not raw.strip():
            return []
        if "application/json" in content_type:
            return [json.loads(raw)]
        return [json.loads(line[5:]) for line in raw.splitlines() if line.startswith("data:")]

    def initialize(self) -> None:
        self._post({
            "jsonrpc": "2.0", "id": 1, "method": "initialize",
            "params": {"protocolVersion": "2025-06-18", "capabilities": {},
                       "clientInfo": {"name": "mist-harbor-asset-pipeline", "version": "1"}},
        })
        self._post({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def call(self, tool: str, arguments: dict, call_id: int = 100) -> dict:
        messages = self._post({"jsonrpc": "2.0", "id": call_id, "method": "tools/call",
                               "params": {"name": tool, "arguments": arguments}})
        for message in messages:
            if message.get("id") != call_id:
                continue
            if "error" in message:
                fail(f"{tool} failed: {message['error']}")
            text = (message.get("result") or {}).get("content", [{}])[0].get("text", "")
            try:
                return json.loads(text)
            except json.JSONDecodeError:
                return {"raw": text}
        fail(f"no response payload for {tool}")
        return {}

    def download(self, download_path: str) -> bytes:
        url = download_path if download_path.startswith("http") else self.url.split("/mcp")[0] + download_path
        request = urllib.request.Request(url, headers={"Authorization": f"Bearer {self.token}"})
        with urllib.request.urlopen(request, timeout=300) as response:
            return response.read()


def pilot_config() -> dict:
    config = json.loads(PILOT_CONFIG.read_text(encoding="utf-8")) if PILOT_CONFIG.is_file() else {}
    url = os.environ.get("PILOT_BLENDER_URL") or config.get("blender", {}).get("url")
    token = os.environ.get("PILOT_BLENDER_TOKEN") or config.get("blender", {}).get("token")
    if not url or not token:
        fail("missing pilot credentials; copy tools/pilot.example.json to .codebuddy/local/pilot.json")
    return {"url": url, "token": token}


# ------------------------------------------------------------------- project io


def pick_artifact(files: list[dict], roles: set[str], suffixes: tuple[str, ...]) -> dict | None:
    """Pick an artifact by `role` when the pilot provides it, else by suffix.

    The pilot team accepted the role-field proposal (2026-09-15); until it ships,
    the suffix fallback keeps this pipeline working against the current response.
    """
    for file in files:
        role = str(file.get("role") or "").lower()
        if role and role in roles:
            return file
    for file in files:
        if str(file.get("path", "")).lower().endswith(suffixes):
            return file
    return None


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def next_version(asset_id: str) -> int:
    """Remote task ids must be unique, so keep incrementing per asset."""
    versions = [0]
    for path in PROVENANCE.glob(f"{asset_id}-v*.json"):
        match = re.match(rf"{re.escape(asset_id)}-v(\d+)\.json$", path.name)
        if match:
            versions.append(int(match.group(1)))
    return max(versions) + 1


def update_manifest(asset_id: str, glb_bytes: bytes, inspect: dict, provenance: dict) -> dict:
    manifest = read_json(MANIFEST)
    bounds = inspect.get("bounds") or {}
    minimum = bounds.get("minimum")
    maximum = bounds.get("maximum")
    extent = bounds.get("extent")
    if not (minimum and maximum and extent):
        fail("glb-inspect is missing bounds; refusing to write a bogus manifest entry")
    # GLB is Y-up; the stored Blender bounds are Z-up (x, z, y).
    entry = {
        "id": asset_id,
        "file": f"{asset_id}.glb",
        "triangles": int(inspect.get("triangle_count", 0)),
        "bounds": {
            "blender_min": [minimum[0], minimum[2], minimum[1]],
            "blender_max": [maximum[0], maximum[2], maximum[1]],
            "godot_size": [round(float(value), 4) for value in extent],
        },
        "bytes": len(glb_bytes),
        "generator": inspect.get("generator", ""),
        "source": f"tools/art/{asset_id}.py",
        "task_id": provenance.get("task_id", ""),
    }
    assets = [item for item in manifest.get("assets", []) if item.get("id") != asset_id]
    assets.append(entry)
    manifest["assets"] = sorted(assets, key=lambda item: str(item["id"]))
    write_json(MANIFEST, manifest)
    return entry


def godot_import() -> None:
    sys.path.insert(0, str(ROOT / "tools"))
    import dev  # noqa: PLC0415 - reuse the pinned-engine resolver from tools/dev.py

    binary = dev.engine(None)
    log_dir = ROOT / "logs"
    log_dir.mkdir(exist_ok=True)
    result = subprocess.run([binary, "--headless", "--path", str(PROJECT), "--editor", "--import", "--quit"],
                            capture_output=True, timeout=600)
    text = (result.stdout + result.stderr).decode("utf-8", errors="replace")
    (log_dir / "asset-import.log").write_text(text, encoding="utf-8")
    if result.returncode or "SCRIPT ERROR:" in text:
        fail(f"Godot import failed; see logs/asset-import.log (exit={result.returncode})")


def register_palette(asset_id: str, name: str, category: str, color: str, height: int, tip: str) -> None:
    palette = read_json(PALETTE)
    items = [item for item in palette.get("items", []) if item.get("id") != asset_id]
    entry = {"id": asset_id, "name": name, "category": category, "color": color,
             "height": height, "mesh": asset_id, "tip": tip}
    insert_at = len(items)
    for index, item in enumerate(items):
        if item.get("category") == category:
            insert_at = index + 1
    items.insert(insert_at, entry)
    palette["items"] = items
    write_json(PALETTE, palette)
    print(f"palette: registered '{asset_id}' in {category} (height={height})")


# ------------------------------------------------------------------------ build


def build(args: argparse.Namespace) -> None:
    script_path = ROOT / "tools" / "art" / f"{args.id}.py"
    if not script_path.is_file():
        fail(f"missing authoring script: {script_path}")
    script = script_path.read_text(encoding="utf-8")
    if len(script.encode("utf-8")) > 256 * 1024:
        fail("script exceeds the 256 KiB inline limit")

    version = args.version or next_version(args.id)
    # The pilot rejects duplicate task ids, so bind the id to the script digest:
    # re-running an unchanged script reuses the same remote task, an edited one does not.
    task_id = f"mist-harbor-{args.id}-v{version}-{sha256(script.encode('utf-8')).hexdigest()[:8]}"
    config = pilot_config()
    pilot = Pilot(config["url"], config["token"])
    pilot.initialize()

    print(f"submit {task_id} -> {config['url']}")
    pilot.call("blender_submit", {
        "request": {"task_id": task_id, "asset_id": args.id, "asset_version": str(version),
                    "script_path": "script.py", "timeout_seconds": args.timeout},
        "script": script,
    })

    state = ""
    deadline = time.time() + args.timeout + 120
    while time.time() < deadline:
        observed = pilot.call("blender_observe", {"task_id": task_id}, call_id=200)
        state = str(observed.get("state") or observed.get("status") or "")
        if state in TERMINAL_STATES:
            break
        print(f"  state={state or 'unknown'}")
        time.sleep(5)
    if state != "succeeded":
        fail(f"task {task_id} ended with state={state or 'unknown'}; "
             f"run: node .codebuddy/local/call-http-mcp.mjs {config['url']} <token> blender_observe")
    print(f"task {task_id} succeeded")

    artifacts = pilot.call("blender_artifacts", {"task_id": task_id}, call_id=300)
    files = artifacts.get("files") or []
    # Prefer the explicit `role` the pilot may attach; fall back to suffixes.
    glb = pick_artifact(files, {"model", "asset", "glb", "mesh"}, (".glb",))
    inspect_file = pick_artifact(files, {"inspect", "report"}, ("glb-inspect.json",))
    preview = pick_artifact(files, {"preview", "render", "image"}, (".png",))
    if not glb or not inspect_file:
        fail(f"artifacts missing GLB or inspection report: {[f['path'] for f in files]}")

    glb_bytes = pilot.download(glb["download_path"])
    if glb.get("sha256") and sha256(glb_bytes).hexdigest() != glb["sha256"]:
        fail("GLB sha256 mismatch")
    inspect = json.loads(pilot.download(inspect_file["download_path"]).decode("utf-8"))

    MODELS.mkdir(parents=True, exist_ok=True)
    (MODELS / f"{args.id}.glb").write_bytes(glb_bytes)
    print(f"wrote {MODELS / (args.id + '.glb')} ({len(glb_bytes)} bytes, sha256 verified)")

    if preview:
        preview_bytes = pilot.download(preview["download_path"])
        PREVIEWS.mkdir(parents=True, exist_ok=True)
        (PREVIEWS / f"{args.id}.png").write_bytes(preview_bytes)
        print(f"wrote {PREVIEWS / (args.id + '.png')}")

    provenance = {
        "id": args.id, "version": version, "task_id": task_id,
        "script": f"tools/art/{args.id}.py",
        "script_sha256": sha256(script.encode("utf-8")).hexdigest(),
        "glb_sha256": sha256(glb_bytes).hexdigest(),
        "bytes": len(glb_bytes), "triangles": inspect.get("triangle_count"),
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
    }
    PROVENANCE.mkdir(parents=True, exist_ok=True)
    write_json(PROVENANCE / f"{args.id}-v{version}.json", provenance)
    write_json(PROVENANCE / f"{args.id}.json", provenance)

    entry = update_manifest(args.id, glb_bytes, inspect, provenance)
    print(f"manifest: {entry['id']} triangles={entry['triangles']} godot_size={entry['bounds']['godot_size']}")

    height = args.height or max(1, math.ceil(entry["bounds"]["godot_size"][1] - 1e-6))
    if not args.no_import:
        godot_import()
        import_sidecar = MODELS / f"{args.id}.glb.import"
        if not import_sidecar.is_file():
            fail(f"Godot did not produce {import_sidecar}")
        print(f"wrote {import_sidecar.name}")
    if not args.no_register:
        register_palette(args.id, args.name or args.id, args.category, args.color,
                         height, args.tip or f"{args.name or args.id}（程序化生成的原创资产）")
    print(f"done: {args.id} (version {version})")


def list_assets(_: argparse.Namespace) -> None:
    manifest = read_json(MANIFEST)
    palette = read_json(PALETTE)
    meshes = {item["id"]: item.get("mesh") for item in palette.get("items", [])}
    print(f"{'id':<12}{'triangles':>10}{'height':>8}{'registered':>12}  script")
    for asset in sorted(manifest.get("assets", []), key=lambda item: str(item["id"])):
        asset_id = str(asset["id"])
        script = ROOT / "tools" / "art" / f"{asset_id}.py"
        print(f"{asset_id:<12}{asset.get('triangles', 0):>10}"
              f"{asset['bounds']['godot_size'][1]:>8.2f}"
              f"{str(meshes.get(asset_id, '-')):>12}  {'(tools/art)' if script.is_file() else '-'}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    subparsers = parser.add_subparsers(dest="action", required=True)
    subparsers.add_parser("list", help="show manifest assets, triangles and palette registration").set_defaults(func=list_assets)

    build_parser = subparsers.add_parser("build", help="author one asset through the remote Blender pilot")
    build_parser.add_argument("--id", required=True)
    build_parser.add_argument("--version", type=int, help="default: next free version for this id")
    build_parser.add_argument("--name", help="Chinese display name; default: id")
    build_parser.add_argument("--category", default="建筑", choices=["地形", "建筑", "自然"])
    build_parser.add_argument("--color", default="b07d4f", help="UI swatch colour, hex without #")
    build_parser.add_argument("--tip", help="tooltip shown in the build dock")
    build_parser.add_argument("--height", type=int, help="grid cells reserved; default: ceil(GLB height)")
    build_parser.add_argument("--no-register", action="store_true", help="do not touch palette.json")
    build_parser.add_argument("--no-import", action="store_true", help="do not run Godot import")
    build_parser.add_argument("--timeout", type=int, default=300)
    build_parser.set_defaults(func=build)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
