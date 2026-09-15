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
	check(scene.world.scenes.size() == 8, "all Blender GLBs imported")
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
	scene._toggle_night()
	await process_frame
	check(scene.world.night, "day-night state toggles")
	scene._toggle_night()
	scene._set_category("自然")
	check(scene.selected == "tree", "category selects valid material")
	scene._rotate_piece()
	check(scene.piece_rotation == 1, "rotation control")
	scene._show_help()
	check(scene.modal != null, "help overlay available")
	scene._close_modal()
	check(scene.modal == null, "help returns to game")
	print("SCENE_SMOKE_RESULT failed=", failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
