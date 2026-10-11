"""Tripo raw GLB -> game asset QA (spec §4, R-ENG-31/37).

Runs in Blender: --background --factory-startup --python tools/art/_tripo_qa.py -- <args>
Steps: import -> ground & centre (origin=footprint centre, base z=0) -> scale to
target height -> decimate to budget -> double-sided -> resize textures -> export.

  --in raw.glb --out out.glb --height 2.2 --faces 5000 --texture 1024 [--yaw-deg 0]
      [--posterize 6]  # 每通道量化级数（low-poly 手绘感，规格 §4 风格锚定）；0=关
"""
import argparse
import bpy
import sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
p = argparse.ArgumentParser()
p.add_argument("--in", dest="src", required=True)
p.add_argument("--out", dest="dst", required=True)
p.add_argument("--height", type=float, required=True, help="target height in metres")
p.add_argument("--faces", type=int, required=True, help="triangle budget")
p.add_argument("--texture", type=int, default=1024)
p.add_argument("--yaw-deg", type=float, default=0.0)
p.add_argument("--posterize", type=int, default=0,
               help="per-channel colour quantisation levels; 0 disables (photoreal)")
args = p.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=args.src)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
assert meshes, "no mesh imported"

# ── 1. 包围盒 → 底面 z=0、水平居中原点 ──
mins = Vector((1e9,) * 3)
maxs = Vector((-1e9,) * 3)
bpy.context.view_layer.update()
for o in meshes:
    for corner in o.bound_box:
        world = o.matrix_world @ Vector(corner)
        mins = Vector(map(min, mins, world))
        maxs = Vector(map(max, maxs, world))
size = maxs - mins
centre = (mins + maxs) / 2.0
roots = [o for o in bpy.context.scene.objects if o.parent is None]
assert roots, "no root object"
root = roots[0]

# ── 2. 落地 + 缩放：世界变换直接烘焙进网格数据 ──
# 🔴 不能用 root.location + transform_apply(meshes)：根节点的位移不会被烘焙进子网格，
# 导出基座仍悬在原偏移（2026-09-28 灯塔"高了/偏了"的共同根因）。
from mathutils import Matrix

scale = args.height / max(size.z, 1e-6)
# 🔴 矩阵序 S·R·T（右往左作用）：先平移落地、再旋转、最后缩放。
# 写成 T·R·S 时平移不被缩放（基座 = -mins.z·scale，悬空 1.3 格——三次复测才抓到）。
bake = (Matrix.Scale(scale, 4)
        @ Matrix.Rotation(args.yaw_deg * 3.14159265 / 180.0, 4, "Z")
        @ Matrix.Translation((-centre.x, -centre.y, -mins.z)))
# 两步直烘焙：① 先把导入变换烘进数据（世界==局部）；② bake 在世界系直接作用。
# 🔴 不能共轭 M⁻¹·b·M：导入旋转 R 使共轭后的平移换轴（z 平移跑到 y），基座悬空。
for o in meshes:
    o.data.transform(o.matrix_world)
    o.matrix_world = Matrix.Identity(4)
for o in bpy.context.scene.objects:
    o.matrix_world = Matrix.Identity(4)
for o in meshes:
    o.data.transform(bake)
bpy.context.view_layer.update()

# ── 3. 减面到预算 ──
# low-poly 管线（2026-09-28 用户反馈"减面后四不像"）：collapse decimate 在高比例下
# 把形碾碎。改为两段：先轻度 decimate 到 ~10 万面，再 **Limited Dissolve** 把共面
# 面片溶成大平面（保形远好于 collapse），重复两轮逼近预算 → 大切面 low-poly 观感。
def tri_count() -> int:
    total = 0
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        for poly in o.data.polygons:
            total += max(len(poly.vertices) - 2, 1)
    return total

current = tri_count()
if current > args.faces * 12:
    dec = meshes[0].modifiers.new("decimate", "DECIMATE")
    dec.ratio = (args.faces * 12) / current
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.modifier_apply(modifier="decimate")
# Limited Dissolve：共面合并（20° 法线容差），迭代直到预算内或收敛
for _round in range(4):
    current = tri_count()
    if current <= args.faces:
        break
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.dissolve_limited(angle_limit=0.35, delimit={"NORMAL"})
    bpy.ops.object.mode_set(mode="OBJECT")
    if tri_count() > current * 0.98:   # 不再收敛 → 上 collapse 补刀
        dec = meshes[0].modifiers.new("decimate", "DECIMATE")
        dec.ratio = args.faces / tri_count()
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.modifier_apply(modifier="decimate")
        break
print(f"QA decimate: {current} -> {tri_count()} tris (budget {args.faces})")

# ── 4. 双面渲染（R-ENG-29）+ 风格：平面着色 + 剥离法线贴图 ──
# 法线贴图携带写实的微观起伏（low-poly 观感的第一杀手），直接断开材质 Normal 输入。
for obj in bpy.context.scene.objects:
    if obj.type == "MESH":
        for poly in obj.data.polygons:
            poly.use_smooth = False
for mat in bpy.data.materials:
    mat.use_backface_culling = False
    if not mat.use_nodes:
        continue
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is not None:
        for link in list(mat.node_tree.links):
            if link.to_node == bsdf and link.to_socket.name in ("Normal",):
                mat.node_tree.links.remove(link)

# ── 5. 贴图降档（R-ENG-31：pck 膨胀防治）+ 色彩量化（low-poly 手绘感）──
for img in bpy.data.images:
    if img.size[0] > args.texture:
        img.scale(args.texture, args.texture)
        print(f"QA texture: {img.name} -> {args.texture}px")
if args.posterize > 0 and bpy.data.images:
    import numpy as np
    levels = float(args.posterize)
    for img in bpy.data.images:
        if img.size[0] == 0 or img.name == "Render Result":
            continue
        arr = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
        arr[:, 0:3] = np.round(arr[:, 0:3] * levels) / levels
        img.pixels = arr.ravel()
        print(f"QA posterize: {img.name} -> {args.posterize} levels/channel")

# ── 7. 灯室测量（灯塔类）：顶部 30% 高度的顶点 XY 质心（相对足迹中心）──
tops = []
top_z = args.height * 0.70
for o in meshes:
    for v in o.data.vertices:
        world = o.matrix_world @ v.co
        if world.z >= top_z:
            tops.append((world.x, world.y))
if len(tops) >= 20:
    lx = sum(t[0] for t in tops) / len(tops)
    ly = sum(t[1] for t in tops) / len(tops)
    print(f"MIST_HARBOR_LANTERN_OFFSET x={lx:.3f} y={ly:.3f} z={args.height * 0.80:.2f} (n={len(tops)})")

# ── 6. 导出（y-up，内嵌贴图）──
bpy.ops.export_scene.gltf(
    filepath=args.dst,
    export_format="GLB", export_yup=True, export_materials="EXPORT",
    export_animations=False, export_cameras=False, export_lights=False)
out = bpy.path.abspath(args.dst)
import os
print(f"MIST_HARBOR_TRIPO_QA_OK {args.dst} {os.path.getsize(bpy.path.abspath(args.dst)) // 1024}KB")
