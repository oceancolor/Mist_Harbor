"""Measure actual GLB geometry and optionally refresh the runtime manifest.

Source metadata may be supplied from a reviewed Git ref. Measurements always
come from current files; missing metadata and licensing remain explicit.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "project" / "assets" / "models"
MANIFEST = MODELS / "manifest.json"
IDENTITY = [[float(i == j) for j in range(4)] for i in range(4)]


def multiply(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def transform(node):
    if "matrix" in node:
        return [[node["matrix"][j * 4 + i] for j in range(4)] for i in range(4)]
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    result = [[1 - 2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w), 0],
              [2*(x*y+z*w), 1 - 2*(x*x+z*z), 2*(y*z-x*w), 0],
              [2*(x*z-y*w), 2*(y*z+x*w), 1 - 2*(x*x+y*y), 0], [0, 0, 0, 1]]
    scale = node.get("scale", [1, 1, 1])
    position = node.get("translation", [0, 0, 0])
    for i in range(3):
        for j in range(3):
            result[i][j] *= scale[j]
        result[i][3] = position[i]
    return result


def inspect(path: Path) -> dict:
    blob = path.read_bytes()
    if len(blob) < 20:
        raise ValueError(f"truncated GLB: {path}")
    magic, version, total = struct.unpack_from("<4sII", blob)
    length, kind = struct.unpack_from("<II", blob, 12)
    if magic != b"glTF" or version != 2 or total != len(blob) or kind != 0x4E4F534A or 20 + length > total:
        raise ValueError(f"invalid GLB container: {path}")
    data = json.loads(blob[20:20+length])
    vertices = triangles = 0
    points = []
    nodes = data.get("nodes", [])

    def visit(index, parent, trail):
        nonlocal vertices, triangles
        if index in trail:
            raise ValueError(f"cyclic GLB scene: {path}")
        node = nodes[index]
        matrix = multiply(parent, transform(node))
        if "mesh" in node:
            for primitive in data["meshes"][node["mesh"]]["primitives"]:
                position = data["accessors"][primitive["attributes"]["POSITION"]]
                vertices += position["count"]
                count = data["accessors"][primitive["indices"]]["count"] if "indices" in primitive else position["count"]
                if primitive.get("mode", 4) != 4 or count % 3:
                    raise ValueError(f"non-triangle primitive: {path}")
                triangles += count // 3
                for corner in itertools.product(*zip(position["min"], position["max"])):
                    point = [sum(matrix[i][j] * corner[j] for j in range(3)) + matrix[i][3] for i in range(3)]
                    if not all(math.isfinite(v) for v in point):
                        raise ValueError(f"nonfinite bounds: {path}")
                    points.append(point)
        for child in node.get("children", []):
            visit(child, matrix, trail | {index})

    scene = data.get("scene", 0)
    for index in data["scenes"][scene].get("nodes", []):
        visit(index, IDENTITY, set())
    if not points or triangles == 0:
        raise ValueError(f"no geometry: {path}")
    minimum = [min(p[i] for p in points) for i in range(3)]
    maximum = [max(p[i] for p in points) for i in range(3)]
    for image in data.get("images", []):
        uri = image.get("uri", "")
        if uri and not uri.startswith("data:"):
            target = (path.parent / uri).resolve()
            if not target.is_relative_to(path.parent.resolve()) or not target.is_file():
                raise ValueError(f"missing or external texture: {uri}")
    return {"id": path.stem, "file": path.name, "bytes": len(blob),
            "sha256": hashlib.sha256(blob).hexdigest(), "triangles": triangles,
            "vertices": vertices, "materials": len(data.get("materials", [])),
            "generator": data.get("asset", {}).get("generator", "unknown"),
            "bounds": {"godot_min": minimum, "godot_max": maximum,
                       "godot_size": [maximum[i]-minimum[i] for i in range(3)]}}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-ref")
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    original = {entry["id"]: entry for entry in manifest["assets"]}
    imported = {}
    if args.source_ref:
        raw = subprocess.check_output(["git", "show", f"{args.source_ref}:project/assets/models/manifest.json"], cwd=ROOT)
        imported = {entry["id"]: entry for entry in json.loads(raw)["assets"]}
    entries = []
    for path in sorted(MODELS.glob("*.glb")):
        previous = original.get(path.stem, imported.get(path.stem, {})).copy()
        if not previous:
            previous["source"] = "unverified"
        previous.setdefault("license", "CC0-1.0" if path.stem in original and not path.stem.startswith("loc_") else "pending-source-review")
        if path.stem not in original and args.source_ref:
            previous["imported_from"] = args.source_ref
        previous.update(inspect(path))
        entries.append(previous)
    known = {entry["id"] for entry in entries}
    for path in (ROOT / "project" / "data" / "locations").glob("*/palette.json"):
        for entry in json.loads(path.read_text(encoding="utf-8"))["items"]:
            mesh = entry.get("mesh", "cube")
            if mesh != "cube" and not mesh.startswith("proc:") and mesh not in known:
                raise ValueError(f"missing model: {path}: {mesh}")
    if args.write:
        manifest.update({"assets": entries, "generator": "audited GLB metadata; see per-asset generator",
                         "origin": "main and reviewed experiment assets; see per-asset source",
                         "license": "see per-asset license; imported assets require source review"})
        MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"models": len(entries), "bytes": sum(a["bytes"] for a in entries),
                      "triangles": sum(a["triangles"] for a in entries),
                      "vertices": sum(a["vertices"] for a in entries)}, indent=2))


if __name__ == "__main__":
    main()
