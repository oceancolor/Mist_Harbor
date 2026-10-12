extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("FAIL " + message)

func _run() -> void:
	var profile := HarborLocationRegistry.profile("quanzhou")
	check(profile.geo_error().is_empty(), "geo meta validates")
	var start := Time.get_ticks_msec()
	var attempts := 0
	var samples: Array = []
	var sheet := Image.create(1040, 832, false, Image.FORMAT_RGB8)
	sheet.fill(Color("e5e3d5"))
	for seed_value in range(20):
		var result := HarborTerrainGenerator.generate(seed_value * 7919, 25, profile.geo_meta)
		check(not result.has("error"), "terrain seed %d accepted: %s" % [seed_value, str(result.get("error", ""))])
		if result.has("error"):
			continue
		attempts += int(result.attempts)
		var replay := HarborTerrainGenerator.generate(int(result.seed), 25, profile.geo_meta)
		check(replay.get("columns") == result.columns, "accepted seed replays unchanged")
		samples.append({"index": seed_value, "requested_seed": seed_value * 7919, "accepted_seed": result.seed, "attempts": result.attempts, "metrics": result.metrics})
		var offset := Vector2i((seed_value % 5) * 208 + 2, (seed_value / 5) * 208 + 2)
		sheet.fill_rect(Rect2i(offset, Vector2i(204, 204)), Color("35685c"))
		for point: Vector2i in result.columns:
			var kind: String = result.columns[point].kind
			var color := Color("8ab18c") if kind == "grass" else (Color("a4a27b") if kind == "mudflat" else Color("b9bcad"))
			sheet.fill_rect(Rect2i(offset + (point + Vector2i(25, 25)) * 4, Vector2i(4, 4)), color)
		print("TERRAIN_SAMPLE ", seed_value, " ", JSON.stringify(result.metrics), " attempts=", result.attempts)
	var report_dir := ProjectSettings.globalize_path("res://../.codebuddy/artifacts/integration")
	DirAccess.make_dir_recursive_absolute(report_dir)
	sheet.save_png(report_dir.path_join("terrain-20-seeds.png"))
	var file := FileAccess.open(report_dir.path_join("terrain-20-seeds.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples": samples, "mean_attempts": attempts / 20.0, "visual_review": "pending", "thresholds": "engineering_initial_values"}, "  "))
	file.close()
	print("TERRAIN_BATCH seeds=20 attempts=", attempts, " ms=", Time.get_ticks_msec() - start)
	_test_state()
	_test_piece_classes()
	_test_daylight_schedule()
	_test_edge_sink()
	_test_geometry()
	print("INTEGRATION_TEST_RESULT passed=", passed, " failed=", failed)
	quit(1 if failed else 0)

## 人造物（含铺在地上的栈道、陶砖、玻璃）永远不进地形；生物进自然；天然岩土与巨石进地形。
const MAN_MADE := ["wood", "brick", "glass", "lamp", "cottage", "roof", "barrel", "beacon", "windmill",
	"mansion", "oyster", "ridge", "whitehouse", "whitehouse_c", "whitehouse_b", "bluedome", "warmhouse",
	"cavehouse", "medgarden", "creole", "resort", "golf", "highland", "nauset", "fogstation", "shingle",
	"church", "buoy"]
const LIVING := ["tree", "flower", "zayton", "banyan", "shrub", "bougainvillea", "vine", "coco", "palm",
	"reeds", "tortoise", "pine", "beachgrass"]
const NATURAL_GROUND := ["grass", "stone", "mudflat", "sand", "tuff", "blacksand", "marsh", "cranberry",
	"boulder", "boulder_mid", "wedge"]

func _expected_layer(kind: String, location: String) -> String:
	if kind == "arch":
		return "terrain" if location == "seychelles" else "built"
	if kind in MAN_MADE:
		return "built"
	if kind in LIVING:
		return "growth"
	return "terrain" if kind in NATURAL_GROUND else ""

func _test_piece_classes() -> void:
	var sources := {"": "res://data/palette.json"}
	for location in HarborLocationRegistry.ids():
		sources[location] = HarborLocationRegistry.palette_path(location)
	for location: String in sources:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(sources[location]))
		for item: Dictionary in data.get("items", []):
			var layer := str(item.get("layer", ""))
			check(HarborLocationRegistry.CATEGORY_BY_LAYER.get(layer, "") == item.get("category"), "%s:%s declares a matching layer and category" % [sources[location], item.id])
			check(_expected_layer(str(item.id), location) == layer, "%s:%s follows the natural/man-made rule" % [sources[location], item.id])
			if str(item.get("name", "")).contains("石基"):
				check(false, "%s:%s natural rock is not named as a man-made foundation" % [sources[location], item.id])
	for location in HarborLocationRegistry.ids():
		var model := HarborWorldModel.new(location)
		var tabs := {"地形": 0, "建筑": 0, "自然": 0}
		for item: Dictionary in model.palette.values():
			check(item.category == HarborLocationRegistry.CATEGORY_BY_LAYER[item.layer], location + ":" + str(item.id) + " UI class derives from layer")
		for item: Dictionary in model.available_items():
			check(tabs.has(item.category), location + ":" + str(item.id) + " is reachable from a dock tab")
			tabs[item.category] = int(tabs.get(item.category, 0)) + 1
		for tab: String in tabs:
			check(int(tabs[tab]) > 0, location + " offers at least one " + tab + " piece")
		if model.palette.has("wood"):
			check(model.palette.wood.category == "建筑" and model.palette.wood.get("mesh") == "cube", location + " boardwalk is built, still a cube")

## 水光调度：状态导出、逐相位水光量、天体方向（择取 cursor_work 的调度架构，
## 水体与天体渲染仍是主线方案）。
## 边缘径向压低（ltld 的 EDGE_SINK 探索）：只沉自然地形，玩家搭建永不被压低。
func _test_edge_sink() -> void:
	var model := HarborWorldModel.new("quanzhou")
	check(model.reset(240910, true), "edge sink fixture")
	# 只测下沉语义本身：完整 rebuild 需要渲染实例（光斑等），放到场景测试里做。
	var world := HarborBuildWorld.new()
	world.model = model
	var limit := float(model.edge + HarborWorldModel.SCENIC_BAND) - HarborBuildWorld.EDGE_SINK_START
	check(world.edge_sink(Vector3i(0, 0, 0), true) == 0.0, "inland terrain never sinks")
	var outer := Vector3i(int(limit) + 4, 0, 0)
	check(world.edge_sink(outer, true) > 0.5, "natural terrain sinks past the scenic band")
	check(world.edge_sink(outer, false) == 0.0, "player pieces never sink, even at the edge")
	var column_a := world.edge_sink(Vector3i(outer.x, 0, 0), true)
	var column_b := world.edge_sink(Vector3i(outer.x, 3, 0), true)
	check(is_equal_approx(column_a, column_b), "a column sinks as one piece (no cracks)")
	check(world.edge_sink(Vector3i(outer.x + 2, 0, 0), true) >= column_a, "sinking grows towards the world edge")
	# 风景带里的自然地形（岛礁/沙洲）照常下沉；玩家只能在可建造区放置，
	# 那里永不下沉——因此不会出现"自然沉了、玩家没沉"的悬空格。
	check(model.set_natural(Vector3i(int(limit) + 4, 0, 0), "stone"), "scenery can still be written in the scenic band")
	check(world.edge_sink(Vector3i(int(limit) + 4, 0, 0), true) > 0.0, "scenery column at the edge sinks")
	var buildable := Vector3i(model.edge - 1, 0, 0)
	check(model.place(buildable, "stone"), "player builds inside the buildable area")
	check(world.edge_sink(buildable, false) == 0.0, "player terrain inside the bounds never sinks")
	world.free()

func _test_daylight_schedule() -> void:
	var daylight := HarborDaylight.new()
	root.add_child(daylight)
	var location := "quanzhou"
	daylight.setup(HarborLocationRegistry.profile(location))
	for phase_index in range(4):
		daylight.apply_phase(phase_index, false, false)
		var state := daylight.environment_state()
		check(str(state["phase"]) == HarborLocationProfile.PHASE_IDS[phase_index], "%s phase %d export keeps its id" % [location, phase_index])
		for key in ["background", "sky_top", "ambient", "sun", "fog"]:
			check(state[key] is Color, "%s phase %d exports a real %s colour" % [location, phase_index, key])
		check(float(state["fog_density"]) > 0.0 and float(state["ambient_energy"]) > 0.0, "%s phase %d exports fog and ambient energy" % [location, phase_index])
		check(is_equal_approx(float(state["water_light"]), daylight.water_light_for_phase(phase_index)), "%s phase %d water light matches the schedule" % [location, phase_index])
		var expected := daylight.state_for(phase_index, false)["celestial"] as Vector3
		var direction := daylight.celestial_direction(float(daylight.state_for(phase_index, false)["sun_x"]), float(state["sun_rotation_y"]))
		check(expected.is_equal_approx(direction if phase_index != HarborLocationProfile.Phase.NIGHT else daylight.moon_direction(direction)), "%s phase %d celestial direction is derived from elevation and azimuth" % [location, phase_index])
		check(is_equal_approx(expected.length(), 1.0), "%s phase %d celestial direction stays normalized" % [location, phase_index])
		var sky_direction: Vector3 = daylight.sky_material.get_shader_parameter("sun_dir")
		check(sky_direction.is_equal_approx(expected), "%s phase %d sky shader uses the scheduled direction" % [location, phase_index])
	var water_lights := []
	for phase_index in range(4):
		water_lights.append(daylight.water_light_for_phase(phase_index))
	check(water_lights.max() > water_lights.min(), "water light differs between phases")
	daylight.set_sunset_overrides({"sun_x": -6.0, "sun_y": 96.0, "light_color": "ff9d5c"})
	daylight.apply_phase(HarborLocationProfile.Phase.SUNSET, false, false)
	var sunset := daylight.environment_state()
	check(is_equal_approx(float(sunset["sun_rotation_x"]), -6.0), "sunset elevation override reaches the environment state")
	check(str((sunset["sun"] as Color).to_html(false)).to_lower() == "ff9d5c", "sunset colour override reaches the environment state")
	daylight.apply_phase(HarborLocationProfile.Phase.DAY, false, false)
	check(not is_equal_approx(float(daylight.environment_state()["sun_rotation_x"]), -6.0), "sunset override never leaks into other phases")
	daylight.queue_free()

func _test_state() -> void:
	for location in HarborLocationRegistry.ids():
		var model := HarborWorldModel.new(location)
		check(model.reset(240910, true), location + " initializes")
		var restored := HarborWorldModel.new(location)
		check(restored.load_document(model.to_document()), location + " has no overlapping footprints")
		check(restored.to_document() == model.to_document(), location + " roundtrips")
		for entry: Dictionary in model.palette.values():
			check(entry.get("layer") in ["terrain", "growth", "built"], location + " has canonical layers")
	var model := HarborWorldModel.new("quanzhou")
	check(model.reset(1234, false), "terrain model fixture")
	var before := model.to_document()
	var legacy := before.duplicate(true)
	legacy.schema_version = 1
	legacy.erase("location_id")
	legacy.erase("geo_meta_version")
	legacy.erase("generator_version")
	var restored := HarborWorldModel.new("quanzhou")
	check(restored.load_document(legacy), "main v1 save migrates without regeneration")
	check(restored.to_document().cells == before.cells, "legacy cells unchanged")
	check(restored.generator_version == 0, "legacy generator remains unspecified")
	var subset_count := 0
	for ids: Array in model.profile.geo_meta.palette_subset.values():
		subset_count += ids.size()
	check(subset_count > 0 and model.available_items().size() == subset_count, "Quanzhou slice exposes exactly its configured subset")
	check(model.palette.has("tree") and not model.is_available("tree"), "legacy definitions do not leak into available palette")
	check(not model.place(Vector3i(24, 0, 24), "tree"), "subset enforced in model, not only UI")
	var bad := before.duplicate(true)
	bad.schema_version = 1.5
	check(not model.load_document(bad) and model.to_document() == before, "fractional schema rejected atomically")
	bad = before.duplicate(true)
	bad.location_id = "../unknown"
	check(not model.load_document(bad) and model.to_document() == before, "unknown location rejected atomically")
	bad = before.duplicate(true)
	bad.generator_version = "1"
	check(not model.load_document(bad) and model.to_document() == before, "malformed generator version rejected")
	model.profile.geo_meta.rule_overrides["new_rule"] = 1
	check(not model.reset(1) and model.to_document() == before, "unknown override leaves live world untouched")
	model.profile.geo_meta.rule_overrides.erase("new_rule")
	model.profile.geo_meta.land_distribution.min_bay_cells = 999999
	check(not model.reset(1) and model.to_document() == before, "exhausted reseeds fail closed")
	check(model.place(Vector3i(25, 19, 25), "stone") == false, "unsupported top fixture stays invalid")
	model.cells.clear()
	model.occupancy.clear()
	check(model.set_natural(Vector3i(0, 0, 0), "beacon"), "natural multi-cell fixture")
	check(not model.set_natural(Vector3i(0, 1, 0), "stone"), "natural cannot corrupt existing footprint")
	check(not model.in_bounds(Vector3i(0, 20, 0), "stone"), "top bound remains exclusive")
	check(HarborExpansionRules.rotate_horizontal(Vector3i.RIGHT, 1) == Vector3i.FORWARD, "connector rotation agrees with Godot Y axis")
	check(HarborExpansionRules.mask_for(model, Vector3i.ZERO) == 0, "multi-cell object never connects to itself")
	check(model.place(Vector3i(1, 2, 0), "brick"), "neighbor on upper footprint")
	check(HarborExpansionRules.mask_for(model, Vector3i.ZERO) & 1 != 0, "connector sees upper-footprint neighbor")
	check(model.place(Vector3i(5, 0, 5), "zayton"), "place one growth individual")
	var isolated := model.growth_pose(Vector3i(5, 0, 5))
	check(model.place(Vector3i(6, 0, 5), "zayton"), "place adjacent growth individual")
	check(model.growth_pose(Vector3i(5, 0, 5)) != isolated, "neighbors resolve a growth cluster")
	model.undo()
	check(model.growth_pose(Vector3i(5, 0, 5)) == isolated, "undo restores individual appearance, not whole cluster")
	check(not JSON.stringify(model.to_document()).contains("variant"), "derived forms never enter save schema")

func _test_geometry() -> void:
	var model := HarborWorldModel.new("quanzhou")
	model.set_natural(Vector3i.ZERO, "stone")
	model.set_natural(Vector3i.RIGHT, "grass")
	var relief := HarborBlockRelief.new(model)
	var stone := HarborBlockRelief.relief_of(model.definition("stone"))
	var grass := HarborBlockRelief.relief_of(model.definition("grass"))
	for index in range(11):
		var z := index / 10.0
		check(is_equal_approx(relief._top_height(Vector3i.ZERO, 1, z, stone, []), relief._top_height(Vector3i.RIGHT, 0, z, grass, [])), "mixed-material seam matches")
		check(relief.blended_color(Vector3i.ZERO, 1, z, Color.WHITE).is_equal_approx(relief.blended_color(Vector3i.RIGHT, 0, z, Color.WHITE)), "shared terrain colors match")
	model.set_natural(Vector3i(0, 0, 1), "wood")
	relief = HarborBlockRelief.new(model)
	check(is_equal_approx(relief._top_height(Vector3i.ZERO, 0.5, 1, stone, []), 1.0), "built contact plane stays flat")
	for kind in ["stone", "grass", "wood"]:
		var cell := Vector3i.ZERO if kind == "stone" else (Vector3i.RIGHT if kind == "grass" else Vector3i.BACK)
		relief.add_block(cell, kind, Color.WHITE, Color.WHITE, Color.WHITE)
	check(relief.vertices().size() > 0 and relief.vertices().size() % 3 == 0, "relief has triangle geometry")
	for vertex in relief.vertices():
		check(vertex.is_finite(), "relief vertices are finite")
