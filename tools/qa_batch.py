"""Blender headless QA 批处理（③B 段，tool-connections.md §4）。

单件调用（由 tools/art_from_tripo.py 驱动，不直接手敲）：
    blender --background --factory-startup --python tools/qa_batch.py --
            --input <in.glb> --output <out.glb>
            --footprint 1,1 --height 2 --faces 600 [--flat-color D8D2C4] [--name loc_x]

职责四件 + 本管线特有：
  1. 减面：decimate 到面数预算（比例两轮逼近，超预算即失败退出）
  2. 网格修复：法线重算向外、原点移到底面中心、Y-up 保持
  3. 尺寸归一：统一缩放到足迹格数（X/Z 按较小边），Y 上限 = height + 0.5
  4. 材质整理：剥掉 PBR（金属度 0 / 粗糙度 1 / 断开非 BaseColor 贴图，
     保留 BaseColor 贴图）；--flat-color 时全断开改纯色
  5. 导出 GLB（Y-up、含材质）；打印 MISTHARBOR_QA JSON 结果行（成败/面数/体积/尺寸）

面数预算按 --faces 逐件传入。600 硬顶已解除（2026-09-27 用户裁定：为先保表现力，
面数限制放宽，当前口径 2000）；单件 < 30 KB 为软目标（贴图另算）。
"""
import argparse
import json
import sys

import bpy
# blender --python 脚本内 argparse 需要跳过 Blender 自身参数：sys.argv 里 "--" 之后才是我们的
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--input", required=True)
ap.add_argument("--output", required=True)
ap.add_argument("--footprint", default="1,1", help="足迹格数 x,z")
ap.add_argument("--height", type=float, default=2.0, help="视觉高度上限（格）")
ap.add_argument("--faces", type=int, default=600, help="面数预算（硬顶）")
ap.add_argument("--flat-color", default="", help="可选：整体改纯色（hex，剥所有贴图）")
ap.add_argument("--name", default="", help="输出网格名（如 loc_cc_prop_buoy）")
args = ap.parse_args(argv)

result = {"ok": False, "file": args.output, "name": args.name}


def finish(code: int) -> None:
    print("MISTHARBOR_QA " + json.dumps(result, ensure_ascii=False))
    sys.exit(code)


# ── 1. 干净场景 + 导入 ──
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=args.input)

mesh_objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not mesh_objs:
    result["error"] = "no mesh objects in GLB"
    finish(1)

# 合并成单对象（烘焙世界变换），材质槽保留
if len(mesh_objs) > 1:
    bpy.context.view_layer.objects.active = mesh_objs[0]
    bpy.ops.object.select_all(action="DESELECT")
    for o in mesh_objs:
        o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mesh = obj.data


def tri_count(m) -> int:
    return sum(len(p.vertices) - 2 for p in m.polygons)


# ── 2. 减面：两轮比例逼近 ──
tris = tri_count(mesh)
budget = args.faces
if tris > budget:
    for attempt in range(2):
        ratio = max(0.05, (budget / tris) * (0.95 if attempt == 0 else 0.92))
        mod = obj.modifiers.new("DecimateMist", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        tris = tri_count(mesh)
        if tris <= budget:
            break
if tris > budget:
    result["error"] = f"face budget exceeded: {tris} > {budget}"
    finish(1)

# ── 3. 网格修复：法线向外 + 原点到底面中心 ──
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")

# ── 4. 尺寸归一：X/Y 按较小边缩放到足迹；Z 上限 height + 0.5 ──
# 🔴 Blender 的 glTF 导入器把 Y-up GLB 转回 Blender 的 Z-up：导入后 X/Y 是足迹、
# Z 是高度。旧代码按 Y-up 算（拿 Z 当足迹边、Y 当高度）→ 塔类资产被压成薄饼
# （2026-09-27 航标塔试产暴露）。
fp = [float(v) for v in args.footprint.split(",")]
bb = obj.bound_box
xs = [v[0] for v in bb]; ys = [v[1] for v in bb]; zs = [v[2] for v in bb]
size = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
if size[0] < 1e-6 or size[1] < 1e-6:
    result["error"] = f"degenerate bbox {size}"
    finish(1)
scale = min(fp[0] / size[0], fp[1] / size[1])
if size[2] * scale > args.height + 0.5:
    scale = (args.height + 0.5) / size[2]
obj.scale = (scale, scale, scale)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bb = obj.bound_box
xs = [v[0] for v in bb]; ys = [v[1] for v in bb]; zs = [v[2] for v in bb]
cx = (max(xs) + min(xs)) / 2.0
cy = (max(ys) + min(ys)) / 2.0
obj.location = (-cx, -cy, -min(zs))
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

# ── 5. 材质整理：剥 PBR，保 BaseColor 贴图；--flat-color 时全纯色 ──
flat = args.flat_color.strip().lstrip("#")
for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        continue
    inputs = bsdf.inputs
    for key in ("Metallic",):
        if key in inputs:
            inputs[key].default_value = 0.0
    for key in ("Roughness", "Specular IOR Level", "Specular"):
        if key in inputs and not inputs[key].is_linked:
            inputs[key].default_value = 1.0 if key == "Roughness" else 0.0
    if flat:
        r = int(flat[0:2], 16) / 255.0
        g = int(flat[2:4], 16) / 255.0
        b = int(flat[4:6], 16) / 255.0
        for socket in list(inputs["Base Color"].links):
            mat.node_tree.links.remove(socket)
        inputs["Base Color"].default_value = (r, g, b, 1.0)
        # 断开其它贴图通道（法线/粗糙度等）
        for key in ("Normal", "Roughness", "Metallic", "Emission"):
            if key in inputs:
                for link in list(inputs[key].links):
                    mat.node_tree.links.remove(link)
    else:
        # 保留 BaseColor 贴图，断开其余 PBR 贴图
        for key in ("Normal", "Roughness", "Metallic", "Emission"):
            if key in inputs:
                for link in list(inputs[key].links):
                    mat.node_tree.links.remove(link)
    # 双面材质：AI 生成网格常有局部翻转面（背面剔除下呈三角窟窿，2026-09-27
    # 泉州组用户反馈"屋顶和墙壁有三角形的窟窿"）。glTF doubleSided=true →
    # Godot 导入即 cull_disabled，两面都画，低模场景的过量绘制可忽略。
    mat.use_backface_culling = False

if args.name:
    obj.name = args.name
    mesh.name = args.name

# ── 6. 导出 ──
bpy.ops.export_scene.gltf(
    filepath=args.output,
    export_format="GLB",
    export_yup=True,
    export_apply=False,
    export_materials="EXPORT",
    export_animations=False,
    export_skins=False,
    export_cameras=False,
    export_lights=False,
    export_extras=False,
)

import os
result.update({
    "ok": True,
    "triangles": tri_count(mesh),
    "materials": len(obj.material_slots),
    "size_units": [round(v, 3) for v in (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))],
    "file_kb": round(os.path.getsize(args.output) / 1024.0, 1) if os.path.exists(args.output) else -1,
})
finish(0)
