"""Refresh manifest entries for deterministic four-location GLBs in Blender."""
from __future__ import annotations

import json
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "project" / "assets" / "models"
MANIFEST = MODELS / "manifest.json"
ASSETS = ["barrel", "flower", "sand", "cliff", "white_house", "blue_dome", "granite", "palm_cluster", "lighthouse", "light_marker"]


def clear() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def inspect(asset_id: str) -> dict:
    path = MODELS / f"{asset_id}.glb"
    clear()
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    minimum = [min(point[index] for point in points) for index in range(3)]
    maximum = [max(point[index] for point in points) for index in range(3)]
    triangles = 0
    for obj in objects:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    return {
        "id": asset_id,
        "file": path.name,
        "triangles": triangles,
        "bounds": {
            "blender_min": minimum,
            "blender_max": maximum,
            "godot_size": [
                round(maximum[0] - minimum[0], 4),
                round(maximum[2] - minimum[2], 4),
                round(maximum[1] - minimum[1], 4),
            ],
        },
        "bytes": path.stat().st_size,
        "generator": "Blender 4.2 deterministic location asset generator",
        "source": "tools/generate_location_assets.py",
        "task_id": f"local-{asset_id}-v1",
    }


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    palette = json.loads((ROOT / "project" / "data" / "palette.json").read_text(encoding="utf-8"))
    previous = {entry["id"]: entry for entry in manifest.get("assets", [])}
    generated = {asset_id: inspect(asset_id) for asset_id in ASSETS}
    for asset_id, entry in generated.items():
        if asset_id in previous and previous[asset_id].get("source", "").startswith("tools/art/"):
            entry["source"] = previous[asset_id]["source"]
            entry["task_id"] = previous[asset_id].get("task_id", "")
            entry["generator"] = previous[asset_id].get("generator", entry["generator"])
    assets = [entry for entry in manifest.get("assets", []) if entry.get("id") not in generated]
    assets.extend(generated.values())
    by_mesh = {item.get("mesh"): item for item in palette.get("items", []) if item.get("expansion")}
    for entry in assets:
        definition = by_mesh.get(entry["id"])
        if definition:
            entry["expansion"] = definition["expansion"]
    manifest["assets"] = sorted(assets, key=lambda item: item["id"])
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value["triangles"] for key, value in generated.items()}, ensure_ascii=False))


if __name__ == "__main__":
    main()
