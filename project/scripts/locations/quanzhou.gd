class_name HarborQuanzhou
extends HarborLocationMechanic

## 泉州·雾港 —— 动词「连」（水平 · 线）
##
## 唯一机制：连通链判定（邻接 + 水面直线可达 BFS）。
## 四环：石构航标塔 →（水面可达）→ 码头栈道 →（相邻）→ 蚵壳厝 →（相邻）→ 红砖古厝聚落。
## 每接通一环开一层「活的」表现，**不显示任何数字、不设产率、不设进度条**。

const LINK_MAX_RANGE := 26.0
const ADJACENT_RANGE := 3

var _prev_links: Array[bool] = [false, false, false]

const NOTICES: Array[String] = [
	"航标与栈道连上了，渔船开始归港。",
	"厝前挂出了渔网与海蛎，白天晾晒，夜里收起。",
	"灯从水边一盏一盏亮进村里。",
]


func id() -> String:
	return "quanzhou"


func verb() -> String:
	return "连"


# ── 地形：开放的多岛礁海湾（回归初代）──
# 玩家主岛居南，泉屿/大坠岛/惠屿散布湾中，水道开阔；岛礁越过可建造边界
# 自然淡出到雾里，没有"边界墙"。

const ISLANDS: Array[Dictionary] = [
	{"c": Vector2(0, 15), "r": 11.5, "top": "grass"},          # 玩家主岛（南，构图主体）
	{"c": Vector2(-22, -13), "r": 5.0, "top": "grass"},        # 泉屿（西北，航标塔）
	{"c": Vector2(20, -14), "r": 6.0, "top": "stone"},         # 大坠岛（东北，石构）
	{"c": Vector2(2, -26), "r": 4.5, "top": "grass"},          # 惠屿（北，远小岛）
	{"c": Vector2(-31, 20), "r": 3.5, "top": "grass"},         # 角礁（西南，风景带）
	{"c": Vector2(32, 22), "r": 3.0, "top": "stone"},          # 角礁（东南，风景带）
	{"c": Vector2(13, -30), "r": 2.5, "top": "grass"},         # 角礁（北东，风景带）
]

func terrain(with_village: bool) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = model.world_seed
	noise.frequency = 0.13
	var limit := model.edge + HarborWorldModel.SCENIC_BAND
	for x in range(-limit, limit + 1):
		for z in range(-limit, limit + 1):
			var point := Vector2(float(x), float(z))
			var wobble := noise.get_noise_2d(float(x), float(z)) * 1.2
			for island in ISLANDS:
				var center: Vector2 = island["c"]
				var radius := float(island["r"])
				var top: String = island["top"]
				var gap := point.distance_to(center) - wobble
				if gap < radius:
					var height := 2 if gap < radius * 0.45 else (1 if gap < radius * 0.78 else 0)
					_column(x, z, height, top, "stone", -1)
					break
	if with_village:
		_seed_village()
		_scatter_groves(noise)


func _column(x: int, z: int, height: int, top_kind: String, base_kind: String = "stone", depth: int = -1) -> void:
	for y in range(depth, height + 1):
		model.set_natural(Vector3i(x, y, z), top_kind if y == height else base_kind)


func _seed_village() -> void:
	# 主岛：栈道下水 + 蚵壳厝 + 红砖古厝聚落（连通链的近端三环）
	_seed(Vector3i(0, model.top_y(0, 5), 5), "wood")
	_seed(Vector3i(1, model.top_y(1, 5), 5), "wood")
	_seed(Vector3i(2, model.top_y(2, 5), 5), "wood")
	_seed(Vector3i(-3, model.top_y(-3, 10), 10), "oyster")
	_seed(Vector3i(3, model.top_y(3, 11), 11), "oyster")
	_seed(Vector3i(0, model.top_y(0, 14), 14), "mansion")
	_seed(Vector3i(5, model.top_y(5, 14), 14), "cottage")
	_seed(Vector3i(-5, model.top_y(-5, 15), 15), "cottage")
	# 灯串：栈道头、两厝之间、村后，夜里把主岛衬亮。
	for offset in [Vector2i(3, 6), Vector2i(0, 8), Vector2i(5, 12), Vector2i(-4, 13), Vector2i(0, 17), Vector2i(-8, 10)]:
		_seed(Vector3i(offset.x, model.top_y(offset.x, offset.y), offset.y), "lamp")
	# 泉屿：石构航标塔（链条起点，隔水相望）+ 屿脚一盏渔灯
	_seed(Vector3i(-22, model.top_y(-22, -13), -13), "beacon")
	_seed(Vector3i(-20, model.top_y(-20, -11), -11), "oyster")
	_seed(Vector3i(-24, model.top_y(-24, -15), -15), "lamp")
	# 大坠岛：红砖聚落 + 石梁引桥
	_seed(Vector3i(20, model.top_y(20, -14), -14), "mansion")
	_seed(Vector3i(18, model.top_y(18, -16), -16), "oyster")
	for offset in [Vector2i(12, -9), Vector2i(11, -8)]:
		_seed(Vector3i(offset.x, model.top_y(offset.x, offset.y) - 1, offset.y), "arch")
	_seed(Vector3i(22, model.top_y(22, -11), -11), "lamp")
	# 惠屿：垂榕
	_seed(Vector3i(2, model.top_y(2, -26), -26), "banyan")


func _scatter_groves(noise: FastNoiseLite) -> void:
	# 刺桐/垂榕/灌木按噪声撒在岛上，密度由噪声决定——自然的聚落感。
	var rng := RandomNumberGenerator.new()
	rng.seed = model.world_seed * 3 + 7
	var limit := model.edge + 4
	for x in range(-limit, limit + 1, 2):
		for z in range(-limit, limit + 1, 2):
			if noise.get_noise_2d(float(x), float(z)) < 0.05:
				continue
			var top := model.top_y(x, z)
			if top <= 0 or not model.has_cell(Vector3i(x, top - 1, z)):
				continue
			var roll := rng.randf()
			var kind := "zayton" if roll < 0.4 else ("banyan" if roll < 0.55 else "shrub")
			model.place_natural(Vector3i(x, top, z), kind, rng.randi_range(0, 3))


func _seed(cell: Vector3i, kind: String) -> void:
	model.place_natural(cell, kind)


# ── 机制：连通链 ──

func evaluate() -> Dictionary:
	var starts := cells_with_role("chain_start")
	var docks := cells_with_role("chain_dock")
	var houses := cells_with_role("chain_house")
	var villages := cells_with_role("chain_village")
	var link_start_dock := _water_reachable(starts, docks)
	var link_dock_house := _adjacent(docks, houses)
	var link_house_village := _adjacent(houses, villages)
	var links: Array[bool] = [link_start_dock, link_dock_house, link_house_village]
	var notice := ""
	for i in range(links.size()):
		if links[i] and not _prev_links[i]:
			notice = NOTICES[i]
	_prev_links = links
	var complete := links[0] and links[1] and links[2]
	var lamp_order := _lamp_order(complete)
	return {
		"links": links,
		"complete": complete,
		"notice": notice,
		"boats": 3 if links[0] else 0,
		"drying": links[1],
		"lights": links[2],
		"lamp_order": lamp_order,
	}


func _water_reachable(from_cells: Array[Vector3i], to_cells: Array[Vector3i]) -> bool:
	## 水面直线可达：两点之间沿水面采样，中间不能有高于水面的实心格。
	for start_cell in from_cells:
		for end_cell in to_cells:
			var a := Vector2(float(start_cell.x), float(start_cell.z))
			var b := Vector2(float(end_cell.x), float(end_cell.z))
			if a.distance_to(b) > LINK_MAX_RANGE:
				continue
			var steps := int(ceili(a.distance_to(b)) * 2.0)
			var blocked := false
			for i in range(1, steps):
				var t := float(i) / float(steps)
				var sample := a.lerp(b, t)
				var cell := Vector3i(roundi(sample.x), 0, roundi(sample.y))
				if model.has_cell(cell) or model.has_cell(cell + Vector3i.UP):
					blocked = true
					break
			if not blocked:
				return true
	return false


func _adjacent(from_cells: Array[Vector3i], to_cells: Array[Vector3i]) -> bool:
	for a in from_cells:
		for b in to_cells:
			var flat := maxi(absi(a.x - b.x), absi(a.z - b.z))
			if flat <= ADJACENT_RANGE and absi(a.y - b.y) <= 2:
				return true
	return false


func _lamp_order(complete: bool) -> Dictionary:
	## 灯火次第亮起：按「离水边的远近」排序，从水边一路亮进内陆。
	var result := {}
	if not complete:
		return result
	var lamps := cells_with_kind("lamp")
	var shore_points := cells_with_role("chain_dock")
	if shore_points.is_empty() or lamps.is_empty():
		return result
	var anchor := Vector2(float(shore_points[0].x), float(shore_points[0].z))
	var ordered: Array[Vector3i] = lamps
	ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return Vector2(float(a.x), float(a.z)).distance_to(anchor) < Vector2(float(b.x), float(b.z)).distance_to(anchor))
	for i in range(ordered.size()):
		result[ordered[i]] = float(i)
	return result


func hint_for(kind: String) -> String:
	match kind:
		"wood":
			return "栈道是水陆接口：把它接到航标塔看得见的水面上。"
		"arch":
			return "石梁跨过水面，把屿和岸连起来——洛阳桥就是这么造的。"
		"beacon":
			return "航标塔是链条的起点，立在湾口或屿上。"
		"oyster":
			return "蚵壳厝挨着栈道建，厝前会挂出渔网。"
		"mansion":
			return "红砖古厝建在蚵壳厝旁边，灯会从这里一路亮进来。"
	return ""


# ── 表现：渔船 ──

var _boats: Array[Node3D] = []
var _boat_time: float = 0.0
var _boat_root: Node3D
var _bird_root: Node3D
var _birds: Array[Node3D] = []
var _bird_phase := 1   # 当前昼夜态（decorate 时写入）


func decorate(root: Node3D, state: Dictionary) -> void:
	if _boat_root == null:
		_boat_root = Node3D.new()
		_boat_root.name = "QuanzhouBoats"
		root.add_child(_boat_root)
		# 常驻湾面的渔船与浮标（不依赖机制进度，水面上一直有生气）。
		for spec in [Vector3(8, 0, 0), Vector3(-10, 0, 2), Vector3(2, 0, -14), Vector3(-6, 0, -18)]:
			var ambient := HarborAmbientLife.make_boat(Color("e8ddc4"), Color("8a6a52"))
			ambient.position = spec
			ambient.rotation.y = float(spec.x) * 0.7
			_boat_root.add_child(ambient)
			_boats.append(ambient)
		for spec in [Vector3(5, 0, -6), Vector3(-14, 0, -2)]:
			var buoy := HarborAmbientLife.make_buoy(Color("C25B4A"))
			buoy.position = spec
			_boat_root.add_child(buoy)
	var wanted := int(state.get("boats", 0)) + 4
	for i in range(_boats.size()):
		_boats[i].visible = i < wanted
	_boat_root.visible = wanted > 0
	# 晨起白鹭 / 夜里鹭鸟剪影（泉州的空气里有鸟，2026-09-28 用户规格）。
	_bird_phase = int(state.get("phase", 1))
	var birds_wanted := 3 if _bird_phase == 0 or _bird_phase == 3 else 0
	if _bird_root == null:
		_bird_root = Node3D.new()
		_bird_root.name = "QuanzhouBirds"
		root.add_child(_bird_root)
		var rng := RandomNumberGenerator.new()
		rng.seed = model.world_seed + 21
		for i in range(3):
			var bird := HarborAmbientLife.make_bird(
				Color("F8F8F4") if i % 2 == 0 else Color("EDEDE6"), 1.6 + rng.randf() * 0.8)
			bird.position = Vector3(rng.randf_range(-30, 30), 8.0 + i * 1.6, rng.randf_range(-20, 20))
			bird.rotation.y = -PI / 2.0   # 头朝 -Z 飞行方向，绕场一圈
			_bird_root.add_child(bird)
			_birds.append(bird)
	_bird_root.visible = birds_wanted > 0
	# 夜态剪影：白鹭变暗色剪影（夜鹭飞过）。
	var bird_color := Color("181820") if _bird_phase == 3 else Color("F6F6F0")
	var bird_mat := StandardMaterial3D.new()
	bird_mat.albedo_color = bird_color
	bird_mat.roughness = 0.9
	for i in range(_birds.size()):
		_birds[i].visible = i < birds_wanted
		_birds[i].scale = Vector3.ONE * (1.0 if _bird_phase == 0 else 1.25)
		for child in _birds[i].get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).material_override = bird_mat
			for grand in (child as Node3D).get_children():
				if grand is MeshInstance3D:
					(grand as MeshInstance3D).material_override = bird_mat


func tick(delta: float) -> void:
	if _boats.is_empty():
		return
	_boat_time += delta
	for i in range(_boats.size()):
		var boat := _boats[i]
		if not boat.visible:
			continue
		# 各船在锚地随波轻摇（不再横穿岛礁）。
		if not boat.has_meta("anchor"):
			boat.set_meta("anchor", boat.position)
		var base: Vector3 = boat.get_meta("anchor")
		HarborAmbientLife.bob(boat, _boat_time, float(i) * 1.7, base.y)
	# 鹭鸟绕场巡飞：匀速圆周 + 高度微起伏 + 扑翼。
	for i in range(_birds.size()):
		var bird := _birds[i]
		if not bird.visible:
			continue
		var angle := _boat_time * (0.10 + 0.02 * float(i)) + float(i) * TAU / 3.0
		var radius := 26.0 + 4.0 * float(i % 2)
		bird.position.x = cos(angle) * radius
		bird.position.z = sin(angle) * radius * 0.7
		bird.position.y = 9.0 + float(i) * 1.4 + sin(_boat_time * 0.7 + float(i)) * 0.8
		bird.rotation.y = -angle - PI / 2.0   # 切向朝前（头 -Z）
		bird.rotation.z = sin(_boat_time * 0.5 + float(i)) * 0.15
		HarborAmbientLife.flap(bird, _boat_time, float(i) * 1.3)


func _make_boat(index: int) -> Node3D:
	return HarborAmbientLife.make_boat()
