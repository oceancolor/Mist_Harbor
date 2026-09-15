"""Launch Blender with the MCP addon enabled and its server started.

The BlenderMCP addon refuses background mode: `blender -b` never runs the main
thread timer that executes commands, so the socket server would accept a
connection and then hang. This helper starts a normal GUI Blender, opens the
asset source file, enables the addon and starts the server on the main thread.
Keep the Blender window open while the agent works.

Usage:
  python tools/blender_mcp.py                       # opens project/art/mist-harbor-kit.blend
  python tools/blender_mcp.py --blend path/to.blend
  python tools/blender_mcp.py --port 9876 --no-blend
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / ".codebuddy" / "local" / "tools.json"
AUTOSTART = ROOT / "tools" / "blender_mcp_autostart.py"


def blender_path(explicit: str | None) -> str:
    config = json.loads(TOOLS.read_text(encoding="utf-8")) if TOOLS.is_file() else {}
    value = explicit or config.get("blender")
    if not value or not Path(value).is_file():
        raise SystemExit(f"Blender not found ({value}). Pass --blender PATH or fix .codebuddy/local/tools.json")
    return str(Path(value))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--blender", help="Blender executable override")
    parser.add_argument("--blend", default=str(ROOT / "project" / "art" / "mist-harbor-kit.blend"))
    parser.add_argument("--no-blend", action="store_true", help="Start Blender without opening a file")
    parser.add_argument("--port", type=int, default=9876)
    args = parser.parse_args()

    command = [blender_path(args.blender)]
    if not args.no_blend:
        blend = Path(args.blend)
        if not blend.is_file():
            raise SystemExit(f"Blend file not found: {blend}")
        command.append(str(blend))
    command += ["--python", str(AUTOSTART)]

    print(f"Starting Blender MCP on port {args.port}; leave the Blender window open while the agent works.")
    raise SystemExit(subprocess.call(command, cwd=ROOT, env={**os.environ, "BLENDER_MCP_PORT": str(args.port)}))


if __name__ == "__main__":
    main()
