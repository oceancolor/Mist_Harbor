"""Mist Harbor asset: island tree. Executor owns GLB export and preview.

Ported from project/art/generate_harbor.py::tree (original procedural mesh, CC0).
Meters, Z-up, origin at the footprint centre, total height 1.8 m (occupies 2 build cells).
Self-contained: the remote pilot submits one inline script, so helpers are inlined.
"""
import bpy
from mathutils import Vector

COLORS = {
    'timber': '795d4c', 'green': '698e75', 'green_light': '8da888', 'green_dark': '4c7969',
}
MATERIALS = {}


def linear(value):
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def srgb_to_linear(hex_color):
    return [linear(int(hex_color[i:i + 2], 16) / 255) for i in (0, 2, 4)]


def material(name):
    if name in MATERIALS:
        return MATERIALS[name]
    rgb = srgb_to_linear(COLORS[name])
    mat = bpy.data.materials.new('Harbor_' + name)
    mat.use_nodes = True
    bsdf = next(node for node in mat.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    for socket_name, value in (('Base Color', (*rgb, 1.0)), ('Roughness', 0.83)):
        socket = bsdf.inputs.get(socket_name)
        if socket is None:
            raise RuntimeError(f'Required Principled BSDF input missing: {socket_name}')
        socket.default_value = value
    MATERIALS[name] = mat
    return mat


def finish(obj, name, mat_name):
    obj.name = name
    obj.data.materials.append(material(mat_name))
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    return obj


def cylinder(name, center, radius, depth, mat_name, top=None, vertices=10):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
                                    radius2=radius if top is None else top,
                                    depth=depth, location=Vector(center))
    return finish(bpy.context.object, name, mat_name)


scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0

cylinder('Trunk', (0, 0, 0.46), 0.075, 0.92, 'timber', top=0.043)
cylinder('Low crown', (0, 0, 0.93), 0.47, 0.72, 'green_dark', top=0, vertices=7)
cylinder('Middle crown', (0.025, 0, 1.25), 0.40, 0.67, 'green', top=0, vertices=7)
cylinder('High crown', (-0.015, 0, 1.57), 0.27, 0.46, 'green_light', top=0, vertices=7)

lowest = min(min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
             for obj in scene.objects)
assert abs(lowest) < 1e-6, f'tree must sit on z=0, got {lowest}'

print('MIST_HARBOR_TREE_OK: meters Z-up; geometry + materials only', flush=True)
