"""Mist Harbor asset: Creole coral-stone house (SY-04).

Z-up, origin at the footprint centre, base at z=0, ~1.9 x 1.9 x 1.95 m (1 cell, h2).
克里奥尔石屋：珊瑚石墙 + 出檐门廊 + 四坡茅草顶 + 板条百叶窗。
"""
import bpy
from mathutils import Vector
from math import pi

COLORS = {
    'coral': 'E0D4C0', 'coral_dark': 'CBBBA4', 'timber': 'BB946C',
    'thatch': 'C8A46A', 'thatch_dark': 'B3935C', 'trim': 'F6F1E4', 'door': '5B5148',
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
        bsdf.inputs['Roughness'].default_value = 0.86
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


# 珊瑚石主墙（1.7 x 1.1 x 1.5）
box('walls', (1.7, 1.1, 1.5), (0.0, 0.15, 0.75), 'coral')
# 墙脚石基（色深一圈）
box('plinth', (1.78, 1.18, 0.22), (0.0, 0.15, 0.11), 'coral_dark')
# 四坡茅草顶：基座檐口 + 四棱锥（cone 4 棱旋转 45° 对齐墙角）
box('eaves', (1.92, 1.32, 0.16), (0.0, 0.15, 1.58), 'thatch_dark')
cylinder('hip_roof', 1.36, 0.62, (0.0, 0.15, 1.97), 'thatch', top=0.08,
         rotation=(0, 0, pi / 4))
# 顶上小烟囱
box('chimney', (0.16, 0.5, 0.16), (0.52, 0.3, 1.78), 'coral_dark')
# 前廊：地板 + 两柱 + 檐
box('porch_floor', (1.7, 0.5, 0.1), (0.0, -0.62, 0.42), 'timber')
box('porch_roof', (1.74, 0.56, 0.07), (0.0, -0.62, 1.32), 'thatch_dark')
for i, dx in enumerate([-0.68, 0.68]):
    box(f'porch_post_{i}', (0.1, 0.1, 0.82), (dx, -0.82, 0.87), 'timber')
# 门 + 两扇百叶窗（板条窗 = 叠两道横条）
box('door', (0.38, 0.06, 0.78), (0.0, -0.41, 0.79), 'door')
for i, dx in enumerate([-0.55, 0.55]):
    box(f'window_frame_{i}', (0.4, 0.05, 0.5), (dx, -0.41, 0.95), 'trim')
    box(f'window_slats_{i}', (0.42, 0.03, 0.4), (dx, -0.435, 0.95), 'timber')

bpy.context.view_layer.update()
lowest = min(min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
             for obj in bpy.context.scene.objects if obj.type == 'MESH')
assert lowest > -0.05, f'creole sinks below z=0: {lowest}'

tris = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH')
bpy.ops.export_scene.gltf(
    filepath='project/assets/models/loc_sy_creole.glb',
    export_format='GLB', export_yup=True, export_materials='EXPORT',
    export_animations=False, export_cameras=False, export_lights=False)
print(f'MIST_HARBOR_ART_OK loc_sy_creole tris={tris}')
