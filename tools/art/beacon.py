"""Mist Harbor asset: harbour beacon lighthouse. Executor owns GLB export and preview.

Ported from project/art/generate_harbor.py::beacon (original procedural mesh, CC0).
Meters, Z-up, origin at the footprint centre, total height 2.8 m (3 build cells).
Self-contained: the remote pilot submits one inline script, so helpers are inlined.
"""
import math

import bpy
from mathutils import Vector

COLORS = {
    'stone': 'c8c5af', 'roof': 'b96450', 'teal': '426e69',
    'glass': '91bbbc', 'gold': 'f3c888', 'timber': '795d4c', 'cream': 'f3ead4',
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

cylinder('Octagonal base', (0, 0, 0.07), 0.42, 0.14, 'stone', vertices=12)
for i in range(5):
    bottom = 0.34 - i * 0.018
    cylinder('Lighthouse band_%d' % i, (0, 0, 0.16 + i * 0.38 + 0.19), bottom, 0.38,
             'roof' if i % 2 else 'cream', top=bottom - 0.018, vertices=12)
box('Tower door', (0, -0.343, 0.35), (0.18, 0.018, 0.4), 'teal')
for z in (0.95, 1.68):
    box('Tower window', (0, -0.315, z), (0.095, 0.03, 0.19), 'glass')
cylinder('Balcony platform', (0, 0, 2.13), 0.43, 0.10, 'teal', vertices=12)
cylinder('Lantern glass', (0, 0, 2.35), 0.24, 0.34, 'gold', vertices=8)
for i in range(8):
    angle = i * math.tau / 8
    cylinder('Lantern post', (0.25 * math.cos(angle), 0.25 * math.sin(angle), 2.35),
             0.018, 0.38, 'timber', vertices=5)
cylinder('Lantern roof', (0, 0, 2.61), 0.39, 0.20, 'roof', top=0, vertices=8)
cylinder('Finial', (0, 0, 2.74), 0.028, 0.12, 'gold', top=0, vertices=6)

bpy.context.view_layer.update()
lowest = min(min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
             for obj in scene.objects)
assert abs(lowest) < 1e-6, f'beacon must sit on z=0, got {lowest}'

print('MIST_HARBOR_BEACON_OK: meters Z-up; geometry + materials only', flush=True)
