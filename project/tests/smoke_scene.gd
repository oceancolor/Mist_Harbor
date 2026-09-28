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
	var palette: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/palette.json"))
	var expected_models := 0
	if palette is Dictionary:
		for item in palette.get("items", []):
			if str(item.get("mesh", "cube")) != "cube":
				expected_models += 1
	check(scene.world.scenes.size() == expected_models, "all Blender GLBs imported")
	check(scene.world.visible_faces > 0, "real terrain mesh generated")
	check(scene.world.ground_collision.shape != null, "raycast collision generated")
	check(scene.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and scene.camera.far >= 1600.0, "perspective orbit camera sees the extended horizon")
	check(scene.world.water_surface.mesh is PlaneMesh and scene.world.water_surface.mesh.size.x >= 1600.0, "extended ocean prevents low-angle edge reveals")
	check(scene.world.shore_foam.mesh != null, "shoreline foam mesh surrounds exposed coast cells")
	check(scene.world.horizon_lod.get_child_count() >= 16, "location-specific low-detail horizon surrounds the scene")
	var water_shader_code: String = scene.world.sea_material.shader.code
	check("fresnel" in water_shader_code and "screen_texture" in water_shader_code and "lod" in water_shader_code, "water shader includes Fresnel refraction and distance LOD")
	scene.target_pitch = 0.0
	scene.target_zoom = 18.0
	scene._update_camera(1.0)
	check(scene.target_pitch >= deg_to_rad(4.0) and scene.camera.position.y >= 1.35, "ground-level orbit stays above the ocean")
	scene.target_pitch = PI
	scene._update_camera(1.0)
	check(scene.target_pitch <= deg_to_rad(89.0), "orbit reaches near-vertical without look-at singularity")
	scene._center_camera()
	scene._update_camera(1.0)
	check(scene.model.place(Vector3i(24,0,24), "cottage", 2), "place through game model")
	await process_frame
	await physics_frame
	check(scene.model.get_cell(Vector3i(24,0,24))["kind"] == "cottage", "placement persisted in scene")
	scene._undo()
	check(not scene.model.has_cell(Vector3i(24,0,24)), "UI undo restores world")
	scene._redo()
	check(scene.model.has_cell(Vector3i(24,0,24)), "UI redo restores command")
	scene._toggle_night()
	await process_frame
	check(scene.world.phase == "sunset", "environment advances from day to sunset")
	scene._toggle_night()
	check(scene.world.night and scene.world.phase == "night", "four-state cycle reaches night")
	scene.world._apply_environment_blend(1.0)
	check(scene.world.moon_disc.visible and not scene.world.sun_disc.visible, "night sky displays the full moon instead of the sun")
	check(scene.world.water_light < 0.5, "night phase darkens refractive water without removing moon reflections")
	var real_lights: Array[Node] = scene.world.find_children("*", "OmniLight3D", true, false)
	check(real_lights.is_empty(), "night rendering uses no OmniLight3D")
	scene.world.set_phase("dawn", false)
	var dawn_disc: Color = scene.world.sun_disc.modulate
	scene.world.set_phase("day", false)
	var day_disc: Color = scene.world.sun_disc.modulate
	scene.world.set_phase("sunset", false)
	var sunset_disc: Color = scene.world.sun_disc.modulate
	check(scene.world.sun_disc.visible and dawn_disc != day_disc and day_disc != sunset_disc, "dawn day and sunset use distinct luminous sun colours")
	scene._set_category("自然")
	var selected_entry: Dictionary = scene.model.definition(scene.selected)
	check(str(selected_entry.get("category", "")) == "自然", "category selects valid material")
	scene._rotate_piece()
	check(scene.piece_rotation == 1, "rotation control")
	scene._show_help()
	check(scene.modal != null, "help overlay available")
	scene._close_modal()
	check(scene.modal == null, "help returns to game")
	scene._switch_location("santorini")
	await process_frame
	check(scene.model.location_id == "santorini", "location switch replaces the active profile")
	check(scene.model.build_max_y() == 32, "scene uses location-specific vertical bounds")
	check(scene.selected in scene.model.palette, "location switch keeps a valid selected material")
	check(scene.objectives.size() == 6, "active location exposes M1-M6 objectives")
	for location_id in ["quanzhou", "seychelles", "cape_cod"]:
		scene._switch_location(location_id)
		await process_frame
		check(scene.model.location_id == location_id, "%s location is playable" % [location_id])
		check(scene.model.cells.size() > 0, "%s location has generated terrain" % [location_id])
	check(scene.world.set_weather_fog(true), "Cape Cod weather fog can be enabled")
	scene.world._apply_environment_blend(1.0)
	check(is_equal_approx(scene.world.environment.fog_density, 0.0075), "Cape Cod weather fog uses the approved density")
	check(scene.world.set_weather_fog(false), "Cape Cod weather fog can be disabled")
	scene.world._apply_environment_blend(1.0)
	check(is_equal_approx(scene.world.environment.fog_density, 0.0036), "weather fog restores the active daytime density")
	check(is_equal_approx(scene.world.environment.fog_height_density, 0.0), "height fog stays disabled")
	print("SCENE_SMOKE_RESULT failed=", failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
