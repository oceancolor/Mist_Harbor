class_name HarborBuildWorld
extends Node3D

## 世界渲染层。
##
## 关键纪律：
##   · MH-ENG-002a：暖光灯**不是**真实 OmniLight3D（全岛共享 8 盏上限 + 相机移动 pop），
##     改为灯体自发光 + 共享光斑贴片；本文件里不存在任何 OmniLight3D / SpotLight3D。
##   · 昼夜切换不再触发世界重建（原 set_night() 末尾的 needs_rebuild 已删除）：
##     `_apply_daylight()` 只写 uniform，是 O(1)。
##   · 光斑贴片是 MultiMesh，不改 instance_count，点亮 = 改一个实例颜色。

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
var decor := Node3D.new()
var shore_foam := MeshInstance3D.new()
var horizon_lod := Node3D.new()
var horizon_location := ""
var ghost := Node3D.new()
var ghost_kind: String = ""
var ghost_material := StandardMaterial3D.new()
var outline_material := StandardMaterial3D.new()
var needs_rebuild: bool = false
var daylight: HarborDaylight
var patches: HarborLightPatches
var scenes: Dictionary = {}
var visible_faces: int = 0
var weather_on: bool = false
var heatmap_on: bool = false

var _emissive: Array[StandardMaterial3D] = []
var _decorated_revision: int = -1
var _patch_revision: int = -1

var night: bool:
	get:
		return daylight != null and daylight.is_night()

var phase: int:
	get:
		return daylight.phase if daylight != null else HarborLocationProfile.Phase.DAY


func setup(source: HarborWorldModel) -> void:
	model = source
	daylight = HarborDaylight.new()
	daylight.name = "Daylight"
	add_child(daylight)
	daylight.setup(model.profile)
	patches = HarborLightPatches.new()
	patches.name = "LightPatches"
	add_child(patches)
	add_child(terrain)
	terrain.add_child(ground_body)
	ground_body.add_child(ground_collision)
	add_child(props)
	add_child(decor)
	add_child(ghost)
	add_child(shore_foam)
	add_child(horizon_lod)
	ghost.visible = false
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_material.albedo_color = Color(0.6, 0.92, 0.75, 0.48)
	ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.albedo_color = Color("effff1")
	_load_scenes()
	model.changed.connect(func() -> void: needs_rebuild = true)
	model.geometry_changed.connect(_invalidate_terrain)
	model.terrain_replaced.connect(func() -> void: _terrain_cache.clear())
	rebuild()
	_refresh_decor(true)


func _load_scenes() -> void:
	scenes.clear()
	for kind in model.palette:
		var entry: Dictionary = model.definition(kind)
		var mesh_value := str(entry.get("mesh", "cube"))
		if mesh_value != "cube" and not mesh_value.begins_with("proc:"):
			var path := "res://assets/models/" + mesh_value + ".glb"
			if ResourceLoader.exists(path):
				scenes[kind] = load(path)
			else:
				push_error("Required Blender asset missing: " + path)


func _process(delta: float) -> void:
	if needs_rebuild:
		needs_rebuild = false
		rebuild()
	_refresh_decor(false)
	model.mechanic.tick(delta)


# ── 昼夜 / 天气：唯一一条分支，四地共用 ──

func set_phase(target_phase: int, target_weather: bool = false, animate: bool = true) -> void:
	_apply_sunset_tuning()
	weather_on = target_weather and model.profile.has_weather_toggle
	daylight.apply_phase(target_phase, weather_on, animate)
	_apply_night_strength()
	_refresh_decor(true)


## 玩家调日落时实时生效：灌进渲染层，若正停在日落态就立刻重算（不播过渡动画）。
func _apply_sunset_tuning() -> void:
	if daylight == null:
		return
	daylight.set_sunset_overrides(model.sunset_tuning if model != null else {})

func apply_sunset_tuning() -> void:
	_apply_sunset_tuning()
	if daylight != null and daylight.phase == HarborLocationProfile.Phase.SUNSET:
		daylight.apply_phase(HarborLocationProfile.Phase.SUNSET, weather_on, false)
		_apply_night_strength()

func set_night(value: bool, animate: bool = true) -> void:
	set_phase(HarborLocationProfile.Phase.NIGHT if value else HarborLocationProfile.Phase.DAY, weather_on, animate)


func toggle_heatmap() -> bool:
	## 覆盖热力图：构图工具，不是评分；默认关闭（R-1：不给分数、不弹达成）。
	if not model.mechanic.has_method("set_heatmap_visible"):
		return false
	heatmap_on = not heatmap_on
	model.mechanic.set_heatmap_visible(decor, model.mechanic_state(), heatmap_on)
	return heatmap_on


func toggle_weather() -> bool:
	if not model.profile.has_weather_toggle:
		return false
	set_phase(daylight.phase, not weather_on)
	return true


func _apply_night_strength() -> void:
	var strength := daylight.night_strength()
	patches.set_strength(strength)
	for material in _emissive:
		material.emission_energy_multiplier = float(material.get_meta("base_emission", 2.2)) * strength


# ── 地形 / 道具 ──

var rebuild_metrics: Dictionary = {}
var _prop_batches: Dictionary = {}
var _terrain_cache: Dictionary = {}

func _invalidate_terrain(parts: Array) -> void:
	for part: Vector3i in parts:
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					_terrain_cache.erase(part + Vector3i(x, y, z))

func rebuild() -> void:
	var started := Time.get_ticks_usec()
	_prop_batches.clear()
	var relief := HarborBlockRelief.new(model)
	relief.div_cap = 2
	for child in props.get_children():
		props.remove_child(child)
		child.queue_free()
	_emissive.clear()
	# 先烘焙岸线距离场：水体波纹与滩涂过渡都依赖它。
	daylight.update_shore(model)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var blocks_rebuilt := 0
	visible_faces = 0
	for cell: Vector3i in model.cells:
		var item: Dictionary = model.cells[cell]
		var kind := str(item["kind"])
		var entry := model.definition(kind)
		if str(entry.get("mesh", "cube")) != "cube":
			_add_prop(cell, item)
			continue
		var base_color := Color(str(entry.get("color", "ffffff")))
		for part in model.footprint_cells(cell, kind, int(item.get("rot", 0))):
			var variation: float = float(posmod(part.x * 71 + part.z * 29 + part.y * 11, 11)) / 150.0
			var color := base_color.lightened(variation)
			if not _terrain_cache.has(part):
				var block := HarborBlockRelief.new(model)
				block.div_cap = relief.div_cap
				block.add_block(part, kind, color, color.darkened(0.1), color.darkened(0.28))
				_terrain_cache[part] = {"vertices": block.vertices(), "normals": block.normals(), "colors": block.colors()}
				blocks_rebuilt += 1
			relief.append_geometry(_terrain_cache[part])
			for face in FACES:
				var offset: Vector3i = face[0]
				if model.has_cell(part + offset) and str(model.definition(str(model.get_cell(part + offset).get("kind", "stone"))).get("mesh", "cube")) == "cube":
					continue
				visible_faces += 1
				var shaded := color
				if kind == "grass" and offset != Vector3i.UP:
					shaded = Color("adad87").lightened(variation)
				if kind == "stone" and part.y < 0:
					shaded = Color("93a99f").lightened(variation + float(part.y + 3) * 0.06)
				for i in [0, 2, 1, 0, 3, 2]:
					var corner: Vector3 = face[1][i]
					vertices.append(Vector3(part) + corner)
					normals.append(Vector3(offset))
					# 水下染色（§5 方案 B，流体折射配套）：海平面以下的顶点向深水色
					# 渐变——石基/滩涂的水下部分呈"浸在水中"的观感，被水面折射
					# 透视出来时是自然的水下色而不是干露的岩色。
					var final_color := shaded
					var world_corner_y: float = float(part.y) + corner.y
					if world_corner_y < -0.2:
						final_color = shaded.lerp(Color("2a6478"), 0.5)
					colors.append(final_color)
	if vertices.is_empty():
		terrain.mesh = null
		ground_collision.shape = null
	else:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = relief.vertices()
		arrays[Mesh.ARRAY_NORMAL] = relief.normals()
		arrays[Mesh.ARRAY_COLOR] = relief.colors()
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := _material(Color.WHITE, false)
		material.vertex_color_use_as_albedo = true
		mesh.surface_set_material(0, material)
		terrain.mesh = mesh
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(vertices)
		shape.backface_collision = true
		ground_collision.shape = shape
	_flush_prop_batches()
	_rebuild_shore_foam()
	_rebuild_horizon_lod()
	_rebuild_patches()
	rebuild_metrics = {"microseconds": Time.get_ticks_usec() - started, "vertices": relief.vertices().size(), "triangles": relief.face_count(), "collision_vertices": vertices.size(), "surfaces": 0 if terrain.mesh == null else terrain.mesh.get_surface_count(), "cells": model.cells.size(), "blocks_rebuilt": blocks_rebuilt, "prop_batches": _prop_batches.size()}



## 岸线浪花镶边（cursor_work 移植）：每条水线边贴 0.24m 泡沫条，波纹 shader
## 做 8-13Hz 的涟漪×闪光脉动——比水面 shader 里的 swash 更"咬"住岸线。
func _rebuild_shore_foam() -> void:
	var vertices := PackedVector3Array()
	var foam_width := 0.24
	var foam_y := -0.17
	for cell: Vector3i in model.cells:
		if cell.y != 0:
			continue
		var item: Dictionary = model.get_cell(cell)
		if str(model.definition(str(item.get("kind", "stone"))).get("mesh", "cube")) != "cube":
			continue
		for direction in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK]:
			if model.has_cell(cell + direction):
				continue   # 邻居有实体 = 不是水线边
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
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var foam_mesh := ArrayMesh.new()
	foam_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var foam_material := ShaderMaterial.new()
	var foam_shader := Shader.new()
	foam_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix, depth_draw_never;
varying vec3 world_pos;
void vertex(){ world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
 float ripple = sin((world_pos.x + world_pos.z) * 7.0 + TIME * 1.7) * 0.5 + 0.5;
 float shimmer = sin((world_pos.x - world_pos.z) * 13.0 - TIME * 2.3) * 0.5 + 0.5;
 ALBEDO = mix(vec3(0.86, 0.94, 0.95), vec3(1.0), ripple);
 ALPHA = 0.20 + ripple * 0.24 + shimmer * 0.08;
}"""
	foam_material.shader = foam_shader
	foam_mesh.surface_set_material(0, foam_material)
	shore_foam.mesh = foam_mesh


## 每地主题化远景环（cursor_work 移植，尺度收到天空球内）：16 件远山石/远城郭
## 绕岛一圈（120-143 格），切点随地点换色换形——泉州塔、圣托里尼白盒子。
func _rebuild_horizon_lod() -> void:
	if horizon_location == model.location_id:
		return
	horizon_location = model.location_id
	for child in horizon_lod.get_children():
		horizon_lod.remove_child(child)
		child.queue_free()
	var base_color := Color("6e8e82")
	var accent_color := Color("d5c3a5")
	var height_scale := 4.0
	var distance_base := 120.0
	match model.location_id:
		"santorini":
			base_color = Color("6e625d")
			accent_color = Color("ece5da")
			height_scale = 8.0
			distance_base = 126.0
		"seychelles":
			base_color = Color("766f66")
			accent_color = Color("4f876b")
			height_scale = 5.0
			distance_base = 122.0
		"cape-cod":
			base_color = Color("9a9687")
			accent_color = Color("d5d0bd")
			height_scale = 3.0
			distance_base = 118.0
	var hills := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	multi.mesh = unit
	multi.instance_count = 16
	hills.multimesh = multi
	var hill_material := _material(Color.WHITE)
	hill_material.vertex_color_use_as_albedo = true
	hill_material.roughness = 1.0
	hills.material_override = hill_material
	hills.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	horizon_lod.add_child(hills)
	for index in range(16):
		var angle := TAU * float(index) / 16.0 + 0.11
		var distance := distance_base + float(posmod(index * 17, 15))
		var width := 14.0 + float(posmod(index * 13, 9))
		var height := height_scale * (0.62 + float(posmod(index * 7, 10)) / 13.0)
		var position_value := Vector3(sin(angle) * distance, -1.4 + height * 0.28, cos(angle) * distance)
		var basis := Basis(Vector3.UP, angle) * Basis.from_scale(Vector3(width, height, width * 0.55))
		multi.set_instance_transform(index, Transform3D(basis, position_value))
		multi.set_instance_color(index, base_color.lerp(Color("c8d4d4"), 0.3).lightened(float(posmod(index, 4)) * 0.02))
		if model.location_id == "santorini" and index % 3 == 0:
			_add_distant_box(position_value + Vector3(0, height * 0.55, 0), Vector3(4.8, 2.0, 3.8), accent_color)
		elif model.location_id == "quanzhou" and index % 5 == 0:
			_add_distant_tower(position_value + Vector3(0, height * 0.4 + 2.2, 0), accent_color, 4.2)
		elif model.location_id == "seychelles" and index % 4 == 0:
			_add_distant_tower(position_value + Vector3(0, height * 0.4 + 1.6, 0), accent_color, 3.2)


func _add_distant_box(position_value: Vector3, size_value: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	instance.mesh = mesh
	instance.position = position_value
	var material := _material(color)
	material.roughness = 1.0
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	horizon_lod.add_child(instance)


func _add_distant_tower(position_value: Vector3, color: Color, height: float) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.6, height, 1.6)
	instance.mesh = mesh
	instance.position = position_value
	var material := _material(color)
	material.roughness = 1.0
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	horizon_lod.add_child(instance)


func _visual_top(part: Vector3i, kind: String) -> float:
	var relief := HarborBlockRelief.new(model)
	return float(part.y) + relief._top_height(part, 0.5, 0.5, HarborBlockRelief.relief_of(model.definition(kind)), [])


## 放在压低过的滩涂上的道具/幽灵要跟着下沉，避免悬空。
func _ground_sink(cell: Vector3i) -> float:
	var ground := cell + Vector3i.DOWN
	if not model.has_cell(ground):
		return 0.0
	var item: Dictionary = model.get_cell(ground)
	if not bool(item.get("natural", false)):
		return 0.0
	var kind := str(item["kind"])
	return float(ground.y) + 1.0 - _visual_top(ground, kind)


func _add_prop(cell: Vector3i, item: Dictionary) -> void:
	var kind := str(item["kind"])
	var entry := model.definition(kind)
	var rotation := int(item.get("rot", 0))
	var root := Node3D.new()
	root.position = Vector3(cell)
	root.position.y -= _ground_sink(cell)
	var visual := _visual(kind)
	# += 叠加（不是赋值）：center_offset 只补 x/z 中心，y 中心由各视觉路径自带
	# （默认立方体 y=h/2、proc 包裹层 y=0、GLB 场景内部自定）。
	visual.position += HarborFootprint.center_offset(entry, rotation)
	visual.rotation.y = float(rotation) * PI / 2.0
	if kind == "zayton":
		var growth := model.growth_pose(cell)
		visual.position += growth.offset
		visual.scale *= float(growth.scale)
	_collect_prop_meshes(visual, root.transform, kind)
	visual.free()
	var body := StaticBody3D.new()
	body.set_meta("cell", cell)
	var shape_node := CollisionShape3D.new()
	shape_node.shape = HarborFootprint.collision_shape(entry, rotation)
	shape_node.position = Vector3(
		float(HarborFootprint.rotated_size(HarborFootprint.size_of(entry), rotation).x) * 0.5,
		float(HarborFootprint.rotated_size(HarborFootprint.size_of(entry), rotation).y) * 0.5,
		float(HarborFootprint.rotated_size(HarborFootprint.size_of(entry), rotation).z) * 0.5)
	body.add_child(shape_node)
	root.add_child(body)
	props.add_child(root)


func _collect_prop_meshes(node: Node, parent_transform: Transform3D, key: String) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform *= node.transform
	if node is MeshInstance3D and node.mesh != null:
		if not _prop_batches.has(key):
			var mesh: Mesh = node.mesh
			for index in range(mesh.get_surface_count()):
				if node.get_surface_override_material(index) != null:
					mesh = mesh.duplicate()
					for surface in range(mesh.get_surface_count()):
						if node.get_surface_override_material(surface) != null:
							mesh.surface_set_material(surface, node.get_surface_override_material(surface))
					break
			_prop_batches[key] = {"mesh": mesh, "material": node.material_override, "transforms": []}
		_prop_batches[key].transforms.append(transform)
	for index in range(node.get_child_count()):
		_collect_prop_meshes(node.get_child(index), transform, key + "/" + str(index))

func _flush_prop_batches() -> void:
	for batch: Dictionary in _prop_batches.values():
		var instance := MultiMeshInstance3D.new()
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = batch.mesh
		mesh.instance_count = batch.transforms.size()
		for index in range(mesh.instance_count):
			mesh.set_instance_transform(index, batch.transforms[index])
		instance.multimesh = mesh
		instance.material_override = batch.material
		props.add_child(instance)

func _visual(kind: String) -> Node3D:
	var entry := model.definition(kind)
	var mesh_value := str(entry.get("mesh", "cube"))
	var emit := bool(entry.get("emit", false))
	if mesh_value.begins_with("proc:"):
		var key := mesh_value.substr(5)
		var built := HarborProcKit.build(key, Color(str(entry.get("color", "ffffff"))), emit)
		# proc 几何是角点基准（局部原点=足迹最小角，几何占 [0..size]）；包一层容器
		# 平移 −size/2，统一成「视觉局部原点=足迹中心」约定——与 center_offset、
		# 幽灵预览、碰撞盒共用同一基准（2026-09-27 幽灵错位修复）。
		var authored := HarborFootprint.size_of(entry)
		var wrapper := Node3D.new()
		wrapper.position = -Vector3(authored.x * 0.5, 0.0, authored.z * 0.5)
		wrapper.add_child(built)
		return wrapper
	if scenes.has(kind):
		return (scenes[kind] as PackedScene).instantiate() as Node3D
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.98, model.item_height(kind), 0.98)
	instance.mesh = box
	instance.position.y = box.size.y * 0.5
	instance.material_override = _material(Color(str(entry.get("color", "ffffff"))), emit)
	return instance


func _material(color: Color, emit: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.88
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emit:
		result.emission_enabled = true
		result.emission = Color("ffbd70")
		result.emission_energy_multiplier = 3.4
		result.set_meta("base_emission", 3.4)
		_emissive.append(result)
	return result


# ── 共享光斑贴片（A-1 材质族）──

func _rebuild_patches() -> void:
	var entries: Array = []
	var state := model.mechanic_state()
	var order_table: Dictionary = state.get("lamp_order", {})
	for cell: Vector3i in model.cells:
		var entry := model.definition(str(model.cells[cell]["kind"]))
		var patch: Variant = entry.get("patch", null)
		if not patch is Dictionary:
			continue
		var height := model.item_height(str(model.cells[cell]["kind"]))
		# 光斑贴在灯脚下的地面视觉顶上（滩涂被压低时贴片跟着落，不悬空）。
		var ground := cell + Vector3i.DOWN
		var ground_top := _visual_top(ground, str(model.get_cell(ground).get("kind", "stone"))) \
			if model.has_cell(ground) else float(cell.y) + 0.05
		entries.append({
			"position": Vector3(float(cell.x) + 0.5, ground_top + 0.06, float(cell.z) + 0.5),
			"normal": Vector3.UP,
			"radius": float((patch as Dictionary).get("radius", 1.5)),
			"color": HarborLocationProfile.hex((patch as Dictionary).get("color", "ffbd70")),
			"order": float(order_table.get(cell, 0.0)),
		})
	patches.rebuild(entries)
	_apply_night_strength()
	if not order_table.is_empty():
		patches.play_sequence()


# ── 地点机制的视觉表现 ──

func _refresh_decor(force: bool) -> void:
	if not force and _decorated_revision == model.revision:
		return
	_decorated_revision = model.revision
	var state := model.mechanic_state()
	state["phase"] = daylight.phase          # 晨夜生态：机制侧按态切换点缀（2026-09-28）
	state["weather_on"] = weather_on
	model.mechanic.decorate(decor, state)


# ── 拾取与幽灵 ──

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
		# 滩涂顶面被压低后，floor(命中点) 会落回地形格本身；命中自然格顶面时向上取放置位。
		if not collider.has_meta("cell") and normal.y > 0.5 and model.has_cell(cell) \
				and bool(model.get_cell(cell).get("natural", false)):
			candidate = cell + Vector3i.UP
		if collider.has_meta("cell"):
			cell = collider.get_meta("cell")
			var height := model.item_height(str(model.get_cell(cell).get("kind", "stone")))
			if normal.y > 0.5:
				candidate = cell + Vector3i(0, height, 0)
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
		# 视觉包在 Pivot 里：Pivot 每次【绝对赋值】center_offset + 旋转（视觉子节点
		# 跨格子复用，+= 会累积漂移）。结构与 _add_prop 同构：角点 root → 中心 Pivot
		# → 视觉；线框按旋转后足迹从角点画，不随节点二次旋转。
		# 旧实现漏了 center_offset 且整体绕角点旋转——绿色幽灵恒偏左上半个格子
		# （2026-09-27 用户截图反馈）。
		var visual := _visual(kind)
		_tint_ghost(visual)
		var pivot := Node3D.new()
		pivot.name = "Pivot"
		pivot.add_child(visual)
		ghost.add_child(pivot)
		var border := MeshInstance3D.new()
		border.mesh = _wire_mesh(model.definition(kind), rotation)
		border.material_override = outline_material
		border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(border)
	var pivot_node := ghost.get_node("Pivot") as Node3D
	var entry := model.definition(kind)
	pivot_node.position = HarborFootprint.center_offset(entry, rotation)
	pivot_node.rotation.y = float(rotation) * PI / 2.0
	ghost_material.albedo_color = Color(0.38, 0.88, 0.72, 0.48) if valid and not removing else Color(0.94, 0.42, 0.31, 0.42)
	ghost.position = Vector3(cell) + Vector3(0.0, 0.012, 0.0)
	ghost.position.y -= _ground_sink(cell)
	ghost.visible = model.in_bounds(cell, kind, rotation)


func _wire_mesh(entry: Dictionary, rotation: int) -> ImmediateMesh:
	var size_value := HarborFootprint.rotated_size(HarborFootprint.size_of(entry), rotation)
	var wire := ImmediateMesh.new()
	var points: Array[Vector3] = [
		Vector3(0, 0, 0), Vector3(size_value.x, 0, 0),
		Vector3(size_value.x, 0, size_value.z), Vector3(0, 0, size_value.z),
	]
	wire.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(4):
		var j := (i + 1) % 4
		for p in [
			points[i] - Vector3(0.02, 0, 0.02), points[j] - Vector3(0.02, 0, 0.02),
			points[i] + Vector3(0.02, size_value.y, 0.02), points[j] + Vector3(0.02, size_value.y, 0.02),
			points[i] - Vector3(0.02, 0, 0.02), points[i] + Vector3(0.02, size_value.y, 0.02),
		]:
			wire.surface_add_vertex(p)
	wire.surface_end()
	return wire


func _tint_ghost(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = ghost_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_tint_ghost(child)
