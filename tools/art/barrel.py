"""Mist Harbor asset: harbour barrel. Executor owns GLB export and preview.

Meters, Z-up, origin at the footprint centre, ~0.6 m wide so it fits one build cell.
"""
import bpy
from mathutils import Vector

scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0


def material(name, base_color, roughness, metallic):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(node for node in mat.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    values = {
        'Base Color': base_color,
        'Roughness': roughness,
        'Metallic': metallic,
    }
    for socket_name, value in values.items():
        socket = bsdf.inputs.get(socket_name)
        if socket is None:
            raise RuntimeError(f'Required Principled BSDF input missing: {socket_name}')
        socket.default_value = value
    return mat


wood = material('BarrelWood', (0.42, 0.27, 0.15, 1.0), 0.75, 0.0)
band = material('BarrelBand', (0.35, 0.35, 0.38, 1.0), 0.45, 0.85)

bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.28, depth=0.7, location=Vector((0.0, 0.0, 0.35)))
body = bpy.context.object
body.name = 'BarrelBody'
body.data.materials.append(wood)

for index, height in enumerate((0.16, 0.54)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.285, minor_radius=0.022, major_segments=16, minor_segments=8,
        location=Vector((0.0, 0.0, height)))
    ring = bpy.context.object
    ring.name = f'BarrelBand{index}'
    ring.data.materials.append(band)

bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.26, depth=0.02, location=Vector((0.0, 0.0, 0.71)))
lid = bpy.context.object
lid.name = 'BarrelLid'
lid.data.materials.append(wood)

for obj in (body, lid) + tuple(bpy.data.objects['BarrelBand%d' % i] for i in range(2)):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

bottom = min((body.matrix_world @ Vector(corner)).z for corner in body.bound_box)
assert abs(bottom) < 1e-6, f'barrel must sit on z=0, got {bottom}'

print('MIST_HARBOR_BARREL_OK: meters Z-up; geometry + materials only', flush=True)
