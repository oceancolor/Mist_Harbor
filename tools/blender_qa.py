"""Blender 4.2 headless QA for generated Mist Harbor GLBs.

Usage:
  blender --background --factory-startup --python tools/blender_qa.py -- \
      --input incoming.glb --output accepted.glb --asset-id sand \
      --budget project/data/asset_budgets.json --receipt receipt.json
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--budget", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    return parser.parse_args(argv)


def triangle_count(objects: list[bpy.types.Object]) -> int:
    total = 0
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        total += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    return total


def bounds(objects: list[bpy.types.Object]) -> tuple[list[float], list[float]]:
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    minimum = [min(point[index] for point in points) for index in range(3)]
    maximum = [max(point[index] for point in points) for index in range(3)]
    return minimum, maximum


def main() -> None:
    args = arguments()
    budgets = json.loads(args.budget.read_text(encoding="utf-8"))
    definition = budgets.get("assets", {}).get(args.asset_id)
    if not isinstance(definition, dict):
        raise SystemExit(f"no QA budget for {args.asset_id}")
    budget = int(definition["triangles"])
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(args.input.resolve()))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise SystemExit("GLB contains no mesh")
    for obj in meshes:
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        for polygon in obj.data.polygons:
            polygon.use_smooth = False
    before = triangle_count(meshes)
    if before > budget:
        ratio = max(0.02, min(1.0, budget / float(before) * 0.96))
        for obj in meshes:
            modifier = obj.modifiers.new("MistHarborBudget", "DECIMATE")
            modifier.ratio = ratio
            modifier.use_collapse_triangulate = True
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    for obj in meshes:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")
    minimum, maximum = bounds(meshes)
    # Place the collective origin at bottom-center while preserving dimensions.
    center_x = (minimum[0] + maximum[0]) * 0.5
    center_y = (minimum[1] + maximum[1]) * 0.5
    bottom_z = minimum[2]
    for obj in meshes:
        obj.location.x -= center_x
        obj.location.y -= center_y
        obj.location.z -= bottom_z
    after = triangle_count(meshes)
    minimum, maximum = bounds(meshes)
    dimensions = [maximum[index] - minimum[index] for index in range(3)]
    max_size = float(definition.get("max_size", 4.0))
    failures: list[str] = []
    if after > budget:
        failures.append(f"triangles {after} exceed budget {budget}")
    if any(not math.isfinite(value) or value <= 0.001 for value in dimensions):
        failures.append(f"invalid dimensions {dimensions}")
    if max(dimensions) > max_size:
        failures.append(f"maximum dimension {max(dimensions):.3f} exceeds {max_size}")
    args.receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt = {
        "asset_id": args.asset_id,
        "accepted": not failures,
        "triangles_before": before,
        "triangles_after": after,
        "budget": budget,
        "bounds": {"minimum": minimum, "maximum": maximum, "dimensions": dimensions},
        "origin": "bottom-center",
        "coordinate_system": "Blender Z-up; glTF exporter converts to Y-up",
        "failures": failures,
    }
    args.receipt.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if failures:
        raise SystemExit("; ".join(failures))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(args.output.resolve()),
        export_format="GLB",
        use_selection=False,
        export_yup=True,
        export_apply=True,
    )
    print(json.dumps(receipt, ensure_ascii=False))


if __name__ == "__main__":
    main()
