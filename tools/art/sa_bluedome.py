"""Mist Harbor asset: Santorini blue-dome church (SA-01).

Z-up, origin at the footprint centre, base at z=0, ~1.9 x 1.9 x 1.95 m (1 cell).
Oia 蓝顶教堂：白灰墙身 + 钴蓝穹顶 + 金色十字 + 附钟楼。
"""
import bpy
from mathutils import Vector

COLORS = {
    'white': 'F6F4EC', 'white_dark': 'E8E4D8', 'blue': '2A6CB4',
    'blue_dark': '235C9C', 'gold': 'D9C98A', 'arch': '5B5148',
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
        bsdf.inputs['Roughness'].default_value = 0.82
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


def cylinder(name, radius, depth, location, mat_name, top=None, vertices=10, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
                                    radius2=radius if top is None else top,
                                    depth=depth, location=location, rotation=rotation)
    return _finish(bpy.context.active_object, mat_name)


def blob(name, radius, location, mat_name, scale=(1, 1, 1), subdivisions=3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius,
                                          location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, mat_name)


# ── 教堂身（白灰抹面，微弧肩线）──
box('nave', (1.5, 1.05, 0.72), (0.0, 0.12, 0.36), 'white')
box('nave_step', (1.56, 1.1, 0.12), (0.0, 0.12, 0.78), 'white_dark')
# 鼓座 + 穹顶（钴蓝半球）
cylinder('drum', 0.42, 0.34, (0.0, 0.12, 1.0), 'white', vertices=12)
blob('dome', 0.44, (0.0, 0.12, 1.16), 'blue', (1.0, 1.0, 0.78))
blob('dome_oculus', 0.1, (0.0, 0.12, 1.5), 'blue_dark', subdivisions=1)
# 金十字
box('cross_v', (0.05, 0.05, 0.3), (0.0, 0.12, 1.72), 'gold')
box('cross_h', (0.2, 0.05, 0.05), (0.0, 0.12, 1.78), 'gold')
# 拱门（内凹深色 + 白框）
box('door_arch', (0.34, 0.06, 0.52), (0.0, -0.42, 0.44), 'arch')
box('door_frame', (0.42, 0.05, 0.6), (0.0, -0.435, 0.46), 'white')
# ── 附钟楼（Oia 式：白塔 + 双拱 + 小蓝顶）──
box('bell_tower', (0.36, 0.36, 1.15), (0.6, -0.52, 0.575), 'white')
box('bell_arch_a', (0.2, 0.2, 0.3), (0.6, -0.52, 0.98), 'arch')
box('bell', (0.12, 0.12, 0.14), (0.6, -0.52, 0.94), 'gold')
cylinder('bell_roof_base', 0.26, 0.1, (0.6, -0.52, 1.2), 'white_dark', vertices=8)
blob('bell_dome', 0.22, (0.6, -0.52, 1.3), 'blue', (1.0, 1.0, 0.75), subdivisions=2)
box('bell_cross_v', (0.04, 0.04, 0.2), (0.6, -0.52, 1.54), 'gold')

bpy.context.view_layer.update()
lowest = min(min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
             for obj in bpy.context.scene.objects if obj.type == 'MESH')
assert lowest > -0.05, f'bluedome sinks below z=0: {lowest}'

tris = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH')
bpy.ops.export_scene.gltf(
    filepath='project/assets/models/loc_sa_bluedome.glb',
    export_format='GLB', export_yup=True, export_materials='EXPORT',
    export_animations=False, export_cameras=False, export_lights=False)
print(f'MIST_HARBOR_ART_OK loc_sa_bluedome tris={tris}')
