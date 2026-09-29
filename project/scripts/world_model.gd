class_name HarborWorldModel
extends RefCounted

signal changed
signal location_changed(location_id: String)

const SAVE_VERSION := 2
const SAVE_PATH := "user://mist_harbor_world_v1.json"
const SLOT_COUNT := 3
const MAX_CELLS := 16000
const MIN_Y := -4
const MAX_Y := 32
const EDGE := 25
const MAX_HISTORY := 160
const SCENIC_BAND := 10

var palette: Dictionary = {}
var location_id: String = ""
var profile: HarborLocationProfile
var mechanic: HarborLocationMechanic
var min_y: int = -4
var max_y: int = 20
var max_cells: int = 12000
## 可建造半宽（随地点 profile.edge）。风景带可再向外延伸 SCENIC_BAND 格：
## 那里的格子只允许 set_natural 写入，玩家永远触碰不到建造校验。
var edge: int = 25
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

var _mechanic_dirty: bool = true
var _mechanic_state: Dictionary = {}


func _init(location: String = "") -> void:
	set_location(location if not location.is_empty() else HarborLocationRegistry.default_id())


func set_location(location: String) -> void:
	if not HarborLocationRegistry.is_valid(location):
		location = HarborLocationRegistry.default_id()
	location_id = location
	profile = HarborLocationRegistry.profile(location)
	min_y = maxi(MIN_Y, profile.min_y)
	max_y = mini(MAX_Y, profile.max_y)
	max_cells = mini(MAX_CELLS, profile.max_cells)
	edge = maxi(8, profile.edge if profile.edge > 0 else EDGE)
	mechanic = HarborLocationRegistry.mechanic(location)
	mechanic.setup(self, profile)
	_load_palette()
	_mechanic_dirty = true
	location_changed.emit(location_id)


func _load_palette() -> void:
	palette.clear()
	for item in HarborLocationRegistry.palette_items(location_id):
		palette[str(item["id"])] = item


func definition(kind: String) -> Dictionary:
	return palette.get(kind, {})


func item_height(kind: String) -> int:
	return HarborFootprint.size_of(definition(kind)).y


func footprint_cells(cell: Vector3i, kind: String, rotation: int = 0) -> Array[Vector3i]:
	return HarborFootprint.cells_for(cell, definition(kind), rotation)


func in_bounds(cell: Vector3i, kind: String = "", rotation: int = 0) -> bool:
	var parts := [cell] if kind.is_empty() else footprint_cells(cell, kind, rotation)
	for part in parts:
		if absi(part.x) > edge or absi(part.z) > edge or part.y < min_y or part.y > max_y:
			return false
	return true


## 自然地形可写入的软边界：可建造区再向外一圈风景带（无可见的"边界墙"，
## 地形以岛礁/沙洲的形式自然淡出到雾里，玩家在建造中自然触到边界）。
func in_scenic_bounds(cell: Vector3i) -> bool:
	return absi(cell.x) <= edge + SCENIC_BAND and absi(cell.z) <= edge + SCENIC_BAND \
		and cell.y >= MIN_Y and cell.y <= max_y


func owner_at(cell: Vector3i) -> Vector3i:
	return occupancy.get(cell, cell)


func has_cell(cell: Vector3i) -> bool:
	return occupancy.has(cell)


func get_cell(cell: Vector3i) -> Dictionary:
	return cells.get(owner_at(cell), {})


func top_y(x: int, z: int) -> int:
	for y in range(max_y - 1, min_y - 1, -1):
		if occupancy.has(Vector3i(x, y, z)):
			return y + 1
	return 0


func can_place(cell: Vector3i, kind: String, rotation: int = 0) -> bool:
	if not palette.has(kind) or cells.size() >= max_cells:
		return false
	var parts := footprint_cells(cell, kind, rotation)
	if parts.is_empty() or not in_bounds(cell, kind, rotation):
		return false
	for part in parts:
		if occupancy.has(part):
			return false
	if cell.y <= 0:
		return mechanic.can_place(cell, kind, rotation)
	for part in parts:
		for direction in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			if occupancy.has(part + direction):
				return mechanic.can_place(cell, kind, rotation)
	return false


func place(cell: Vector3i, kind: String, rotation: int = 0) -> bool:
	if not can_place(cell, kind, rotation):
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


## 地形与自然预置：直接写入，不进撤销栈，不计入玩家成果。
## 自然地形允许写进风景带（可建造区之外），玩家建造仍受 in_bounds 限制。
func set_natural(cell: Vector3i, kind: String, rotation: int = 0) -> bool:
	if cells.has(cell):
		return false
	if not (in_bounds(cell, kind, rotation) or in_scenic_bounds(cell)):
		return false
	_set_raw(cell, {"kind": kind, "rot": rotation, "natural": true})
	return true


func place_natural(cell: Vector3i, kind: String, rotation: int = 0) -> bool:
	if not palette.has(kind):
		return false
	if not (in_bounds(cell, kind, rotation) or in_scenic_bounds(cell)):
		return false
	for part in footprint_cells(cell, kind, rotation):
		if occupancy.has(part):
			return false
	_set_raw(cell, {"kind": kind, "rot": rotation, "natural": true})
	return true


func _record(cell: Vector3i, before: Dictionary, after: Dictionary) -> void:
	_set_raw(cell, after)
	undo_stack.append({"cell": cell, "before": before, "after": after.duplicate()})
	if undo_stack.size() > MAX_HISTORY:
		undo_stack.pop_front()
	redo_stack.clear()
	_touch()


func _set_raw(cell: Vector3i, value: Dictionary) -> void:
	if cells.has(cell):
		var previous: Dictionary = cells[cell]
		for part in footprint_cells(cell, str(previous["kind"]), int(previous.get("rot", 0))):
			occupancy.erase(part)
		cells.erase(cell)
	if not value.is_empty():
		cells[cell] = value.duplicate()
		for part in footprint_cells(cell, str(value["kind"]), int(value.get("rot", 0))):
			occupancy[part] = cell


func _touch() -> void:
	revision += 1
	dirty = true
	_mechanic_dirty = true
	changed.emit()


func mechanic_state() -> Dictionary:
	if _mechanic_dirty:
		_mechanic_state = mechanic.evaluate()
		_mechanic_dirty = false
	return _mechanic_state


func undo() -> bool:
	if undo_stack.is_empty():
		return false
	var command: Dictionary = undo_stack.pop_back()
	_set_raw(command["cell"], command["before"])
	redo_stack.append(command)
	stats["undone"] += 1
	_touch()
	return true


func redo() -> bool:
	if redo_stack.is_empty():
		return false
	var command: Dictionary = redo_stack.pop_back()
	_set_raw(command["cell"], command["after"])
	undo_stack.append(command)
	_touch()
	return true


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
	mechanic.terrain(with_village)
	_touch()
	dirty = false


func to_document() -> Dictionary:
	var entries: Array = []
	var sorted_cells: Array = cells.keys()
	sorted_cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.x != b.x: return a.x < b.x
		if a.y != b.y: return a.y < b.y
		return a.z < b.z)
	for cell: Vector3i in sorted_cells:
		var value: Dictionary = cells[cell]
		entries.append({
			"position": [cell.x, cell.y, cell.z],
			"kind": value["kind"],
			"rotation": value["rot"],
			"natural": value.get("natural", false),
		})
	return {
		"schema_version": SAVE_VERSION,
		"game": "mist-harbor",
		"location_id": location_id,
		"seed": world_seed,
		"cells": entries,
		"stats": stats.duplicate(),
	}


func _integer(value: Variant, low: int, high: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high


func load_document(document: Variant) -> bool:
	last_error = ""
	if not document is Dictionary or document.get("game") != "mist-harbor":
		last_error = "不是受支持的雾港存档。"
		return false
	if int(document.get("schema_version", 0)) != SAVE_VERSION:
		last_error = "不是受支持的雾港存档（需要版本 %d）。" % [SAVE_VERSION]
		return false
	var saved_location := str(document.get("location_id", location_id))
	if saved_location != location_id:
		last_error = "这是《%s》的存档，无法导入《%s》。" % [
			HarborLocationRegistry.display_name(saved_location),
			HarborLocationRegistry.display_name(location_id),
		]
		return false
	var entries: Variant = document.get("cells")
	if not entries is Array or entries.size() > max_cells:
		last_error = "存档格子数量超过安全上限。"
		return false
	if not _integer(document.get("seed"), 0, 2147483647):
		last_error = "存档种子无效。"
		return false
	var next_cells: Dictionary = {}
	var next_occupancy: Dictionary = {}
	for entry in entries:
		if not entry is Dictionary:
			last_error = "格子记录格式错误。"
			return false
		var position: Variant = entry.get("position")
		var kind: String = str(entry.get("kind", ""))
		var natural := bool(entry.get("natural", false))
		# 自然地形可落在风景带（edge + SCENIC_BAND）；玩家构件只能落在可建造区（edge）。
		var half_width := edge + (SCENIC_BAND if natural else 0)
		if not position is Array or position.size() != 3 or not palette.has(kind):
			last_error = "坐标或建材类型无效。"
			return false
		if not _integer(position[0], -half_width, half_width) or not _integer(position[1], MIN_Y, MAX_Y) or not _integer(position[2], -half_width, half_width):
			last_error = "坐标超出建造范围。"
			return false
		if not _integer(entry.get("rotation", 0), 0, 3) or typeof(entry.get("natural", false)) != TYPE_BOOL:
			last_error = "旋转或地形标记无效。"
			return false
		var cell := Vector3i(int(position[0]), int(position[1]), int(position[2]))
		# 风景带里的自然地形超出可建造区是合法的；玩家构件仍受 in_bounds 限制。
		if not (in_bounds(cell, kind, int(entry.get("rotation", 0))) or (natural and in_scenic_bounds(cell))):
			last_error = "构件超出建造范围。"
			return false
		for part in footprint_cells(cell, kind, int(entry.get("rotation", 0))):
			if next_occupancy.has(part):
				last_error = "存档中存在重叠格子。"
				return false
			next_occupancy[part] = cell
		next_cells[cell] = {
			"kind": kind,
			"rot": int(entry.get("rotation", 0)),
			"natural": entry.get("natural", false),
		}
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
	stats = next_stats
	world_seed = int(document["seed"])
	undo_stack.clear()
	redo_stack.clear()
	_touch()
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


func slot_path(index: int) -> String:
	return "user://slot_%s_%d.json" % [location_id, clampi(index, 1, SLOT_COUNT)]


func slot_info(index: int) -> Dictionary:
	var path := slot_path(index)
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
	var path := slot_path(index)
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
	var path := slot_path(index)
	if not FileAccess.file_exists(path):
		last_error = "存档槽 %d 还是空的。" % [index]
		return false
	if not import_json(FileAccess.get_file_as_string(path)):
		return false
	current_slot = index
	return true


func delete_slot(index: int) -> bool:
	var path := slot_path(index)
	if not FileAccess.file_exists(path):
		return true
	if DirAccess.remove_absolute(path) != OK:
		last_error = "无法删除存档槽 %d。" % [index]
		return false
	return true


func migrate_legacy_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(slot_path(1)):
		return false
	return DirAccess.copy_absolute(SAVE_PATH, slot_path(1)) == OK


func save_local() -> bool:
	return save_slot(current_slot)


func load_local() -> bool:
	if load_slot(current_slot):
		return true
	if not FileAccess.file_exists(SAVE_PATH):
		last_error = "还没有本地存档，先保存你的岛屿。"
		return false
	return import_json(FileAccess.get_file_as_string(SAVE_PATH))
