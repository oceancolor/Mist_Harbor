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
	var palette_file: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/palette.json"))
	var expected_materials := 0
	if palette_file is Dictionary:
		expected_materials = (palette_file as Dictionary).get("items", []).size()
	check(model.palette.size() == expected_materials and expected_materials > 0, "palette matches data/palette.json")
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
	check(Model.slot_path(9) == Model.slot_path(3), "slot index is clamped")
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
