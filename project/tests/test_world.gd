extends SceneTree

const Model = preload("res://scripts/world_model.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

## 模型清单必须与磁盘上的 GLB 一致：曾经出现过清单记 15980 字节、实际 240684 字节的资产，
## 导致面数/体积结论全部失真。这里按实物重算 bytes 与三角数。
func _check_manifest() -> void:
	var dir := DirAccess.open("res://assets/models")
	check(dir != null, "model directory exists")
	if dir == null: return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/manifest.json"))
	check(raw is Dictionary, "manifest parses")
	if not (raw is Dictionary): return
	var assets: Array = (raw as Dictionary).get("assets", []) as Array
	var on_disk := 0
	for entry_name in DirAccess.get_files_at("res://assets/models"):
		if entry_name.ends_with(".glb"): on_disk += 1
	check(assets.size() == on_disk and on_disk > 0, "manifest covers every GLB on disk")
	var mismatched := 0
	var no_bounds := 0
	var detail := ""
	for entry: Dictionary in assets:
		var asset_id := str(entry.get("id", ""))
		var path := "res://assets/models/" + str(entry.get("file", asset_id + ".glb"))
		if not FileAccess.file_exists(path):
			mismatched += 1
			detail = asset_id + " 文件缺失"
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		var bytes: PackedByteArray = file.get_buffer(file.get_length())
		file.close()
		var stats := _glb_stats(bytes)
		if stats.is_empty() or stats.has("error"):
			mismatched += 1
			detail = "%s GLB 解析失败：%s" % [asset_id, str(stats.get("error", "unknown"))]
		elif int(stats["bytes"]) != int(entry.get("bytes", -1)):
			mismatched += 1
			detail = "%s 字节记 %s 实际 %s" % [asset_id, entry.get("bytes"), stats["bytes"]]
		elif int(stats["triangles"]) != int(entry.get("triangles", -1)):
			mismatched += 1
			detail = "%s 三角记 %s 实际 %s（GLB %d 字节）" % [asset_id, entry.get("triangles"), stats["triangles"], bytes.size()]
		var bounds: Dictionary = entry.get("bounds", {}) as Dictionary
		if (bounds.get("godot_size", []) as Array).size() != 3:
			no_bounds += 1
	check(mismatched == 0, "manifest bytes and triangles match the real GLBs" + (" (" + detail + ")" if mismatched > 0 else ""))
	check(no_bounds == 0, "every manifest entry carries real bounds")

## 日落调参跟作品走：能存能读、坏值按坏档拒绝、默认取地点配置。
func _sunset_cases(snapshot: Dictionary) -> void:
	var tuned := Model.new()
	tuned.reset(240910, false)
	check(tuned.sunset_tuning.is_empty(), "new work starts on the location default sunset")
	check(not tuned.set_sunset_tuning({"light_energy": 99.0}), "out-of-range sunset rejected")
	check(not tuned.set_sunset_tuning({"sky_top": "not-a-color"}), "bad sunset colour rejected")
	check(not tuned.set_sunset_tuning({"nope": 1}), "unknown sunset key rejected")
	check(tuned.sunset_tuning.is_empty(), "rejected sunset tuning does not stick")
	var values := {"light_color": "ff9a5a", "light_energy": 1.25, "ambient": 0.33,
		"ambient_color": "ffbf80", "sky_horizon": "ffc98a", "sky_top": "2a3a6a",
		"sun_x": -6.5, "sun_y": 120.0}
	check(tuned.set_sunset_tuning(values), "sunset tuning accepted")
	check(tuned.dirty, "sunset tuning marks the work dirty so it gets saved")
	var restored := Model.new()
	check(restored.load_document(tuned.to_document()), "sunset tuning roundtrips")
	check(restored.sunset_tuning == values, "saved sunset survives a reload")
	var broken: Dictionary = tuned.to_document().duplicate(true)
	broken["sunset"] = {"sun_x": -400.0}
	check(not restored.load_document(broken), "corrupt sunset rejected")
	broken = tuned.to_document().duplicate(true)
	broken["sunset"] = "warm"
	check(not restored.load_document(broken), "non-dictionary sunset rejected")
	check(restored.sunset_tuning == values, "rejected sunset save preserves live tuning")
	# 旧档没有 sunset 字段时也能读，并按该地点默认渲染。
	var legacy_snapshot: Dictionary = snapshot.duplicate(true)
	legacy_snapshot.erase("sunset")
	var legacy_model := Model.new()
	check(legacy_model.load_document(legacy_snapshot), "v1 saves without sunset still load")
	check(legacy_model.sunset_tuning.is_empty(), "missing sunset falls back to the location default")
	var profile := HarborLocationRegistry.profile("quanzhou")
	check(HarborSunsetTuning.merged(profile, {})["light_color"] == profile.sunset_sun_color.to_html(false), "sunset defaults come from the location profile")

func _glb_stats(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 20 or bytes.slice(0, 4).get_string_from_ascii() != "glTF":
		return {}
	# GLB 布局：magic(4) + version(4) + total(4) + [json 段长度(4) + 段类型(4)] …
	var length := bytes.decode_u32(12)
	if bytes.decode_u32(16) != 0x4E4F534A or 20 + length > bytes.size():
		return {"error": "length"}
	var parser := JSON.new()
	if parser.parse(bytes.slice(20, 20 + length).get_string_from_utf8()) != OK:
		return {"error": "json:%s" % [parser.get_error_message()]}
	var document: Variant = parser.data
	if not (document is Dictionary): return {"error": "not-object"}
	var data: Dictionary = document as Dictionary
	var triangles := 0
	for mesh in data.get("meshes", []):
		for primitive in (mesh as Dictionary).get("primitives", []):
			var primitive_dict: Dictionary = primitive as Dictionary
			var accessors: Array = data.get("accessors", []) as Array
			if primitive_dict.has("indices"):
				var index: Dictionary = accessors[int(primitive_dict["indices"])] as Dictionary
				triangles += int(index.get("count", 0)) / 3
			elif (primitive_dict.get("attributes", {}) as Dictionary).has("POSITION"):
				var positions: Dictionary = accessors[int((primitive_dict["attributes"] as Dictionary)["POSITION"])] as Dictionary
				triangles += int(positions.get("count", 0)) / 3
	return {"bytes": bytes.size(), "triangles": triangles}

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)

func _run() -> void:
	_check_manifest()
	var model := Model.new()
	model.reset(240910, false)
	var initial := JSON.stringify(model.to_document())
	var expected_materials := HarborLocationRegistry.palette_items(model.location_id).size()
	check(model.palette.size() == expected_materials and expected_materials > 0, "palette matches canonical location registry")
	check(model.cells.size() > 500 and model.cells.size() < Model.MAX_CELLS, "bounded real terrain")
	check(model.placed_count() == 0, "natural terrain does not count as learner work")
	var other := Model.new()
	other.reset(240910, false)
	check(JSON.stringify(other.to_document()) == initial, "same seed yields same world")
	other.reset(1234, false)
	check(JSON.stringify(other.to_document()) != initial, "different seed changes world")
	var cell := Vector3i(23,0,23)
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
	model.profile.geo_meta.palette_subset.built.append("beacon")
	check(model.place(Vector3i(23,0,22),"beacon"), "tall model placed")
	check(model.has_cell(Vector3i(23,2,22)), "tall model reserves upper cells")
	check(not model.place(Vector3i(23,1,22),"wood"), "cannot intersect tall model")
	check(model.erase(Vector3i(23,2,22)), "hit upper footprint removes whole model")
	check(not model.has_cell(Vector3i(23,0,22)), "all footprint released")
	check(not model.place(Vector3i(80,0,0),"wood"), "world bounds enforced")
	check(not model.place(Vector3i(0,19,0),"beacon"), "height bounds enforced")
	check(not model.place(Vector3i(21,10,21),"wood"), "unsupported midair cell rejected")
	check(not model.place(Vector3i(23,0,21),"invalid"), "unknown material rejected")
	var slots := Model.new()
	slots.reset(240910, false)
	check(slots.place(Vector3i(23,0,24), "cottage"), "slot fixture placed")
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
	check(fixture.place(Vector3i(23,0,24), "cottage"), "achievement fixture placed")
	var fresh: Array = board.evaluate(fixture, {"night_photos": 1})
	check(fresh.size() >= 2, "placing a piece and a night photo unlock achievements")
	check(board.is_unlocked("first_piece"), "first piece achievement recorded")
	check(board.is_unlocked("night_owl"), "night photo achievement reads photo stats")
	check(board.evaluate(fixture, {"night_photos": 1}).is_empty(), "achievements are reported only once")
	var snapshot := model.to_document()
	check(other.import_json(JSON.stringify(snapshot)), "JSON save/load roundtrip")
	check(JSON.stringify(other.to_document()) == JSON.stringify(snapshot), "roundtrip preserves all cells and stats")
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
	_sunset_cases(snapshot)
	model.undo()
	check(model.redo_stack.size() > 0, "redo branch present")
	model.place(Vector3i(22,0,23),"stone")
	check(model.redo_stack.is_empty(), "new command discards redo branch")
	var village := Model.new()
	village.reset(240910, true)
	check(village.placed_count() == 0, "starter scenery not credited as learner construction")
	check(other.load_document(village.to_document()), "starter world has no overlapping footprints")
	print("WORLD_TEST_RESULT passed=", passed, " failed=", failed)
	quit(1 if failed else 0)
