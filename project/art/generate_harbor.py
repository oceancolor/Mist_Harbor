"""Original, deterministic low-poly modules for Mist Harbor. Blender 4.2+, no add-ons."""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

SEED = 240910
COLORS = {
    'plaster': 'e6dbc4', 'stone': 'c8c5af', 'roof': 'b96450',
    'roof_edge': 'd58667', 'timber': '795d4c', 'teal': '426e69',
    'glass': '91bbbc', 'gold': 'f3c888', 'green': '698e75',
    'green_light': '8da888', 'green_dark': '4c7969',
    'pink': 'd5a0a1', 'cream': 'f3ead4', 'soil': '746953',
}
MATERIALS = {}
ACTIVE = None


def linear(value):
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def material(name):
    if name in MATERIALS:
        return MATERIALS[name]
    raw = COLORS[name]
    rgb = [linear(int(raw[i:i + 2], 16) / 255) for i in (0, 2, 4)]
    mat = bpy.data.materials.new('Harbor_' + name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*rgb, 1)
    shader.inputs['Roughness'].default_value = 0.83
    if name == 'gold':
        shader.inputs['Emission Color'].default_value = (*rgb, 1)
        shader.inputs['Emission Strength'].default_value = 0.7
    MATERIALS[name] = mat
    return mat


def finish(obj, name, mat, bevel=0):
    obj.name = name
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    ACTIVE.objects.link(obj)
    obj.data.materials.append(material(mat))
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


def box(name, center, size, mat, bevel=0.012, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.dimensions = size
    obj = finish(obj, name, mat, bevel)
    if rotation:
        obj.rotation_euler = rotation
    return obj


def cylinder(name, center, radius, depth, mat, top=None, vertices=10):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
                                    radius2=radius if top is None else top,
                                    depth=depth, location=center)
    return finish(bpy.context.object, name, mat)


def ico(name, center, scale, mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=center)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat)


def prism(name, width, depth, bottom, peak, mat):
    x, y = width / 2, depth / 2
    vertices = [(-x,-y,bottom),(x,-y,bottom),(0,-y,peak),
                (-x,y,bottom),(x,y,bottom),(0,y,peak)]
    faces = [(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    ACTIVE.objects.link(obj)
    obj.data.materials.append(material(mat))
    return obj


def window(x, y, z, side=False):
    size = (0.018,0.20,0.23) if side else (0.20,0.018,0.23)
    box('Window frame', (x,y,z), size, 'timber', 0)
    size = (0.025,0.145,0.175) if side else (0.145,0.025,0.175)
    box('Warm window', (x,y,z), size, 'gold', 0)
    size = (0.029,0.018,0.20) if side else (0.018,0.029,0.20)
    box('Window mullion', (x,y,z), size, 'cream', 0)


def cottage():
    box('Stone foundation',(0,0,0.055),(0.92,0.88,0.11),'stone')
    box('Plaster walls',(0,0,0.37),(0.82,0.78,0.63),'plaster')
    prism('Terracotta roof',1.03,0.97,0.68,1.0,'roof')
    box('Roof ridge',(0,0,0.994),(0.045,1.0,0.012),'roof_edge',0)
    box('Door frame',(-0.20,-0.405,0.265),(0.235,0.045,0.43),'timber',0)
    box('Painted door',(-0.20,-0.432,0.265),(0.177,0.018,0.37),'teal',0)
    box('Doorstep',(-0.20,-0.45,0.03),(0.30,0.16,0.06),'stone')
    window(0.20,-0.404,0.43)
    window(0.415,0.07,0.44,True)
    for y in [-0.3,0.3]:
        box('Corner timber',(-0.417,y,0.39),(0.025,0.04,0.55),'timber',0)


def roof():
    prism('Modular gable',1.07,1.05,0.03,0.65,'roof')
    box('Ridge cap',(0,0,0.64),(0.07,1.08,0.03),'roof_edge',0)
    box('Eave left',(-0.53,0,0.035),(0.035,1.08,0.07),'timber',0)
    box('Eave right',(0.53,0,0.035),(0.035,1.08,0.07),'timber',0)


def arch():
    for x in [-0.405,0.405]:
        box('Pier',(x,0,0.265),(0.19,0.93,0.53),'stone')
    for i in range(9):
        a0, a1 = math.pi * i / 9, math.pi * (i + 1) / 9
        vertices = []
        for y in [-0.46,0.46]:
            for r, a in [(0.49,a0),(0.49,a1),(0.30,a1),(0.30,a0)]:
                vertices.append((math.cos(a)*r,y,0.48+math.sin(a)*r))
        faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        mesh = bpy.data.meshes.new('Arch stone')
        mesh.from_pydata(vertices,[],faces)
        mesh.update()
        obj = bpy.data.objects.new('Voussoir_%02d'%i,mesh)
        ACTIVE.objects.link(obj)
        obj.data.materials.append(material('cream' if i % 3 == 0 else 'stone'))
    box('Bridge deck',(0,0,0.96),(1,1,0.08),'plaster',0)


def tree():
    cylinder('Trunk',(0,0,0.46),0.075,0.92,'timber',top=0.043)
    cylinder('Low crown',(0,0,0.93),0.47,0.72,'green_dark',top=0,vertices=7)
    cylinder('Middle crown',(0.025,0,1.25),0.40,0.67,'green',top=0,vertices=7)
    cylinder('High crown',(-0.015,0,1.57),0.27,0.46,'green_light',top=0,vertices=7)


def beacon():
    cylinder('Octagonal base',(0,0,0.07),0.42,0.14,'stone',vertices=12)
    for i in range(5):
        bottom = 0.34 - i*0.018
        cylinder('Lighthouse band_%d'%i,(0,0,0.16+i*0.38+0.19),bottom,0.38,
                 'roof' if i % 2 else 'cream',top=bottom-0.018,vertices=12)
    box('Tower door',(0,-0.343,0.35),(0.18,0.018,0.4),'teal',0)
    for z in [0.95,1.68]:
        box('Tower window',(0,-0.315, z),(0.095,0.03,0.19),'glass',0)
    cylinder('Balcony platform',(0,0,2.13),0.43,0.10,'teal',vertices=12)
    cylinder('Lantern glass',(0,0,2.35),0.24,0.34,'gold',vertices=8)
    for i in range(8):
        angle = i*math.tau/8
        cylinder('Lantern post',(0.25*math.cos(angle),0.25*math.sin(angle),2.35),0.018,0.38,'timber',vertices=5)
    cylinder('Lantern roof',(0,0,2.61),0.39,0.20,'roof',top=0,vertices=8)
    cylinder('Finial',(0,0,2.74),0.028,0.12,'gold',top=0,vertices=6)


def lamp():
    cylinder('Base',(0,0,0.04),0.15,0.08,'stone',vertices=8)
    cylinder('Lamp post',(0,0,0.48),0.041,0.94,'teal',vertices=8)
    box('Lantern body',(0,0,1.015),(0.23,0.23,0.25),'gold',0)
    cylinder('Lantern hat',(0,0,1.195),0.21,0.11,'teal',top=0,vertices=4)
    box('Lantern foot',(0,0,0.88),(0.29,0.29,0.05),'teal',0)
    for x in [-0.11,0.11]:
        for y in [-0.11,0.11]:
            box('Lantern frame',(x,y,1.015),(0.024,0.024,0.26),'timber',0)


def windmill():
    box('Windmill plinth',(0,0,0.07),(0.94,0.88,0.14),'stone')
    box('Windmill walls',(0,0,0.58),(0.70,0.67,1.02),'plaster')
    prism('Windmill roof',0.87,0.85,1.10,1.48,'roof')
    box('Door',(0.14,-0.35,0.34),(0.18,0.03,0.45),'teal',0)
    window(-0.20,-0.35,0.65)
    cylinder('Axle',(0,-0.46,1.26),0.075,0.08,'timber',vertices=10).rotation_euler.x=math.pi/2
    for i in range(4):
        a = math.pi/4 + i*math.pi/2
        x, z = math.sin(a)*0.27,1.26+math.cos(a)*0.27
        box('Sail arm_%d'%i,(x,-0.47,z),(0.08,0.045,0.65),'timber',0,rotation=(0,a,0))
        box('Sail cloth_%d'%i,(math.sin(a)*0.39,-0.50,1.26+math.cos(a)*0.39),
            (0.17,0.026,0.31),'cream',0,rotation=(0,a,0))


def flower():
    box('Planter',(0,0,0.065),(0.85,0.85,0.13),'timber',0.016)
    box('Garden soil',(0,0,0.133),(0.74,0.74,0.018),'soil',0)
    for i in range(9):
        x = (i%3-1)*0.23
        y = (i//3-1)*0.23
        z = 0.23 + (i%2)*0.025
        cylinder('Stem_%d'%i,(x,y,0.195),0.012,0.12,'green_dark',vertices=5)
        ico('Bloom_%d'%i,(x,y,z),(0.083,0.078,0.065),['pink','gold','cream'][i%3])
        ico('Leaf_%d'%i,(x+0.07,y,0.19),(0.095,0.055,0.026),'green')


def bounds_and_triangles(objects):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    points, triangle_count = [], 0
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangle_count += len(mesh.loop_triangles)
        points.extend(obj.matrix_world @ v.co for v in mesh.vertices)
        evaluated.to_mesh_clear()
    low = [min(p[i] for p in points) for i in range(3)]
    high = [max(p[i] for p in points) for i in range(3)]
    return {'blender_min': low, 'blender_max': high,
            'godot_size': [round(high[0]-low[0],4),round(high[2]-low[2],4),round(high[1]-low[1],4)]}, triangle_count


def main():
    global ACTIVE
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    args.output.mkdir(parents=True,exist_ok=True)
    args.source.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system='METRIC'
    bpy.context.scene.unit_settings.scale_length=1.0
    catalog = []
    for index, build in enumerate([cottage,roof,arch,tree,beacon,lamp,windmill,flower]):
        name = build.__name__
        ACTIVE = bpy.data.collections.new('Harbor_'+name)
        bpy.context.scene.collection.children.link(ACTIVE)
        build()
        objects = list(ACTIVE.objects)
        bpy.context.view_layer.update()
        bounds, triangles = bounds_and_triangles(objects)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        path = args.output / (name+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                                  export_yup=True,export_apply=True,export_cameras=False,
                                  export_lights=False,export_animations=False)
        catalog.append({'id':name,'file':path.name,'triangles':triangles,'bounds':bounds,'bytes':path.stat().st_size})
        print('ASSET',name,'triangles=',triangles,'bytes=',path.stat().st_size)
        for obj in objects:
            obj.location += Vector((index%4*2.6,index//4*3.5,0))
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.scene['project']='Mist Harbor / original procedural assets'
    bpy.context.scene['seed']=SEED
    bpy.ops.wm.save_as_mainfile(filepath=str(args.source))
    manifest = {'schema_version':1,'generator':'Blender '+bpy.app.version_string,
                'origin':'Original procedural meshes authored for Mist Harbor; no external game assets',
                'seed':SEED,'license':'CC0-1.0','units':'meters','gltf_up_axis':'Y','assets':catalog}
    (args.output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print('BLENDER_ASSETS_COMPLETE', len(catalog), args.source)


if __name__ == '__main__':
    main()
