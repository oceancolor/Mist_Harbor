"""Mist Harbor asset: warm harbour lamp. Executor owns GLB export and preview.

Ported from project/art/generate_harbor.py::lamp (original procedural mesh, CC0).
Meters, Z-up, origin at the footprint centre, total height 1.25 m (occupies 2 build cells).
Self-contained: the remote pilot submits one inline script, so helpers are inlined.
"""
import bpy
from mathutils import Vector

COLORS = {
    'stone': 'c8c5af', 'teal': '426e69', 'gold': 'f3c888', 'timber': '795d4c',
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
    if name == 'gold':
        # Warm glow for night mode; optional sockets must exist on this runtime.
        for socket_name, value in (('Emission Color', (*rgb, 1.0)), ('Emission Strength', 0.7)):
            socket = bsdf.inputs.get(socket_name)
            if socket is None:
                raise RuntimeError(f'Principled BSDF input missing: {socket_name}')
            socket.default_value = value
    MATERIALS[name] = mat
    return mat


def finish(obj, name, mat_name):
    obj.name = name
    obj.data.materials.append(material(mat_name))
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    return obj


def box(name, center, size, mat_name):
    bpy.ops.mesh.primitive_cube_add(size=1, location=Vector(center))
    obj = bpy.context.object
    obj.dimensions = Vector(size)
    return finish(obj, name, mat_name)


def cylinder(name, center, radius, depth, mat_name, top=None, vertices=10):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
                                    radius2=radius if top is None else top,
                                    depth=depth, location=Vector(center))
    return finish(bpy.context.object, name, mat_name)


scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0

cylinder('Base', (0, 0, 0.04), 0.15, 0.08, 'stone', vertices=8)
cylinder('Lamp post', (0, 0, 0.48), 0.041, 0.94, 'teal', vertices=8)
box('Lantern body', (0, 0, 1.015), (0.23, 0.23, 0.25), 'gold')
cylinder('Lantern hat', (0, 0, 1.195), 0.21, 0.11, 'teal', top=0, vertices=4)
box('Lantern foot', (0, 0, 0.88), (0.29, 0.29, 0.05), 'teal')
for x in (-0.11, 0.11):
    for y in (-0.11, 0.11):
        box('Lantern frame', (x, y, 1.015), (0.024, 0.024, 0.26), 'timber')

lowest = min(min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
             for obj in scene.objects)
assert abs(lowest) < 1e-6, f'lamp must sit on z=0, got {lowest}'

print('MIST_HARBOR_LAMP_OK: meters Z-up; geometry + materials only', flush=True)
