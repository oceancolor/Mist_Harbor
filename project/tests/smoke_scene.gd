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
	var palette: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		HarborLocationRegistry.palette_path(scene.model.location_id)))
	var expected_models := 0
	if palette is Dictionary:
		for item in palette.get("items", []):
			var mesh_value := str(item.get("mesh", "cube"))
			if mesh_value != "cube" and not mesh_value.begins_with("proc:"):
				expected_models += 1
	check(scene.world.scenes.size() == expected_models, "all Blender GLBs imported")
	check(scene.world.visible_faces > 0, "real terrain mesh generated")
	check(scene.world.ground_collision.shape != null, "raycast collision generated")
	var build_cell := Vector3i(0, 0, -2)
	check(scene.model.place(build_cell, "cottage", 2), "place through game model")
	await process_frame
	await physics_frame
	check(scene.model.get_cell(build_cell)["kind"] == "cottage", "placement persisted in scene")
	# 放置落点对齐：视觉子节点全局位置 = 格子角点 − 地面下沉 + center_offset。
	# 幽灵预览与放置共用同一套基准（2026-09-27 错位修复的回归防线）。
	var prop_root: Node3D = null
	for child in scene.world.props.get_children():
		for sub in child.get_children():
			if sub is StaticBody3D and sub.get_meta("cell", Vector3i(999999, 999999, 999999)) == build_cell:
				prop_root = child
	check(prop_root != null, "placed prop root found at hovered cell")
	if prop_root != null:
		var entry: Dictionary = scene.model.definition("cottage")
		var sink: float = scene.world._ground_sink(build_cell)
		var expected := Vector3(build_cell.x, build_cell.y - sink, build_cell.z) \
			+ HarborFootprint.center_offset(entry, 2)
		var vis := prop_root.get_child(0) as Node3D
		check(vis.global_position.distance_to(expected) < 0.05,
			"placed visual aligns with footprint center")
	# 幽灵预览对齐：视觉盒与线框都应落在格子 [cell, cell+1] 带内（同一基准）。
	var ghost_cell := Vector3i(2, 0, 6)
	scene.world.show_ghost("wood", ghost_cell, 0, true, false)
	var ghost_vis: Node = scene.world.ghost.get_node("Pivot").get_child(0)
	if ghost_vis is MeshInstance3D:
		var g_aabb: AABB = (ghost_vis as MeshInstance3D).global_transform * (ghost_vis as MeshInstance3D).get_aabb()
		check(absf(g_aabb.position.x - float(ghost_cell.x) - 0.01) < 0.05
			and absf(g_aabb.position.z - float(ghost_cell.z) - 0.01) < 0.05,
			"ghost visual xz centered in cell")
		check(absf(g_aabb.position.y - (float(ghost_cell.y) + 0.012
			- scene.world._ground_sink(ghost_cell))) < 0.05, "ghost visual y at cell base")
	var ghost_border := scene.world.ghost.get_child(1) as MeshInstance3D
	var b_aabb: AABB = ghost_border.global_transform * ghost_border.get_aabb()
	check(absf(b_aabb.position.x - float(ghost_cell.x) + 0.02) < 0.05
		and absf(b_aabb.position.y - (float(ghost_cell.y) + 0.012
		- scene.world._ground_sink(ghost_cell))) < 0.05, "ghost wire outlines the cell")
	scene._undo()
	check(not scene.model.has_cell(build_cell), "UI undo restores world")
	scene._redo()
	check(scene.model.has_cell(build_cell), "UI redo restores command")
	# N 键四态循环：昼 → 日落 → 夜 → 晨 → 昼
	check(scene.world.phase == HarborLocationProfile.Phase.DAY, "day is the entry state")
	scene._toggle_night()
	await process_frame
	check(scene.world.phase == HarborLocationProfile.Phase.SUNSET, "first N press reaches sunset")
	scene._toggle_night()
	await process_frame
	check(scene.world.night, "second N press reaches night")
	check(scene.world.daylight.night_strength() > 0.9, "night lights are fully on at night")
	scene._toggle_night()
	scene._toggle_night()
	await process_frame
	check(scene.world.phase == HarborLocationProfile.Phase.DAY, "the cycle returns to day")
	check(scene.world.daylight.environment.fog_density > 0.0, "fog stays a location constant")
	check(scene.world.daylight.sky != null, "vertex gradient skybox exists")
	scene._set_category("自然")
	var selected_entry: Dictionary = scene.model.definition(scene.selected)
	check(str(selected_entry.get("category", "")) == "自然", "category selects valid material")
	scene._rotate_piece()
	check(scene.piece_rotation == 1, "rotation control")
	scene._show_help()
	check(scene.modal != null, "help overlay available")
	scene._close_modal()
	check(scene.modal == null, "help returns to game")
	await _run_location_switch(scene)
	print("SCENE_SMOKE_RESULT failed=", failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _run_location_switch(scene: Node3D) -> void:
	for id in HarborLocationRegistry.ids():
		scene._enter_location(id)
		await process_frame
		await physics_frame
		check(scene.model.location_id == id, "scene enters " + id)
		check(scene.world.visible_faces > 0, "terrain renders in " + id)
		check(scene.world.daylight.profile == scene.model.profile, "daylight follows the profile in " + id)
		var state: Dictionary = scene.model.mechanic_state()
		check(not state.is_empty(), "mechanic state available in " + id)
		if id == "cape-cod":
			scene._toggle_weather()
			await process_frame
			check(scene.world.weather_on, "weather axis toggles on cape cod")
			scene._toggle_weather()
	scene._enter_location(HarborLocationRegistry.default_id())
	await process_frame
	check(scene.model.location_id == HarborLocationRegistry.default_id(), "scene returns to the default location")
