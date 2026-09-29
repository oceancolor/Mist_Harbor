"""Mist Harbor asset: Cycladic windmill (SA-02).

Z-up, origin at the footprint centre, base at z=0, ~1.9 x 1.9 x 2.55 m (1 cell, h3).
基克拉泽斯风车：白圆塔（上窄下宽）+ 木桁锥顶 + 八翼帆（朝 -Y 迎风）。
"""
import bpy
from mathutils import Vector
from math import pi, cos, sin

COLORS = {
    'white': 'F6F4EC', 'blue': '2A6CB4', 'roof': '7A5A48',
    'sail': '6F5A44', 'sail_cloth': 'E8E0CC', 'stone': 'D8D2C4',
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


# 白圆塔（锥度收分）+ 石基座
cylinder('base', 0.48, 0.3, (0.0, 0.0, 0.15), 'stone', top=0.44, vertices=12)
cylinder('tower', 0.44, 1.95, (0.0, 0.0, 1.25), 'white', top=0.34, vertices=12)
# 蓝门窗（贴 -Y 面朝海风）
box('door', (0.3, 0.06, 0.58), (0.0, -0.46, 0.44), 'blue')
box('window_a', (0.2, 0.05, 0.26), (0.0, -0.43, 1.25), 'blue')
box('window_b', (0.18, 0.05, 0.24), (0.0, -0.4, 1.72), 'blue')
# 木桁锥顶
cylinder('roof', 0.4, 0.52, (0.0, 0.0, 2.48), 'roof', top=0.04, vertices=10)
# 八翼帆：轮毂在塔身上部 -Y 侧，双辐板 + 帆布
hub = (0.0, -0.44, 1.9)
box('hub', (0.16, 0.14, 0.16), hub, 'sail')
for i in range(8):
    a = i * pi / 4.0
    arm_dir = (cos(a), 0.0, sin(a))
    ax, _, az = hub
    # 帆臂
    box(f'arm_{i}', (0.88, 0.05, 0.07),
        (ax + arm_dir[0] * 0.5, hub[1] - 0.02, az + arm_dir[2] * 0.5),
        'sail', rotation=(0, a, 0))
    # 帆布（桁架外侧的梯形板，转 45° 相位）
    box(f'cloth_{i}', (0.62, 0.02, 0.16),
        (ax + arm_dir[0] * 0.66, hub[1] - 0.06, az + arm_dir[2] * 0.66),
        'sail_cloth', rotation=(0, a, 0))

bpy.context.view_layer.update()
lowest = min(min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
             for obj in bpy.context.scene.objects if obj.type == 'MESH')
assert lowest > -0.05, f'windmill sinks below z=0: {lowest}'

tris = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH')
bpy.ops.export_scene.gltf(
    filepath='project/assets/models/loc_sa_windmill.glb',
    export_format='GLB', export_yup=True, export_materials='EXPORT',
    export_animations=False, export_cameras=False, export_lights=False)
print(f'MIST_HARBOR_ART_OK loc_sa_windmill tris={tris}')
