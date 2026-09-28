class_name HarborBuildWorld
extends Node3D

const MODEL_SCRIPT = preload("res://scripts/world_model.gd")
const ExpansionRules = preload("res://scripts/expansion_rules.gd")
const FACES: Array = [
	[Vector3i.UP, [Vector3(0,1,0), Vector3(0,1,1), Vector3(1,1,1), Vector3(1,1,0)]],
	[Vector3i.DOWN, [Vector3(0,0,1), Vector3(0,0,0), Vector3(1,0,0), Vector3(1,0,1)]],
	[Vector3i.RIGHT, [Vector3(1,0,0), Vector3(1,1,0), Vector3(1,1,1), Vector3(1,0,1)]],
	[Vector3i.LEFT, [Vector3(0,0,1), Vector3(0,1,1), Vector3(0,1,0), Vector3(0,0,0)]],
	[Vector3i.BACK, [Vector3(1,0,1), Vector3(1,1,1), Vector3(0,1,1), Vector3(0,0,1)]],
	[Vector3i.FORWARD, [Vector3(0,0,0), Vector3(0,1,0), Vector3(1,1,0), Vector3(1,0,0)]]
]

var model: HarborWorldModel
var terrain := MeshInstance3D.new()
var ground_body := StaticBody3D.new()
var ground_collision := CollisionShape3D.new()
var props := Node3D.new()
var prop_nodes: Dictionary = {}
var scenes: Dictionary = {}
var ghost := Node3D.new()
var ghost_kind: String = ""
var ghost_material := StandardMaterial3D.new()
var outline_material := StandardMaterial3D.new()
var needs_rebuild: bool = false
var sun := DirectionalLight3D.new()
var tropical_fill := DirectionalLight3D.new()
var environment := Environment.new()
var sky_material := ProceduralSkyMaterial.new()
var sea_material: ShaderMaterial
var night: bool = false
var phase: String = "day"
var phase_from: Dictionary = {}
var phase_to: Dictionary = {}
var phase_blend: float = 1.0
var weather_fog: bool = false
var boats: Array[Node3D] = []
var time_passed: float = 0.0
var visible_faces: int = 0

func setup(source: HarborWorldModel) -> void:
	model = source
	_build_environment()
	add_child(terrain)
	terrain.add_child(ground_body)
	ground_body.add_child(ground_collision)
	add_child(props)
	add_child(ghost)
	ghost.visible = false
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_material.albedo_color = Color(0.6, 0.92, 0.75, 0.48)
	ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.albedo_color = Color("effff1")
	for kind in model.palette:
		var entry: Dictionary = model.definition(kind)
		if entry.get("mesh") != "cube":
			var path := "res://assets/models/" + str(entry["mesh"]) + ".glb"
			if ResourceLoader.exists(path):
				scenes[kind] = load(path)
			else:
				push_error("Required Blender asset missing: " + path)
	model.cells_changed.connect(_on_cells_changed)
	rebuild()
	set_phase("day", false)

func _on_cells_changed(dirty_cells: Array[Vector3i], full_rebuild: bool) -> void:
	if full_rebuild:
		needs_rebuild = true
		return
	var origins: Dictionary = {}
	var terrain_changed := false
	for dirty_cell in dirty_cells:
		var origin := model.owner_at(dirty_cell)
		origins[origin] = true
		var item := model.get_cell(dirty_cell)
		if item.is_empty() or _is_voxel(item):
			terrain_changed = true
	if terrain_changed:
		needs_rebuild = true
		return
	for origin: Vector3i in origins:
		_refresh_prop(origin)

func _build_environment() -> void:
	environment.background_mode = Environment.BG_SKY
	environment.background_color = Color("cfdfd6")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	sky_material.sky_top_color = Color("9cb4be")
	sky_material.sky_horizon_color = Color("e0e0d8")
	sky_material.ground_horizon_color = Color("74a98d")
	sky_material.ground_bottom_color = Color("35685c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dceae0")
	environment.ambient_light_energy = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("cadfd8")
	environment.fog_density = 0.0035
	environment.fog_height_density = 0.0
	environment.fog_sun_scatter = 0.0
	environment.fog_aerial_perspective = 0.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color("ffe6bd")
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85.0
	sun.shadow_bias = 0.05
	add_child(sun)
	tropical_fill.rotation_degrees = Vector3(-25, 200, 0)
	tropical_fill.light_color = Color("b8d4e0")
	tropical_fill.light_energy = 0.30
	tropical_fill.shadow_enabled = false
	tropical_fill.visible = false
	add_child(tropical_fill)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	water.mesh = plane
	water.position.y = -0.23
	sea_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform vec3 deep_color : source_color = vec3(0.37, 0.62, 0.62);
uniform vec3 shallow_color : source_color = vec3(0.64, 0.80, 0.76);
uniform vec3 lagoon_color : source_color = vec3(0.64, 0.80, 0.76);
uniform float lagoon_radius = 18.0;
uniform float shallow_radius = 18.0;
uniform float deep_radius = 32.0;
uniform float wave_scale = 0.75;
uniform float wave_speed = 0.50;
varying vec3 pos;
void vertex(){ pos = VERTEX; }
void fragment(){
 float w = sin(pos.x * wave_scale + pos.z * wave_scale * 0.53 + TIME * wave_speed);
 float w2 = sin(pos.z * wave_scale * 0.73 - pos.x * wave_scale * 0.27 - TIME * wave_speed * 0.49);
 float lines = smoothstep(0.97, 1.0, w * w2) * 0.11;
 float radial = length(pos.xz);
 vec3 near_water = mix(lagoon_color, shallow_color, smoothstep(lagoon_radius, shallow_radius, radial));
 vec3 water_color = mix(near_water, deep_color, smoothstep(shallow_radius, deep_radius, radial));
 ALBEDO = water_color + lines;
}
"""
	sea_material.shader = shader
	water.material_override = sea_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_make_boat(Vector3(5, -0.08, -9), 0.5)
	_make_boat(Vector3(17, -0.08, 0), -0.8)
	_make_boat(Vector3(-3, -0.08, 12), 1.7)

func _make_boat(position_value: Vector3, yaw: float) -> void:
	var boat := Node3D.new()
	boat.position = position_value
	boat.rotation.y = yaw
	var hull := MeshInstance3D.new()
	var hull_mesh := PrismMesh.new()
	hull_mesh.size = Vector3(0.65, 0.28, 1.75)
	hull.mesh = hull_mesh
	hull.rotation.z = PI
	hull.material_override = _material(Color("9b7058"))
	boat.add_child(hull)
	var mast := MeshInstance3D.new()
	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = 0.026
	mast_mesh.bottom_radius = 0.026
	mast_mesh.height = 1.75
	mast.mesh = mast_mesh
	mast.position.y = 0.85
	mast.material_override = _material(Color("b39170"))
	boat.add_child(mast)
	var sail := MeshInstance3D.new()
	var sail_mesh := ImmediateMesh.new()
	sail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [Vector3(0,1.68,0), Vector3(0,0.30,0.85), Vector3(0,0.30,0.03)]:
		sail_mesh.surface_add_vertex(vertex)
	sail_mesh.surface_end()
	sail.mesh = sail_mesh
	sail.material_override = _material(Color("f1e5ce"))
	boat.add_child(sail)
	add_child(boat)
	boats.append(boat)

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.88
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _process(delta: float) -> void:
	if needs_rebuild:
		needs_rebuild = false
		rebuild()
	time_passed += delta
	if phase_blend < 1.0:
		phase_blend = minf(1.0, phase_blend + delta / 2.5)
		_apply_environment_blend(phase_blend)
	for index in range(boats.size()):
		boats[index].position.y = -0.08 + sin(time_passed * 0.7 + index * 2) * 0.045
		boats[index].rotation.z = sin(time_passed * 0.55 + index) * 0.035

func rebuild() -> void:
	for child in props.get_children():
		props.remove_child(child)
		child.queue_free()
	prop_nodes.clear()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	visible_faces = 0
	for cell: Vector3i in model.cells:
		var item: Dictionary = model.cells[cell]
		var kind := str(item["kind"])
		if not _is_voxel(item):
			_add_prop(cell, item)
			continue
		var base_color := Color(str(model.definition(kind).get("color", "ffffff")))
		var variation: float = float(posmod(cell.x * 71 + cell.z * 29 + cell.y * 11, 11)) / 150.0
		base_color = base_color.lightened(variation)
		for face in FACES:
			var offset: Vector3i = face[0]
			var neighbor: Dictionary = model.get_cell(cell + offset)
			if not neighbor.is_empty() and _is_voxel(neighbor):
				continue
			visible_faces += 1
			var color := base_color
			if kind == "grass" and offset != Vector3i.UP:
				color = Color("adad87").lightened(variation)
			if kind == "stone" and cell.y < 0:
				color = Color("93a99f").lightened(variation + float(cell.y + 3) * 0.06)
			for i in [0, 2, 1, 0, 3, 2]:
				vertices.append(Vector3(cell) + face[1][i])
				normals.append(Vector3(offset))
				colors.append(color)
	if vertices.is_empty():
		terrain.mesh = null
		ground_collision.shape = null
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := _material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, material)
	terrain.mesh = mesh
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	ground_collision.shape = shape

func _add_prop(cell: Vector3i, item: Dictionary) -> void:
	var kind := str(item["kind"])
	var root := Node3D.new()
	root.position = Vector3(cell) + Vector3(0.5, 0, 0.5)
	var variant := model.connection_variant(cell)
	var visual := _visual(kind, variant)
	visual.rotation.y = float(item.get("rot", 0)) * PI / 2.0
	root.add_child(visual)
	var body := StaticBody3D.new()
	body.set_meta("cell", cell)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var height := model.item_height(kind)
	shape.size = Vector3(0.92, height, 0.92)
	shape_node.position.y = float(height) * 0.5
	shape_node.shape = shape
	body.add_child(shape_node)
	root.add_child(body)
	root.set_meta("cell", cell)
	root.set_meta("variant", variant)
	_add_expansion_seams(root, cell, kind)
	if kind in ["lamp", "beacon", "lighthouse", "light_marker"]:
		_add_emissive_light(root, height, kind)
	props.add_child(root)
	prop_nodes[cell] = root

func _visual(kind: String, variant: String = "single") -> Node3D:
	var variant_path := "res://assets/models/%s_%s.glb" % [kind, variant]
	if ResourceLoader.exists(variant_path):
		return (load(variant_path) as PackedScene).instantiate() as Node3D
	if scenes.has(kind):
		return (scenes[kind] as PackedScene).instantiate() as Node3D
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.98, model.item_height(kind), 0.98)
	instance.mesh = box
	instance.position.y = box.size.y * 0.5
	instance.material_override = _material(Color(str(model.definition(kind).get("color", "ffffff"))))
	return instance

func _refresh_prop(cell: Vector3i) -> void:
	if prop_nodes.has(cell):
		var old: Node = prop_nodes[cell]
		prop_nodes.erase(cell)
		old.get_parent().remove_child(old)
		old.queue_free()
	var item: Dictionary = model.cells.get(cell, {})
	if not item.is_empty() and not _is_voxel(item):
		_add_prop(cell, item)

func _is_voxel(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var definition: Dictionary = model.definition(str(item.get("kind", "")))
	return definition.get("mesh") == "cube" or (bool(item.get("natural", false)) and definition.get("category") == "地形")

func _add_expansion_seams(root: Node3D, cell: Vector3i, kind: String) -> void:
	var expansion: Dictionary = model.definition(kind).get("expansion", {})
	if expansion.is_empty():
		return
	var mask := model.connection_mask(cell)
	var color := Color(str(model.definition(kind).get("color", "ffffff")))
	for index in range(ExpansionRules.DIRECTIONS.size()):
		if not mask & (1 << index):
			continue
		var direction: Vector3i = ExpansionRules.DIRECTIONS[index]
		var seam := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 0.12, 0.18)
		if direction.x != 0:
			box.size.x = 0.54
		elif direction.z != 0:
			box.size.z = 0.54
		else:
			box.size.y = 0.54
		seam.mesh = box
		seam.position = Vector3(direction) * 0.38 + Vector3(0, 0.12, 0)
		seam.material_override = _material(color.darkened(0.08))
		seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(seam)

func _add_emissive_light(root: Node3D, height: int, kind: String) -> void:
	var glow := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15 if kind in ["lamp", "light_marker"] else 0.25
	sphere.height = sphere.radius * 2.0
	glow.mesh = sphere
	glow.position.y = float(height) - 0.18
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffd28a")
	material.emission_enabled = true
	material.emission = Color("ffb45f")
	material.emission_energy_multiplier = 2.2
	material.disable_fog = true
	glow.material_override = material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	var pool := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.9 if kind in ["lamp", "light_marker"] else 1.8
	disc.bottom_radius = disc.top_radius
	disc.height = 0.012
	pool.mesh = disc
	pool.position.y = 0.025
	var pool_material := StandardMaterial3D.new()
	pool_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pool_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_material.albedo_color = Color(1.0, 0.67, 0.30, 0.24)
	pool_material.no_depth_test = false
	pool_material.disable_fog = true
	pool.material_override = pool_material
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pool)

func pick(camera: Camera3D, screen_position: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 180.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var normal: Vector3 = hit["normal"]
		var position_value: Vector3 = hit["position"]
		var inside := position_value - normal * 0.02
		var cell := Vector3i(floori(inside.x), floori(inside.y), floori(inside.z))
		var collider: Object = hit["collider"]
		var candidate_point := position_value + normal * 0.02
		var candidate := Vector3i(floori(candidate_point.x), floori(candidate_point.y), floori(candidate_point.z))
		if collider.has_meta("cell"):
			cell = collider.get_meta("cell")
			if normal.y > 0.5:
				candidate = cell + Vector3i(0, model.item_height(str(model.get_cell(cell).get("kind", "stone"))), 0)
			elif normal.y < -0.5:
				candidate = cell + Vector3i.DOWN
			else:
				candidate = cell + Vector3i(roundi(normal.x), 0, roundi(normal.z))
		return {"cell": model.owner_at(cell), "place": candidate, "normal": normal, "hit": true}
	var point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if point != null:
		var cell := Vector3i(floori(point.x), 0, floori(point.z))
		return {"cell": cell, "place": cell, "normal": Vector3.UP, "hit": false}
	return {}

func show_ghost(kind: String, cell: Vector3i, rotation: int, valid: bool, removing: bool) -> void:
	var key := kind + ("-erase" if removing else "")
	if ghost_kind != key:
		ghost_kind = key
		for child in ghost.get_children():
			ghost.remove_child(child)
			child.queue_free()
		var visual := _visual(kind, "single")
		_tint_ghost(visual)
		ghost.add_child(visual)
		var border := MeshInstance3D.new()
		var wire := ImmediateMesh.new()
		var height := float(model.item_height(kind))
		var points: Array[Vector3] = [Vector3(-0.51,0,-0.51),Vector3(0.51,0,-0.51),Vector3(0.51,0,0.51),Vector3(-0.51,0,0.51)]
		wire.surface_begin(Mesh.PRIMITIVE_LINES)
		for i in range(4):
			var j := (i + 1) % 4
			for p in [points[i], points[j], points[i] + Vector3.UP * height, points[j] + Vector3.UP * height, points[i], points[i] + Vector3.UP * height]:
				wire.surface_add_vertex(p)
		wire.surface_end()
		border.mesh = wire
		border.material_override = outline_material
		border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(border)
	ghost_material.albedo_color = Color(0.38, 0.88, 0.72, 0.48) if valid and not removing else Color(0.94, 0.42, 0.31, 0.42)
	ghost.position = Vector3(cell) + Vector3(0.5, 0.012, 0.5)
	ghost.rotation.y = float(rotation) * PI / 2.0
	ghost.visible = model.in_bounds(cell)

func _tint_ghost(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = ghost_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_tint_ghost(child)

func set_night(value: bool) -> void:
	set_phase("night" if value else "day")

func set_phase(value: String, animated: bool = true) -> void:
	if model.location == null:
		return
	phase_from = _current_environment_state()
	phase_to = model.location.phase(value)
	if weather_fog and model.location.fog_density_weather > 0.0:
		phase_to["fog_density"] = model.location.fog_density_weather
	_apply_location_water()
	phase = value
	night = value == "night"
	tropical_fill.visible = model.location_id == "seychelles" and not night
	phase_blend = 0.0 if animated else 1.0
	_apply_environment_blend(phase_blend)

func set_weather_fog(value: bool) -> bool:
	if model.location_id != "cape_cod":
		weather_fog = false
		return false
	weather_fog = value
	set_phase(phase)
	return true

func next_phase() -> String:
	var phases := ["dawn", "day", "sunset", "night"]
	set_phase(phases[(phases.find(phase) + 1) % phases.size()])
	return phase

func _current_environment_state() -> Dictionary:
	return {
		"background": sky_material.sky_horizon_color.to_html(false),
		"sky_top": sky_material.sky_top_color.to_html(false),
		"ambient": environment.ambient_light_color.to_html(false),
		"ambient_energy": environment.ambient_light_energy,
		"sun": sun.light_color.to_html(false),
		"sun_energy": sun.light_energy,
		"sun_rotation_x": sun.rotation_degrees.x,
		"fog": environment.fog_light_color.to_html(false),
		"fog_density": environment.fog_density,
	}

func _apply_location_water() -> void:
	var water: Dictionary = model.location.water
	sea_material.set_shader_parameter("deep_color", Color(str(water.get("deep_color", "35685c"))))
	sea_material.set_shader_parameter("shallow_color", Color(str(water.get("shallow_color", "74a98d"))))
	sea_material.set_shader_parameter("lagoon_color", Color(str(water.get("lagoon_color", water.get("shallow_color", "74a98d")))))
	sea_material.set_shader_parameter("lagoon_radius", float(water.get("lagoon_radius", water.get("shallow_radius", 18.0))))
	sea_material.set_shader_parameter("shallow_radius", float(water.get("shallow_radius", 18.0)))
	sea_material.set_shader_parameter("deep_radius", float(water.get("deep_radius", 32.0)))
	sea_material.set_shader_parameter("wave_scale", float(water.get("wave_scale", 0.75)))
	sea_material.set_shader_parameter("wave_speed", float(water.get("wave_speed", 0.5)))

func _mix_color(key: String, weight: float) -> Color:
	return Color(str(phase_from.get(key, phase_to.get(key, "ffffff")))).lerp(Color(str(phase_to.get(key, "ffffff"))), weight)

func _apply_environment_blend(weight: float) -> void:
	if phase_to.is_empty():
		return
	environment.background_color = _mix_color("background", weight)
	sky_material.sky_horizon_color = _mix_color("background", weight)
	sky_material.sky_top_color = _mix_color("sky_top", weight)
	sky_material.ground_horizon_color = Color(str(model.location.water.get("lagoon_color", model.location.water.get("shallow_color", "74a98d"))))
	sky_material.ground_bottom_color = Color(str(model.location.water.get("deep_color", "35685c")))
	environment.fog_light_color = _mix_color("fog", weight)
	environment.ambient_light_color = _mix_color("ambient", weight)
	environment.fog_density = lerpf(float(phase_from.get("fog_density", phase_to.get("fog_density", 0.0035))), float(phase_to.get("fog_density", 0.0035)), weight)
	environment.ambient_light_energy = lerpf(float(phase_from.get("ambient_energy", environment.ambient_light_energy)), float(phase_to.get("ambient_energy", 0.3)), weight)
	sun.light_color = _mix_color("sun", weight)
	sun.light_energy = lerpf(float(phase_from.get("sun_energy", phase_to.get("sun_energy", 0.5))), float(phase_to.get("sun_energy", 0.5)), weight)
	var rotation_x := lerpf(float(phase_from.get("sun_rotation_x", sun.rotation_degrees.x)), float(phase_to.get("sun_rotation_x", -48.0)), weight)
	sun.rotation_degrees.x = rotation_x
