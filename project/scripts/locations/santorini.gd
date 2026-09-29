class_name HarborSantorini
extends HarborLocationMechanic

## 圣托里尼 —— 动词「凿 / 悬挑」（垂直 · 向外）
##
## 唯一机制：悬挑可达性校验（BFS 锚固判定）。从锚固在实心崖体的格子算起，向外最多 3 格。
## 凿崖（Yposkafa）按 lgd §2.2 R-2 留到 1.1；本作只做悬挑一个系统。

const MAX_OVERHANG := 3
const BUTTRESS := "arch"
const STEP := 4


func id() -> String:
	return "santorini"


func verb() -> String:
	return "悬挑"


# ── 地形：月牙形五级台地 + 開放愛琴海 ──
# 参照 Oia 实景（2026-09-26 重建设计）：白色小镇不是"平顶高原 + 一堵崖壁"，
# 而是顺火山口崖层层下降的五级台地；白屋群沿每级崖沿密排，蓝顶教堂守中段、
# 风车守崖顶两端。月牙只保留朝南的弧（圆心在北界外），南面完全开放的海。

const CALDERA := Vector2(0.0, -34.0)

func terrain(with_village: bool) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = model.world_seed
	noise.frequency = 0.1
	# 一直铺到风景带外缘：台地越过可建造区继续延伸，与不可建造区无缝相接。
	var limit := model.edge + HarborWorldModel.SCENIC_BAND
	var levels: Dictionary = {}
	for x in range(-limit, limit + 1):
		for z in range(-limit, limit + 1):
			var point := Vector2(float(x), float(z))
			var distance := point.distance_to(CALDERA)
			var dy := float(z) - CALDERA.y   # 相对湾心的南向分量
			if distance < 13.0 or dy < 1.5:
				continue  # 火山口内湾（海）+ 只留朝南的月牙弧
			var wobble := noise.get_noise_2d(float(x), float(z)) * 0.9
			var d := distance + wobble
			var height := -1
			var kind := "tuff"
			if d <= 17.0:
				height = 12   # 崖顶（风车与最高白屋）
			elif d <= 20.0:
				height = 9
			elif d <= 23.0:
				height = 6
			elif d <= 26.0:
				height = 3
			elif d <= 30.0:
				height = 1    # 崖脚黑砂滩 → 水线
				kind = "blacksand"
			if height < 0:
				continue
			levels[Vector2i(x, z)] = height
			_column(x, z, height, kind, "tuff", -2)
	# 崖沿刷一圈白石基座（Oia 式层叠白城：低角度看每级崖沿是连续的白边，
	# 白屋坐在白边上，裸露红褐只出现在大落差壁面）。
	for key: Vector2i in levels.keys():
		var height := int(levels[key])
		if height < 3:
			continue
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor: Vector2i = key + offset
			if levels.has(neighbor) and int(levels[neighbor]) < height - 1:
				model.set_natural(Vector3i(key.x, height, key.y), "stone")
				break
	# 开放海面上的小离岛与礁石
	var islets := [
		{"c": Vector2(-8, 18), "r": 3.0, "top": "tuff"},
		{"c": Vector2(10, 22), "r": 4.0, "top": "tuff"},
		{"c": Vector2(24, 10), "r": 2.5, "top": "blacksand"},
		{"c": Vector2(-22, 24), "r": 2.0, "top": "tuff"},
	]
	for islet in islets:
		var center: Vector2 = islet["c"]
		var radius := float(islet["r"])
		var top: String = islet["top"]
		for x in range(-limit, limit + 1):
			for z in range(-limit, limit + 1):
				var point := Vector2(float(x), float(z))
				var wobble := noise.get_noise_2d(float(x), float(z)) * 0.6
				var gap := point.distance_to(center) - wobble
				if gap < radius:
					var height := 1 if gap < radius * 0.55 else 0
					_column(x, z, height, top, "tuff", -1)
	if with_village:
		_seed_village(levels)
		_scatter_greens(noise)


func _column(x: int, z: int, height: int, top_kind: String, base_kind: String = "tuff", depth: int = -1) -> void:
	for y in range(depth, height + 1):
		model.set_natural(Vector3i(x, y, z), top_kind if y == height else base_kind)


func _seed_village(levels: Dictionary) -> void:
	## 白屋群沿各级崖沿密排（参考图的核心元素），间或彩色小屋与暖光灯；
	## 蓝顶教堂守每级中段（|x| 最小的崖沿），风车守崖顶两端（Oia 的排布）。
	var rng := RandomNumberGenerator.new()
	rng.seed = model.world_seed * 3 + 7
	# 崖沿格集合（存在低一阶以上的邻居 = 朝海边缘）
	var shores: Dictionary = {}
	for key: Vector2i in levels.keys():
		var height := int(levels[key])
		if height < 3:
			continue
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor: Vector2i = key + offset
			if levels.has(neighbor) and int(levels[neighbor]) < height - 1:
				shores[key] = true
				break
	# 蓝顶教堂：每级中段最靠中的崖沿格（参考图里最显眼的元素）——先放地标，再排屋。
	for target_height in [3, 6, 9, 12]:
		var best_key := Vector2i.ZERO
		var best_d := INF
		for key: Vector2i in shores.keys():
			if int(levels[key]) != target_height:
				continue
			var d := absf(float(key.x))
			if d < best_d:
				best_d = d
				best_key = key
		if best_d < INF:
			_seed(Vector3i(best_key.x, target_height + 1, best_key.y), "bluedome")
	# 风车：崖顶（12）的崖沿，东西两翼各一（找每侧 |x| 最小的崖沿格）
	for side in [1, -1]:
		var best_key := Vector2i.ZERO
		var best_d := INF
		for key: Vector2i in shores.keys():
			if int(levels[key]) != 12 or signf(float(key.x)) != float(side):
				continue
			var d := absf(float(key.x))
			if d >= 10.0 and d < best_d:
				best_d = d
				best_key = key
		if best_d < INF:
			_seed(Vector3i(best_key.x, 13, best_key.y), "windmill")
	# 洞穴屋与花园落在崖脚黑砂滩（从实际地形找支承格，杜绝硬编码悬空）
	for key: Vector2i in levels.keys():
		if int(levels[key]) == 1 and absf(float(key.x) + 10.0) < 2.5:
			_seed(Vector3i(key.x, 2, key.y), "cavehouse")
			break
	for key: Vector2i in levels.keys():
		if int(levels[key]) == 1 and absf(float(key.x) - 14.0) < 2.5:
			_seed(Vector3i(key.x, 2, key.y), "medgarden")
			break
	# 逐格排屋
	for key: Vector2i in levels.keys():
		var height := int(levels[key])
		if height < 1:
			continue
		var top := Vector3i(key.x, height + 1, key.y)   # 台地顶格已被岩块占，放其上一格
		var roll := rng.randf()
		if shores.has(key):
			if roll < 0.62:
				_seed_house(top, rng, key)
			elif roll < 0.70:
				_seed(top, "warmhouse", _shore_rotation(key))
			elif roll < 0.74:
				_seed(top, "lamp")
		elif roll < 0.10:
			_seed_house(top, rng, key)   # 台地内部第二排（层叠感）


func _scatter_greens(noise: FastNoiseLite) -> void:
	# 勒杜鹃/葡萄藤/灌木撒在崖顶与离岛——地中海花园感。
	var rng := RandomNumberGenerator.new()
	rng.seed = model.world_seed * 5 + 11
	var limit := model.edge + 4
	for x in range(-limit, limit + 1, 2):
		for z in range(-limit, limit + 1, 2):
			if noise.get_noise_2d(float(x), float(z)) < 0.02:
				continue
			var top := model.top_y(x, z)
			if top <= 0 or not model.has_cell(Vector3i(x, top - 1, z)):
				continue
			var roll := rng.randf()
			var kind := "bougainvillea" if roll < 0.4 else ("vine" if roll < 0.6 else "shrub")
			model.place_natural(Vector3i(x, top, z), kind, rng.randi_range(0, 3))


func _seed(cell: Vector3i, kind: String, rotation: int = 0) -> void:
	## 物理一致性守卫（2026-09-28 悬空建筑修复）：玩家放置有支承校验，
	## 自然预置路径同样必须有——月牙重建后残留旧坐标曾让 cavehouse 悬空在湾口水面。
	if not model.has_cell(cell + Vector3i.DOWN):
		push_warning("santorini seed skipped (no support): %s @ %s" % [kind, cell])
		return
	model.place_natural(cell, kind, rotation)


# ── 表现：晨间过路船 + 夜间发光浮标（2026-09-28 用户规格）──

var _sea_root: Node3D
var _sea_boats: Array[Node3D] = []
var _sea_buoys: Array[Node3D] = []
var _sea_time := 0.0
var _sea_phase := 1


func decorate(root: Node3D, state: Dictionary) -> void:
	_sea_phase = int(state.get("phase", 1))
	if _sea_root == null:
		_sea_root = Node3D.new()
		_sea_root.name = "SantoriniSea"
		root.add_child(_sea_root)
		var rng := RandomNumberGenerator.new()
		rng.seed = model.world_seed + 31
		# 晨间过路船：湾口横渡的帆船（开湾阔海，月牙外侧）。
		for i in range(2):
			var boat := HarborAmbientLife.make_boat(Color("fdf6e3"), Color("b99a6b"))
			boat.position = Vector3(rng.randf_range(-30, 30), 0.0, float(24 + i * 7))
			boat.rotation.y = -PI / 2.0
			_sea_root.add_child(boat)
			_sea_boats.append(boat)
		# 夜间发光浮标：湾面零星散落（暖黄，夜里是渔火）。
		for i in range(6):
			var buoy := HarborAmbientLife.make_buoy(Color("FFD98A"), 1.8)
			buoy.position = Vector3(rng.randf_range(-34, 34), 0.0, rng.randf_range(6, 34))
			_sea_root.add_child(buoy)
			_sea_buoys.append(buoy)
	var night := _sea_phase == 3
	for boat in _sea_boats:
		boat.visible = _sea_phase <= 1   # 晨/昼有船，日落后回港
	for buoy in _sea_buoys:
		buoy.visible = night


func tick(delta: float) -> void:
	_sea_time += delta
	for i in range(_sea_boats.size()):
		var boat := _sea_boats[i]
		if not boat.visible:
			continue
		# 横渡湾口：匀速向 +X，出画后从另一侧回来。
		boat.position.x += delta * (1.1 + 0.3 * float(i))
		if boat.position.x > 40.0:
			boat.position.x = -40.0
		HarborAmbientLife.bob(boat, _sea_time, float(i) * 2.3, 0.0)
	for i in range(_sea_buoys.size()):
		if _sea_buoys[i].visible:
			HarborAmbientLife.bob(_sea_buoys[i], _sea_time, float(i) * 1.9, 0.0)


## 白屋三变体（方体/拱廊/露台）随机选型；朝向统一朝海（顺崖等高线）——
## R-ENG-38 保留"变体差异"，收回"随机朝向"（崖壁小尺度上读作乱堆，2026-09-29 复验）。
func _seed_house(cell: Vector3i, rng: RandomNumberGenerator, key: Vector2i) -> void:
	var roll := rng.randf()
	var kind := "whitehouse" if roll < 0.5 else ("whitehouse_b" if roll < 0.8 else "whitehouse_c")
	model.place_natural(cell, kind, _shore_rotation(key))


## 朝海朝向：门面统一指向湾心外侧（低一级台地/海）——Oia 参考图里房子全部
## 顺着崖等高线朝海排布。
## 🔴 必须用 posmod：GDScript 的 % 对负数保持负号（-2 % 4 == -2），atan2 出负角
## 时 rot=-2 会写进存档，load_document 校验 0..3 直接拒载（2026-09-29 回归抓到）。
func _shore_rotation(key: Vector2i) -> int:
	var dx := float(key.x) - CALDERA.x
	var dz := float(key.y) - CALDERA.y
	return posmod(int(round(atan2(dx, dz) / (PI * 0.5))), 4)


# ── 机制：悬挑 ──

func overhangs() -> Dictionary:
	## Dijkstra：下方有实心格（或扶壁柱）的格子记 0，水平方向每外扩一格 +1。
	var result := {}
	var queue: Array[Vector3i] = []
	for cell: Vector3i in model.cells:
		if model.has_cell(cell + Vector3i.DOWN) or str(model.cells[cell]["kind"]) == BUTTRESS:
			result[cell] = 0
			queue.append(cell)
	var head := 0
	while head < queue.size():
		var current: Vector3i = queue[head]
		head += 1
		var value: int = result[current]
		for direction in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor: Vector3i = current + direction
			if result.has(neighbor) or not model.has_cell(neighbor):
				continue
			result[neighbor] = value + 1
			queue.append(neighbor)
	return result


func _overhang_at(cell: Vector3i, kind: String) -> int:
	if model.has_cell(cell + Vector3i.DOWN) or kind == BUTTRESS or cell.y <= 0:
		return 0
	var best := MAX_OVERHANG + 1
	for direction in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		var neighbor: Vector3i = cell + direction
		if not model.has_cell(neighbor):
			continue
		if str(model.get_cell(neighbor).get("kind", "tuff")) == BUTTRESS:
			return 1
		var table := overhangs()
		if table.has(neighbor):
			best = mini(best, int(table[neighbor]) + 1)
	return best


func can_place(cell: Vector3i, kind: String, _rotation: int) -> bool:
	return _overhang_at(cell, kind) <= MAX_OVERHANG


func placement_note(_cell: Vector3i, _kind: String, _rotation: int) -> String:
	return "悬挑最多三格：再往外就要先立一根扶壁柱。"


func evaluate() -> Dictionary:
	var table := overhangs()
	var max_value := 0
	var view_cells: Array[Vector3i] = []
	for cell: Vector3i in model.cells:
		if not model.has_cell(cell + Vector3i.UP) and not model.has_cell(cell + Vector3i(0, 0, -1)):
			view_cells.append(cell)
		if table.has(cell):
			max_value = maxi(max_value, int(table[cell]))
	return {"overhangs": table, "max_overhang": max_value, "viewpoints": view_cells}


func hint_for(kind: String) -> String:
	match kind:
		"whitehouse":
			return "白墙屋可以贴着崖壁一层层往上叠；向外悬挑最多三格。"
		"arch":
			return "扶壁柱撑住挑出的平台，想挑得更远就靠它。"
		"bluedome":
			return "蓝顶盖在白墙屋顶上，两格宽。"
		"cavehouse":
			return "洞穴屋嵌进崖壁，洞口留一盏暖光。"
	return ""
