"""Mist Harbor asset: bay cottage. Executor owns GLB export and preview.

Ported from project/art/generate_harbor.py::cottage (original procedural mesh, CC0).
Meters, Z-up, origin at the footprint centre, total height 1.0 m (1 build cell, stackable).
Self-contained: the remote pilot submits one inline script, so helpers are inlined.
"""
import bpy
from mathutils import Vector

COLORS = {
    'plaster': 'e6dbc4', 'stone': 'c8c5af', 'roof': 'b96450',
    'roof_edge': 'd58667', 'timber': '795d4c', 'teal': '426e69',
    'glass': '91bbbc', 'gold': 'f3c888', 'cream': 'f3ead4',
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


def finish(obj, name, mat_name, bevel=0):
    obj.name = name
    obj.data.materials.append(material(mat_name))
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    if bevel:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        modifier = obj.modifiers.new('Soft handmade edges', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 1
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def box(name, center, size, mat_name, bevel=0.012):
    bpy.ops.mesh.primitive_cube_add(size=1, location=Vector(center))
    obj = bpy.context.object
    obj.dimensions = Vector(size)
    return finish(obj, name, mat_name, bevel)


def prism(name, width, depth, bottom, peak, mat_name):
    x, y = width / 2, depth / 2
    vertices = [(-x, -y, bottom), (x, -y, bottom), (0, -y, peak),
                (-x, y, bottom), (x, y, bottom), (0, y, peak)]
    faces = [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material(mat_name))
    return obj


def window(x, y, z, side=False):
    box('Window frame', (x, y, z), (0.018, 0.20, 0.23) if side else (0.20, 0.018, 0.23), 'timber', 0)
    box('Warm window', (x, y, z), (0.025, 0.145, 0.175) if side else (0.145, 0.025, 0.175), 'gold', 0)
    box('Window mullion', (x, y, z), (0.029, 0.018, 0.20) if side else (0.018, 0.029, 0.20), 'cream', 0)


scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0

box('Stone foundation', (0, 0, 0.055), (0.92, 0.88, 0.11), 'stone')
box('Plaster walls', (0, 0, 0.37), (0.82, 0.78, 0.63), 'plaster')
prism('Terracotta roof', 1.03, 0.97, 0.68, 1.0, 'roof')
box('Roof ridge', (0, 0, 0.994), (0.045, 1.0, 0.012), 'roof_edge', 0)
box('Door frame', (-0.20, -0.405, 0.265), (0.235, 0.045, 0.43), 'timber', 0)
box('Painted door', (-0.20, -0.432, 0.265), (0.177, 0.018, 0.37), 'teal', 0)
box('Doorstep', (-0.20, -0.45, 0.03), (0.30, 0.16, 0.06), 'stone')
window(0.20, -0.404, 0.43)
window(0.415, 0.07, 0.44, True)
for y in (-0.3, 0.3):
    box('Corner timber', (-0.417, y, 0.39), (0.025, 0.04, 0.55), 'timber', 0)

bpy.context.view_layer.update()
lowest = min(min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
             for obj in scene.objects)
assert abs(lowest) < 1e-6, f'cottage must sit on z=0, got {lowest}'

print('MIST_HARBOR_COTTAGE_OK: meters Z-up; geometry + materials only', flush=True)
