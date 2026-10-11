class_name HarborTerrainGenerator
extends RefCounted

const VERSION := 1
const MAX_ATTEMPTS := 40
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]

static func generate(seed_value: int, edge: int, geo: Dictionary) -> Dictionary:
	for attempt in range(MAX_ATTEMPTS):
		var candidate_seed := posmod(seed_value + attempt * 104729, 2147483647)
		var columns := _candidate(candidate_seed, edge, geo)
		var metrics := measure(columns, edge)
		var limits: Dictionary = geo.get("land_distribution", {})
		var land_range: Array = limits.get("land_ratio_range", [0.30, 0.50])
		var mud_range: Array = limits.get("mudflat_band_ratio", [0.12, 0.30])
		if metrics.landmasses < int(limits.get("min_landmasses", 2)):
			continue
		if metrics.bay_cells < int(limits.get("min_bay_cells", 8)):
			continue
		if metrics.land_ratio < float(land_range[0]) or metrics.land_ratio > float(land_range[1]):
			continue
		if metrics.mudflat_ratio < float(mud_range[0]) or metrics.mudflat_ratio > float(mud_range[1]):
			continue
		return {"seed": candidate_seed, "columns": columns, "metrics": metrics, "attempts": attempt + 1}
	return {"error": "泉州地形生成未通过形态校验；当前作品未被修改。", "attempts": MAX_ATTEMPTS}

static func _candidate(seed_value: int, edge: int, geo: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var outline: Dictionary = geo.get("island_outline", {})
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = float(outline.get("noise_frequency", 0.12))
	var angle := rng.randf_range(-PI, PI)
	var scale_value := rng.randf_range(0.92, 1.10)
	var shift := Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-1.5, 1.5))
	var bay_shift := rng.randf_range(-2.0, 2.0)
	var island_radius := rng.randf_range(3.0, 4.5)
	var columns: Dictionary = {}
	for x in range(-edge, edge + 1):
		for z in range(-edge, edge + 1):
			var point := (Vector2(x, z).rotated(angle) - shift) / scale_value
			var n := noise.get_noise_2d(x, z)
			var main_distance := Vector2((point.x + 4.0) / 18.0, (point.y - 1.0) / 20.0).length()
			var bay_distance := Vector2((point.x - bay_shift) / 11.5, (point.y + 12.0) / 19.0).length()
			var island_distance := point.distance_to(Vector2(17, 10)) / island_radius
			var islet_distance := point.distance_to(Vector2(14, -14)) / 3.0
			var jitter := float(outline.get("shore_jitter", 0.18)) * n
			var mainland := main_distance < 1.0 + jitter and bay_distance > 1.0 - jitter
			if not mainland and island_distance >= 1.0 + jitter and islet_distance >= 1.0 + jitter:
				continue
			columns[Vector2i(x, z)] = {"height": 1 if n > -0.1 else 0, "kind": "grass"}
	var shore: Dictionary = {}
	for point: Vector2i in columns:
		for direction: Vector2i in DIRECTIONS:
			if not columns.has(point + direction):
				shore[point] = true
				break
	for point: Vector2i in columns:
		if shore.has(point):
			columns[point] = {"height": 0, "kind": "mudflat"}
		elif noise.get_noise_2d(point.x + 100, point.y - 100) > 0.2:
			columns[point] = {"height": 2, "kind": "stone"}
	return columns

static func measure(columns: Dictionary, edge: int) -> Dictionary:
	var remaining := columns.duplicate()
	var masses := 0
	var largest := 0
	while not remaining.is_empty():
		var queue: Array[Vector2i] = [remaining.keys()[0]]
		remaining.erase(queue[0])
		var cursor := 0
		while cursor < queue.size():
			var point := queue[cursor]
			cursor += 1
			for direction: Vector2i in DIRECTIONS:
				var neighbor := point + direction
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					queue.append(neighbor)
		if queue.size() >= 4:
			masses += 1
		largest = maxi(largest, queue.size())
	var bay := 0
	var mudflat := 0
	for point: Vector2i in columns:
		if columns[point].kind == "mudflat":
			mudflat += 1
	for x in range(-edge, edge + 1):
		for z in range(-edge, edge + 1):
			var point := Vector2i(x, z)
			if columns.has(point):
				continue
			var adjacent := 0
			for direction: Vector2i in DIRECTIONS:
				if columns.has(point + direction):
					adjacent += 1
			if adjacent >= 3:
				bay += 1
	return {"landmasses": masses, "largest_landmass": largest, "bay_cells": bay,
		"land_ratio": float(columns.size()) / float((edge * 2 + 1) * (edge * 2 + 1)),
		"mudflat_ratio": float(mudflat) / maxf(1.0, columns.size()), "land_cells": columns.size()}
