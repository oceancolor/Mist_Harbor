extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition: failures += 1

func _run() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	await physics_frame
	scene._close_modal()
	var expected_models := 0
	for item: Dictionary in scene.model.palette.values():
		var mesh := str(item.get("mesh", "cube"))
		if mesh != "cube" and not mesh.begins_with("proc:"):
			expected_models += 1
	check(scene.world.scenes.size() == expected_models, "all Blender GLBs imported")
	check(scene.world.visible_faces > 0, "real terrain mesh generated")
	check(scene.world.ground_collision.shape != null, "raycast collision generated")
	check(scene.model.place(Vector3i(24,0,24), "cottage", 2), "place through game model")
	await process_frame
	await physics_frame
	check(scene.model.get_cell(Vector3i(24,0,24))["kind"] == "cottage", "placement persisted in scene")
	scene._undo()
	check(not scene.model.has_cell(Vector3i(24,0,24)), "UI undo restores world")
	scene._redo()
	check(scene.model.has_cell(Vector3i(24,0,24)), "UI redo restores command")
	var initial_phase: int = scene.world.phase
	scene._toggle_night()
	await process_frame
	check(scene.world.phase == (initial_phase + 1) % 4, "four-phase daylight control advances")
	scene.world.set_night(true, false)
	check(scene.world.night, "night state remains available")
	scene.world.set_night(false, false)
	scene._set_category("自然")
	var selected_entry: Dictionary = scene.model.definition(scene.selected)
	check(str(selected_entry.get("category", "")) == "自然", "category selects valid material")
	scene._rotate_piece()
	check(scene.piece_rotation == 1, "rotation control")
	scene._show_help()
	check(scene.modal != null, "help overlay available")
	scene._close_modal()
	check(scene.modal == null, "help returns to game")
	check(not scene.learning_mode and not scene.objective_panel.visible, "learning prompts are opt-in")
	scene.world.rebuild()
	var cached: PackedVector3Array = scene.world.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(scene.world.rebuild_metrics.blocks_rebuilt == 0, "unchanged rebuild reuses terrain geometry")
	scene.world._terrain_cache.clear()
	scene.world.rebuild()
	var fresh: PackedVector3Array = scene.world.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(cached == fresh, "cached terrain exactly matches a full rebuild")
	check(scene.model.place(Vector3i(24, 0, 23), "stone"), "terrain edit fixture")
	scene.world.rebuild()
	check(scene.world.rebuild_metrics.blocks_rebuilt < 28, "edit recomputes only bounded terrain neighborhood")
	cached = scene.world.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	scene.world._terrain_cache.clear()
	scene.world.rebuild()
	fresh = scene.world.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(cached == fresh, "incremental terrain has no stale neighbor seams")
	_test_light_patches()
	_test_location_switch(scene)
	_test_dock_fit(scene)
	print("SCENE_SMOKE_RESULT failed=", failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _test_dock_fit(scene: Node3D) -> void:
	for location in ["santorini", "seychelles"]:
		check(scene._finish_location_pick(location, false), location + " dock fixture loads")
		var viewport_width: float = scene.get_viewport().get_visible_rect().size.x
		for tab in ["地形", "建筑", "自然"]:
			scene._set_category(tab)
			var expected: int = scene._category_items().size()
			check(scene.dock_items.get_child_count() == expected and expected > 0, "%s %s dock shows every piece" % [location, tab])
			check(scene.dock.get_combined_minimum_size().x <= viewport_width - 32.0 + 0.5 and scene.dock.position.x >= 0.0, "%s %s dock stays on screen" % [location, tab])
	check(scene.model.definition("boulder").category == "地形" and scene.item_buttons.has("tortoise"), "Seychelles boulders and tortoise are selectable")

func _test_light_patches() -> void:
	var patches := HarborLightPatches.new()
	root.add_child(patches)
	var position := Vector3(12, 3, -8)
	for normal in [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3(1, 2, 3).normalized()]:
		for radius in [0.5, 3.0]:
			var entry := {"position": position, "normal": normal, "radius": radius}
			patches.rebuild([entry])
			var transform := HarborLightPatches.transform_for(entry)
			check(transform.origin.is_equal_approx(position + normal * 0.03), "patch radius never moves its center")
			check(is_equal_approx(transform.basis.x.length(), radius * 2.0) and is_equal_approx(transform.basis.y.length(), radius * 2.0), "patch scales both local plane axes")
			check(is_equal_approx(absf(transform.basis.z.normalized().dot(normal)), 1.0), "patch keeps its surface normal")
	var entries: Array = []
	entries.resize(HarborLightPatches.CAPACITY + 1)
	entries.fill({"position": position})
	patches.rebuild(entries)
	check(patches.multimesh.visible_instance_count == HarborLightPatches.CAPACITY, "patch capacity is bounded")
	patches.rebuild([])
	check(patches.multimesh.visible_instance_count == 0, "empty patches clear previous lights")
	patches.queue_free()

class FailingSave extends HarborWorldModel:
	func save_local() -> bool:
		last_error = "save failure fixture"
		return false

func _write_fixture(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _test_location_switch(scene: Node3D) -> void:
	var original: HarborWorldModel = scene.model
	var original_world: HarborBuildWorld = scene.world
	var before := original.to_document()
	scene._pick_location("cape-cod")
	check(scene.modal != null and scene.model == original, "dirty location switch requires confirmation")
	scene._close_modal()
	check(scene.model.to_document() == before and scene.model.dirty, "cancel preserves edits and history")
	var failing := FailingSave.new()
	scene.model = failing
	check(not scene._finish_location_pick("cape-cod", true) and scene.model == failing, "save failure blocks location switch")
	scene.model = original
	var target := HarborWorldModel.new("cape-cod")
	var files := [target.slot_path(1), original.slot_path(original.current_slot), HarborWorldModel.SAVE_PATH]
	var backups: Dictionary = {}
	for path: String in files:
		backups[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
	_write_fixture(HarborWorldModel.SAVE_PATH, JSON.stringify(before))
	_write_fixture(target.slot_path(1), "{broken")
	check(not scene._finish_location_pick("cape-cod", false), "bad target slot blocks switch instead of reseeding")
	check(scene.model == original and scene.world == original_world and original.to_document() == before, "bad target keeps model, renderer, and data")
	check(FileAccess.get_file_as_string(target.slot_path(1)) == "{broken", "bad target file is preserved")
	_write_fixture(original.slot_path(original.current_slot), "{\"cells\": 1, \"seed\": {}}")
	check(original.slot_info(original.current_slot).cells == 0, "slot list tolerates malformed metadata")
	check(not original.load_local() and original.to_document() == before, "corrupt current slot cannot fallback to legacy save")
	var startup: Node3D = load("res://main.tscn").instantiate()
	root.add_child(startup)
	check(startup.world == null and not startup.is_processing() and not startup.location_error.is_empty(), "startup preserves corrupt save and stops dependent input")
	startup.queue_free()
	check(target.reset(240910, false), "valid target fixture")
	_write_fixture(target.slot_path(1), JSON.stringify(target.to_document()))
	check(scene._finish_location_pick("cape-cod", true), "save-and-switch succeeds with a valid target")
	var restored := HarborWorldModel.new("quanzhou")
	check(restored.load_local() and restored.to_document().cells == before.cells, "save-and-switch preserves old construction on disk")
	check(scene.model.location_id == "cape-cod" and scene.world.model == scene.model, "successful switch activates one matching renderer")
	for path: String in backups:
		if backups[path] == null:
			DirAccess.remove_absolute(path)
		else:
			_write_fixture(path, backups[path])
