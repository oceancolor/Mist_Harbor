"""Mist Harbor asset: Seychelles granite boulder cluster (SY-01).

Z-up, origin at the footprint centre, base at z=0, ~1.9 x 1.9 x 1.6 m (1 cell).
Anse Source d'Argent 式花岗岩巨石：三块浑圆巨岩错位咬合，上亮下暗。
"""
import bpy
from mathutils import Vector

COLORS = {
    'granite': 'B8A092', 'granite_light': 'D8C4B4', 'granite_dark': '8A7A70',
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
        bsdf.inputs['Roughness'].default_value = 0.9
        MATERIALS[name] = mat
    return MATERIALS[name]


def _finish(obj, mat_name):
    obj.data.materials.append(material(mat_name))
    for p in obj.data.polygons:
        p.use_smooth = True   # 花岗岩浑圆面，平滑着色才有巨石感
    return obj


def blob(name, radius, location, mat_name, scale=(1, 1, 1), subdivisions=3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius,
                                          location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, mat_name)


# 主岩：体量最大，略扁（风化磨圆）
blob('boulder_main', 0.72, (0.02, 0.08, 0.62), 'granite', (1.0, 0.9, 0.86))
# 右前 companion：偏暖的受光面
blob('boulder_right', 0.5, (0.58, -0.38, 0.4), 'granite_light', (0.95, 0.88, 0.8))
# 左后暗岩
blob('boulder_back', 0.46, (-0.58, 0.34, 0.36), 'granite_dark', (0.95, 0.9, 0.78))
# 顶部小岩（咬合在主岩肩上）
blob('boulder_crown', 0.28, (-0.12, 0.3, 1.32), 'granite_light', (1.0, 0.85, 0.72), subdivisions=2)

bpy.context.view_layer.update()
lowest = min(min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
             for obj in bpy.context.scene.objects if obj.type == 'MESH')
assert lowest > -0.05, f'boulder sinks below z=0: {lowest}'

tris = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH')
bpy.ops.export_scene.gltf(
    filepath='project/assets/models/loc_sy_boulder.glb',
    export_format='GLB', export_yup=True, export_materials='EXPORT',
    export_animations=False, export_cameras=False, export_lights=False)
print(f'MIST_HARBOR_ART_OK loc_sy_boulder tris={tris}')
