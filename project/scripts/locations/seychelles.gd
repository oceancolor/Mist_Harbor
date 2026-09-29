class_name HarborSeychelles
extends HarborLocationMechanic

## 塞舌尔 —— 动词「叠」（垂直 · 向上）
##
## 唯一机制：堆叠平衡判定（接触面比 vs 层高阈值）。
## `contact_ratio ≥ T(n)` 为稳，否则缓慢摇晃且**上方不可再叠**（唯一硬限制）。
## 红线：不显示层数、不排名、不设最高纪录（显示即变挑战游戏，P1 崩）。

const STACK_ROLES: Array[String] = ["boulder", "boulder_mid", "creole"]
const STEADY_STACKS_FOR_TURTLE := 2


func id() -> String:
	return "seychelles"


func verb() -> String:
	return "叠"


# ── 地形：花岗岩主岛 + 沙滩梯度入水 + 离岛礁排 ──
# 岛体从花岗岩丘 → 草环 → 白沙 → 浅滩水下一层 → 海，梯度连续无"台地边"。

const ISLET_ARCS: Array[Dictionary] = [
	{"c": Vector2(26, 16), "r": 3.5},
	{"c": Vector2(-28, 20), "r": 3.0},
	{"c": Vector2(6, -28), "r": 4.0},
	{"c": Vector2(36, -26), "r": 2.5},
	{"c": Vector2(-36, -28), "r": 2.5},
	{"c": Vector2(-32, 36), "r": 2.0},
	{"c": Vector2(34, 34), "r": 3.0},
]

func terrain(with_village: bool) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = model.world_seed
	noise.frequency = 0.13
	var limit := model.edge + HarborWorldModel.SCENIC_BAND
	for x in range(-limit, limit + 1):
		for z in range(-limit, limit + 1):
			var point := Vector2(float(x), float(z))
			var distance := point.length()
			var wobble := noise.get_noise_2d(float(x), float(z))
			if distance < 10.0 - wobble * 1.5:
				# 花岗岩丘：两级台地，从水边自然隆起。
				var height := int(clampf(floori((10.0 - distance) * 0.5 + wobble * 1.5), 1.0, 4.0))
				_column(x, z, height, "stone", "stone", -1)
			elif distance < 15.0 + wobble * 2.0:
				_column(x, z, 1, "grass", "sand", 0)
			elif distance < 21.0 + wobble * 2.0:
				_column(x, z, 0, "sand", "stone", 0)
			elif distance < 26.0 + wobble * 2.0:
				# 浅滩泻湖：水下沙层（青绿泻湖大环正落在这里）。
				_column(x, z, -1, "sand", "stone", -1)
	for islet in ISLET_ARCS:
		var center: Vector2 = islet["c"]
		var radius := float(islet["r"])
		for x in range(-limit, limit + 1):
			for z in range(-limit, limit + 1):
				var point := Vector2(float(x), float(z))
				var wobble := noise.get_noise_2d(float(x), float(z)) * 0.8
				var gap := point.distance_to(center) - wobble
				if gap < radius:
					var height := 1 if gap < radius * 0.5 else -1
					_column(x, z, height, "stone" if height == 1 else "sand", "stone", -1)
	if with_village:
		_seed_village()
		_seed_resorts()
	_scatter_boulders(noise)
	_scatter_flora(noise, with_village)


func _column(x: int, z: int, height: int, top_kind: String, base_kind: String = "stone", depth: int = -2) -> void:
	for y in range(depth, height + 1):
		model.set_natural(Vector3i(x, y, z), top_kind if y == height else base_kind)


func _seed_village() -> void:
	# 沙滩上的克里奥尔聚落 + 暖光灯 + 苇草簇。
	_seed(Vector3i(-3, model.top_y(-3, 12), 12), "creole")
	_seed(Vector3i(3, model.top_y(3, 13), 13), "creole")
	_seed(Vector3i(0, model.top_y(0, 15), 15), "creole")
	_seed(Vector3i(7, model.top_y(7, 11), 11), "cottage")
	for offset in [Vector2i(-6, 15), Vector2i(6, 16)]:
		_seed(Vector3i(offset.x, model.top_y(offset.x, offset.y), offset.y), "lamp")
	for offset in [Vector2i(0, 10), Vector2i(-5, 9), Vector2i(5, 8)]:
		_seed(Vector3i(offset.x, model.top_y(offset.x, offset.y), offset.y), "reeds")


func _seed(cell: Vector3i, kind: String) -> void:
	model.place_natural(cell, kind)


## 度假村与高尔夫：主岛东滩一座度假村，东北离岛一座临海度假村，
## 主岛草环上一块三杆洞高尔夫果岭——塞舌尔的人造地标。
func _seed_resorts() -> void:
	_seed(Vector3i(8, model.top_y(8, 14), 14), "resort")
	_seed(Vector3i(26, model.top_y(26, 18), 18), "resort")
	_seed(Vector3i(-6, model.top_y(-6, 10), 10), "golf")


func _scatter_boulders(noise: FastNoiseLite) -> void:
	## 初始地形自带散落巨石：玩家的素材库与天然地基，零门槛起步。
	var rng := RandomNumberGenerator.new()
	rng.seed = model.world_seed * 7 + 13
	var target := 26
	var placed := 0
	var guard := 0
	while placed < target and guard < 600:
		guard += 1
		var x := rng.randi_range(-20, 20)
		var z := rng.randi_range(-20, 20)
		var point := Vector2(float(x), float(z))
		var distance := point.length()
		if distance > 18.0:
			continue
		var y := model.top_y(x, z)
		var big := rng.randf() < 0.35
		if model.place_natural(Vector3i(x, y, z), "boulder" if big else "boulder_mid", rng.randi_range(0, 3)):
			placed += 1


func _scatter_flora(noise: FastNoiseLite, with_village: bool) -> void:
	## 椰子/棕榈/灌木/苇草按噪声与海拔分布：内圈高椰、草环棕榈、滩涂苇草。
	var rng := RandomNumberGenerator.new()
	rng.seed = model.world_seed * 11 + 3
	var limit := model.edge + 4
	for x in range(-limit, limit + 1, 2):
		for z in range(-limit, limit + 1, 2):
			var point := Vector2(float(x), float(z))
			var distance := point.length()
			if noise.get_noise_2d(float(x), float(z)) < -0.1:
				continue
			var top := model.top_y(x, z)
			if top <= -1 or not model.has_cell(Vector3i(x, top - 1, z)):
				continue
			var ground := str(model.get_cell(Vector3i(x, top - 1, z))["kind"])
			var kind := ""
			if ground == "grass":
				var roll := rng.randf()
				kind = "coco" if roll < 0.42 else ("palm" if roll < 0.7 else "shrub")
			elif ground == "sand" and distance < 21.0:
				var roll := rng.randf()
				kind = "reeds" if roll < 0.35 else ("palm" if roll < 0.5 else "coco")
			if kind.is_empty():
				continue
			model.place_natural(Vector3i(x, top, z), kind, rng.randi_range(0, 3))


# ── 机制：稳度 ──

func is_stack(kind: String) -> bool:
	return kind in STACK_ROLES


func stack_layers(cell: Vector3i) -> int:
	## n = 该石下方到最近实心地面的堆叠层数。
	var value := 0
	var probe := cell + Vector3i.DOWN
	while model.has_cell(probe) and value < 32:
		if bool(model.get_cell(probe).get("natural", false)):
			return maxi(1, value)
		value += 1
		probe += Vector3i.DOWN
	return maxi(1, value)


func threshold(layers: int) -> float:
	return minf(0.30 + 0.05 * float(layers), 0.70)


func contact_ratio(cell: Vector3i, kind: String, rotation: int) -> float:
	var definition_kind := model.definition(kind)
	var bottom := HarborFootprint.bottom_cells(cell, definition_kind, rotation)
	if bottom.is_empty():
		return 1.0
	var supported := 0
	for part in bottom:
		if model.has_cell(part + Vector3i.DOWN):
			supported += 1
	return float(supported) / float(bottom.size())


func evaluate() -> Dictionary:
	var steady: Array[Vector3i] = []
	var wobbly: Array[Vector3i] = []
	var stacks: Dictionary = {}
	for cell: Vector3i in model.cells:
		var item: Dictionary = model.cells[cell]
		if bool(item.get("natural", false)):
			continue
		var kind := str(item["kind"])
		if not is_stack(kind):
			continue
		var layers := stack_layers(cell)
		var ratio := contact_ratio(cell, kind, int(item.get("rot", 0)))
		var ok := ratio >= threshold(layers)
		stacks[cell] = {"ratio": ratio, "threshold": threshold(layers), "layers": layers, "steady": ok}
		if ok:
			steady.append(cell)
		else:
			wobbly.append(cell)
	return {
		"steady": steady,
		"wobbly": wobbly,
		"stacks": stacks,
		"steady_stacks": _cluster_count(steady),
		"turtles": mini(3, _cluster_count(steady) / STEADY_STACKS_FOR_TURTLE),
	}


func _cluster_count(cells: Array[Vector3i]) -> int:
	if cells.is_empty():
		return 0
	var seen := {}
	var groups := 0
	for cell in cells:
		if seen.has(cell):
			continue
		groups += 1
		var stack: Array[Vector3i] = [cell]
		while not stack.is_empty():
			var current: Vector3i = stack.pop_back()
			if seen.has(current):
				continue
			seen[current] = true
			for offset in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
				var neighbor: Vector3i = current + offset
				if cells.has(neighbor) and not seen.has(neighbor):
					stack.append(neighbor)
	return groups


func can_place(cell: Vector3i, kind: String, rotation: int) -> bool:
	if not is_stack(kind):
		return true
	var top := HarborFootprint.top_cells(cell, model.definition(kind), rotation)
	for part in top:
		pass
	# 摇石上方不可再叠：支撑格必须是稳的。
	var bottom := HarborFootprint.bottom_cells(cell, model.definition(kind), rotation)
	for part in bottom:
		var under := part + Vector3i.DOWN
		if not model.has_cell(under):
			continue
		var item: Dictionary = model.get_cell(under)
		if bool(item.get("natural", false)):
			continue
		var under_kind := str(item["kind"])
		if not is_stack(under_kind):
			continue
		var layers := stack_layers(model.owner_at(under))
		if contact_ratio(model.owner_at(under), under_kind, int(item.get("rot", 0))) < threshold(layers):
			return false
	return true


func placement_note(_cell: Vector3i, _kind: String, _rotation: int) -> String:
	return "这块石头还没垫稳，先塞一块楔石，再往上叠。"


func hint_for(kind: String) -> String:
	match kind:
		"wedge":
			return "楔石塞进石缝，能让上面的石头站得更稳。"
		"boulder", "boulder_mid":
			return "大石在下、小石在上，越高越要收分；R 键换朝向，重心会变。"
		"creole":
			return "珊瑚石屋要有平的石面才站得住。"
	return ""


# ── 表现：象龟 ──
# 漫游 AI（2026-09-27 B1）：走-歇交替的随机漫步，水线/离锚 5 格即折返。
# 常驻 1 只守在草环（"世界活着"的免费信号），稳石奖励最多再 +3 只。
# 视觉用 GLB（loc_sy_tortoise），proc 几何留作缺资产时的回退。

const TURTLE_GLB := "res://assets/models/loc_sy_tortoise_ai.glb"
const TURTLE_SPEED := 0.22          # 米/秒：象龟的真实爬速，慢到需要驻足才发现它在动
const TURTLE_LEASH := 5.0           # 离锚点的最大游荡半径

var _turtle_root: Node3D
var _turtles: Array[Node3D] = []
var _turtle_time := 0.0
var _turtle_targets: Array[Vector3] = []
var _turtle_rng := RandomNumberGenerator.new()
var _sea_turtles: Array[Node3D] = []     # 晨赴海 / 夜登岸的过路龟（2026-09-28 用户规格）
var _sea_phase := 1
var _ambient: Node3D
var _ambient_boats: Array[Node3D] = []


func _make_turtle() -> Node3D:
	if ResourceLoader.exists(TURTLE_GLB):
		return (load(TURTLE_GLB) as PackedScene).instantiate() as Node3D
	return HarborProcKit.build("tortoise", Color("7A6254"))


func _walkable(x: float, z: float) -> bool:
	## 龟只走在露出水面的实地上（泻湖水下的沙 top_y ≤ 0）。
	var col := Vector2i(floori(x), floori(z))
	var top := model.top_y(col.x, col.y)
	return top >= 1 and model.has_cell(Vector3i(col.x, top - 1, col.y))


## 过路龟径向爬行：晨出海（半径增大，入水后从头再来）；夜登岸（半径减小，抵滩重来）。
## 返回新 (x,z)；Vector2.ZERO 表示本帧不移动。
func _sea_phase_tick(angle: float, index: int, delta: float) -> Vector2:
	var outward := _sea_phase != 3   # 晨=出海 / 夜=登岸
	var next_radius := Vector2(_sea_turtles[index].position.x, _sea_turtles[index].position.z).length() \
		+ (1.0 if outward else -1.0) * TURTLE_SPEED * 0.8 * delta
	if (outward and next_radius > 23.5) or (not outward and next_radius < 20.5):
		next_radius = 20.5 if outward else 23.0
	if not _walkable(cos(angle) * next_radius, sin(angle) * next_radius):
		return Vector2.ZERO
	return Vector2(cos(angle) * next_radius, sin(angle) * next_radius)

func _ground_height(x: float, z: float) -> float:
	## 贴地高度：整数格顶，再按地面种类补偿滩涂压低（与 build_world 视觉一致量级）。
	var col := Vector2i(floori(x), floori(z))
	var top := model.top_y(col.x, col.y)
	var y := float(maxi(top, 1))
	if model.has_cell(Vector3i(col.x, top - 1, col.y)):
		var kind := str(model.get_cell(Vector3i(col.x, top - 1, col.y))["kind"])
		if kind in ["sand", "blacksand"]:
			y -= 0.42
		elif kind in ["marsh", "cranberry", "grass"]:
			y -= 0.2
	return y


func decorate(root: Node3D, state: Dictionary) -> void:
	if _turtle_root == null:
		_turtle_root = Node3D.new()
		_turtle_root.name = "SeychellesTurtles"
		root.add_child(_turtle_root)
		_turtle_rng.seed = model.world_seed * 13 + 1
		# 泻湖里的帆船与浮标（浅水环上，随波轻摇）。
		_ambient = Node3D.new()
		_ambient.name = "SeychellesBoats"
		root.add_child(_ambient)
		for spec in [Vector3(-6, 0, 20), Vector3(9, 0, 17), Vector3(2, 0, -22), Vector3(22, 0, -4)]:
			var boat := HarborAmbientLife.make_boat(Color("fdf6e3"), Color("b99a6b"))
			boat.position = spec
			boat.rotation.y = float(spec.x) * 0.6 + 1.2
			_ambient.add_child(boat)
			_ambient_boats.append(boat)
		for spec in [Vector3(3, 0, 21), Vector3(-14, 0, 12)]:
			var buoy := HarborAmbientLife.make_buoy(Color("4FB6C9"))
			buoy.position = spec
			_ambient.add_child(buoy)
	# 常驻龟锚在草环西侧 + 稳石奖励龟锚在各自石堆旁。
	_turtle_targets = [Vector3(-4.5, 0.0, 10.5)]
	for cell in (state.get("steady", []) as Array).slice(0, 8):
		_turtle_targets.append(Vector3(float((cell as Vector3i).x) + 0.5, 0.0, float((cell as Vector3i).z) + 0.5))
	var wanted := 1 + mini(3, int(state.get("turtles", 0)))
	while _turtles.size() < wanted:
		var turtle := _make_turtle()
		turtle.name = "Turtle%d" % [_turtles.size()]
		_turtles.append(turtle)
		_turtle_root.add_child(turtle)
		var anchor := _turtle_targets[mini(_turtles.size() - 1, _turtle_targets.size() - 1)]
		turtle.position = Vector3(anchor.x + _turtle_rng.randf_range(-0.8, 0.8), 0.0,
			anchor.z + _turtle_rng.randf_range(-0.8, 0.8))
		turtle.position.y = _ground_height(turtle.position.x, turtle.position.z)
		turtle.rotation.y = _turtle_rng.randf() * TAU
		turtle.set_meta("wander", {
			"anchor": Vector2(anchor.x, anchor.z),
			"heading": _turtle_rng.randf() * TAU,
			"timer": _turtle_rng.randf_range(2.0, 6.0),
			"resting": false,
		})
	for i in range(_turtles.size()):
		_turtles[i].visible = i < wanted
	# 过路龟（用户规格：晨起爬向大海 / 夜里从海上爬上沙滩）：沙滩环半径 ~19-23。
	_sea_phase = int(state.get("phase", 1))
	var sea_wanted := 2 if _sea_phase == 0 or _sea_phase == 3 else 0
	while _sea_turtles.size() < sea_wanted:
		var sea_turtle := _make_turtle()
		sea_turtle.scale = Vector3.ONE * 0.8
		_turtle_root.add_child(sea_turtle)
		_sea_turtles.append(sea_turtle)
	for i in range(_sea_turtles.size()):
		var sea_turtle := _sea_turtles[i]
		var angle := float(i) * PI + 0.7
		var start_radius := 23.0 if _sea_phase == 3 else 20.5
		sea_turtle.position = Vector3(cos(angle) * start_radius, 0.0, sin(angle) * start_radius)
		sea_turtle.position.y = _ground_height(sea_turtle.position.x, sea_turtle.position.z)
		sea_turtle.rotation.y = -angle + (PI if _sea_phase == 3 else 0.0)
		sea_turtle.visible = sea_wanted > 0
		sea_turtle.set_meta("sea_angle", angle)


func tick(delta: float) -> void:
	_turtle_time += delta
	for i in range(_ambient_boats.size()):
		var boat := _ambient_boats[i]
		if not boat.has_meta("anchor"):
			boat.set_meta("anchor", boat.position)
		var base: Vector3 = boat.get_meta("anchor")
		HarborAmbientLife.bob(boat, _turtle_time, float(i) * 1.9, base.y)
	for i in range(_sea_turtles.size()):
		var sea_turtle := _sea_turtles[i]
		if not sea_turtle.visible:
			continue
		var next_pos := _sea_phase_tick(float(sea_turtle.get_meta("sea_angle")), i, delta)
		if next_pos != Vector2.ZERO:
			sea_turtle.position.x = next_pos.x
			sea_turtle.position.z = next_pos.y
			sea_turtle.position.y = _ground_height(next_pos.x, next_pos.y)
	for i in range(_turtles.size()):
		var turtle := _turtles[i]
		if not turtle.visible:
			continue
		var w: Dictionary = turtle.get_meta("wander")
		# 走-歇交替：歇 3~8 秒，走 4~10 秒后换向。
		w["timer"] = float(w["timer"]) - delta
		if float(w["timer"]) <= 0.0:
			var resting := not bool(w["resting"]) if _turtle_rng.randf() < 0.55 else bool(w["resting"])
			w["resting"] = resting
			w["timer"] = _turtle_rng.randf_range(3.0, 8.0) if resting else _turtle_rng.randf_range(4.0, 10.0)
			if not resting:
				w["heading"] = _turtle_rng.randf() * TAU
		if not bool(w["resting"]):
			var heading := float(w["heading"])
			var anchor: Vector2 = w["anchor"]
			var pos := Vector2(turtle.position.x, turtle.position.z)
			var next := pos + Vector2(cos(heading), sin(heading)) * TURTLE_SPEED * delta
			# 前方不是实地 / 超出游荡半径 → 折返换向（象龟不会下海）。
			if not _walkable(next.x, next.y) or next.distance_to(anchor) > TURTLE_LEASH:
				w["heading"] = heading + PI + _turtle_rng.randf_range(-0.8, 0.8)
			else:
				turtle.position.x = next.x
				turtle.position.z = next.y
			# 模型头朝 +X：yaw = -heading 才对得上行进方向。
			turtle.rotation.y = lerp_angle(turtle.rotation.y, -heading, minf(delta * 1.2, 1.0))
		# 贴地 + 爬行微起伏。
		turtle.position.y = _ground_height(turtle.position.x, turtle.position.z) \
			+ (0.0 if bool(w["resting"]) else sin(_turtle_time * 3.1 + float(i) * 2.0) * 0.008)
