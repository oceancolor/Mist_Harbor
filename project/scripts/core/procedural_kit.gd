class_name HarborProcKit
extends RefCounted

## 程序化占位几何（低多边形 / 纯色 / 无贴图 / 无骨骼）。
##
## 用途：把四个地点的新建材先做成可玩的几何，资产管线（见 3D tools config/）产出
## GLB 后，只需把建材表的 `mesh` 从 `proc:<key>` 改成 `<glb 名>` 即可替换，不需要动代码。
##
## 纪律：单件 ≤ 600 面（godot-web-perf.md §2 硬顶）；emission 走 StandardMaterial3D
## 标准分支，不新增 shader 排列。

static var CACHE: Dictionary = {}

static func has(key: String) -> bool:
	return CACHE.has(key) or key in [
		"mansion", "oyster", "ridge", "beacon", "zayton", "banyan",
		"whitehouse", "bluedome", "cavehouse", "bougainvillea", "vine",
		"warmhouse", "windmill",
		"boulder", "boulder_mid", "wedge", "creole", "coco", "tortoise",
		"highland", "nauset", "fogstation", "shingle", "buoy",
		"palm", "shrub", "reeds", "pine", "beachgrass", "church",
		"medgarden", "pergola", "resort", "golf",
	]


static func build(key: String, color: Color, emit: bool = false) -> Node3D:
	if not CACHE.has(key):
		CACHE[key] = _create(key)
	var template: Node3D = CACHE[key]
	var node := template.duplicate() as Node3D
	_tint(node, color, emit)
	return node


static func _tint(node: Node, color: Color, emit: bool) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		var material: Material = instance.material_override
		if material == null:
			material = instance.get_surface_override_material(0)
		if material is StandardMaterial3D:
			var clone := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
			if clone.albedo_color == Color("ffffff"):
				clone.albedo_color = color
			if emit and bool(node.get_meta("emissive", false)):
				clone.emission_enabled = true
				clone.emission = Color("ffbd70")
				clone.emission_energy_multiplier = 2.2
			instance.material_override = clone
	for child in node.get_children():
		_tint(child, color, emit)


static func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.vertex_color_use_as_albedo = false
	return material


static func _box(parent: Node, size_value: Vector3, position_value: Vector3, color: Color,
		rotation_value: Vector3 = Vector3.ZERO, emissive: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	instance.rotation = rotation_value
	instance.material_override = _mat(color)
	instance.set_meta("emissive", emissive)
	parent.add_child(instance)
	return instance


static func _cylinder(parent: Node, radius: float, height: float, position_value: Vector3,
		color: Color, sides: int = 8, emissive: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = _mat(color)
	instance.set_meta("emissive", emissive)
	parent.add_child(instance)
	return instance


static func _cone(parent: Node, radius: float, height: float, position_value: Vector3,
		color: Color, sides: int = 8) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = _mat(color)
	parent.add_child(instance)
	return instance


static func _sphere(parent: Node, radius: float, position_value: Vector3, color: Color,
		scale_value: Vector3 = Vector3.ONE, rings: int = 5, sides: int = 8) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = sides
	mesh.rings = rings
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	instance.scale = scale_value
	instance.material_override = _mat(color)
	parent.add_child(instance)
	return instance


static func _create(key: String) -> Node3D:
	var root := Node3D.new()
	root.name = "proc_" + key
	match key:
		"mansion": _mansion(root)
		"oyster": _oyster(root)
		"ridge": _ridge(root)
		"beacon": _beacon(root)
		"zayton": _zayton(root)
		"banyan": _banyan(root)
		"whitehouse": _whitehouse(root)
		"bluedome": _bluedome(root)
		"cavehouse": _cavehouse(root)
		"warmhouse": _warmhouse(root)
		"windmill": _windmill(root)
		"bougainvillea": _bougainvillea(root)
		"vine": _vine(root)
		"boulder": _boulder(root, 1.0)
		"boulder_mid": _boulder(root, 0.68)
		"wedge": _wedge(root)
		"creole": _creole(root)
		"coco": _coco(root)
		"tortoise": _tortoise(root)
		"highland": _lighthouse(root, 4.0, Color("F4F1E8"), false, 18.0)
		"nauset": _lighthouse(root, 3.0, Color("E8E4DC"), true, 8.0)
		"fogstation": _fogstation(root)
		"shingle": _shingle(root)
		"buoy": _buoy(root)
		"palm": _palm(root)
		"shrub": _shrub(root)
		"reeds": _reeds(root)
		"pine": _pine(root)
		"beachgrass": _beachgrass(root)
		"church": _church(root)
		"medgarden": _medgarden(root)
		"resort": _resort(root)
		"golf": _golf(root)
	return root


# ── 泉州 ──

static func _mansion(root: Node3D) -> void:
	var white := Color("b9bcad")
	var red := Color("c8856b")
	var tile := Color("c67360")
	_box(root, Vector3(3, 0.28, 3), Vector3(1.5, 0.14, 1.5), white)
	for offset in [Vector3(0.5, 1.0, 0.5), Vector3(2.5, 1.0, 0.5), Vector3(0.5, 1.0, 2.5), Vector3(2.5, 1.0, 2.5)]:
		_box(root, Vector3(0.34, 1.0, 0.34), offset, white)
	# 四面墙留出中心天井
	for rect in [
		[Vector3(1.5, 1.0, 0.14), Vector3(2.72, 0.86, 0.28)],
		[Vector3(1.5, 1.0, 2.86), Vector3(2.72, 0.86, 0.28)],
		[Vector3(0.14, 1.0, 1.5), Vector3(0.28, 0.86, 2.72)],
		[Vector3(2.86, 1.0, 1.5), Vector3(0.28, 0.86, 2.72)],
	]:
		_box(root, rect[1], rect[0], red)
	# 红瓦屋面（中间镂空 = 天井）
	for rect in [
		[Vector3(1.5, 2.04, 0.72), Vector3(3.0, 0.16, 1.44)],
		[Vector3(1.5, 2.04, 2.28), Vector3(3.0, 0.16, 1.44)],
		[Vector3(0.72, 2.04, 1.5), Vector3(1.44, 0.16, 1.2)],
		[Vector3(2.28, 2.04, 1.5), Vector3(1.44, 0.16, 1.2)],
	]:
		_box(root, rect[1], rect[0], tile)
	_box(root, Vector3(0.5, 0.12, 0.5), Vector3(1.5, 2.16, 1.5), tile)


static func _oyster(root: Node3D) -> void:
	var shell := Color("D8D2C4")
	var brick := Color("B5624A")
	var tile := Color("c67360")
	_box(root, Vector3(2, 1.4, 2), Vector3(1, 0.7, 1), shell)
	_box(root, Vector3(2.06, 0.16, 0.2), Vector3(1, 1.46, 0.1), brick)
	_box(root, Vector3(2.06, 0.16, 0.2), Vector3(1, 1.46, 1.9), brick)
	_box(root, Vector3(0.2, 0.16, 2.06), Vector3(0.1, 1.46, 1), brick)
	_box(root, Vector3(0.2, 0.16, 2.06), Vector3(1.9, 1.46, 1), brick)
	_box(root, Vector3(2.1, 0.18, 2.1), Vector3(1, 1.62, 1), tile)
	_box(root, Vector3(0.44, 0.62, 0.1), Vector3(1, 0.42, 1.96), brick)


static func _ridge(root: Node3D) -> void:
	var tile := Color("c67360")
	_box(root, Vector3(1.02, 0.16, 0.24), Vector3(0.5, 0.16, 0.5), tile)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.3, 0.14, 0.22), Vector3(0.5 + side * 0.42, 0.34, 0.5), tile,
			Vector3(0, 0, side * 0.55))


static func _beacon(root: Node3D) -> void:
	var stone := Color("b9bcad")
	var brick := Color("c8856b")
	_box(root, Vector3(1.1, 0.3, 1.1), Vector3(0.5, 0.15, 0.5), stone)
	for tier in range(5):
		var shrink := 0.42 - float(tier) * 0.05
		var y := 0.5 + float(tier) * 0.5
		_cylinder(root, shrink, 0.34, Vector3(0.5, y, 0.5), stone if tier % 2 == 0 else brick, 8)
		_cylinder(root, shrink + 0.08, 0.08, Vector3(0.5, y + 0.24, 0.5), brick, 8)
	_cylinder(root, 0.16, 0.3, Vector3(0.5, 2.86, 0.5), Color("eac989"), 8, true)


static func _zayton(root: Node3D) -> void:
	_cylinder(root, 0.12, 1.1, Vector3(0.5, 0.55, 0.5), Color("8a6a52"), 6)
	_sphere(root, 0.34, Vector3(0.5, 1.3, 0.5), Color("C8434A"), Vector3(1.5, 0.85, 1.5), 4, 7)
	_sphere(root, 0.24, Vector3(0.24, 1.05, 0.72), Color("C8434A"), Vector3(1.2, 0.8, 1.2), 4, 6)
	_sphere(root, 0.22, Vector3(0.76, 1.16, 0.28), Color("D4575C"), Vector3(1.2, 0.8, 1.2), 4, 6)


static func _banyan(root: Node3D) -> void:
	_cylinder(root, 0.18, 1.6, Vector3(0.5, 0.8, 0.5), Color("8a6a52"), 6)
	_sphere(root, 0.62, Vector3(0.5, 2.0, 0.5), Color("6E9B6A"), Vector3(1.3, 0.8, 1.3), 4, 7)
	for i in range(6):
		var angle := float(i) * TAU / 6.0
		_cylinder(root, 0.035, 0.75,
			Vector3(0.5 + cos(angle) * 0.4, 1.3, 0.5 + sin(angle) * 0.4), Color("7d6a55"), 4)


# ── 圣托里尼 ──

static func _whitehouse(root: Node3D) -> void:
	var white := Color("F8F8F4")
	var blue := Color("2A6CB4")
	_box(root, Vector3(2, 2, 2), Vector3(1, 1, 1), white)
	_box(root, Vector3(2.06, 0.12, 2.06), Vector3(1, 2.04, 1), Color("EDEDE6"))
	_box(root, Vector3(0.46, 0.8, 0.08), Vector3(1, 0.5, 1.96), blue)
	_box(root, Vector3(0.42, 0.42, 0.08), Vector3(1.42, 1.3, 1.96), blue)


static func _bluedome(root: Node3D) -> void:
	var blue := Color("2A6CB4")
	_cylinder(root, 0.86, 0.52, Vector3(1, 0.26, 1), Color("F8F8F4"), 9)   # 白色鼓座
	_sphere(root, 0.88, Vector3(1, 0.72, 1), blue, Vector3(1.0, 0.86, 1.0), 5, 10)
	_box(root, Vector3(0.16, 0.5, 0.16), Vector3(1, 1.7, 1), Color("d9c98a"))


static func _cavehouse(root: Node3D) -> void:
	var rock := Color("D4C4A8")
	var warm := Color("eac989")
	_box(root, Vector3(1.9, 2, 1.9), Vector3(0.5, 1, 0.5), rock)
	_box(root, Vector3(0.86, 1.1, 0.2), Vector3(0.5, 0.6, 0.92), Color("5b5148"))
	_box(root, Vector3(0.5, 0.5, 0.1), Vector3(0.5, 0.55, 0.99), warm, Vector3.ZERO, true)


static func _warmhouse(root: Node3D) -> void:
	# 彩色小屋（Oia 点缀色）：暖赭墙 + 白平顶 + 蓝门框。
	_box(root, Vector3(1.9, 1.6, 1.9), Vector3(0.5, 0.8, 0.5), Color("D8A05A"))
	_box(root, Vector3(2.0, 0.14, 2.0), Vector3(0.5, 1.67, 0.5), Color("F8F8F4"))
	_box(root, Vector3(0.36, 0.72, 0.08), Vector3(0.5, 0.42, 0.94), Color("2A6CB4"))


static func _windmill(root: Node3D) -> void:
	# 基克拉泽斯风车：白圆塔 + 深色锥顶 + 八叶木十字。
	_cylinder(root, 0.42, 2.4, Vector3(0.5, 1.2, 0.5), Color("F6F4EC"), 9)
	_box(root, Vector3(0.3, 0.52, 0.08), Vector3(0.5, 0.56, 0.94), Color("2A6CB4"))
	_cone(root, 0.5, 0.44, Vector3(0.5, 2.62, 0.5), Color("7A5A48"), 9)
	for i in range(8):
		var angle := float(i) * PI / 4.0
		_box(root, Vector3(0.92, 0.1, 0.03),
			Vector3(0.5 + cos(angle) * 0.46, 2.35 + sin(angle) * 0.46, 0.72),
			Color("6f5a44"), Vector3(0, 0, angle))


static func _bougainvillea(root: Node3D) -> void:
	_cylinder(root, 0.06, 0.5, Vector3(0.5, 0.25, 0.5), Color("6f7a4a"), 5)
	for i in range(5):
		var angle := float(i) * TAU / 5.0
		_sphere(root, 0.17, Vector3(0.5 + cos(angle) * 0.22, 0.56 + float(i % 2) * 0.14, 0.5 + sin(angle) * 0.22),
			Color("D4537E"), Vector3.ONE, 3, 6)


static func _vine(root: Node3D) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.22
	mesh.outer_radius = 0.44
	mesh.rings = 8
	mesh.ring_segments = 10
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3(0.5, 0.1, 0.5)
	instance.material_override = _mat(Color("7A8A5A"))
	root.add_child(instance)


# ── 塞舌尔 ──

static func _boulder(root: Node3D, scale_value: float) -> void:
	var granite := Color("B8A092")
	_sphere(root, 0.5 * scale_value * 3.0, Vector3(1.5, 1.0 * scale_value * 1.5, 1.5), granite,
		Vector3(1.0, 0.78 * scale_value, 0.92), 5, 9)
	_sphere(root, 0.28 * scale_value * 3.0, Vector3(1.05, 1.5 * scale_value, 1.15), Color("D8C4B4"),
		Vector3(0.9, 0.7, 0.9), 4, 7)
	_sphere(root, 0.2 * scale_value * 3.0, Vector3(2.0, 0.55 * scale_value * 1.4, 1.9), Color("8A7A70"),
		Vector3(1.0, 0.6, 1.0), 4, 7)


static func _wedge(root: Node3D) -> void:
	_box(root, Vector3(0.8, 0.34, 0.7), Vector3(0.5, 0.17, 0.5), Color("A89889"), Vector3(0, 0.2, 0.08))
	_box(root, Vector3(0.42, 0.22, 0.44), Vector3(0.42, 0.36, 0.56), Color("8F8275"), Vector3(0.1, 0.6, 0))


static func _creole(root: Node3D) -> void:
	# 克里奥尔石屋：珊瑚石墙 + 出檐门廊 + 四坡茅草顶 + 烟囱。
	var coral := Color("E0D4C0")
	var timber := Color("BB946C")
	var thatch := Color("C8A46A")
	_box(root, Vector3(1.7, 1.1, 1.5), Vector3(1.0, 0.55, 1.05), coral)
	for corner in [Vector3(0.2, 0, 0.35), Vector3(1.8, 0, 0.35), Vector3(0.2, 0, 1.75), Vector3(1.8, 0, 1.75)]:
		_box(root, Vector3(0.12, 1.1, 0.12), corner + Vector3(0, 0.55, 0), timber)
	# 门廊地板 + 两根廊柱
	_box(root, Vector3(1.7, 0.1, 0.5), Vector3(1.0, 0.42, 1.75), timber)
	_box(root, Vector3(0.1, 0.8, 0.1), Vector3(0.28, 0.87, 1.9), timber)
	_box(root, Vector3(0.1, 0.8, 0.1), Vector3(1.72, 0.87, 1.9), timber)
	# 四坡顶：两段斜切盒近似
	_box(root, Vector3(1.9, 0.22, 1.9), Vector3(1.0, 1.28, 1.05), thatch)
	_cone(root, 1.5, 0.62, Vector3(1.0, 1.66, 1.05), thatch, 4)
	_box(root, Vector3(0.16, 0.5, 0.16), Vector3(1.45, 1.7, 0.75), Color("9a8a78"))
	_box(root, Vector3(0.4, 0.7, 0.08), Vector3(1.0, 0.55, 1.72), Color("5b5148"))


static func _coco(root: Node3D) -> void:
	# 椰子树：弯干（两段斜接）+ 顶部放射大叶 + 叶下果串。
	var lean := 0.16
	var lower := MeshInstance3D.new()
	var lower_mesh := CylinderMesh.new()
	lower_mesh.top_radius = 0.13
	lower_mesh.bottom_radius = 0.17
	lower_mesh.height = 1.3
	lower_mesh.radial_segments = 6
	lower.mesh = lower_mesh
	lower.position = Vector3(0.5, 0.65, 0.5)
	lower.rotation.z = lean * 0.5
	lower.material_override = _mat(Color("8a7355"))
	root.add_child(lower)
	var upper := MeshInstance3D.new()
	var upper_mesh := CylinderMesh.new()
	upper_mesh.top_radius = 0.10
	upper_mesh.bottom_radius = 0.13
	upper_mesh.height = 1.3
	upper_mesh.radial_segments = 6
	upper.mesh = upper_mesh
	upper.position = Vector3(0.5 + lean * 0.5, 1.75, 0.5)
	upper.rotation.z = lean * 1.4
	upper.material_override = _mat(Color("96795c"))
	root.add_child(upper)
	var crown := Vector3(0.5 + lean * 1.05, 2.36, 0.5)
	for i in range(7):
		var angle := float(i) * TAU / 7.0
		_box(root, Vector3(1.7, 0.06, 0.4),
			crown + Vector3(cos(angle) * 0.7, 0.02, sin(angle) * 0.7),
			Color("2E7A4E"), Vector3(0, -angle, -0.26))
	_sphere(root, 0.09, crown + Vector3(0.1, -0.12, 0.12), Color("8a6a3c"), Vector3.ONE, 3, 6)


static func _palm(root: Node3D) -> void:
	# 棕榈：直干、叶更挺（塞舌尔与热带岸线的高低搭配）。
	_cylinder(root, 0.11, 2.6, Vector3(0.5, 1.3, 0.5), Color("9a8262"), 6)
	for i in range(6):
		var angle := float(i) * TAU / 6.0 + 0.4
		_box(root, Vector3(1.9, 0.05, 0.34),
			Vector3(0.5 + cos(angle) * 0.8, 2.6 - 0.1, 0.5 + sin(angle) * 0.8),
			Color("37935A"), Vector3(0, -angle, -0.34))


static func _shrub(root: Node3D) -> void:
	# 灌木丛：两三个错位的低球 + 亮面受光。
	_sphere(root, 0.3, Vector3(0.45, 0.26, 0.5), Color("4E8F52"), Vector3(1.2, 0.85, 1.2), 4, 6)
	_sphere(root, 0.22, Vector3(0.68, 0.2, 0.34), Color("5CA45E"), Vector3.ONE, 4, 6)
	_sphere(root, 0.18, Vector3(0.3, 0.18, 0.68), Color("437A48"), Vector3.ONE, 4, 6)


static func _reeds(root: Node3D) -> void:
	# 苇草：一丛细长的斜杆 + 穗。
	for i in range(9):
		var x := 0.24 + float(i % 3) * 0.26 + float((i / 3) % 2) * 0.08
		var z := 0.3 + float(i / 3) * 0.2
		var h := 0.7 + float((i * 7) % 5) * 0.12
		var tilt := 0.12 + float(i % 4) * 0.05
		var dir := float(i) * 1.7
		_box(root, Vector3(0.045, h, 0.045),
			Vector3(x, h * 0.5, z),
			Color("b8a46a"), Vector3(sin(dir) * tilt, dir, cos(dir) * tilt))
		_box(root, Vector3(0.07, 0.16, 0.07),
			Vector3(x + sin(dir) * h * tilt * 0.5, h * 0.92, z + cos(dir) * h * tilt * 0.5),
			Color("c8b482"), Vector3(sin(dir) * tilt, dir, cos(dir) * tilt))


static func _pine(root: Node3D) -> void:
	# 海岸松：斜干 + 两三层深绿团（新英格兰海岸）。
	_cylinder(root, 0.09, 1.2, Vector3(0.48, 0.6, 0.5), Color("6f5a44"), 5)
	_cylinder(root, 0.07, 1.0, Vector3(0.56, 1.35, 0.54), Color("7a6650"), 5)
	_sphere(root, 0.42, Vector3(0.5, 1.6, 0.5), Color("2F5D3E"), Vector3(1.25, 0.8, 1.25), 4, 7)
	_sphere(root, 0.3, Vector3(0.6, 2.05, 0.55), Color("38684A"), Vector3.ONE, 4, 6)
	_sphere(root, 0.22, Vector3(0.38, 2.35, 0.46), Color("416F50"), Vector3.ONE, 4, 6)


static func _beachgrass(root: Node3D) -> void:
	# 沙滩草：金黄矮丛（沙丘固沙）。
	for i in range(7):
		var angle := float(i) * TAU / 7.0 + 0.3
		var tilt := 0.3
		_box(root, Vector3(0.05, 0.62, 0.05),
			Vector3(0.5 + cos(angle) * 0.06, 0.31, 0.5 + sin(angle) * 0.06),
			Color("cdb97e"), Vector3(cos(angle) * tilt, angle, sin(angle) * tilt))


static func _church(root: Node3D) -> void:
	# 新英格兰教堂：白板墙 + 尖塔 + 钟楼，两格宽两格高。
	_box(root, Vector3(1.9, 1.1, 1.5), Vector3(0.5, 0.55, 0.5), Color("F2EFE6"))
	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(2.0, 0.55, 1.6)
	roof.mesh = roof_mesh
	roof.position = Vector3(0.5, 1.38, 0.5)
	roof.rotation.y = PI * 0.5
	roof.material_override = _mat(Color("5A6068"))
	root.add_child(roof)
	_box(root, Vector3(0.34, 1.5, 0.34), Vector3(0.5, 1.85, 0.28), Color("F2EFE6"))
	_box(root, Vector3(0.24, 0.5, 0.24), Vector3(0.5, 2.35, 0.28), Color("EFEAE0"))
	_cone(root, 0.22, 0.5, Vector3(0.5, 2.85, 0.28), Color("4A5058"), 4)
	_box(root, Vector3(0.3, 0.62, 0.06), Vector3(0.5, 0.42, 1.24), Color("3E4448"))


static func _resort(root: Node3D) -> void:
	# 塞舌尔豪华度假村：两排白色平房型客房 + 无边泳池 + 棕榈。
	var wall := Color("F6F1E4")
	var roof_c := Color("C9B07E")
	var pool := Color("5FD4CE")
	_box(root, Vector3(3.4, 0.9, 1.3), Vector3(2.0, 0.45, 0.75), wall)
	_box(root, Vector3(3.4, 0.16, 1.42), Vector3(2.0, 0.95, 0.75), roof_c)
	_box(root, Vector3(3.4, 0.9, 1.3), Vector3(2.0, 0.45, 2.4), wall)
	_box(root, Vector3(3.4, 0.16, 1.42), Vector3(2.0, 0.95, 2.4), roof_c)
	_box(root, Vector3(1.5, 0.22, 1.0), Vector3(2.0, 0.14, 1.55), pool)
	_box(root, Vector3(0.9, 0.14, 0.9), Vector3(0.4, 0.75, 1.55), Color("D9C9A8"))
	_cylinder(root, 0.09, 1.6, Vector3(3.7, 0.8, 1.0), Color("9a8262"), 5)
	_sphere(root, 0.5, Vector3(3.7, 1.7, 1.0), Color("37935A"), Vector3(1.3, 0.7, 1.3), 4, 7)


static func _golf(root: Node3D) -> void:
	# 高尔夫果岭：修剪草坪 + 沙坑 + 旗杆球洞。
	_box(root, Vector3(2.9, 0.1, 2.9), Vector3(1.5, 0.06, 1.5), Color("6FBF63"))
	_sphere(root, 0.34, Vector3(0.7, 0.1, 2.1), Color("EFE6C8"), Vector3(1.2, 0.35, 1.0), 3, 7)
	_cylinder(root, 0.02, 0.9, Vector3(2.2, 0.5, 0.8), Color("f5f2ea"), 4)
	_box(root, Vector3(0.22, 0.16, 0.02), Vector3(2.2, 0.88, 0.8), Color("D94F4F"))


static func _medgarden(root: Node3D) -> void:
	# 地中海花园：石阶平台 + 木质葡萄棚架 + 陶盆勒杜鹃。
	_box(root, Vector3(1.9, 0.16, 1.9), Vector3(0.5, 0.08, 0.5), Color("D9D2C0"))
	for post in [Vector3(0.14, 0, 0.14), Vector3(0.86, 0, 0.14), Vector3(0.14, 0, 0.86), Vector3(0.86, 0, 0.86)]:
		_box(root, Vector3(0.09, 0.9, 0.09), Vector3(0.5 + post.x, 0.61, 0.5 + post.z), Color("9a7b58"))
	_box(root, Vector3(1.9, 0.06, 0.09), Vector3(0.5, 1.08, 0.14), Color("8a6f50"))
	_box(root, Vector3(1.9, 0.06, 0.09), Vector3(0.5, 1.08, 0.86), Color("8a6f50"))
	for i in range(5):
		_box(root, Vector3(0.06, 0.05, 1.6), Vector3(0.1 + float(i) * 0.42, 1.05, 0.5), Color("8a6f50"))
	_sphere(root, 0.2, Vector3(0.2, 0.95, 0.5), Color("6FA36A"), Vector3(1.0, 0.6, 1.4), 3, 6)
	_sphere(root, 0.16, Vector3(0.85, 0.9, 0.5), Color("7A4E68"), Vector3(1.2, 0.6, 1.2), 3, 6)


static func _tortoise(root: Node3D) -> void:
	_sphere(root, 0.42, Vector3(0.5, 0.34, 0.5), Color("7A6254"), Vector3(1.0, 0.62, 1.15), 5, 8)
	_sphere(root, 0.14, Vector3(0.5, 0.32, 0.86), Color("C8B49A"), Vector3(1.0, 0.9, 1.0), 4, 6)
	for offset in [Vector3(0.22, 0.12, 0.28), Vector3(0.78, 0.12, 0.28), Vector3(0.22, 0.12, 0.72), Vector3(0.78, 0.12, 0.72)]:
		_box(root, Vector3(0.16, 0.16, 0.2), offset, Color("C8B49A"))


# ── Cape Cod ──

static func _lighthouse(root: Node3D, height: float, body: Color, stripes: bool, _range: float) -> void:
	var base := 0.52
	_cylinder(root, base, 0.28, Vector3(0.5, 0.14, 0.5), Color("b9bcad"), 8)
	var tiers := int(height * 2.0)
	for i in range(tiers):
		var radius := base - float(i) * 0.045
		var y := 0.3 + (float(i) + 0.5) * (height - 0.6) / float(tiers)
		var colour := body
		if stripes and i % 2 == 1:
			colour = Color("C0493F")
		_cylinder(root, radius, (height - 0.6) / float(tiers) + 0.02, Vector3(0.5, y, 0.5), colour, 8)
	_cylinder(root, 0.34, 0.24, Vector3(0.5, height - 0.42, 0.5), Color("4a4f55"), 8)
	_cylinder(root, 0.24, 0.3, Vector3(0.5, height - 0.16, 0.5), Color("EAF2F6"), 8, true)
	_cone(root, 0.34, 0.28, Vector3(0.5, height + 0.06, 0.5), Color("5c4a3e"), 8)


static func _fogstation(root: Node3D) -> void:
	_box(root, Vector3(1.1, 1.2, 1.1), Vector3(0.5, 0.6, 0.5), Color("B0B4B0"))
	_box(root, Vector3(1.2, 0.16, 1.2), Vector3(0.5, 1.26, 0.5), Color("8d9490"))
	_cylinder(root, 0.14, 0.5, Vector3(0.5, 1.6, 0.5), Color("6f7470"), 8)
	_cylinder(root, 0.1, 0.16, Vector3(0.5, 1.92, 0.5), Color("DCE6EA"), 8, true)


static func _shingle(root: Node3D) -> void:
	_box(root, Vector3(2, 1.3, 2), Vector3(1, 0.65, 1), Color("A8A8A4"))
	_box(root, Vector3(2.1, 0.6, 1.06), Vector3(1, 1.6, 0.5), Color("7f827d"), Vector3(0.5, 0, 0))
	_box(root, Vector3(2.1, 0.6, 1.06), Vector3(1, 1.6, 1.5), Color("8d9089"), Vector3(-0.5, 0, 0))
	_box(root, Vector3(0.4, 0.6, 0.08), Vector3(1, 0.4, 1.96), Color("4f5450"))


static func _buoy(root: Node3D) -> void:
	_box(root, Vector3(0.48, 0.34, 0.48), Vector3(0.5, 0.2, 0.5), Color("8a6f4e"))
	_cylinder(root, 0.16, 0.3, Vector3(0.5, 0.5, 0.5), Color("C25B4A"), 8)
	_cylinder(root, 0.05, 0.4, Vector3(0.5, 0.8, 0.5), Color("6f7470"), 5)
