"""Mist Harbor asset: Guso-stone octagonal beacon pagoda (QZ-06).

Octagonal five-story stone pagoda tower, 1x1 footprint, ~3.1 m tall (3 cells),
origin at footprint centre, base at z=0. Stone body #B9BCAD with terracotta
accents #C8856B (quanzhou-spec D-1), no lantern room, no light effects.
Face budget < 400. Exports raw GLB for QA.
"""
import bpy

COLORS = {
    'stone': 'b9bcad',
    'stone_dark': 'a4a89b',
    'brick': 'c8856b',
    'dark': '5b5148',
}
MATERIALS = {}


def linear(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def srgb_to_linear(hex_color):
    return [linear(int(hex_color[i:i + 2], 16) / 255) for i in (0, 2, 4)]


def material(name):
    if name not in MATERIALS:
        rgb = srgb_to_linear(COLORS[name])
        mat = bpy.data.materials.new('Harbor_' + name)
        mat.use_nodes = True
        bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        bsdf.inputs['Base Color'].default_value = (*rgb, 1.0)
        bsdf.inputs['Roughness'].default_value = 0.85
        MATERIALS[name] = mat
    return MATERIALS[name]


def shade(obj, mat_name):
    obj.data.materials.append(material(mat_name))
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj


def cyl(name, radius, depth, location, mat_name, sides=8, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth,
                                        location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    return shade(obj, mat_name)


# 基座两层
cyl('pagoda_plinth', 0.50, 0.14, (0, 0, 0.07), 'stone_dark')
cyl('pagoda_plinth2', 0.45, 0.12, (0, 0, 0.20), 'stone_dark')

# 五层塔身：逐层收分 + 每层压一圈陶砖腰檐（八角起翘感用薄锥台近似）
radii = [0.38, 0.35, 0.32, 0.29, 0.26]
y = 0.26
for i, r in enumerate(radii):
    story_h = 0.42
    cyl(f'pagoda_story_{i}', r, story_h, (0, 0, y + story_h / 2), 'stone')
    # 每层朝前一扇小窗（深色薄盒嵌在塔身面）
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, r - 0.03, y + story_h * 0.62))
    win = bpy.context.active_object
    win.name = f'pagoda_win_{i}'
    win.scale = (0.09, 0.06, 0.12)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    shade(win, 'dark')
    # 腰檐：陶砖色薄八棱台（顶层为顶檐）
    eave_h = 0.07
    cyl(f'pagoda_eave_{i}', r + 0.09, eave_h, (0, 0, y + story_h + eave_h / 2), 'brick')
    y += story_h + eave_h

# 塔顶收头：小八棱柱 + 塔刹
cyl('pagoda_crown', 0.16, 0.12, (0, 0, y + 0.06), 'stone_dark')
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.13, radius2=0.02, depth=0.22,
                                location=(0, 0, y + 0.23))
shade(bpy.context.active_object, 'brick').name = 'pagoda_finial'

bpy.ops.export_scene.gltf(
    filepath='.codebuddy/local/art/qz_beacon_raw.glb',
    export_format='GLB', export_yup=True, export_materials='EXPORT',
    export_animations=False, export_cameras=False, export_lights=False)
print('MIST_HARBOR_ART_OK qz_beacon')
