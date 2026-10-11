"""Mist Harbor asset: Highland Light lighthouse (CC-01).

Z-up, origin at the footprint centre, base at z=0, ~1.9 x 1.9 x 3.4 m (1 cell, h4).
Highland Light（Truro 高地灯塔）：锥形白塔 + 黑色灯室 + 值班人小屋。
"""
import bpy
from mathutils import Vector
from math import pi, cos, sin

COLORS = {
    'white': 'F2EFE6', 'brick': 'D8D2C4', 'black': '2E3136', 'lantern': 'FFE9A8',
    'roof': '5A6068', 'door': '4A5058',
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
        bsdf.inputs['Roughness'].default_value = 0.84
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


def cylinder(name, radius, depth, location, mat_name, top=None, vertices=10, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
                                    radius2=radius if top is None else top,
                                    depth=depth, location=location, rotation=rotation)
    return _finish(bpy.context.active_object, mat_name)


# ── 灯塔主体（右侧，塔中轴 x=0.35）──
cylinder('tower', 0.36, 2.6, (0.35, 0.0, 1.3), 'white', top=0.28)
box('tower_band', (0.6, 0.6, 0.1), (0.35, 0.0, 0.9), 'brick')   # 塔身箍带
cylinder('gallery', 0.4, 0.08, (0.35, 0.0, 2.66), 'black', vertices=12)
# 栏杆：一圈细柱
for i in range(8):
    a = i * pi / 4.0
    box(f'rail_{i}', (0.04, 0.04, 0.22),
        (0.35 + 0.36 * cos(a), 0.36 * sin(a), 2.81), 'black')
cylinder('lantern', 0.24, 0.42, (0.35, 0.0, 2.91), 'lantern', vertices=10)
cylinder('cap', 0.3, 0.3, (0.35, 0.0, 3.27), 'black', top=0.02, vertices=10)
box('tower_door', (0.26, 0.05, 0.56), (0.35, -0.37, 0.28), 'door')
# ── 值班人小屋（左侧，接塔）──
box('house', (0.95, 0.9, 0.72), (-0.5, 0.0, 0.36), 'white')
cylinder('house_roof', 0.78, 0.42, (-0.5, 0.0, 0.93), 'roof', top=0.1,
         rotation=(0, 0, pi / 4))
box('house_door', (0.3, 0.05, 0.52), (-0.22, -0.46, 0.26), 'door')
box('house_window', (0.3, 0.05, 0.34), (-0.62, -0.46, 0.44), 'lantern')
box('chimney', (0.16, 0.16, 0.4), (-0.72, 0.2, 1.2), 'brick')

bpy.context.view_layer.update()
lowest = min(min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
             for obj in bpy.context.scene.objects if obj.type == 'MESH')
assert lowest > -0.05, f'highland sinks below z=0: {lowest}'

tris = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH')
bpy.ops.export_scene.gltf(
    filepath='project/assets/models/loc_cc_highland.glb',
    export_format='GLB', export_yup=True, export_materials='EXPORT',
    export_animations=False, export_cameras=False, export_lights=False)
print(f'MIST_HARBOR_ART_OK loc_cc_highland tris={tris}')
