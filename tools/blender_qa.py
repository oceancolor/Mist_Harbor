"""Normalize a staged GLB and flatten explicitly requested modular contact planes.

Run with Blender --background --factory-startup --python-exit-code 1 --python
this file, followed by -- --input draft.glb --output fitted.glb --asset-id ID
--receipt receipt.json [--size X Y Z] [--contact bottom] [--contact top].
Sizes and contact bands use Blender meters (Z-up). No triangle cap is implicit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

PLANES = {"bottom": (2, False), "top": (2, True), "left": (0, False),
          "right": (0, True), "front": (1, False), "back": (1, True)}


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--budget", type=Path, help="legacy size specification; triangle limits are not inherited")
    parser.add_argument("--size", nargs=3, type=float, metavar=("X", "Y", "Z"))
    parser.add_argument("--contact", action="append", choices=sorted(PLANES), default=[])
    parser.add_argument("--band", type=float, default=0.02)
    parser.add_argument("--max-triangles", type=int, default=0, help="optional explicit QA gate, never automatic decimation")
    args = parser.parse_args(argv)
    paths = [args.input.resolve(), args.output.resolve(), args.receipt.resolve()]
    if len(set(paths)) != 3:
        parser.error("input, output and receipt must be distinct files")
    if not math.isfinite(args.band) or args.band <= 0:
        parser.error("band must be a positive finite distance")
    if args.size and any(not math.isfinite(v) or v <= 0 for v in args.size):
        parser.error("size must contain three positive finite values")
    return args


def bounds(objects):
    points = [vertex.co for obj in objects for vertex in obj.data.vertices]
    if not points or any(not all(math.isfinite(v) for v in p) for p in points):
        raise ValueError("mesh has no finite vertices")
    return ([min(p[i] for p in points) for i in range(3)],
            [max(p[i] for p in points) for i in range(3)])


def main() -> None:
    args = arguments()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.ops.import_scene.gltf(filepath=str(args.input.resolve()))
    objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not objects:
        raise ValueError("GLB contains no mesh")
    transforms = {obj.name: obj.matrix_world.copy() for obj in objects}
    for obj in objects:
        obj.data = obj.data.copy()
        obj.data.transform(transforms[obj.name])
        obj.parent = None
        obj.matrix_world = Matrix.Identity(4)
    minimum, maximum = bounds(objects)
    size = [maximum[i] - minimum[i] for i in range(3)]
    if min(size) <= 1e-6:
        raise ValueError("GLB must have nonzero extent on all axes")
    target = args.size or size
    center = [(minimum[0] + maximum[0]) / 2, (minimum[1] + maximum[1]) / 2, minimum[2]]
    for obj in objects:
        for vertex in obj.data.vertices:
            vertex.co = Vector([(vertex.co[i] - center[i]) * target[i] / size[i] for i in range(3)])
    minimum, maximum = bounds(objects)
    contacts = []
    failures = []
    for name in sorted(set(args.contact)):
        axis, upper = PLANES[name]
        plane = maximum[axis] if upper else minimum[axis]
        candidates = [vertex for obj in objects for vertex in obj.data.vertices
                      if abs(vertex.co[axis] - plane) <= args.band]
        if len(candidates) < 3:
            failures.append(f"{name}: fewer than three contact vertices; needs authored connector geometry")
        for vertex in candidates:
            vertex.co[axis] = plane
        contacts.append({"plane": name, "axis": axis, "value": plane, "vertices": len(candidates),
                         "max_deviation": max((abs(v.co[axis] - plane) for v in candidates), default=0.0)})
    triangles = vertices = boundary_edges = 0
    for obj in objects:
        mesh = bmesh.new()
        mesh.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
        boundary_edges += sum(edge.is_boundary for edge in mesh.edges)
        mesh.to_mesh(obj.data)
        mesh.free()
        obj.data.update()
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        vertices += len(obj.data.vertices)
    minimum, maximum = bounds(objects)
    dimensions = [maximum[i] - minimum[i] for i in range(3)]
    if args.max_triangles > 0 and triangles > args.max_triangles:
        failures.append("explicit runtime geometry gate exceeded")
    if args.budget:
        spec = json.loads(args.budget.read_text(encoding="utf-8")).get("assets", {}).get(args.asset_id, {})
        if "max_size" in spec and max(dimensions) > float(spec["max_size"]):
            failures.append("size exceeds asset specification")
    receipt = {"asset_id": args.asset_id, "accepted": not failures,
               "source_sha256": hashlib.sha256(args.input.read_bytes()).hexdigest(),
               "triangles": triangles, "vertices": vertices, "boundary_edges": boundary_edges,
               "bounds": {"minimum": minimum, "maximum": maximum, "dimensions": dimensions},
               "contact_planes": contacts, "origin": "bottom-center", "units": "meters",
               "coordinate_system": "Blender Z-up; GLB Y-up", "failures": failures}
    args.receipt.parent.mkdir(parents=True, exist_ok=True)
    args.receipt.write_text(json.dumps(receipt, ensure_ascii=False, indent=2), encoding="utf-8")
    if failures:
        raise ValueError("; ".join(failures))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(args.output.resolve()), export_format="GLB",
                              use_selection=True, export_yup=True, export_apply=True)
    receipt["output_sha256"] = hashlib.sha256(args.output.read_bytes()).hexdigest()
    args.receipt.write_text(json.dumps(receipt, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(receipt, ensure_ascii=False))


if __name__ == "__main__":
    main()
