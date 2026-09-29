class_name HarborCapeCod
extends HarborLocationMechanic

## Cape Cod —— 动词「照」（水平 · 面）
##
## 唯一机制：光锥覆盖判定（距离 + 高度差 + 一次射线遮挡），**纯数据计算**，
## 不依赖渲染、不依赖真实光源数量——即使零真实 SpotLight3D，玩法依然成立（§2.3 R-1）。
## 光锥一律是假体积光 mesh + A-1 材质族（blend_mix，禁用 additive：密排会叠爆）。
## 「雾 / 秋」是正交天气开关，不占四态昼夜的状态机位。

const COVERAGE_MIN_HEIGHT := -1

var _beam_root: Node3D
var _beams: Array[Node3D] = []
var _beam_time := 0.0
var _heat_root: MultiMeshInstance3D
var _ambient: Node3D
var _ambient_boats: Array[Node3D] = []
var _fishing_boat: Node3D
var _fishing_time := 0.0
var _fishing_phase := 1


func id() -> String:
	return "cape-cod"


func verb() -> String:
	return "照"


# ── 地形：沙丘海角（贯穿东西至地图两端）+ 岬角灯塔台 + 防波堤 + 游艇码头 ──

const HEADLAND := Vector2(30.0, -6.0)   # 东端岬角（灯塔崖台，探出可建造区）

func terrain(with_village: bool) -> void:
	var dunes := FastNoiseLite.new()
	dunes.seed = model.world_seed
	dunes.frequency = 0.16
	var marsh_noise := FastNoiseLite.new()
	marsh_noise.seed = model.world_seed + 91
	marsh_noise.frequency = 0.22
	var bog := Vector2(-8.0, 8.0)
	var limit := model.edge + 8
	for x in range(-limit, limit + 1):
		var point_x := float(x)
		var spine := sin(point_x * 0.12) * 3.0
		# 海角向西收窄为岬角（灯塔崖台），向东是缓坡半岛。
		var taper := 1.0
		if point_x > 22.0:
			taper = maxf(0.35, 1.0 - (point_x - 22.0) * 0.16)
		for z in range(-limit, limit + 1):
			var point := Vector2(point_x, float(z))
			var half_width := (10.0 - maxf(0.0, absf(point_x) - 13.0) * 0.4) * taper \
				+ dunes.get_noise_2d(point_x, float(z)) * 1.8
			var offset_z := float(z) - spine
			if absf(offset_z) > half_width:
				continue
			var height := 1 if dunes.get_noise_2d(point_x * 1.7, float(z) * 1.7) > 0.28 else 0
			if point_x > 26.0:
				height = 2  # 岬角崖台
			var kind := "sand"
			if height == 0 and marsh_noise.get_noise_2d(point_x, float(z)) > 0.14:
				kind = "marsh"
			if height == 2:
				kind = "stone"
			if point.distance_to(bog) < 4.5:
				kind = "cranberry"
				height = 0
			_column(x, z, height, kind)
		# 防波堤：从码头湾口向海延伸的两条石堤。
		if x >= -2 and x <= 8:
			_column(x, roundi(spine) - 4, 0, "stone")
			_column(x, roundi(spine) + 4, 0, "stone")
	# 游艇码头：木栈桥从主街伸进海湾，尽头回转。
	for offset in [Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(6, 3)]:
		_seed(Vector3i(offset.x, -1, offset.y), "wood")
		_seed(Vector3i(offset.x, 0, offset.y), "wood")
	if with_village:
		_seed_village()
		_scatter_flora(dunes)


func _column(x: int, z: int, height: int, top_kind: String) -> void:
	for y in range(-2, height + 1):
		model.set_natural(Vector3i(x, y, z), top_kind if y == height else "stone")


func _seed_village() -> void:
	# 教堂 + 板墙小屋聚落（主街在 x∈[-14, 2]）
	_seed(Vector3i(-12, model.top_y(-12, 2), 2), "church")
	for offset in [Vector2i(-9, 0), Vector2i(-6, 1), Vector2i(-2, 0), Vector2i(0, 1), Vector2i(-4, 2)]:
		_seed(Vector3i(offset.x, model.top_y(offset.x, offset.y), offset.y), "shingle")
	# 两座灯塔：高地灯塔守主湾，小灯塔在东端岬角崖台
	_seed(Vector3i(28, model.top_y(28, -6), -6), "highland")
	_seed(Vector3i(-16, model.top_y(-16, -3), -3), "nauset")
	_seed(Vector3i(-19, model.top_y(-19, -2), -2), "fogstation")
	for offset in [Vector2i(1, 2), Vector2i(3, 1)]:
		_seed(Vector3i(offset.x, model.top_y(offset.x, offset.y), offset.y), "lamp")
	for offset in [Vector2i(-7, 3), Vector2i(-11, -2)]:
		_seed(Vector3i(offset.x, model.top_y(offset.x, offset.y), offset.y), "beachgrass")


func _scatter_flora(dunes: FastNoiseLite) -> void:
	# 海岸松 inland 成带，沙滩草沿丘脊，盐沼边苇草。
	var rng := RandomNumberGenerator.new()
	rng.seed = model.world_seed * 13 + 5
	var limit := model.edge + 4
	for x in range(-limit, limit + 1, 2):
		for z in range(-limit, limit + 1, 2):
			if dunes.get_noise_2d(float(x), float(z)) < -0.05:
				continue
			var top := model.top_y(x, z)
			if top <= -1 or not model.has_cell(Vector3i(x, top - 1, z)):
				continue
			var ground := str(model.get_cell(Vector3i(x, top - 1, z))["kind"])
			var kind := ""
			if ground == "sand" and float(x) < 18.0:
				var roll := rng.randf()
				kind = "pine" if roll < 0.4 else ("beachgrass" if roll < 0.75 else "shrub")
			elif ground == "marsh":
				kind = "reeds" if rng.randf() < 0.5 else "beachgrass"
			if kind.is_empty():
				continue
			model.place_natural(Vector3i(x, top, z), kind, rng.randi_range(0, 3))


func _seed(cell: Vector3i, kind: String) -> void:
	model.place_natural(cell, kind)


# ── 机制：光锥覆盖 ──

func sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell: Vector3i in model.cells:
		var item: Dictionary = model.cells[cell]
		var definition_kind := model.definition(str(item["kind"]))
		var beam: Variant = definition_kind.get("beam", null)
		if beam is Dictionary:
			var spec: Dictionary = beam
			# 有的亮有的不亮，各转各的（速度/相位互异），光束足够长且渐隐不截断。
			result.append({
				"cell": cell,
				"rot": int(item.get("rot", 0)),
				"light_x": float(spec.get("light_x", 0.0)),
				"light_z": float(spec.get("light_z", 0.0)),
				"range": float(spec.get("range", 8.0)),
				"color": HarborLocationProfile.hex(spec.get("color", "EAF2F6")),
				"lit": bool(spec.get("lit", true)),
				"speed": float(spec.get("speed", 0.8)),
				"phase": float(spec.get("phase", 0.0)),
			})
	return result


func sweep_height(cell: Vector3i) -> float:
	## 光束发出点 = palette beam.light_y（灯室实际高度）；未配置时回退到「格顶 +0.2」。
	## AI 灯塔（loc_cc_bld_highland_ai，总高 3.6）灯室在 ~3.1，旧公式给 4.2 → 光束悬空
	## （2026-09-28 用户反馈"灯塔和灯塔光的发出点不吻合"）。
	var beam: Variant = model.definition(str(model.get_cell(cell)["kind"])).get("beam", null)
	if beam is Dictionary and (beam as Dictionary).has("light_y"):
		return float(cell.y) + float((beam as Dictionary)["light_y"])
	return float(cell.y + model.item_height(str(model.get_cell(cell)["kind"]))) + 0.2


func evaluate() -> Dictionary:
	var light_sources := sources()
	var covered := {}
	var targets := _targets()
	for target: Vector3i in targets:
		for source in light_sources:
			var origin: Vector3i = source["cell"]
			var range_value: float = source["range"]
			var a := Vector2(float(origin.x), float(origin.z))
			var b := Vector2(float(target.x), float(target.z))
			if a.distance_to(b) > range_value:
				continue
			if target.y < COVERAGE_MIN_HEIGHT:
				continue
			if sweep_height(origin) - float(target.y) < -1.0:
				continue
			if not _visible(origin, target):
				continue
			covered[Vector2i(target.x, target.z)] = true
			break
	var total := maxi(1, targets.size())
	return {
		"sources": light_sources,
		"covered": covered,
		"coverage": float(covered.size()) / float(total),
		"targets": targets,
	}


func _targets() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for cell: Vector3i in model.cells:
		if cell.y < 0:
			continue
		if model.has_cell(cell + Vector3i.UP):
			continue
		result.append(cell)
	return result


func _visible(origin: Vector3i, target: Vector3i) -> bool:
	## 一次射线遮挡：沿灯顶到目标的连线采样，中间出现高于连线的实心格即被挡。
	var from := Vector3(float(origin.x) + 0.5, sweep_height(origin), float(origin.z) + 0.5)
	var to := Vector3(float(target.x) + 0.5, float(target.y) + 0.5, float(target.z) + 0.5)
	var steps := int(clampi(roundi(from.distance_to(to) * 1.5), 2, 24))
	for i in range(1, steps):
		var point := from.lerp(to, float(i) / float(steps))
		var probe := Vector3i(roundi(point.x), roundi(point.y), roundi(point.z))
		if model.has_cell(probe + Vector3i.UP) and not model.owner_at(probe + Vector3i.UP) == target:
			return false
	return true


func hint_for(kind: String) -> String:
	match kind:
		"highland":
			return "高地灯塔射程十八格，主力补光靠它；塔位决定整条海岸的明暗。"
		"nauset":
			return "小灯塔射程八格，专门补边角的暗角。"
		"fogstation":
			return "雾号站在雾天里光晕加倍。"
		"cranberry":
			return "蔓越莓沼泽秋天会变血红——一年只红一次。"
	return ""


# ── 表现：旋转光束 + 覆盖热力图 ──

func decorate(root: Node3D, state: Dictionary) -> void:
	_fishing_phase = int(state.get("phase", 1))
	if _beam_root == null:
		_beam_root = Node3D.new()
		_beam_root.name = "CapeCodBeams"
		root.add_child(_beam_root)
		# 游艇码头湾的系泊小艇与浮标（栈桥是地形里的木栈道）。
		_ambient = Node3D.new()
		_ambient.name = "CapeCodBoats"
		root.add_child(_ambient)
		for spec in [Vector3(5, 0, 7), Vector3(7, 0, 8), Vector3(3, 0, 8), Vector3(-20, 0, -10)]:
			var boat := HarborAmbientLife.make_boat(Color("f2ede2"), Color("7a8288"))
			boat.position = spec
			boat.rotation.y = float(spec.z) * 0.5
			_ambient.add_child(boat)
			_ambient_boats.append(boat)
		for spec in [Vector3(9, 0, 9), Vector3(1, 0, 9), Vector3(-16, 0, -8)]:
			var buoy := HarborAmbientLife.make_buoy(Color("E8A13C") if int(spec.x) % 2 == 0 else Color("4FB6C9"))
			buoy.position = spec
			_ambient.add_child(buoy)
		# 晨间渔船出海（2026-09-28 用户规格）：一艘拖网渔船向深水缓慢驶出，出画回环。
		_fishing_boat = HarborAmbientLife.make_boat(Color("d8e2e6"), Color("5a6a72"))
		_fishing_boat.position = Vector3(-6, 0, 22)
		_fishing_boat.rotation.y = PI * 0.85
		_ambient.add_child(_fishing_boat)
	if _heat_root == null:
		_heat_root = MultiMeshInstance3D.new()
		_heat_root.name = "CapeCodHeatmap"
		_heat_root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(_heat_root)
	var light_sources: Array = state.get("sources", [])
	for beam in _beams:
		beam.visible = false
	while _beams.size() < light_sources.size():
		var node := _make_beam()
		_beams.append(node)
		_beam_root.add_child(node)
	for i in range(light_sources.size()):
		var source: Dictionary = light_sources[i]
		var node := _beams[i]
		node.visible = bool(source.get("lit", true))
		node.set_meta("speed", float(source.get("speed", 0.8)))
		node.set_meta("phase", float(source.get("phase", 0.0)))
		if not node.visible:
			continue
		var cell: Vector3i = source["cell"]
		# 灯室横偏（light_x/light_z，palette 配置）随建材朝向旋转——
		# 雾号站的灯在支臂上、AI 灯塔的灯室被附属房挤偏，格心不等于灯心。
		var light_off := Vector2(float(source.get("light_x", 0.0)), float(source.get("light_z", 0.0)))
		light_off = light_off.rotated(float(source.get("rot", 0)) * PI / 2.0)
		node.position = Vector3(float(cell.x) + 0.5 + light_off.x, sweep_height(cell),
			float(cell.z) + 0.5 + light_off.y)
		node.set_meta("range", source["range"])
		# 光束要"足够长且逐渐变淡"：长度 ~2.4 倍射程，微张角，端部半径趋零（不截断），
		# 沿长度渐隐由 A-1 贴图负责（近端 0.04 → 中段峰值 → 远端 0）。
		var length := float(source["range"]) * 2.4
		var mesh := CylinderMesh.new()
		mesh.top_radius = length * 0.14
		mesh.bottom_radius = 0.16
		mesh.height = length
		mesh.radial_segments = 8
		mesh.rings = 1
		(node.get_child(0) as MeshInstance3D).mesh = mesh
		(node.get_child(0) as MeshInstance3D).position = Vector3(0, 0, length * 0.5)
		(node.get_child(0) as MeshInstance3D).rotation = Vector3(PI * 0.5, 0, 0)
		(node.get_child(0) as MeshInstance3D).material_override = HarborA1Material.beam(source["color"], 0.13)


func _make_beam() -> Node3D:
	var node := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mesh_instance)
	return node


func set_heatmap_visible(root: Node3D, state: Dictionary, visible: bool) -> void:
	if _heat_root == null:
		return
	if not visible:
		_heat_root.multimesh = null
		return
	var covered: Dictionary = state.get("covered", {})
	var targets: Array = state.get("targets", [])
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = maxi(1, targets.size())
	multimesh.visible_instance_count = targets.size()
	for i in range(targets.size()):
		var cell: Vector3i = targets[i]
		var transform := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)),
			Vector3(float(cell.x) + 0.5, float(cell.y) + 1.02, float(cell.z) + 0.5))
		multimesh.set_instance_transform(i, transform.scaled(Vector3(0.9, 0.9, 1.0)))
		var lit := covered.has(Vector2i(cell.x, cell.z))
		multimesh.set_instance_color(i, Color(0.98, 0.82, 0.45, 0.55) if lit else Color(0.16, 0.24, 0.52, 0.45))
	_heat_root.multimesh = multimesh
	_heat_root.material_override = HarborA1Material.overlay(Color.WHITE, 1.0)


func tick(delta: float) -> void:
	_beam_time += delta
	for beam in _beams:
		if beam.visible:
			# 各灯塔独立旋转：速度/相位来自各自建材表配置，互不同步。
			beam.rotation.y = _beam_time * float(beam.get_meta("speed", 0.8)) + float(beam.get_meta("phase", 0.0))
	for i in range(_ambient_boats.size()):
		var boat := _ambient_boats[i]
		if not boat.has_meta("anchor"):
			boat.set_meta("anchor", boat.position)
		var base: Vector3 = boat.get_meta("anchor")
		HarborAmbientLife.bob(boat, _beam_time, float(i) * 2.1, base.y)
	# 晨间渔船出海：缓慢驶向深水（东北向），出画后从湾内回环（仅晨/昼可见）。
	if _fishing_boat != null:
		_fishing_boat.visible = _fishing_phase <= 1
		if _fishing_boat.visible:
			_fishing_time += delta
			_fishing_boat.position.x += cos(0.45) * delta * 0.8
			_fishing_boat.position.z -= sin(0.45) * delta * 0.8
			if _fishing_boat.position.length() > 42.0:
				_fishing_boat.position = Vector3(-6, 0, 22)
			HarborAmbientLife.bob(_fishing_boat, _fishing_time, 0.0, 0.0)
