"""Mist Harbor asset: flower planter. Executor owns GLB export and preview.

Ported from project/art/generate_harbor.py::flower (original procedural mesh, CC0).
Meters, Z-up, origin at the footprint centre, total height 0.32 m (1 build cell).
A 3x3 grid of stems, blooms and leaves on a timber planter.
Self-contained: the remote pilot submits one inline script, so helpers are inlined.
"""
import bpy
from mathutils import Vector

COLORS = {
    'timber': '795d4c', 'soil': '746953', 'green': '698e75', 'green_dark': '4c7969',
    'pink': 'd5a0a1', 'gold': 'f3c888', 'cream': 'f3ead4',
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


def cylinder(name, center, radius, depth, mat_name, vertices=10):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
                                    radius2=radius, depth=depth, location=Vector(center))
    return finish(bpy.context.object, name, mat_name)


def ico(name, center, scale, mat_name):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=Vector(center))
    obj = bpy.context.object
    obj.scale = Vector(scale)
    return finish(obj, name, mat_name)


scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0

box('Planter', (0, 0, 0.065), (0.85, 0.85, 0.13), 'timber', 0.016)
box('Garden soil', (0, 0, 0.133), (0.74, 0.74, 0.018), 'soil', 0)
for i in range(9):
    x = (i % 3 - 1) * 0.23
    y = (i // 3 - 1) * 0.23
    z = 0.23 + (i % 2) * 0.025
    cylinder('Stem_%d' % i, (x, y, 0.195), 0.012, 0.12, 'green_dark', vertices=5)
    ico('Bloom_%d' % i, (x, y, z), (0.083, 0.078, 0.065), ['pink', 'gold', 'cream'][i % 3])
    ico('Leaf_%d' % i, (x + 0.07, y, 0.19), (0.095, 0.055, 0.026), 'green')

bpy.context.view_layer.update()
lowest = min(min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
             for obj in scene.objects)
assert abs(lowest) < 1e-6, f'flower must sit on z=0, got {lowest}'

print('MIST_HARBOR_FLOWER_OK: meters Z-up; geometry + materials only', flush=True)
