"""Mist Harbor asset: bridge arch. Executor owns GLB export and preview.

Ported from project/art/generate_harbor.py::arch (original procedural mesh, CC0).
Meters, Z-up, origin at the footprint centre, total height 1.0 m (1 build cell).
Nine voussoirs are built as explicit meshes, alternating cream and stone.
Self-contained: the remote pilot submits one inline script, so helpers are inlined.
"""
import math

import bpy
from mathutils import Vector

COLORS = {'stone': 'c8c5af', 'cream': 'f3ead4', 'plaster': 'e6dbc4'}
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


def link_mesh(name, vertices, faces, mat_name):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material(mat_name))
    return obj


scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0

for x in (-0.405, 0.405):
    box('Pier', (x, 0, 0.265), (0.19, 0.93, 0.53), 'stone')

for i in range(9):
    a0, a1 = math.pi * i / 9, math.pi * (i + 1) / 9
    vertices = []
    for y in (-0.46, 0.46):
        for r, a in ((0.49, a0), (0.49, a1), (0.30, a1), (0.30, a0)):
            vertices.append((math.cos(a) * r, y, 0.48 + math.sin(a) * r))
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    link_mesh('Voussoir_%02d' % i, vertices, faces, 'cream' if i % 3 == 0 else 'stone')

box('Bridge deck', (0, 0, 0.96), (1, 1, 0.08), 'plaster', 0)

bpy.context.view_layer.update()
lowest = min(min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
             for obj in scene.objects)
assert abs(lowest) < 1e-6, f'arch must sit on z=0, got {lowest}'

print('MIST_HARBOR_ARCH_OK: meters Z-up; geometry + materials only', flush=True)
