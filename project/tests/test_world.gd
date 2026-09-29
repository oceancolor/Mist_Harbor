extends SceneTree

const Model = preload("res://scripts/world_model.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)

func _run() -> void:
	var model := Model.new()
	model.reset(240910, false)
	var initial := JSON.stringify(model.to_document())
	var palette_file: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		HarborLocationRegistry.palette_path(model.location_id)))
	var expected_materials := 0
	if palette_file is Dictionary:
		expected_materials = (palette_file as Dictionary).get("items", []).size()
	check(model.palette.size() == expected_materials and expected_materials > 0, "palette matches the location palette")
	check(model.cells.size() > 500 and model.cells.size() < model.max_cells, "bounded real terrain")
	check(model.placed_count() == 0, "natural terrain does not count as learner work")
	var other := Model.new()
	other.reset(240910, false)
	check(JSON.stringify(other.to_document()) == initial, "same seed yields same world")
	other.reset(1234, false)
	check(JSON.stringify(other.to_document()) != initial, "different seed changes world")
	# 泉州主岛在 (0,12) 一带：(0,0,-2) 是开阔水道，离各岛都够远。
	var cell := Vector3i(0,0,-2)
	check(model.place(cell,"wood"), "foundation on sea")
	check(not model.place(cell,"stone"), "overlap rejected")
	check(model.place(cell+Vector3i.UP,"cottage",1), "stack on support")
	check(model.stats["rotated"] == 1, "rotation recorded")
	check(model.placed_count() == 2, "count derives from live world")
	check(model.undo(), "undo succeeds")
	check(not model.has_cell(cell+Vector3i.UP), "undo restores prior cell")
	check(model.redo(), "redo succeeds")
	check(model.get_cell(cell+Vector3i.UP)["rot"] == 1, "redo preserves orientation")
	check(model.erase(cell+Vector3i.UP), "remove piece")
	check(model.undo(), "undo deletion")
	check(model.has_cell(cell+Vector3i.UP), "deletion is reversible")
	check(model.place(Vector3i(0,0,-3),"beacon"), "tall model placed")
	check(model.has_cell(Vector3i(0,2,-3)), "tall model reserves upper cells")
	check(not model.place(Vector3i(0,1,-3),"wood"), "cannot intersect tall model")
	check(model.erase(Vector3i(0,2,-3)), "hit upper footprint removes whole model")
	check(not model.has_cell(Vector3i(0,0,-3)), "all footprint released")
	check(not model.place(Vector3i(80,0,0),"wood"), "world bounds enforced")
	check(not model.place(Vector3i(0,19,0),"beacon"), "height bounds enforced")
	check(not model.place(Vector3i(0,10,-2),"wood"), "unsupported midair cell rejected")
	check(not model.place(Vector3i(0,0,-4),"invalid"), "unknown material rejected")
	_run_multi_cell_checks()
	_run_location_checks()
	var slots := Model.new()
	slots.reset(240910, false)
	check(slots.place(Vector3i(0,0,-6), "cottage"), "slot fixture placed")
	check(slots.save_slot(2), "save slot writes a file")
	check(bool(slots.slot_info(2).get("exists", false)), "slot info reports the saved slot")
	check(int(slots.slot_info(2).get("cells", 0)) == (slots.to_document().get("cells", []) as Array).size(), "slot info reports the piece count")
	check(slots.load_slot(2), "load slot restores the world")
	check(slots.delete_slot(2), "delete slot removes the file")
	check(not bool(slots.slot_info(2).get("exists", true)), "deleted slot reports empty")
	check(slots.slot_path(9) == slots.slot_path(3), "slot index is clamped")
	DirAccess.remove_absolute("user://achievements.json")
	var board := Achievements.new()
	root.add_child(board)
	check(board.entries.size() > 0, "achievements load their definitions")
	var fixture := Model.new()
	fixture.reset(240910, false)
	check(fixture.place(Vector3i(0,0,-6), "cottage"), "achievement fixture placed")
	var fresh: Array = board.evaluate(fixture, {"night_photos": 1})
	check(fresh.size() >= 2, "placing a piece and a night photo unlock achievements")
	check(board.is_unlocked("first_piece"), "first piece achievement recorded")
	check(board.is_unlocked("night_owl"), "night photo achievement reads photo stats")
	check(board.evaluate(fixture, {"night_photos": 1}).is_empty(), "achievements are reported only once")
	var snapshot := model.to_document()
	check(other.import_json(JSON.stringify(snapshot)), "JSON save/load roundtrip")
	check(JSON.stringify(other.to_document()) == JSON.stringify(snapshot), "roundtrip preserves all cells and stats")
	check(int(snapshot.get("schema_version", 0)) == Model.SAVE_VERSION, "save carries the schema version")
	check(str(snapshot.get("location_id", "")) == model.location_id, "save carries the location id")
	var foreign: Dictionary = snapshot.duplicate(true)
	foreign["location_id"] = "cape-cod"
	check(not other.load_document(foreign), "save from another location is rejected")
	check(other.last_error.find("无法导入") >= 0, "cross-location import explains itself")
	var before := JSON.stringify(other.to_document())
	var invalid: Dictionary = snapshot.duplicate(true)
	invalid["schema_version"] = 900
	check(not other.load_document(invalid), "future save version rejected")
	check(JSON.stringify(other.to_document()) == before, "failed load is atomic")
	invalid = snapshot.duplicate(true)
	invalid["cells"][0]["kind"] = "script://evil"
	check(not other.load_document(invalid), "foreign asset type rejected")
	invalid = snapshot.duplicate(true)
	invalid["cells"][0]["position"] = [1000000,0,0]
	check(not other.load_document(invalid), "out of bounds save rejected")
	invalid = snapshot.duplicate(true)
	invalid["cells"][0]["position"] = [0.5,0,0]
	check(not other.load_document(invalid), "fractional grid coordinate rejected")
	invalid = snapshot.duplicate(true)
	invalid["cells"].append(invalid["cells"][0].duplicate(true))
	check(not other.load_document(invalid), "overlapping save entries rejected")
	invalid = snapshot.duplicate(true)
	invalid["stats"] = {"saved": -1}
	check(not other.load_document(invalid), "negative metrics rejected")
	check(not other.import_json("{broken"), "malformed JSON rejected")
	check(not other.import_json(" ".repeat(4000001)), "oversize save rejected")
	check(JSON.stringify(other.to_document()) == before, "all rejected saves preserve live state")
	model.undo()
	check(model.redo_stack.size() > 0, "redo branch present")
	model.place(Vector3i(0,0,-5),"stone")
	check(model.redo_stack.is_empty(), "new command discards redo branch")
	var village := Model.new()
	village.reset(240910, true)
	check(village.placed_count() == 0, "starter scenery not credited as learner construction")
	check(other.load_document(village.to_document()), "starter world has no overlapping footprints")
	print("WORLD_TEST_RESULT passed=", passed, " failed=", failed)
	quit(1 if failed else 0)


func _run_multi_cell_checks() -> void:
	## M0：多格构件由 core 统一处理，四地复用同一套占位 / 碰撞 / 撤销逻辑。
	var model := Model.new("quanzhou")
	model.reset(240910, false)
	var origin := Vector3i(0, 0, -2)
	check(model.place(origin, "oyster"), "2x2x2 footprint placed")
	for part in model.footprint_cells(origin, "oyster", 0):
		check(model.owner_at(part) == origin, "footprint cells map back to the origin")
	check(model.footprint_cells(origin, "oyster", 0).size() == 8, "2x2x2 reserves eight cells")
	check(not model.place(origin + Vector3i(1, 0, 1), "brick"), "footprint overlap rejected")
	check(model.erase(origin + Vector3i(1, 0, 1)), "erase by inner cell removes the whole piece")
	check(not model.has_cell(origin), "whole footprint released on erase")
	var rotated := HarborFootprint.rotated_size(HarborFootprint.size_of(model.definition("mansion")), 1)
	check(rotated == Vector3i(3, 2, 3), "rotation swaps the horizontal footprint")


func _run_location_checks() -> void:
	for id in HarborLocationRegistry.ids():
		var model := Model.new(id)
		check(model.location_id == id, "location switches to " + id)
		check(model.profile.display_name != "", "profile loads for " + id)
		check(model.palette.size() > 3, "palette loads for " + id)
		model.reset(model.profile.world_seed, true)
		check(model.cells.size() > 200 and model.cells.size() < model.max_cells, "terrain generated for " + id)
		var document := model.to_document()
		var reader := Model.new(id)
		check(reader.load_document(document), "footprints do not overlap in " + id)
		var state := model.mechanic_state()
		check(state is Dictionary and not state.is_empty(), "mechanic evaluates for " + id)
		for phase in range(4):
			var params := model.profile.light_params(phase)
			check(params.has("light_energy") and params.has("sky_top"), "phase %d has light parameters in %s" % [phase, id])
		var day := HarborLocationProfile.Phase.DAY
		var night := HarborLocationProfile.Phase.NIGHT
		check(model.profile.fog_density_for(day, false) == model.profile.fog_density_day, "day uses the day fog shelf in " + id)
		check(model.profile.fog_density_for(night, false) == model.profile.fog_density_night, "night uses the night fog shelf in " + id)
		check(model.profile.fog_density_for(HarborLocationProfile.Phase.DAWN, false) == model.profile.fog_density_day, "dawn reuses the day fog shelf in " + id)
		# 夜态雾色 = 该态下限色（雾的夜色），不再取与昼档雾色的 max（R-ENG-16 后修正）。
		var night_fog := model.profile.fog_color_for(night)
		check(night_fog.is_equal_approx(model.profile.fog_floor_by_phase[night]), "night fog uses the floor colour in " + id)
	# 天气轴两类（2026-09-28 规格）：fog=海雾（泉州）/ cloud=云量（圣托里尼、CC）。
	var foggy := Model.new("quanzhou")
	check(foggy.profile.has_weather_toggle and foggy.profile.weather_kind == "fog", "quanzhou owns the fog axis")
	check(is_equal_approx(foggy.profile.fog_density_for(HarborLocationProfile.Phase.DAWN, true), 0.0045), "fog shelf overrides the density")
	var cloudy := Model.new("cape-cod")
	check(cloudy.profile.has_weather_toggle and cloudy.profile.weather_kind == "cloud", "cape cod owns the cloud axis")
	check(is_equal_approx(cloudy.profile.fog_density_for(HarborLocationProfile.Phase.NIGHT, true), 0.0058), "cloud axis keeps the phase fog value")
	check(not Model.new("seychelles").profile.has_weather_toggle, "seychelles has no weather axis")
	# 🔴 R-ENG-16 回归：hex() 曾用 is_valid_hex_number(true) 校验裸十六进制，
	# 全部颜色静默回落白色 → 整屏过曝 + 海面隐身。
	check(HarborLocationProfile.hex("9CB4BE") == Color("9cb4be"), "hex parses bare rrggbb")
	check(HarborLocationProfile.hex("#FF7738") == Color("#ff7738"), "hex parses #-prefixed values")
	check(HarborLocationProfile.hex("", Color("123456")) == Color("123456"), "hex falls back on empty input")
	var qz := HarborLocationRegistry.profile("quanzhou")
	check(qz.sky_top_color == Color("4a9be8"), "profile colors do not silently fall back to white")
	check(qz.water_deep_color == Color("1d5e93"), "water colors parsed from the profile")
	# 🟡 R-ENG-17（新增）：线性色调映射下不允许削顶。
	# albedo × (sun_energy × sun_max + ambient_energy × ambient_max) × exposure ≤ 1。
	for id in HarborLocationRegistry.ids():
		var location := HarborLocationRegistry.profile(id)
		var max_albedo := 0.0
		for item in HarborLocationRegistry.palette_items(id):
			var swatch := Color(str(item.get("color", "ffffff")))
			max_albedo = maxf(max_albedo, maxf(swatch.r, maxf(swatch.g, swatch.b)))
		for phase in range(4):
			var params := location.light_params(phase)
			var sun_c: Color = params["light_color"]
			var ambient_c: Color = params["sky_horizon"]
			var sun_max := maxf(sun_c.r, maxf(sun_c.g, sun_c.b))
			var ambient_max := maxf(ambient_c.r, maxf(ambient_c.g, ambient_c.b))
			var radiance := max_albedo * (float(params["light_energy"]) * sun_max + float(params["ambient"]) * ambient_max) * location.tonemap_exposure
			check(radiance <= 1.0, "no highlight clipping in %s phase %d (radiance=%.2f)" % [id, phase, radiance])
	var chain := Model.new("quanzhou")
	chain.reset(240910, false)
	var links: Array = chain.mechanic_state().get("links", [])
	check(links.size() == 3, "quanzhou reports three chain links")
	var santorini := Model.new("santorini")
	santorini.reset(santorini.profile.world_seed, false)
	check(santorini.mechanic_state().has("overhangs"), "santorini reports cantilever distances")
	var seychelles := Model.new("seychelles")
	seychelles.reset(seychelles.profile.world_seed, false)
	check(seychelles.mechanic_state().has("steady"), "seychelles reports stack steadiness")
	var cape := Model.new("cape-cod")
	cape.reset(cape.profile.world_seed, false)
	check(cape.mechanic_state().has("covered"), "cape cod reports beam coverage")
