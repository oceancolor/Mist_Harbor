"""Mist Harbor asset: Minnan swallowtail roof ridge (QZ-03).

Z-up, origin at the footprint centre, base at z=0, total height 0.55 m
(placed on top of pitched roofs). Face budget < 200. Exports raw GLB for QA.
"""
import bpy

COLORS = {
    'tile': 'c67360',
    'tile_dark': 'b35f4d',
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


def box(name, size, location, mat_name, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material(mat_name))
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj


# 主脊：横贯一格的脊梁
box('ridge_beam', (0.98, 0.16, 0.14), (0, 0, 0.07), 'tile')
# 两端高高翘起、末端分叉如燕尾（左右对称，各两根翘叉）
for side in (-1, 1):
    # 上翘的尾段（相对水平面上抬约 45°）
    box(f'ridge_tail_{side}', (0.30, 0.14, 0.10),
        (side * 0.52, 0, 0.16), 'tile', rotation=(0, side * -0.7, 0))
    # 分叉的双翘（燕尾两羽）
    for prong in (-1, 1):
        box(f'ridge_prong_{side}_{prong}', (0.26, 0.05, 0.06),
            (side * 0.62, prong * 0.055, 0.34), 'tile_dark', rotation=(0, side * -1.25, 0))
# 脊身中段的小凸饰（闽南脊面常有一道压条）
box('ridge_crest', (0.44, 0.06, 0.05), (0, 0, 0.17), 'tile_dark')

bpy.ops.export_scene.gltf(
    filepath='.codebuddy/local/art/qz_ridge_raw.glb',
    export_format='GLB', export_yup=True, export_materials='EXPORT',
    export_animations=False, export_cameras=False, export_lights=False)
print('MIST_HARBOR_ART_OK qz_ridge')
