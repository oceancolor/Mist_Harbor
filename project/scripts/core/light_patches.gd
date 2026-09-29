class_name HarborLightPatches
extends MultiMeshInstance3D

## A-1 材质族 · 共享光斑贴片（MH-ENG-002b）
##
## 四地点共用的唯一光表现手段：零真实点光源 / 零灯光预算 / 零全岛重建。
##
## 🔴 R-ENG-19：这里**刻意不用自定义 shader**——自定义 shader 一旦输出 ALPHA
## （透明管线）在 Web 导出里静默不渲染（见 daylight.gd 顶部证据链）。
## 改用 StandardMaterial3D + 径向渐变贴图 + MultiMesh 实例颜色，实测可渲染。
## 「次第亮起」依旧只写实例颜色，不动任何网格。
##
## 两条硬纪律（不变）：
##   1. 运行时**绝不**改 `instance_count`，只改 `visible_instance_count`。
##   2. 材质只有一个，创建于 _ready；rebuild/set_strength 都是 O(n) 写实例数据。

const CAPACITY := 512
const SEQUENCE_STEP := 0.15

var _entries: Array = []
var _strength: float = 0.0
var _sequence_time: float = -1.0
var _sequence_total: float = 0.0
var _sequence_step_value: float = SEQUENCE_STEP
var _sequence_active: bool = false


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	material_override = _patch_material()
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 径向柔边贴图：中心 alpha 1 → 边缘 0，近似原 shader 的 pow(1-d, 1.7) 衰减。
static func _patch_material() -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 128
	texture.height = 128
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	material.disable_receive_shadows = true
	return material


## entries: [{position: Vector3, normal: Vector3, radius: float, color: Color, order: float}]
func rebuild(entries: Array) -> void:
	_entries = entries
	var count := mini(entries.size(), CAPACITY)
	multimesh.visible_instance_count = count
	for i in range(count):
		var entry: Dictionary = entries[i]
		var position_value: Vector3 = entry.get("position", Vector3.ZERO)
		var normal: Vector3 = entry.get("normal", Vector3.UP)
		var radius := float(entry.get("radius", 1.5))
		var basis := Basis()
		if absf(normal.y) > 0.7:
			basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
		else:
			var right := Vector3.UP.cross(normal).normalized()
			if right.length_squared() < 0.001:
				right = Vector3.RIGHT
			var up := normal.cross(right).normalized()
			basis = Basis(right, up, normal)
		var transform := Transform3D(basis, position_value + normal * 0.03)
		transform = transform.scaled(Vector3(radius * 2.0, radius * 2.0, 1.0))
		multimesh.set_instance_transform(i, transform)
	_refresh_colors()


func set_strength(value: float) -> void:
	_strength = clampf(value, 0.0, 1.0)
	_sequence_time = -1.0
	_sequence_active = false
	_refresh_colors()


## 泉州「灯火次第亮起」：按 order 从水边到内陆 0.15s/ 栋依次点亮。
func play_sequence(step: float = SEQUENCE_STEP) -> void:
	if _entries.is_empty():
		return
	_sequence_step_value = step
	_sequence_time = 0.0
	var max_order := 0.0
	for entry in _entries:
		max_order = maxf(max_order, float(entry.get("order", 0.0)))
	_sequence_total = max_order * step + 0.4
	_sequence_active = true


func _process(delta: float) -> void:
	if not _sequence_active:
		return
	_sequence_time += delta
	if _sequence_time >= _sequence_total:
		_sequence_active = false
	_refresh_colors()


func _refresh_colors() -> void:
	for i in range(multimesh.visible_instance_count):
		var entry: Dictionary = _entries[i]
		var color: Color = entry.get("color", Color("ffbd70"))
		var alpha := _strength
		if _sequence_active:
			var order := float(entry.get("order", 0.0)) * _sequence_step_value
			alpha = _strength * clampf((_sequence_time - order) / 0.35, 0.0, 1.0)
		multimesh.set_instance_color(i, Color(color.r, color.g, color.b, alpha))
