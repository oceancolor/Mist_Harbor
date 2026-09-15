"""Run inside Blender (`blender file.blend --python tools/blender_mcp_autostart.py`).

Enables the MCP for Blender addon and starts its socket server on the main
thread. The addon refuses `blender -b` because queued commands are drained by a
main-thread timer that never runs in background mode, so this always targets a
GUI Blender.
"""
import os

import bpy
import addon_utils

PORT = int(os.environ.get("BLENDER_MCP_PORT", "9876"))

addon_utils.enable("blender_mcp", default_set=True, persistent=True)
addon = bpy.context.preferences.addons.get("blender_mcp")
if addon is not None and hasattr(addon.preferences, "port"):
    addon.preferences.port = PORT


def _start():
    bpy.ops.blendermcp.start_server()
    print("BLENDERMCP_AUTOSTART listening on port", PORT)
    return None


bpy.app.timers.register(_start, first_interval=1.0, persistent=False)
