class_name HarborAmbientLife
extends RefCounted

## 水面与人文点缀（初代手感的回归）：渔船/帆船/浮标——各地点共用，随波轻摇。
## 船是视觉装饰，不进世界模型、不占格子、不参与机制。

static func make_boat(sail_color: Color = Color("f1e5ce"), hull_color: Color = Color("9b7058")) -> Node3D:
	var boat := Node3D.new()
	var hull := MeshInstance3D.new()
	var hull_mesh := PrismMesh.new()
	hull_mesh.size = Vector3(0.65, 0.28, 1.75)
	hull.mesh = hull_mesh
	hull.rotation.z = PI
	hull.material_override = _paint(hull_color)
	boat.add_child(hull)
	var mast := MeshInstance3D.new()
	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = 0.026
	mast_mesh.bottom_radius = 0.026
	mast_mesh.height = 1.75
	mast.mesh = mast_mesh
	mast.position.y = 0.85
	mast.material_override = _paint(Color("b39170"))
	boat.add_child(mast)
	var sail := MeshInstance3D.new()
	var sail_mesh := ImmediateMesh.new()
	sail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [Vector3(0, 1.68, 0), Vector3(0, 0.30, 0.85), Vector3(0, 0.30, 0.03)]:
		sail_mesh.surface_add_vertex(vertex)
	sail_mesh.surface_end()
	sail.mesh = sail_mesh
	sail.material_override = _paint(sail_color)
	boat.add_child(sail)
	return boat


static func make_buoy(color: Color = Color("C25B4A"), glow: float = 0.0) -> Node3D:
	var node := Node3D.new()
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.16
	body_mesh.height = 0.32
	body_mesh.radial_segments = 8
	body_mesh.rings = 4
	body.mesh = body_mesh
	body.material_override = _paint(color)
	if glow > 0.0:
		body.material_override.emission_enabled = true
		body.material_override.emission = color
		body.material_override.emission_energy_multiplier = glow
	node.add_child(body)
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.02
	pole_mesh.bottom_radius = 0.02
	pole_mesh.height = 0.5
	pole.mesh = pole_mesh
	pole.position.y = 0.3
	pole.material_override = _paint(Color("6f7470"))
	node.add_child(pole)
	return node


static func _paint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


## 简易锚定：让一组装饰物随波轻微起伏（由各地点 mechanic 的 tick 驱动）。
static func bob(node: Node3D, time_value: float, phase: float, base_y: float) -> void:
	node.position.y = base_y + sin(time_value * 0.9 + phase) * 0.05
	node.rotation.z = sin(time_value * 0.7 + phase * 1.3) * 0.04
	node.rotation.x = sin(time_value * 0.6 + phase * 0.7) * 0.03


## 飞鸟（泉州晨鹭 / 夜鹭剪影）：小身躯 + 一对扑翼，扇翅由 tick 驱动。
static func make_bird(color: Color = Color.WHITE, scale_factor: float = 1.0) -> Node3D:
	var bird := Node3D.new()
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.5, 0.09, 0.14) * scale_factor
	body.mesh = body_mesh
	body.material_override = _paint(color)
	bird.add_child(body)
	var wings := Node3D.new()
	wings.name = "Wings"
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wing_mesh := BoxMesh.new()
		wing_mesh.size = Vector3(0.2, 0.03, 0.44) * scale_factor
		wing.mesh = wing_mesh
		wing.material_override = _paint(color)
		wing.position = Vector3(0, 0, side * 0.22 * scale_factor)
		wings.add_child(wing)
	bird.add_child(wings)
	return bird


## 扑翼（tick 驱动；头部在 -Z， Wings 绕 X 轴上下扇）。
static func flap(bird: Node3D, time_value: float, phase: float = 0.0) -> void:
	var wings := bird.get_node_or_null("Wings") as Node3D
	if wings != null:
		wings.rotation.x = sin(time_value * 9.0 + phase) * 0.55
