"""Mist Harbor asset: coco de mer palm (SY-03).

Z-up, origin at the footprint centre, base at z=0, ~1.9 x 1.9 x 2.8 m (1 cell, h3).
海椰子（Coco de mer）：弯干三段 + 巨大扇形叶环抱 + 叶下著名双椰果串。
"""
import bpy
from mathutils import Vector
from math import cos, sin, pi

COLORS = {
    'trunk': '8A7355', 'trunk_dark': '7A6549', 'leaf': '2E7A4E', 'leaf_light': '37935A',
    'coco': '8A6A3C',
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


def _finish(obj, mat_name, smooth=False):
    obj.data.materials.append(material(mat_name))
    for p in obj.data.polygons:
        p.use_smooth = smooth
    return obj


def box(name, size, location, mat_name, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, mat_name)


def cylinder(name, radius, depth, location, mat_name, top=None, vertices=8, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
                                    radius2=radius if top is None else top,
                                    depth=depth, location=location, rotation=rotation)
    return _finish(bpy.context.active_object, mat_name)


def blob(name, radius, location, mat_name, scale=(1, 1, 1), subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius,
                                          location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, mat_name)


# 弯干三段（朝 +X 倾斜，海椰子树干粗短有环痕）
cylinder('trunk_low', 0.19, 1.0, (0.03, 0.0, 0.5), 'trunk', top=0.16, rotation=(0, -0.1, 0))
cylinder('trunk_mid', 0.16, 0.95, (0.19, 0.0, 1.4), 'trunk', top=0.13, rotation=(0, -0.22, 0))
cylinder('trunk_top', 0.13, 0.85, (0.41, 0.0, 2.22), 'trunk_dark', top=0.10, rotation=(0, -0.34, 0))
crown = Vector((0.56, 0.0, 2.62))
# 巨扇叶：8 片，先上扬后下垂的弧线（每片两段：叶柄上扬 + 叶身下垂）
for i in range(8):
    a = i * pi / 4.0 + 0.25
    yaw = -a
    tilt = 0.62
    # 叶柄段
    box(f'frond_stem_{i}', (1.05, 0.06, 0.16),
        (crown.x + cos(a) * 0.45, crown.y + sin(a) * 0.45, crown.z + 0.18),
        'trunk_dark', rotation=(0, tilt, yaw))
    # 叶身段（下垂弧）
    box(f'frond_blade_{i}', (1.55, 0.34, 0.05),
        (crown.x + cos(a) * 1.15, crown.y + sin(a) * 1.15, crown.z - 0.12),
        'leaf' if i % 2 == 0 else 'leaf_light', rotation=(0, -0.55, yaw))
    # 中肋亮线
    box(f'frond_rib_{i}', (1.5, 0.06, 0.03),
        (crown.x + cos(a) * 1.15, crown.y + sin(a) * 1.15, crown.z - 0.085),
        'leaf_light', rotation=(0, -0.55, yaw))
# 海椰子的著名双椰：两颗大果挂在冠下
blob('coco_a', 0.15, (0.48, -0.14, 2.42), 'coco', (1.0, 0.9, 1.15))
blob('coco_b', 0.15, (0.66, 0.1, 2.4), 'coco', (1.0, 0.9, 1.15))

bpy.context.view_layer.update()
lowest = min(min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
             for obj in bpy.context.scene.objects if obj.type == 'MESH')
assert lowest > -0.05, f'coco sinks below z=0: {lowest}'

tris = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH')
bpy.ops.export_scene.gltf(
    filepath='project/assets/models/loc_sy_coco.glb',
    export_format='GLB', export_yup=True, export_materials='EXPORT',
    export_animations=False, export_cameras=False, export_lights=False)
print(f'MIST_HARBOR_ART_OK loc_sy_coco tris={tris}')
