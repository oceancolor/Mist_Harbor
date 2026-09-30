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
var build_fill := DirectionalLight3D.new()
var cinematic: bool = false
var environment := Environment.new()
var sky_material := ProceduralSkyMaterial.new()
var sea_material: ShaderMaterial
var water_surface := MeshInstance3D.new()
var shore_foam := MeshInstance3D.new()
var wet_shore := MeshInstance3D.new()
var horizon_lod := Node3D.new()
var sun_disc := Sprite3D.new()
var moon_disc := Sprite3D.new()
var viewer_position := Vector3(0, 12, 32)
var horizon_location: String = ""
var celestial_from := Vector3.ZERO
var celestial_to := Vector3.ZERO
var water_light: float = 1.0
var water_light_from: float = 1.0
var water_light_to: float = 1.0
var night: bool = false
var phase: String = "day"
var phase_from: Dictionary = {}
var phase_to: Dictionary = {}
var phase_blend: float = 1.0
var phase_from_night: bool = false
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
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.sky_material = sky_material
	environment.sky = sky
	sky_material.sky_top_color = Color("9cb4be")
	sky_material.sky_horizon_color = Color("e0e0d8")
	sky_material.ground_horizon_color = Color("74a98d")
	sky_material.ground_bottom_color = Color("35685c")
	sky_material.sun_angle_max = 8.0
	sky_material.sun_curve = 0.12
	sky_material.sky_energy_multiplier = 1.0
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dceae0")
	environment.ambient_light_energy = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.glow_enabled = false
	environment.glow_intensity = 0.42
	environment.glow_strength = 0.68
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.15
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
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_bias = 0.05
	add_child(sun)
	tropical_fill.rotation_degrees = Vector3(-25, 200, 0)
	tropical_fill.light_color = Color("b8d4e0")
	tropical_fill.light_energy = 0.30
	tropical_fill.shadow_enabled = false
	tropical_fill.visible = false
	add_child(tropical_fill)
	build_fill.rotation_degrees = Vector3(-28, 75, 0)
	build_fill.light_color = Color("8a8494")
	build_fill.light_energy = 0.22
	build_fill.shadow_enabled = false
	add_child(build_fill)
	var plane := PlaneMesh.new()
	plane.size = Vector2(1600, 1600)
	plane.subdivide_width = 96
	plane.subdivide_depth = 96
	water_surface.mesh = plane
	water_surface.position.y = -0.23
	sea_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled, depth_draw_opaque;
uniform vec3 deep_color : source_color = vec3(0.37, 0.62, 0.62);
uniform vec3 shallow_color : source_color = vec3(0.64, 0.80, 0.76);
uniform vec3 lagoon_color : source_color = vec3(0.64, 0.80, 0.76);
uniform float water_light = 1.0;
uniform float lagoon_radius = 18.0;
uniform float shallow_radius = 18.0;
uniform float deep_radius = 32.0;
uniform float wave_scale = 0.75;
uniform float wave_speed = 0.50;
uniform vec3 dark_water : source_color = vec3(0.16, 0.20, 0.19);
uniform float sunset_mix : hint_range(0.0, 1.0) = 0.0;
uniform float wave_strength : hint_range(0.0, 0.3) = 0.08;
uniform float water_roughness : hint_range(0.02, 1.0) = 0.18;
uniform float base_fill : hint_range(0.0, 0.2) = 0.025;
varying vec3 world_pos;

vec2 fade(vec2 t) {
 return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

vec2 hash_grad(vec2 cell) {
 float n = sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453;
 return vec2(cos(n), sin(n * 1.6183));
}

float perlin(vec2 p) {
 vec2 cell = floor(p);
 vec2 f = fract(p);
 vec2 u = fade(f);
 float n00 = dot(hash_grad(cell), f);
 float n10 = dot(hash_grad(cell + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
 float n01 = dot(hash_grad(cell + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
 float n11 = dot(hash_grad(cell + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
 return mix(mix(n00, n10, u.x), mix(n01, n11, u.x), u.y);
}

float fbm(vec2 p) {
 float value = 0.0;
 float amp = 0.55;
 float freq = 1.0;
 for (int i = 0; i < 4; i++) {
  value += perlin(p * freq) * amp;
  freq *= 2.03;
  amp *= 0.48;
 }
 return value;
}

void vertex(){
 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment(){
 float scale = mix(0.085, 0.145, clamp(wave_scale, 0.0, 1.6) / 1.6);
 vec2 p = world_pos.xz * scale;
 float t = TIME * wave_speed * 0.22;
 vec2 warp = vec2(
  perlin(p * 0.55 + vec2(t * 0.37, -t * 0.21)),
  perlin(p * 0.47 + vec2(18.2, 7.4) - t * 0.29)
 );
 vec2 q = p + warp * 0.85;
 float e = 0.22;
 float h = fbm(q + vec2(t * 0.31, -t * 0.19));
 float hx = fbm(q + vec2(e + t * 0.31, -t * 0.19));
 float hz = fbm(q + vec2(t * 0.31, e - t * 0.19));
 vec2 slope = vec2(hx - h, hz - h) / e;
 float swell = perlin(q * 0.28 + vec2(-t * 0.17, t * 0.11));
 slope += vec2(0.22, 0.08) * swell;
 float camera_distance = length(CAMERA_POSITION_WORLD - world_pos);
 slope *= wave_strength * 1.65 * mix(1.0, 0.22, smoothstep(40.0, 220.0, camera_distance));
 vec3 world_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
 NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
 float radial = length(world_pos.xz);
 vec3 near_water = mix(lagoon_color, shallow_color, smoothstep(lagoon_radius, shallow_radius, radial));
 vec3 water_color = mix(near_water, deep_color, smoothstep(shallow_radius, deep_radius, radial));
 water_color = mix(water_color, dark_water, sunset_mix);
 ALBEDO = water_color * water_light;
 METALLIC = 0.0;
 SPECULAR = 0.5;
 ROUGHNESS = clamp(water_roughness + h * 0.045, 0.08, 0.42);
 EMISSION = water_color * base_fill;
}
"""
	sea_material.shader = shader
	water_surface.material_override = sea_material
	water_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water_surface)
	shore_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shore_foam)
	wet_shore.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wet_shore)
	add_child(horizon_lod)
	_build_celestial_bodies()
	_make_boat(Vector3(5, -0.08, -9), 0.5)
	_make_boat(Vector3(17, -0.08, 0), -0.8)
	_make_boat(Vector3(-3, -0.08, 12), 1.7)

func _build_celestial_bodies() -> void:
	sun_disc.texture = _celestial_texture(false)
	sun_disc.pixel_size = 0.30
	sun_disc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sun_disc.shaded = false
	sun_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sun_disc)
	moon_disc.texture = _celestial_texture(true)
	moon_disc.pixel_size = 0.24
	moon_disc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	moon_disc.shaded = false
	moon_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon_disc.visible = false
	add_child(moon_disc)
	celestial_from = _celestial_target("day")
	celestial_to = celestial_from
	sun_disc.position = celestial_to
	moon_disc.position = _moon_target()

func _celestial_texture(is_moon: bool) -> ImageTexture:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / float(size)
			var distance_to_center := uv.distance_to(Vector2(0.5, 0.5))
			var alpha := 1.0 - smoothstep(0.38, 0.50, distance_to_center)
			var glow := 1.0 - smoothstep(0.18, 0.49, distance_to_center)
			var color := Color(1.0, 0.93, 0.65, alpha * (0.48 + glow * 0.52))
			if is_moon:
				var crater := 0.0
				for center in [Vector2(0.38, 0.36), Vector2(0.61, 0.43), Vector2(0.47, 0.62)]:
					crater = maxf(crater, 1.0 - smoothstep(0.035, 0.085, uv.distance_to(center)))
				color = Color(0.82 - crater * 0.16, 0.88 - crater * 0.15, 1.0 - crater * 0.10, alpha)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _celestial_target(value: String) -> Vector3:
	# The camera orbits a ground focus and never points below the ocean, so the
	# sky bodies use compressed apparent elevations that remain visible near
	# the horizon while preserving dawn/day/sunset ordering.
	var azimuth := -140.0
	var elevation := 10.0
	match value:
		"dawn":
			azimuth = 105.0
			elevation = 6.0
		"sunset":
			azimuth = -105.0
			elevation = 5.0
		"night":
			azimuth = -145.0
			elevation = 9.0
	var azimuth_radians := deg_to_rad(azimuth)
	var elevation_radians := deg_to_rad(elevation)
	return Vector3(
		sin(azimuth_radians) * cos(elevation_radians),
		sin(elevation_radians),
		cos(azimuth_radians) * cos(elevation_radians)
	) * 260.0

func _moon_target() -> Vector3:
	return _celestial_target("night")

func _rebuild_horizon_lod() -> void:
	if model == null:
		return
	horizon_location = model.location_id
	for child in horizon_lod.get_children():
		horizon_lod.remove_child(child)
		child.queue_free()
	var base_color := Color("6e8e82")
	var accent_color := Color("d5c3a5")
	var height_scale := 4.0
	var distance_base := 145.0
	match model.location_id:
		"santorini":
			base_color = Color("6e625d")
			accent_color = Color("ece5da")
			height_scale = 11.0
			distance_base = 160.0
		"seychelles":
			base_color = Color("766f66")
			accent_color = Color("4f876b")
			height_scale = 6.0
			distance_base = 150.0
		"cape_cod":
			base_color = Color("9a9687")
			accent_color = Color("d5d0bd")
			height_scale = 3.0
			distance_base = 138.0
	var sun_away := sun_look_yaw() + PI
	for index in range(16):
		var angle := TAU * float(index) / 16.0 + 0.11
		if absf(angle_difference(angle, sun_away)) < deg_to_rad(28.0):
			continue
		var distance := distance_base + float(posmod(index * 17, 19))
		var width := 12.0 + float(posmod(index * 13, 9))
		var height := height_scale * (0.62 + float(posmod(index * 7, 10)) / 13.0)
		var piece := MeshInstance3D.new()
		var ridge := BoxMesh.new()
		ridge.size = Vector3(width, height * 0.55, 7.0 if model.location_id == "santorini" else 14.0)
		piece.mesh = ridge
		piece.position = Vector3(sin(angle) * distance, height * 0.12, cos(angle) * distance)
		piece.rotation.y = angle
		piece.material_override = _distant_material(base_color.darkened(0.18 + float(posmod(index, 4)) * 0.03))
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		horizon_lod.add_child(piece)
		if model.location_id == "santorini" and index % 3 == 0:
			_add_distant_box(piece.position + Vector3(0, height * 0.62, 0), Vector3(4.8, 2.4, 3.8), accent_color)
		elif model.location_id == "quanzhou" and index % 5 == 0:
			_add_distant_tower(piece.position + Vector3(0, height * 0.5 + 2.7, 0), accent_color, 5.5)
		elif model.location_id == "seychelles" and index % 4 == 0:
			_add_distant_tower(piece.position + Vector3(0, height * 0.5 + 2.0, 0), accent_color, 4.0)
	_add_location_landmark(model.location_id, accent_color, distance_base)

func _distant_material(color: Color) -> StandardMaterial3D:
	var material := _material(color.darkened(0.12))
	material.roughness = 1.0
	material.metallic = 0.0
	return material

func _add_distant_box(position_value: Vector3, size_value: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = _distant_material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	horizon_lod.add_child(instance)

func _add_distant_tower(position_value: Vector3, color: Color, height: float) -> void:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.45
	mesh.bottom_radius = 0.72
	mesh.height = height
	mesh.radial_segments = 8
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = _distant_material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	horizon_lod.add_child(instance)

func _add_location_landmark(id_value: String, color: Color, distance: float) -> void:
	var position_value := Vector3(-distance * 0.72, 3.0, -distance * 0.69)
	if id_value == "cape_cod":
		_add_distant_tower(position_value + Vector3(0, 6.0, 0), Color("e8e5dd"), 12.0)
	elif id_value == "quanzhou":
		_add_distant_tower(position_value + Vector3(0, 4.0, 0), Color("b7755d"), 8.0)
	elif id_value == "santorini":
		for offset in [Vector3(-4, 0, 0), Vector3(0, 1.5, 0), Vector3(4, 3.0, 0)]:
			_add_distant_box(position_value + offset, Vector3(3.5, 2.8, 3.5), color)

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
	_rebuild_shore_foam()

func _rebuild_shore_foam() -> void:
	var vertices := PackedVector3Array()
	var wet_vertices := PackedVector3Array()
	var wet_normals := PackedVector3Array()
	var foam_width := 0.30
	var foam_y := -0.145
	for cell: Vector3i in model.cells:
		if cell.y != 0 or not _is_voxel(model.cells[cell]):
			continue
		var directions := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK]
		var coast_directions: Array[Vector3i] = []
		for direction: Vector3i in directions:
			var neighbor := model.get_cell(cell + direction)
			if not neighbor.is_empty() and _is_voxel(neighbor):
				continue
			coast_directions.append(direction)
		if coast_directions.is_empty():
			continue
		var kind := str(model.cells[cell].get("kind", ""))
		if kind in ["sand", "grass", "stone", "granite"]:
			var wet_y := float(cell.y) + 1.004
			for vertex in [
				Vector3(cell.x, wet_y, cell.z),
				Vector3(cell.x, wet_y, cell.z + 1),
				Vector3(cell.x + 1, wet_y, cell.z + 1),
				Vector3(cell.x, wet_y, cell.z),
				Vector3(cell.x + 1, wet_y, cell.z + 1),
				Vector3(cell.x + 1, wet_y, cell.z),
			]:
				wet_vertices.append(vertex)
				wet_normals.append(Vector3.UP)
		for direction: Vector3i in coast_directions:
			var a := Vector3.ZERO
			var b := Vector3.ZERO
			var c := Vector3.ZERO
			var d := Vector3.ZERO
			if direction == Vector3i.RIGHT:
				a = Vector3(cell.x + 1.0, foam_y, cell.z)
				b = Vector3(cell.x + 1.0, foam_y, cell.z + 1.0)
				c = b + Vector3(foam_width, 0, 0)
				d = a + Vector3(foam_width, 0, 0)
			elif direction == Vector3i.LEFT:
				a = Vector3(cell.x, foam_y, cell.z + 1.0)
				b = Vector3(cell.x, foam_y, cell.z)
				c = b + Vector3(-foam_width, 0, 0)
				d = a + Vector3(-foam_width, 0, 0)
			elif direction == Vector3i.FORWARD:
				a = Vector3(cell.x, foam_y, cell.z)
				b = Vector3(cell.x + 1.0, foam_y, cell.z)
				c = b + Vector3(0, 0, -foam_width)
				d = a + Vector3(0, 0, -foam_width)
			else:
				a = Vector3(cell.x + 1.0, foam_y, cell.z + 1.0)
				b = Vector3(cell.x, foam_y, cell.z + 1.0)
				c = b + Vector3(0, 0, foam_width)
				d = a + Vector3(0, 0, foam_width)
			for vertex in [a, b, c, a, c, d]:
				vertices.append(vertex)
	if vertices.is_empty():
		shore_foam.mesh = null
	else:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var foam_mesh := ArrayMesh.new()
		foam_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var foam_material := ShaderMaterial.new()
		var foam_shader := Shader.new()
		foam_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
varying vec3 world_pos;
void vertex(){ world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
 float ripple = sin((world_pos.x + world_pos.z) * 7.0 + TIME * 1.7) * 0.5 + 0.5;
 float shimmer = sin((world_pos.x - world_pos.z) * 13.0 - TIME * 2.3) * 0.5 + 0.5;
 float broken = smoothstep(0.42, 0.78, ripple * 0.62 + shimmer * 0.38);
 ALBEDO = mix(vec3(0.86, 0.94, 0.95), vec3(1.0), ripple);
 ALPHA = broken * (0.20 + ripple * 0.28);
}"""
		foam_material.shader = foam_shader
		foam_mesh.surface_set_material(0, foam_material)
		shore_foam.mesh = foam_mesh
	if wet_vertices.is_empty():
		wet_shore.mesh = null
		return
	var wet_arrays: Array = []
	wet_arrays.resize(Mesh.ARRAY_MAX)
	wet_arrays[Mesh.ARRAY_VERTEX] = wet_vertices
	wet_arrays[Mesh.ARRAY_NORMAL] = wet_normals
	var wet_mesh := ArrayMesh.new()
	wet_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wet_arrays)
	var sand_color := Color(str(model.definition("sand").get("color", "d9c89f"))).darkened(0.28)
	var wet_material := _material(sand_color)
	wet_material.roughness = 0.22
	wet_material.metallic = 0.0
	wet_mesh.surface_set_material(0, wet_material)
	wet_shore.mesh = wet_mesh

func _add_prop(cell: Vector3i, item: Dictionary) -> void:
	var kind := str(item["kind"])
	var root := Node3D.new()
	root.position = Vector3(cell) + Vector3(0.5, 0, 0.5)
	var variant := model.connection_variant(cell)
	var visual := _visual(kind, variant)
	visual.rotation.y = float(item.get("rot", 0)) * PI / 2.0
	_harden_building_materials(visual)
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

func _harden_building_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var source: Material = node.material_override
		if source == null:
			source = node.get_active_material(0)
		if source is StandardMaterial3D:
			var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
			material.roughness = maxf(material.roughness, 0.78)
			material.metallic = minf(material.metallic, 0.04)
			material.ao_enabled = true
			material.ao_light_affect = 0.35
			node.material_override = material
	for child in node.get_children():
		_harden_building_materials(child)

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
	phase_from_night = night
	celestial_from = sun_disc.position
	celestial_to = _celestial_target(value)
	water_light_from = water_light
	water_light_to = _water_light_for_phase(value)
	phase_from = _current_environment_state()
	phase_to = _styled_phase(value, model.location.phase(value))
	if weather_fog and model.location.fog_density_weather > 0.0:
		phase_to["fog_density"] = model.location.fog_density_weather
	_apply_location_water()
	phase = value
	night = value == "night"
	tropical_fill.visible = model.location_id == "seychelles" and not night
	phase_blend = 0.0 if animated else 1.0
	_apply_environment_blend(phase_blend)
	_rebuild_horizon_lod()

func _styled_phase(value: String, source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	var azimuths := {"dawn": 105.0, "day": -140.0, "sunset": -105.0, "night": -145.0}
	result["sun_rotation_y"] = float(azimuths.get(value, -30.0))
	if value != "sunset":
		return result
	# Sunset is the cinematic/photo phase. Preserve each location's base
	# palette while converging on a readable gold backlight and warm haze.
	var horizon := Color(str(result.get("background", "e6c59b"))).lerp(Color("e2c79f"), 0.68)
	var sky_top := Color(str(result.get("sky_top", "b76543"))).lerp(Color("b96747"), 0.62)
	var location_sun := Color(str(result.get("sun", "ffd29a")))
	result["background"] = horizon.to_html(false)
	result["sky_top"] = sky_top.to_html(false)
	result["ambient"] = Color(str(result.get("ambient", "8f8494"))).lerp(Color("8f8494"), 0.72).to_html(false)
	result["ambient_energy"] = clampf(float(result.get("ambient_energy", 0.32)), 0.30, 0.38)
	result["sun"] = location_sun.lerp(Color("ffd29a"), 0.78).to_html(false)
	result["sun_energy"] = clampf(float(result.get("sun_energy", 1.0)), 1.0, 1.60)
	result["sun_rotation_x"] = -12.0
	result["fog"] = horizon.darkened(0.06).to_html(false)
	return result

func set_cinematic(value: bool) -> void:
	cinematic = value
	if not phase_to.is_empty():
		_apply_environment_blend(phase_blend)

func sun_look_yaw() -> float:
	var to_sun := sun.global_transform.basis.z
	return atan2(-to_sun.x, -to_sun.z)

func sun_look_pitch() -> float:
	return deg_to_rad(11.0)

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
		"sun_rotation_y": sun.rotation_degrees.y,
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
	var location_wave_scale := float(water.get("wave_scale", 0.75))
	sea_material.set_shader_parameter("wave_scale", location_wave_scale)
	sea_material.set_shader_parameter("wave_speed", float(water.get("wave_speed", 0.5)))
	sea_material.set_shader_parameter("wave_strength", 0.055 + minf(location_wave_scale, 1.6) * 0.025)
	sea_material.set_shader_parameter("dark_water", Color(0.16, 0.20, 0.19))

func set_viewer_position(value: Vector3) -> void:
	viewer_position = value

func _water_light_for_phase(value: String) -> float:
	match value:
		"dawn":
			return 0.86
		"sunset":
			return 0.78
		"night":
			return 0.46
	return 1.0

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
	water_light = lerpf(water_light_from, water_light_to, weight)
	sea_material.set_shader_parameter("water_light", water_light)
	sea_material.set_shader_parameter("sunset_mix", 0.62 if phase == "sunset" else (0.18 if phase == "night" else 0.0))
	sea_material.set_shader_parameter("water_roughness", 0.16 if phase == "sunset" else (0.28 if phase == "night" else 0.22))
	sea_material.set_shader_parameter("base_fill", 0.04 if phase == "night" else 0.025)
	environment.fog_light_color = _mix_color("fog", weight)
	environment.ambient_light_color = _mix_color("ambient", weight)
	environment.fog_density = lerpf(float(phase_from.get("fog_density", phase_to.get("fog_density", 0.0035))), float(phase_to.get("fog_density", 0.0035)), weight)
	var ambient_energy := lerpf(float(phase_from.get("ambient_energy", environment.ambient_light_energy)), float(phase_to.get("ambient_energy", 0.3)), weight)
	if not cinematic and phase == "sunset":
		ambient_energy = minf(ambient_energy + 0.14, 0.52)
	environment.ambient_light_energy = ambient_energy
	sun.light_color = _mix_color("sun", weight)
	sun.light_energy = lerpf(float(phase_from.get("sun_energy", phase_to.get("sun_energy", 0.5))), float(phase_to.get("sun_energy", 0.5)), weight)
	var rotation_x := lerpf(float(phase_from.get("sun_rotation_x", sun.rotation_degrees.x)), float(phase_to.get("sun_rotation_x", -48.0)), weight)
	sun.rotation_degrees.x = rotation_x
	var rotation_y := lerp_angle(
		deg_to_rad(float(phase_from.get("sun_rotation_y", sun.rotation_degrees.y))),
		deg_to_rad(float(phase_to.get("sun_rotation_y", -30.0))),
		weight
	)
	sun.rotation_degrees.y = rad_to_deg(rotation_y)
	environment.glow_enabled = phase in ["sunset", "night"]
	sky_material.sun_angle_max = 12.0 if phase == "sunset" else (6.0 if phase == "night" else 8.0)
	sky_material.sun_curve = 0.18 if phase == "sunset" else 0.10
	build_fill.visible = not cinematic
	build_fill.light_energy = 0.28 if phase == "sunset" else (0.12 if phase == "night" else 0.18)
	build_fill.rotation_degrees = Vector3(-28, sun.rotation_degrees.y + 160.0, 0)
	sun_disc.position = celestial_from.lerp(celestial_to, weight)
	moon_disc.position = _moon_target()
	var target_night := phase == "night"
	var sun_alpha := lerpf(0.0 if phase_from_night else 1.0, 0.0 if target_night else 1.0, weight)
	var moon_alpha := lerpf(1.0 if phase_from_night else 0.0, 1.0 if target_night else 0.0, weight)
	var disc_color := _mix_color("sun", weight).lightened(0.18)
	var sun_boost := 1.7 if phase == "sunset" else 1.15
	sun_disc.modulate = Color(disc_color.r * sun_boost, disc_color.g * sun_boost, disc_color.b * sun_boost, sun_alpha)
	moon_disc.modulate = Color(1.02, 1.10, 1.25, moon_alpha)
	# ProceduralSky already draws the sun disk; the extra sprite punched a
	# dark hole into the glitter path when the camera faced the light.
	sun_disc.visible = false
	moon_disc.visible = moon_alpha > 0.01
