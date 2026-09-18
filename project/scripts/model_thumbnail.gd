extends Node
class_name ModelThumbnails

## Renders build-dock icons from the actual GLB files at runtime and caches them.
## New materials therefore need no icon code: drop the GLB + palette entry and the
## dock picks it up. If rendering is unavailable (headless, dummy driver) nothing
## is cached and the caller keeps its hand-drawn fallback.

signal thumbnail_ready(kind: String)

const SIZE := 96
const MANIFEST := "res://assets/models/manifest.json"

var _cache: Dictionary = {}
var _bounds: Dictionary = {}
var _queue: Array[String] = []
var _busy := false
var _viewport: SubViewport
var _camera: Camera3D
var _root: Node3D

func _ready() -> void:
	_load_bounds()

func has(kind: String) -> bool:
	return _cache.has(kind)

func texture_for(kind: String) -> Texture2D:
	return _cache.get(kind)

func request(kinds: Array) -> void:
	for value in kinds:
		var kind := str(value)
		if _cache.has(kind) or _queue.has(kind):
			continue
		_queue.append(kind)
	if not _busy:
		_render_next()

func _load_bounds() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not parsed is Dictionary:
		return
	for asset in (parsed as Dictionary).get("assets", []):
		_bounds[str(asset["id"])] = asset.get("bounds", {}).get("godot_size", [1.0, 1.0, 1.0])

func _render_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var kind: String = _queue.pop_front()
	await _render_one(kind)
	_render_next()

func _render_one(kind: String) -> void:
	var path := "res://assets/models/%s.glb" % [kind]
	if not ResourceLoader.exists(path):
		return
	_ensure_stage()
	if _viewport == null:
		return
	var packed: Resource = load(path)
	if not packed is PackedScene:
		return
	var instance: Node = (packed as PackedScene).instantiate()
	_root.add_child(instance)
	_frame(kind)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	instance.queue_free()
	if image == null or image.is_empty() or not _has_content(image):
		return
	_cache[kind] = ImageTexture.create_from_image(image)
	thumbnail_ready.emit(kind)

func _frame(kind: String) -> void:
	var size_values: Array = _bounds.get(kind, [1.0, 1.0, 1.0])
	var height := maxf(0.25, float(size_values[1]))
	var span := maxf(0.3, maxf(float(size_values[0]), float(size_values[2])))
	var center := Vector3(0, height * 0.5, 0)
	var radius := maxf(span, height) * 0.72
	var distance := radius / tan(deg_to_rad(_camera.fov * 0.5)) * 1.15
	var direction := Vector3(0.68, 0.6, 0.68).normalized()
	_camera.position = center + direction * distance
	_camera.look_at_from_position(_camera.position, center, Vector3.UP)

func _has_content(image: Image) -> bool:
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			if image.get_pixel(x, y).a > 0.06:
				return true
	return false

func _ensure_stage() -> void:
	if _viewport != null:
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.own_world_3d = true
	add_child(_viewport)
	_root = Node3D.new()
	_viewport.add_child(_root)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	_viewport.add_child(_camera)
	_camera.make_current()
	var key := DirectionalLight3D.new()
	key.position = Vector3(6, 9, 5)
	key.look_at_from_position(key.position, Vector3.ZERO, Vector3.UP)
	key.light_energy = 2.6
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.position = Vector3(-7, 4, -6)
	fill.look_at_from_position(fill.position, Vector3.ZERO, Vector3.UP)
	fill.light_energy = 1.1
	_viewport.add_child(fill)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 1, 1)
	environment.ambient_light_energy = 0.9
	world.environment = environment
	_viewport.add_child(world)
