class_name HarborBuildWorld
extends Node3D

const MODEL_SCRIPT = preload("res://scripts/world_model.gd")
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
var scenes: Dictionary = {}
var ghost := Node3D.new()
var ghost_kind: String = ""
var ghost_material := StandardMaterial3D.new()
var outline_material := StandardMaterial3D.new()
var needs_rebuild: bool = false
var sun := DirectionalLight3D.new()
var environment := Environment.new()
var sea_material: ShaderMaterial
var night: bool = false
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
	model.changed.connect(func() -> void: needs_rebuild = true)
	rebuild()

func _build_environment() -> void:
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("cfdfd6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dceae0")
	environment.ambient_light_energy = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("cadfd8")
	environment.fog_density = 0.0035
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
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	water.mesh = plane
	water.position.y = -0.23
	sea_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 deep_color : source_color = vec3(0.37, 0.62, 0.62);
uniform vec3 shallow_color : source_color = vec3(0.64, 0.80, 0.76);
varying vec3 pos;
void vertex(){ pos = VERTEX; }
void fragment(){
 float w = sin(pos.x * 1.5 + pos.z * 0.8 + TIME * 0.45);
 float w2 = sin(pos.z * 1.1 - pos.x * 0.4 - TIME * 0.22);
 float lines = smoothstep(0.97, 1.0, w * w2) * 0.11;
 float radial = clamp(length(pos.xz) / 100.0, 0.0, 1.0);
 ALBEDO = mix(shallow_color, deep_color, radial * 0.7 + w * 0.015) + lines;
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
	for index in range(boats.size()):
		boats[index].position.y = -0.08 + sin(time_passed * 0.7 + index * 2) * 0.045
		boats[index].rotation.z = sin(time_passed * 0.55 + index) * 0.035

func rebuild() -> void:
	for child in props.get_children():
		props.remove_child(child)
		child.queue_free()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	visible_faces = 0
	for cell: Vector3i in model.cells:
		var item: Dictionary = model.cells[cell]
		var kind := str(item["kind"])
		if model.definition(kind).get("mesh") != "cube":
			_add_prop(cell, item)
			continue
		var base_color := Color(str(model.definition(kind).get("color", "ffffff")))
		var variation: float = float(posmod(cell.x * 71 + cell.z * 29 + cell.y * 11, 11)) / 150.0
		base_color = base_color.lightened(variation)
		for face in FACES:
			var offset: Vector3i = face[0]
			var neighbor: Dictionary = model.get_cell(cell + offset)
			if not neighbor.is_empty() and model.definition(str(neighbor["kind"])).get("mesh") == "cube":
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
	var visual := _visual(kind)
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
	if night and kind in ["lamp", "beacon"]:
		var light := OmniLight3D.new()
		light.position.y = float(height) - 0.2
		light.light_color = Color("ffbd70")
		light.light_energy = 1.6
		light.omni_range = 3.0 if kind == "lamp" else 5.5
		root.add_child(light)
	props.add_child(root)

func _visual(kind: String) -> Node3D:
	if scenes.has(kind):
		return (scenes[kind] as PackedScene).instantiate() as Node3D
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.98, model.item_height(kind), 0.98)
	instance.mesh = box
	instance.position.y = box.size.y * 0.5
	instance.material_override = _material(Color(str(model.definition(kind).get("color", "ffffff"))))
	return instance

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
		var visual := _visual(kind)
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
	night = value
	environment.background_color = Color("182d3b") if night else Color("cfdfd6")
	environment.fog_light_color = environment.background_color
	environment.ambient_light_color = Color("7395ad") if night else Color("dceae0")
	environment.ambient_light_energy = 0.25 if night else 0.30
	sun.light_color = Color("93b6cb") if night else Color("ffe6bd")
	sun.light_energy = 0.28 if night else 0.55
	sea_material.set_shader_parameter("deep_color", Color("1f3d52") if night else Color("5e9e9e"))
	sea_material.set_shader_parameter("shallow_color", Color("365764") if night else Color("a3ccc2"))
	needs_rebuild = true
