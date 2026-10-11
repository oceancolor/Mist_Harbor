"""Mist Harbor asset: Cape Cod shingle cottage (CC-02).

Z-up, origin at the footprint centre, base at z=0, ~1.9 x 1.9 x 1.85 m (1 cell, h2).
银灰木瓦小屋：风化雪杉瓦墙 + 陡坡灰顶 + 老虎窗 + 砖烟囱 + 白框窗。
"""
import bpy
from mathutils import Vector
from math import pi

COLORS = {
    'shingle': '8A8578', 'shingle_dark': '797467', 'roof': '4A4E52',
    'trim': 'F2EFE6', 'door': '5B5148', 'brick': '7A5A48', 'glass': 'D8E2E0',
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
        bsdf.inputs['Roughness'].default_value = 0.87
        MATERIALS[name] = mat
    return MATERIALS[name]


def _finish(obj, mat_name):
    obj.data.materials.append(material(mat_name))
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj


def box(name, size, location, mat_name, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, mat_name)


def cylinder(name, radius, depth, location, mat_name, top=None, vertices=4, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
                                    radius2=radius if top is None else top,
                                    depth=depth, location=location, rotation=rotation)
    return _finish(bpy.context.active_object, mat_name)


# 主体：木瓦墙（1.8 x 0.95 x 1.1），两层瓦色微差制造横向纹理
box('walls', (1.8, 0.95, 1.1), (0.0, 0.0, 0.55), 'shingle')
box('weather_line', (1.82, 0.97, 0.08), (0.0, 0.0, 0.62), 'shingle_dark')
box('weather_line_low', (1.82, 0.97, 0.08), (0.0, 0.0, 0.34), 'shingle_dark')
# 陡坡主顶（Cape Cod 特征：接近 45°）
box('eaves', (1.94, 1.1, 0.12), (0.0, 0.0, 1.16), 'roof')
cylinder('gable_roof', 0.86, 0.62, (0.0, 0.0, 1.53), 'roof', top=0.04,
         rotation=(0, 0, pi / 4))
# 老虎窗（前坡）
box('dormer', (0.42, 0.36, 0.34), (0.34, -0.42, 1.36), 'shingle')
cylinder('dormer_roof', 0.32, 0.2, (0.34, -0.42, 1.6), 'roof', top=0.02,
         rotation=(0, 0, pi / 4))
box('dormer_win', (0.26, 0.04, 0.2), (0.34, -0.62, 1.34), 'glass')
# 砖烟囱（Cape Cod 灰泥帽）
box('chimney', (0.2, 0.2, 0.62), (-0.52, 0.12, 1.62), 'brick')
box('chimney_cap', (0.26, 0.26, 0.06), (-0.52, 0.12, 1.95), 'roof')
# 白框窗 x2 + 门
box('door', (0.38, 0.05, 0.74), (0.0, -0.49, 0.37), 'door')
for i, dx in enumerate([-0.58, 0.58]):
    box(f'win_{i}', (0.4, 0.04, 0.44), (dx, -0.49, 0.68), 'glass')
    box(f'win_trim_{i}', (0.46, 0.05, 0.5), (dx, -0.495, 0.68), 'trim')

bpy.context.view_layer.update()
lowest = min(min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
             for obj in bpy.context.scene.objects if obj.type == 'MESH')
assert lowest > -0.05, f'shingle sinks below z=0: {lowest}'

tris = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH')
bpy.ops.export_scene.gltf(
    filepath='project/assets/models/loc_cc_shingle.glb',
    export_format='GLB', export_yup=True, export_materials='EXPORT',
    export_animations=False, export_cameras=False, export_lights=False)
print(f'MIST_HARBOR_ART_OK loc_cc_shingle tris={tris}')
