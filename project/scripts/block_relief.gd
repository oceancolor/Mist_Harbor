class_name HarborBlockRelief
extends RefCounted

# 立方体「形制化」几何生成器（relief）
#
# 目的：让 cube 不再是「完美立方 + 单一法线 + 单一点色」的塑料方块，
#       而是按 kind 拥有各自的形制（顶面起伏 / 塌边 / 板厚 / 明暗）。
#
# 三条硬约束（改动不得违反）：
#   ① 输出仍进**单个 ArrayMesh**，draw call 数量不变
#   ② **不产生内部缝隙** —— 塌边/起伏只发生在「暴露边」，被 cube 邻居包住的边保持齐平
#   ③ 不参与碰撞（碰撞另行用粗网格，见 build_world.gd），故视觉法线可斜，
#      pick() 行为不受影响
#
# 回源：设计依据见 strategy/geo-meta-and-build-grammar.md §6.1（面数解禁后改守运行时预算）

# palette 未给 relief 字段时的默认形制（= 温和的自然土块）
const DEFAULT_RELIEF := {
	"top_div": 2,       # 顶面细分 N（1 = 不细分，仍是纯平面）
	"top_amp": 0.05,    # 顶面起伏幅度
	"top_slump": 0.10,  # 顶面暴露边的塌落深度
	"thickness": 1.0,   # 实心厚度（<1 = 顶板，自顶面向下延伸，顶面仍与邻居齐平）
	"ao": 0.20,         # 假 AO 强度（按上方邻域遮挡）
	"edge_shade": 0.06, # 顶面靠暴露边的压暗
}

# [方向, origin, u_axis, v_axis] —— 保证 u × v 指向面外，绕序即逆时针
const FACES := [
	[Vector3i(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
	[Vector3i(0, -1, 0), Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3i(1, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3i(-1, 0, 0), Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3i(0, 0, 1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3i(0, 0, -1), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 0, 0)]
]

const RING := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]

var _model: HarborWorldModel
var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _cols := PackedColorArray()
# 全局档位覆盖（由 build_world.gd 设置）：
#   div_cap >= 0 时限制顶面细分上限；div_cap == 0 或 plain 时退回纯立方（回归对照用）
var div_cap: int = -1
var plain: bool = false

func _init(model: HarborWorldModel) -> void:
	_model = model

func vertices() -> PackedVector3Array:
	return _verts

func normals() -> PackedVector3Array:
	return _norms

func colors() -> PackedColorArray:
	return _cols

func face_count() -> int:
	return _verts.size() / 3

static func relief_of(definition: Dictionary) -> Dictionary:
	var result := DEFAULT_RELIEF.duplicate()
	if definition.has("relief"):
		for key in definition["relief"]:
			result[key] = definition["relief"][key]
	return result

# 生成一格的形制几何。颜色由调用方按现有逻辑算好传入，本文件只负责「按面分配 + AO + 起伏压暗」。
func add_block(cell: Vector3i, kind: String, top_color: Color, side_color: Color, bottom_color: Color) -> void:
	var relief := relief_of(_model.definition(kind))
	var div := maxi(1, int(relief.get("top_div", 2)))
	if div_cap >= 0:
		div = mini(div, div_cap)
	if plain or div_cap == 0:
		div = 1
		relief["top_slump"] = 0.0
		relief["top_amp"] = 0.0
		relief["thickness"] = 1.0
		relief["ao"] = 0.0
		relief["edge_shade"] = 0.0
	var thickness := clampf(float(relief.get("thickness", 1.0)), 0.12, 1.0)
	var opened := _open_sides(cell)
	var ao := float(relief.get("ao", 0.20))
	var edge_shade := float(relief.get("edge_shade", 0.06))
	var occlusion := _occlusion(cell)
	var shade_top := top_color * (1.0 - ao * occlusion)
	var base := Vector3(cell)
	for face in FACES:
		var direction: Vector3i = face[0]
		var neighbor := _model.get_cell(cell + direction)
		if not neighbor.is_empty() and _is_cube(str(neighbor.get("kind", ""))):
			continue
		var origin: Vector3 = face[1]
		var u_axis: Vector3 = face[2]
		var v_axis: Vector3 = face[3]
		var is_top := direction == Vector3i.UP
		var is_bottom := direction == Vector3i.DOWN
		# u 轴垂直 => 这是侧面：垂直方向不分段，水平方向取 3 列以匹配顶面边界
		var vertical := absf(u_axis.y) > 0.5
		var nu := 1
		var nv := 1
		if is_top:
			nu = div
			nv = div
		elif vertical:
			nu = 1
			nv = 2
		var points := PackedVector3Array()
		var shades := PackedColorArray()
		for i in range(nv + 1):
			for j in range(nu + 1):
				var point := origin + u_axis * (float(j) / float(nu)) + v_axis * (float(i) / float(nv))
				var tint := side_color
				if is_top:
					var xt := float(i) / float(nv)
					var zt := float(j) / float(nu)
					var edge := _edge_weight(xt, zt, opened)
					point.y = _top_height(cell, xt, zt, relief, opened)
					tint = shade_top * (1.0 - edge_shade * edge)
				elif is_bottom:
					point.y = 1.0 - thickness
					tint = bottom_color
				else:
					var ht := float(i) / float(nv)
					var xt := 1.0 if direction.x > 0 else (0.0 if direction.x < 0 else ht)
					var zt := 1.0 if direction.z > 0 else (0.0 if direction.z < 0 else ht)
					if j == nu:
						point.y = _top_height(cell, xt, zt, relief, opened)
					else:
						point.y = 1.0 - thickness
				points.append(base + point)
				shades.append(tint)
		for i in range(nv):
			for j in range(nu):
				var a := i * (nu + 1) + j
				var b := i * (nu + 1) + j + 1
				var c := (i + 1) * (nu + 1) + j + 1
				var d := (i + 1) * (nu + 1) + j
				_triangle(points[a], points[b], points[c], shades[a], shades[b], shades[c])
				_triangle(points[a], points[c], points[d], shades[a], shades[c], shades[d])

func _triangle(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() > 0.000001:
		normal = normal.normalized()
	else:
		normal = Vector3.UP
	_verts.append(a)
	_verts.append(b)
	_verts.append(c)
	_norms.append(normal)
	_norms.append(normal)
	_norms.append(normal)
	_cols.append(ca)
	_cols.append(cb)
	_cols.append(cc)

# 顶面在某局部位置的高度（相对格底）。
# 两条「不露缝」保证：
#   · 塌落只作用于**暴露边**（被 cube 邻居包住的边保持 1.0，与邻居齐平）
#   · 起伏用**世界坐标的连续噪声**——相邻格在共享边上取到同一个噪声值，
#     若按格子哈希，两侧会算出不同高度而露缝（这是必须避开的坑）
func _top_height(cell: Vector3i, x: float, z: float, relief: Dictionary, opened: Array) -> float:
	var edge := _edge_weight(x, z, opened)
	var inner := 1.0 - clampf(_edge_distance(x, z) * 2.0, 0.0, 1.0)
	var n := _noise2(float(cell.x) + x, float(cell.z) + z)
	var bump := float(relief.get("top_amp", 0.05)) * (n - 0.5) * 2.0 * inner
	return 1.0 - float(relief.get("top_slump", 0.10)) * edge + bump

# 到最近边界的距离（0 = 中心，1 = 边界）——**对称**，保证共享边两侧取到同一值
static func _edge_distance(x: float, z: float) -> float:
	return maxf(absf(x - 0.5), absf(z - 0.5)) * 2.0

# 二维 value noise：平滑插值，输入为**世界坐标**，故跨格连续
static func _noise2(wx: float, wz: float) -> float:
	var x0 := floori(wx)
	var z0 := floori(wz)
	var fx := wx - float(x0)
	var fz := wz - float(z0)
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uz := fz * fz * (3.0 - 2.0 * fz)
	var a := _hash01(x0, z0)
	var b := _hash01(x0 + 1, z0)
	var c := _hash01(x0, z0 + 1)
	var d := _hash01(x0 + 1, z0 + 1)
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uz)

# 距暴露边越近权重越高（角落两方向叠加 => 更深，形成圆润的土堆角）
static func _edge_weight(x: float, z: float, opened: Array) -> float:
	var fx := 0.0
	if opened[0]:
		fx = maxf(fx, (x - 0.5) * 2.0)
	if opened[1]:
		fx = maxf(fx, (0.5 - x) * 2.0)
	var fz := 0.0
	if opened[2]:
		fz = maxf(fz, (z - 0.5) * 2.0)
	if opened[3]:
		fz = maxf(fz, (0.5 - z) * 2.0)
	return clampf(fx + fz, 0.0, 1.3)

# 四个水平方向是否暴露（邻居不是 cube）→ [+X, -X, +Z, -Z]
func _open_sides(cell: Vector3i) -> Array:
	var result := []
	for direction in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var neighbor := _model.get_cell(cell + direction)
		result.append(neighbor.is_empty() or not _is_cube(str(neighbor.get("kind", ""))))
	return result

# 假 AO：上方八邻域被 cube 占得越多，本格顶面越暗（凹地/夹缝自然变暗）
func _occlusion(cell: Vector3i) -> float:
	var blocked := 0
	for offset in RING:
		var neighbor := _model.get_cell(cell + Vector3i(offset.x, 1, offset.y))
		if not neighbor.is_empty() and _is_cube(str(neighbor.get("kind", ""))):
			blocked += 1
	return float(blocked) / float(RING.size())

func _is_cube(kind: String) -> bool:
	return _model.definition(kind).get("mesh") == "cube"

static func _hash01(a: int, b: int) -> float:
	return float(posmod(a * 73856093 + b * 19349663, 65536)) / 65535.0
