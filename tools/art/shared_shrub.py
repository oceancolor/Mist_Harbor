"""Mist Harbor asset: seaside evergreen shrub (shared, all locations).

1x1 footprint, ~0.55 m tall, origin at footprint centre, base at z=0.
Low-poly blob bush for dense MultiMesh scattering. Face budget < 150.
Exports raw GLB for QA.
"""
import bpy

COLORS = {
    'leaf': '4E8F52',
    'leaf_light': '5CA45E',
    'leaf_dark': '437A48',
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


def blob(name, radius, location, scale, mat_name):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material(mat_name))
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj


# 三四个错位的低球团成丛，底部平贴 z=0
blob('shrub_core', 0.30, (0.02, 0.0, 0.26), (1.25, 1.1, 0.95), 'leaf')
blob('shrub_left', 0.20, (-0.22, 0.05, 0.19), (1.0, 0.9, 0.8), 'leaf_light')
blob('shrub_right', 0.17, (0.24, -0.03, 0.16), (0.95, 1.05, 0.85), 'leaf_dark')
blob('shrub_top', 0.14, (0.05, -0.08, 0.42), (1.0, 1.0, 0.75), 'leaf_light')

bpy.ops.export_scene.gltf(
    filepath='.codebuddy/local/art/shrub_raw.glb',
    export_format='GLB', export_yup=True, export_materials='EXPORT',
    export_animations=False, export_cameras=False, export_lights=False)
print('MIST_HARBOR_ART_OK shrub')
