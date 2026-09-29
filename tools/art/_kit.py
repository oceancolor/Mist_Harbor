"""Shared helpers for Mist Harbor asset scripts (batch 3+).

Asset scripts start with:
    import sys, os; sys.path.insert(0, os.path.dirname(__file__))
    from _kit import box, cyl, blob, torus, export, mat

Conventions: metres, Z-up, base at z=0, visual origin = footprint centre,
front (door) on -Y (exports to Godot +Z toward default camera).
"""
import bpy
from mathutils import Vector

_MATERIALS = {}


def _linear(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def mat(hex_color, rough=0.85):
    key = (hex_color, rough)
    if key not in _MATERIALS:
        rgb = [_linear(int(hex_color[i:i + 2], 16) / 255) for i in (0, 2, 4)]
        m = bpy.data.materials.new('Harbor_' + hex_color)
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        bsdf.inputs['Base Color'].default_value = (*rgb, 1.0)
        bsdf.inputs['Roughness'].default_value = rough
        _MATERIALS[key] = m
    return _MATERIALS[key]


def _finish(obj, m, smooth=False):
    obj.data.materials.append(m)
    for p in obj.data.polygons:
        p.use_smooth = smooth
    return obj


def box(name, size, location, hex_color, rotation=(0, 0, 0), rough=0.85, smooth=False):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, mat(hex_color, rough), smooth)


def cyl(name, radius, depth, location, hex_color, top=None, vertices=10,
        rotation=(0, 0, 0), rough=0.85):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
                                    radius2=radius if top is None else top,
                                    depth=depth, location=location, rotation=rotation)
    return _finish(bpy.context.active_object, mat(hex_color, rough))


def blob(name, radius, location, hex_color, scale=(1, 1, 1), subdivisions=3,
         rough=0.85, smooth=True):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius,
                                          location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, mat(hex_color, rough), smooth)


def torus(name, major, minor, location, hex_color, rough=0.85):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     location=location)
    return _finish(bpy.context.active_object, mat(hex_color, rough))


def export(asset_id):
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.context.view_layer.update()
    lowest = min(min((obj.matrix_world @ Vector(c)).z for c in obj.bound_box) for obj in meshes)
    assert lowest > -0.05, f'{asset_id} sinks below z=0: {lowest}'
    tris = sum(len(o.data.polygons) for o in meshes)
    bpy.ops.export_scene.gltf(
        filepath=f'project/assets/models/{asset_id}.glb',
        export_format='GLB', export_yup=True, export_materials='EXPORT',
        export_animations=False, export_cameras=False, export_lights=False)
    print(f'MIST_HARBOR_ART_OK {asset_id} tris={tris}')
