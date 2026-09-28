"""Generate original low-poly four-location assets with Blender 4.2.

This deterministic fallback keeps the game fully buildable without an online
generation service. AI-produced candidates can replace these GLBs only after
passing the same Blender QA budgets.
"""
from __future__ import annotations

import math
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "project" / "assets" / "models"


def clear() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    value = bpy.data.materials.new(name)
    value.diffuse_color = color
    value.roughness = 0.9
    return value


def cube(name: str, location: tuple[float, float, float], scale: tuple[float, float, float],
         mat: bpy.types.Material, bevel: float = 0.0) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("soft_edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def cylinder(name: str, location: tuple[float, float, float], radius: float, depth: float,
             mat: bpy.types.Material, vertices: int = 10, radius_top: float | None = None) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius, radius2=radius if radius_top is None else radius_top,
        depth=depth, location=location,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def export(asset_id: str) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            for polygon in obj.data.polygons:
                polygon.use_smooth = False
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT / f"{asset_id}.glb"),
        export_format="GLB",
        export_yup=True,
        export_apply=True,
    )


def sand() -> None:
    mat = material("warm_sand", (0.69, 0.57, 0.36, 1))
    cube("sand_tile", (0, 0, 0.18), (0.98, 0.98, 0.36), mat, 0.08)


def cliff() -> None:
    rock = material("volcanic_rock", (0.30, 0.24, 0.22, 1))
    cube("cliff_core", (0, 0, 0.45), (0.98, 0.98, 0.9), rock, 0.06)
    cube("cliff_ledge", (0.18, -0.04, 0.88), (0.58, 0.72, 0.16), rock, 0.04)


def white_house() -> None:
    white = material("lime_white", (0.82, 0.80, 0.72, 1))
    blue = material("aegean_blue", (0.08, 0.30, 0.55, 1))
    cube("house", (0, 0, 0.43), (0.92, 0.86, 0.86), white, 0.05)
    cube("door", (0, -0.438, 0.32), (0.24, 0.03, 0.54), blue, 0.02)


def blue_dome() -> None:
    white = material("dome_base", (0.85, 0.83, 0.76, 1))
    blue = material("dome_blue", (0.07, 0.34, 0.66, 1))
    cylinder("base", (0, 0, 0.16), 0.42, 0.32, white, 12)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, location=(0, 0, 0.38), scale=(0.42, 0.42, 0.30))
    dome = bpy.context.object
    dome.name = "blue_dome"
    dome.data.materials.append(blue)


def granite() -> None:
    mat = material("seychelles_granite", (0.48, 0.46, 0.42, 1))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.58, location=(0, 0, 0.54))
    rock = bpy.context.object
    rock.name = "rounded_granite"
    rock.scale = (0.82, 0.68, 0.92)
    rock.rotation_euler = (0.12, -0.08, 0.28)
    rock.data.materials.append(mat)


def palm_cluster() -> None:
    trunk = material("palm_trunk", (0.34, 0.20, 0.10, 1))
    leaf = material("palm_leaf", (0.12, 0.42, 0.22, 1))
    for x, y, height, tilt in [(-0.18, 0.08, 1.45, 0.12), (0.22, -0.12, 1.18, -0.16)]:
        stem = cylinder("trunk", (x, y, height * 0.5), 0.055, height, trunk, 7, 0.04)
        stem.rotation_euler[1] = tilt
        for index in range(6):
            angle = index * math.tau / 6
            leaf_obj = cube(
                "leaf", (x + math.cos(angle) * 0.22, y + math.sin(angle) * 0.22, height),
                (0.42, 0.10, 0.035), leaf, 0.015,
            )
            leaf_obj.rotation_euler[2] = angle


def lighthouse() -> None:
    white = material("lighthouse_white", (0.84, 0.82, 0.75, 1))
    red = material("lighthouse_red", (0.60, 0.16, 0.12, 1))
    glass = material("lantern_glass", (0.95, 0.66, 0.25, 1))
    cylinder("tower", (0, 0, 1.05), 0.36, 2.1, white, 12, 0.25)
    cylinder("red_band", (0, 0, 1.25), 0.32, 0.22, red, 12, 0.29)
    cylinder("lantern", (0, 0, 2.25), 0.26, 0.38, glass, 10)
    cylinder("roof", (0, 0, 2.56), 0.34, 0.24, red, 10, 0.0)


def light_marker() -> None:
    red = material("marker_red", (0.67, 0.25, 0.16, 1))
    warm = material("marker_warm", (0.95, 0.65, 0.24, 1))
    cylinder("post", (0, 0, 0.72), 0.09, 1.44, red, 8)
    cylinder("lamp", (0, 0, 1.55), 0.20, 0.28, warm, 8)
    cylinder("cap", (0, 0, 1.78), 0.25, 0.18, red, 8, 0.0)


BUILDERS = {
    "sand": sand,
    "cliff": cliff,
    "white_house": white_house,
    "blue_dome": blue_dome,
    "granite": granite,
    "palm_cluster": palm_cluster,
    "lighthouse": lighthouse,
    "light_marker": light_marker,
}


def main() -> None:
    for asset_id, builder in BUILDERS.items():
        clear()
        builder()
        export(asset_id)
        print(f"generated {asset_id}")


if __name__ == "__main__":
    main()
