"""Run one tools/art/<id>.py script in a clean Blender scene (local Blender only).

The remote pilot submits these scripts into an already-empty scene; running them
locally needs the default cube/camera/light removed first, otherwise the
"must sit on z=0" assertion sees the default objects.

Usage:
  blender --background --factory-startup --python tools/art/_local_run.py -- tools/art/<id>.py
"""
import runpy
import sys

import bpy

bpy.ops.wm.read_factory_settings(use_empty=True)

argv = sys.argv
script = argv[argv.index("--") + 1] if "--" in argv else None
if not script:
    raise SystemExit("usage: blender --background --python tools/art/_local_run.py -- <script.py>")

runpy.run_path(script, run_name="__main__")
print("MIST_HARBOR_LOCAL_RUN_OK:", script, flush=True)
