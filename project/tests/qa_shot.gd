extends SceneTree

## 渲染诊断：开真窗口跑一帧，存截图 + 打印水/环境/光的关键状态。
## 用法：godot --path project --script res://tests/qa_shot.gd [phase]
## 输出：user://qa-shot-<phase>.png

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for i in range(40):
		await process_frame
	# 关掉开场地点菜单
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	for i in range(10):
		await process_frame
	var world: Node3D = scene.get("world")
	var daylight: Node3D = world.get("daylight")
	var water: MeshInstance3D = daylight.get("water")
	var water_material: ShaderMaterial = daylight.get("water_material")
	var environment: Environment = (daylight.get("environment") as WorldEnvironment).environment
	var sun: DirectionalLight3D = daylight.get("sun")
	print("DIAG water visible=", water.visible, " pos=", water.global_position, " aabb=", water.get_aabb())
	print("DIAG water mesh=", water.mesh != null, " material=", water.material_override != null,
		" transparency=", water_material.get_shader_parameter("transparency"),
		" deep=", water_material.get_shader_parameter("deep_color"),
		" tint=", water_material.get_shader_parameter("tint"))
	print("DIAG env fog_density=", environment.fog_density, " fog_color=", environment.fog_light_color,
		" bg=", environment.background_color, " ambient=", environment.ambient_light_energy,
		" ambient_color=", environment.ambient_light_color, " exposure=", environment.tonemap_exposure)
	print("DIAG sun energy=", sun.light_energy, " color=", sun.light_color,
		" rot=", sun.rotation_degrees, " shadow=", sun.shadow_enabled)
	print("DIAG sky params top=", daylight.get("sky_material").get_shader_parameter("top_color"),
		" horizon=", daylight.get("sky_material").get_shader_parameter("horizon_color"))
	print("DIAG terrain faces=", world.get("visible_faces"), " cells=", scene.get("model").cells.size())
	var image := root.get_viewport().get_texture().get_image()
	var path := "user://qa-shot.png"
	image.save_png(path)
	print("SAVED: ", ProjectSettings.globalize_path(path))
	quit(0)
