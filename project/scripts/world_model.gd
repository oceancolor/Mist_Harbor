class_name HarborWorldModel
extends RefCounted

signal changed
signal cells_changed(dirty_cells: Array[Vector3i], full_rebuild: bool)

const SAVE_VERSION := 2
const SAVE_PATH := "user://mist_harbor_world_v1.json"
const SLOT_COUNT := 3
const MAX_CELLS := 12000
const MIN_Y := -4
const MAX_Y := 20
const EDGE := 25
const MAX_HISTORY := 160
const LocationProfile = preload("res://scripts/location_profile.gd")
const ExpansionRules = preload("res://scripts/expansion_rules.gd")

var palette: Dictionary = {}
var locations: Dictionary = {}
var location_id: String = "quanzhou"
var location: HarborLocationProfile
var cells: Dictionary = {}
var occupancy: Dictionary = {}
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var stats: Dictionary = {"rotated": 0, "undone": 0, "saved": 0, "removed": 0}
var world_seed: int = 240910
var current_slot: int = 1
var revision: int = 0
var dirty: bool = false
var last_error: String = ""

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/palette.json"))
	if parsed is Dictionary:
		for item in parsed.get("items", []):
			palette[str(item["id"])] = item
	locations = LocationProfile.load_all()
	location_id = LocationProfile.default_id()
	location = locations.get(location_id, HarborLocationProfile.new())

func set_location(value: String, reset_world: bool = true) -> bool:
	if not locations.has(value):
		last_error = "未知地点：%s" % [value]
		return false
	location_id = value
	location = locations[value]
	if reset_world:
		reset(location.seed, true)
	return true

func location_ids() -> Array:
	return locations.keys()

func build_edge() -> int:
	return location.edge if location != null else EDGE

func build_min_y() -> int:
	return location.min_y if location != null else MIN_Y

func build_max_y() -> int:
	return location.max_y if location != null else MAX_Y

func definition(kind: String) -> Dictionary:
	return palette.get(kind, {})

func available_items(category: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in palette.values():
		var allowed: Array = entry.get("locations", [])
		if not allowed.is_empty() and location_id not in allowed:
			continue
		if not category.is_empty() and str(entry.get("category", "")) != category:
			continue
		result.append(entry)
	return result

func item_height(kind: String) -> int:
	return int(definition(kind).get("height", 1))

func in_bounds(cell: Vector3i, height: int = 1) -> bool:
	return abs(cell.x) <= build_edge() and abs(cell.z) <= build_edge() and cell.y >= build_min_y() and cell.y + height <= build_max_y()

func owner_at(cell: Vector3i) -> Vector3i:
	return occupancy.get(cell, cell)

func has_cell(cell: Vector3i) -> bool:
	return occupancy.has(cell)

func get_cell(cell: Vector3i) -> Dictionary:
	return cells.get(owner_at(cell), {})

func top_y(x: int, z: int) -> int:
	for y in range(build_max_y() - 1, build_min_y() - 1, -1):
		if occupancy.has(Vector3i(x, y, z)):
			return y + 1
	return 0

func can_place(cell: Vector3i, kind: String) -> bool:
	if not palette.has(kind) or cells.size() >= MAX_CELLS:
		return false
	var allowed: Array = definition(kind).get("locations", [])
	if not allowed.is_empty() and location_id not in allowed:
		return false
	var height := item_height(kind)
	if not in_bounds(cell, height):
		return false
	for dy in range(height):
		if occupancy.has(cell + Vector3i(0, dy, 0)):
			return false
	# 水面可直接打地基，空中的新格必须与既有格相接。
	if cell.y <= 0:
		return true
	for direction in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		if occupancy.has(cell + direction):
			if location_id == "seychelles" and kind == "granite" and cell.y > 1:
				return occupancy.has(cell + Vector3i.DOWN)
			return true
	return false

func place(cell: Vector3i, kind: String, rotation: int = 0) -> bool:
	if not can_place(cell, kind):
		return false
	var value := {"kind": kind, "rot": posmod(rotation, 4), "natural": false}
	_record(cell, {}, value)
	if value["rot"] != 0:
		stats["rotated"] += 1
	return true

func erase(cell: Vector3i) -> bool:
	var origin := owner_at(cell)
	if not cells.has(origin):
		return false
	_record(origin, cells[origin].duplicate(), {})
	stats["removed"] += 1
	return true

func _record(cell: Vector3i, before: Dictionary, after: Dictionary) -> void:
	var dirty_cells := ExpansionRules.dirty_neighborhood(cell, maxi(item_height(str(before.get("kind", ""))), item_height(str(after.get("kind", "")))))
	_set_raw(cell, after)
	undo_stack.append({"cell": cell, "before": before, "after": after.duplicate()})
	if undo_stack.size() > MAX_HISTORY:
		undo_stack.pop_front()
	redo_stack.clear()
	_touch(dirty_cells, false)

func _set_raw(cell: Vector3i, value: Dictionary) -> void:
	if cells.has(cell):
		var old_height := item_height(str(cells[cell]["kind"]))
		for dy in range(old_height):
			occupancy.erase(cell + Vector3i(0, dy, 0))
		cells.erase(cell)
	if not value.is_empty():
		cells[cell] = value.duplicate()
		for dy in range(item_height(str(value["kind"]))):
			occupancy[cell + Vector3i(0, dy, 0)] = cell

func _touch(dirty_cells: Array[Vector3i] = [], full_rebuild: bool = true) -> void:
	revision += 1
	dirty = true
	changed.emit()
	cells_changed.emit(dirty_cells, full_rebuild)

func undo() -> bool:
	if undo_stack.is_empty():
		return false
	var command: Dictionary = undo_stack.pop_back()
	_set_raw(command["cell"], command["before"])
	redo_stack.append(command)
	stats["undone"] += 1
	_touch(ExpansionRules.dirty_neighborhood(command["cell"], maxi(item_height(str(command["before"].get("kind", ""))), item_height(str(command["after"].get("kind", ""))))), false)
	return true

func redo() -> bool:
	if redo_stack.is_empty():
		return false
	var command: Dictionary = redo_stack.pop_back()
	_set_raw(command["cell"], command["after"])
	undo_stack.append(command)
	_touch(ExpansionRules.dirty_neighborhood(command["cell"], maxi(item_height(str(command["before"].get("kind", ""))), item_height(str(command["after"].get("kind", ""))))), false)
	return true

func connection_mask(cell: Vector3i) -> int:
	return ExpansionRules.mask_for(self, owner_at(cell))

func connection_variant(cell: Vector3i) -> String:
	return ExpansionRules.variant_for_mask(connection_mask(cell))

func connection_snapshot(cell: Vector3i) -> Dictionary:
	var origin := owner_at(cell)
	var item := get_cell(origin)
	if item.is_empty():
		return {}
	return {
		"cell": origin,
		"kind": str(item.get("kind", "")),
		"mask": connection_mask(origin),
		"variant": connection_variant(origin),
	}

func mechanic_progress() -> Dictionary:
	match location.mechanic if location != null else "":
		"connectivity":
			return _connectivity_progress()
		"cantilever":
			var cantilevers := 0
			for cell: Vector3i in cells:
				if not bool(cells[cell].get("natural", false)) and cell.y > 0 and not occupancy.has(cell + Vector3i.DOWN):
					cantilevers += 1
			return {"kind": "cantilever", "value": cantilevers, "target": 6}
		"stability":
			var stable_stacks := 0
			for cell: Vector3i in cells:
				if str(cells[cell].get("kind", "")) == "granite" and occupancy.has(cell + Vector3i.DOWN):
					stable_stacks += 1
			return {"kind": "stability", "value": stable_stacks, "target": 8}
		"light_network":
			var linked_lights := 0
			for cell: Vector3i in cells:
				if str(definition(str(cells[cell].get("kind", ""))).get("expansion", {}).get("family", "")) == "light_network" and connection_mask(cell) != 0:
					linked_lights += 1
			return {"kind": "light_network", "value": linked_lights, "target": 6}
	return {"kind": "free_build", "value": placed_count(), "target": 12}

func _connectivity_progress() -> Dictionary:
	var candidates: Dictionary = {}
	for cell: Vector3i in cells:
		var family := str(definition(str(cells[cell].get("kind", ""))).get("expansion", {}).get("family", ""))
		if family in ["path", "bridge", "house"] and not bool(cells[cell].get("natural", false)):
			candidates[cell] = true
	if candidates.is_empty():
		return {"kind": "connectivity", "value": 0, "target": 8}
	var frontier: Array[Vector3i] = [candidates.keys()[0]]
	var visited: Dictionary = {}
	while not frontier.is_empty():
		var current: Vector3i = frontier.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		for direction: Vector3i in ExpansionRules.DIRECTIONS:
			var next_cell: Vector3i = current + direction
			if candidates.has(next_cell) and not visited.has(next_cell):
				frontier.append(next_cell)
	return {"kind": "connectivity", "value": visited.size(), "target": 8}

func player_counts() -> Dictionary:
	var result: Dictionary = {}
	for value in cells.values():
		if not value.get("natural", false):
			var kind := str(value["kind"])
			result[kind] = int(result.get(kind, 0)) + 1
	return result

func placed_count() -> int:
	var total: int = 0
	for amount in player_counts().values():
		total += int(amount)
	return total

func reset(seed_value: int = 240910, with_village: bool = true) -> void:
	world_seed = seed_value
	cells.clear()
	occupancy.clear()
	undo_stack.clear()
	redo_stack.clear()
	stats = {"rotated": 0, "undone": 0, "saved": 0, "removed": 0}
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.12
	for x in range(-21, 22):
		for z in range(-20, 22):
			var a := Vector2((x + 4.0) / 11.0, (z + 1.0) / 9.0).length()
			var b := Vector2((x - 12.0) / 5.0, (z - 7.0) / 5.6).length()
			var c := Vector2((x + 12.0) / 4.0, (z + 14.0) / 3.3).length()
			if location_id == "santorini":
				a = Vector2((x + 8.0) / 8.0, z / 14.0).length()
				b = Vector2((x - 3.0) / 5.0, (z - 8.0) / 6.0).length()
				c = 9.0
			elif location_id == "seychelles":
				a = Vector2((x + 7.0) / 7.0, (z + 2.0) / 6.0).length()
				b = Vector2((x - 9.0) / 5.0, (z - 8.0) / 4.0).length()
				c = Vector2((x - 11.0) / 3.5, (z + 10.0) / 3.0).length()
			elif location_id == "cape_cod":
				a = Vector2((x + 2.0) / 17.0, (z + 1.0) / 5.5).length()
				b = Vector2((x - 13.0) / 5.0, (z - 7.0) / 7.0).length()
				c = 9.0
			var distance := minf(a, minf(b, c))
			var n := noise.get_noise_2d(float(x), float(z))
			if distance > 0.95 + n * 0.18:
				continue
			var height: int = 0
			if a < 0.62:
				height = 1
			if a < 0.29:
				height = 2
			if location_id == "santorini":
				height = maxi(0, int((1.0 - a) * 7.0))
			elif location_id in ["seychelles", "cape_cod"]:
				height = 0 if distance > 0.42 else 1
			# Two foundation layers keep silhouettes solid while avoiding thousands
			# of permanently hidden cells on WebGL builds.
			for y in range(-1, height + 1):
				var kind := "stone"
				if y == height:
					if location_id == "santorini":
						kind = "cliff"
					elif location_id == "seychelles":
						kind = "granite" if distance < 0.55 else "sand"
					elif location_id == "cape_cod":
						kind = "grass" if distance < 0.55 else "sand"
					else:
						kind = "grass" if distance < 0.85 else "wood"
				_set_raw(Vector3i(x, y, z), {"kind": kind, "rot": 0, "natural": true})
	if with_village:
		_seed_village()
	_touch([], true)
	dirty = false

func _seed_village() -> void:
	if location_id == "santorini":
		for p in [Vector2i(-8,0), Vector2i(-6,1), Vector2i(-4,2), Vector2i(-2,3), Vector2i(0,4)]:
			_seed_item(p, "white_house", posmod(p.x, 4))
			_seed_at(Vector3i(p.x, top_y(p.x, p.y), p.y), "blue_dome", 0)
		return
	if location_id == "seychelles":
		for p in [Vector2i(-7,-2), Vector2i(-4,1), Vector2i(7,8), Vector2i(10,-9)]:
			_seed_item(p, "palm_cluster", 0)
		return
	if location_id == "cape_cod":
		_seed_item(Vector2i(13, 6), "lighthouse", 0)
		for p in [Vector2i(-8,0), Vector2i(-2,0), Vector2i(4,1), Vector2i(9,3)]:
			_seed_item(p, "light_marker", 0)
		return
	for x in range(-10, 4):
		var floor_cell := Vector3i(x, top_y(x, 0) - 1, 0)
		if cells.has(floor_cell):
			_set_raw(floor_cell, {"kind": "stone", "rot": 0, "natural": true})
	for p in [Vector2i(-7,-1),Vector2i(-5,-2),Vector2i(-3,-1),Vector2i(-1,-2),Vector2i(1,1),Vector2i(-6,2),Vector2i(-9,1),Vector2i(-9,-1),Vector2i(-8,-1),Vector2i(-6,-1),Vector2i(-4,-2),Vector2i(-2,-2),Vector2i(-3,2),Vector2i(-1,2),Vector2i(1,-1),Vector2i(-5,2),Vector2i(-8,2),Vector2i(-4,2)]:
		_seed_item(p, "cottage", posmod(p.x, 4))
	_seed_item(Vector2i(-5, -5), "windmill", 1)
	_seed_item(Vector2i(12, 6), "beacon", 0)
	for p in [Vector2i(-11, -2), Vector2i(-9, -6), Vector2i(-2, -5), Vector2i(1, -3), Vector2i(-7, 5), Vector2i(-10, 3), Vector2i(0, 5), Vector2i(14, 8), Vector2i(11, 9), Vector2i(-12, -14)]:
		_seed_item(p, "tree", 0)
	for p in [Vector2i(-6, 0), Vector2i(-2, 0), Vector2i(3, 1), Vector2i(11, 6)]:
		_seed_item(p, "lamp", 0)
	for p in [Vector2i(-7, -2), Vector2i(-3, -2), Vector2i(-6, 3), Vector2i(-8, 1)]:
		_seed_item(p, "flower", 0)
	for x in range(5, 9):
		_seed_at(Vector3i(x, 0, 4), "wood", 0)
	_seed_at(Vector3i(8, 1, 4), "lamp", 0)

func _seed_item(position: Vector2i, kind: String, rotation: int) -> void:
	_seed_at(Vector3i(position.x, top_y(position.x, position.y), position.y), kind, rotation)

func _seed_at(cell: Vector3i, kind: String, rotation: int) -> void:
	for dy in range(item_height(kind)):
		if has_cell(cell + Vector3i(0, dy, 0)):
			return
	_set_raw(cell, {"kind": kind, "rot": rotation, "natural": true})

func to_document() -> Dictionary:
	var entries: Array = []
	var sorted_cells: Array = cells.keys()
	sorted_cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.x != b.x: return a.x < b.x
		if a.y != b.y: return a.y < b.y
		return a.z < b.z)
	for cell: Vector3i in sorted_cells:
		var value: Dictionary = cells[cell]
		entries.append({"position": [cell.x, cell.y, cell.z], "kind": value["kind"], "rotation": value["rot"], "natural": value.get("natural", false)})
	return {"schema_version": SAVE_VERSION, "game": "mist-harbor", "location_id": location_id, "seed": world_seed, "cells": entries, "stats": stats.duplicate()}

func _integer(value: Variant, low: int, high: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high

func load_document(document: Variant) -> bool:
	last_error = ""
	if not document is Dictionary or document.get("game") != "mist-harbor" or int(document.get("schema_version", 0)) not in [1, SAVE_VERSION]:
		last_error = "不是受支持的雾港存档（需要版本 1 或 2）。"
		return false
	var next_location_id := str(document.get("location_id", "quanzhou"))
	if not locations.has(next_location_id):
		last_error = "存档地点无效。"
		return false
	var next_location: HarborLocationProfile = locations[next_location_id]
	var entries: Variant = document.get("cells")
	if not entries is Array or entries.size() > MAX_CELLS:
		last_error = "存档格子数量超过安全上限。"
		return false
	if not _integer(document.get("seed"), 0, 2147483647):
		last_error = "存档种子无效。"
		return false
	# 全部验证完成后才替换现场，坏存档不能破坏当前作品。
	var next_cells: Dictionary = {}
	var next_occupancy: Dictionary = {}
	for entry in entries:
		if not entry is Dictionary:
			last_error = "格子记录格式错误。"
			return false
		var position: Variant = entry.get("position")
		var kind: String = str(entry.get("kind", ""))
		if not position is Array or position.size() != 3 or not palette.has(kind):
			last_error = "坐标或建材类型无效。"
			return false
		if not _integer(position[0], -next_location.edge, next_location.edge) or not _integer(position[1], next_location.min_y, next_location.max_y) or not _integer(position[2], -next_location.edge, next_location.edge):
			last_error = "坐标超出建造范围。"
			return false
		if not _integer(entry.get("rotation", 0), 0, 3) or typeof(entry.get("natural", false)) != TYPE_BOOL:
			last_error = "旋转或地形标记无效。"
			return false
		var cell := Vector3i(int(position[0]), int(position[1]), int(position[2]))
		if abs(cell.x) > next_location.edge or abs(cell.z) > next_location.edge or cell.y < next_location.min_y or cell.y + item_height(kind) > next_location.max_y:
			last_error = "模型高度超出建造范围。"
			return false
		for dy in range(item_height(kind)):
			var occupied := cell + Vector3i(0, dy, 0)
			if next_occupancy.has(occupied):
				last_error = "存档中存在重叠格子。"
				return false
			next_occupancy[occupied] = cell
		next_cells[cell] = {"kind": kind, "rot": int(entry.get("rotation", 0)), "natural": entry.get("natural", false)}
	var next_stats: Dictionary = {}
	var saved_stats: Variant = document.get("stats", {})
	if not saved_stats is Dictionary:
		last_error = "操作统计格式错误。"
		return false
	for key in ["rotated", "undone", "saved", "removed"]:
		if not _integer(saved_stats.get(key, 0), 0, 10000000):
			last_error = "操作统计超出范围。"
			return false
		next_stats[key] = int(saved_stats.get(key, 0))
	cells = next_cells
	occupancy = next_occupancy
	location_id = next_location_id
	location = next_location
	stats = next_stats
	world_seed = int(document["seed"])
	undo_stack.clear()
	redo_stack.clear()
	_touch([], true)
	dirty = false
	return true

func import_json(text: String) -> bool:
	if text.to_utf8_buffer().size() > 4000000:
		last_error = "存档大于 4 MB，已拒绝。"
		return false
	var parser := JSON.new()
	if parser.parse(text) != OK:
		last_error = "JSON 格式不正确，当前作品未被修改。"
		return false
	return load_document(parser.data)

static func slot_path(index: int, for_location: String = "quanzhou") -> String:
	var safe_location := for_location.validate_filename().to_snake_case()
	return "user://%s_slot_%d.json" % [safe_location, clampi(index, 1, SLOT_COUNT)]

func slot_info(index: int) -> Dictionary:
	var path := slot_path(index, location_id)
	var info := {"slot": index, "exists": false, "cells": 0, "seed": 0, "saved_at": ""}
	if not FileAccess.file_exists(path):
		return info
	info["exists"] = true
	info["saved_at"] = Time.get_datetime_string_from_unix_time(int(FileAccess.get_modified_time(path)), true)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var document := parsed as Dictionary
		info["cells"] = int((document.get("cells", []) as Array).size())
		info["seed"] = int(document.get("seed", 0))
	return info

func save_slot(index: int) -> bool:
	stats["saved"] += 1
	var path := slot_path(index, location_id)
	var output := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if output == null:
		stats["saved"] -= 1
		last_error = "无法写入存档槽 %d，请使用导出 JSON。" % [index]
		return false
	output.store_string(JSON.stringify(to_document()))
	output.flush()
	output.close()
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		stats["saved"] -= 1
		last_error = "保存失败，请导出 JSON 备份。"
		return false
	current_slot = index
	dirty = false
	changed.emit()
	return true

func load_slot(index: int) -> bool:
	var path := slot_path(index, location_id)
	if not FileAccess.file_exists(path):
		last_error = "存档槽 %d 还是空的。" % [index]
		return false
	if not import_json(FileAccess.get_file_as_string(path)):
		return false
	current_slot = index
	return true

func delete_slot(index: int) -> bool:
	var path := slot_path(index, location_id)
	if not FileAccess.file_exists(path):
		return true
	if DirAccess.remove_absolute(path) != OK:
		last_error = "无法删除存档槽 %d。" % [index]
		return false
	return true

func migrate_legacy_save() -> bool:
	"""Keep both historical single-save and pre-location slot files in Quanzhou."""
	if location_id != "quanzhou":
		return false
	var migrated := false
	for index in range(1, SLOT_COUNT + 1):
		var old_slot := "user://slot_%d.json" % [index]
		var new_slot := slot_path(index, location_id)
		if FileAccess.file_exists(old_slot) and not FileAccess.file_exists(new_slot):
			migrated = DirAccess.copy_absolute(old_slot, new_slot) == OK or migrated
	if FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(slot_path(1, location_id)):
		migrated = DirAccess.copy_absolute(SAVE_PATH, slot_path(1, location_id)) == OK or migrated
	return migrated

func save_local() -> bool:
	return save_slot(current_slot)

func load_local() -> bool:
	if load_slot(current_slot):
		return true
	if not FileAccess.file_exists(SAVE_PATH):
		last_error = "还没有本地存档，先保存你的岛屿。"
		return false
	return import_json(FileAccess.get_file_as_string(SAVE_PATH))
