"""Mist Harbor asset: Aldabra giant tortoise (SY-02).

Z-up, origin at the footprint centre, base at z=0, ~0.9 x 0.9 x 0.55 m (1 cell).
亚达伯拉象龟：高圆背甲 + 盾片棱线 + 伸缩颈头 + 四柱状腿。
"""
import bpy
from mathutils import Vector

COLORS = {
    'shell': '6E5638', 'shell_rim': '7D6248', 'skin': '9A8A72', 'skin_dark': '857663',
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
        bsdf.inputs['Roughness'].default_value = 0.88
        MATERIALS[name] = mat
    return MATERIALS[name]


def _finish(obj, mat_name, smooth=False):
    obj.data.materials.append(material(mat_name))
    for p in obj.data.polygons:
        p.use_smooth = smooth
    return obj


def blob(name, radius, location, mat_name, scale=(1, 1, 1), subdivisions=3, smooth=True):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius,
                                          location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, mat_name, smooth)


def box(name, size, location, mat_name, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, mat_name)


def cylinder(name, radius, depth, location, mat_name, top=None, vertices=8):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
                                    radius2=radius if top is None else top,
                                    depth=depth, location=location)
    return _finish(bpy.context.active_object, mat_name)


# 背甲：高圆穹顶（象龟的标志性轮廓）
blob('shell_dome', 0.34, (0.02, 0.02, 0.34), 'shell', (1.15, 0.85, 0.72))
# 甲缘：稍宽的扁环体，形成裙边
blob('shell_rim', 0.36, (0.02, 0.02, 0.22), 'shell_rim', (1.2, 0.92, 0.34))
# 盾片棱线：三条纵向浅棱（用细长弯条近似）
for i, (dx, dy, rot) in enumerate([(0.0, 0.0, 0.0), (0.16, 0.0, 0.25), (-0.16, 0.0, -0.25)]):
    box(f'shell_scute_{i}', (0.05, 0.5, 0.04),
        (0.02 + dx, dy, 0.52 - abs(dx) * 0.55), 'shell_rim', rotation=(0, rot, 0))
# 颈 + 头（前伸）
cylinder('neck', 0.075, 0.2, (0.36, 0.0, 0.22), 'skin')
blob('head', 0.11, (0.45, 0.0, 0.24), 'skin', (1.0, 0.85, 0.8), subdivisions=2)
# 四条柱状腿（象龟腿如象腿）
for i, (dx, dy) in enumerate([(0.22, 0.2), (0.22, -0.2), (-0.22, 0.2), (-0.22, -0.2)]):
    cylinder(f'leg_{i}', 0.095, 0.22, (dx, dy, 0.11), 'skin_dark', top=0.085, vertices=7)
# 尾
box('tail', (0.1, 0.06, 0.06), (-0.42, 0.0, 0.14), 'skin', rotation=(0, 0.5, 0))

bpy.context.view_layer.update()
lowest = min(min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
             for obj in bpy.context.scene.objects if obj.type == 'MESH')
assert lowest > -0.05, f'tortoise sinks below z=0: {lowest}'

tris = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH')
bpy.ops.export_scene.gltf(
    filepath='project/assets/models/loc_sy_tortoise.glb',
    export_format='GLB', export_yup=True, export_materials='EXPORT',
    export_animations=False, export_cameras=False, export_lights=False)
print(f'MIST_HARBOR_ART_OK loc_sy_tortoise tris={tris}')
