class_name HarborLocationMechanic
extends RefCounted

## 地点独占机制基类。
##
## 硬约束（§1.5）：**每个地点只允许一个 location_mechanic**。需要两个以上系统说明设计超载。
## 判定一律是纯数据（不依赖渲染、不依赖真实光源数量），反馈一律是视觉 + 一句话提示：
## 不显示数字、不设产率、不排名、不弹成就（P1 松弛无压）。

var model: HarborWorldModel
var profile: HarborLocationProfile


func setup(world_model: HarborWorldModel, location_profile: HarborLocationProfile) -> void:
	model = world_model
	profile = location_profile


func id() -> String:
	return ""


func verb() -> String:
	return ""


func terrain(_with_village: bool) -> void:
	pass


func evaluate() -> Dictionary:
	return {}


func hint_for(_kind: String) -> String:
	return ""


func can_place(_cell: Vector3i, _kind: String, _rotation: int) -> bool:
	return true


func placement_note(_cell: Vector3i, _kind: String, _rotation: int) -> String:
	return ""


func decorate(_root: Node3D, _state: Dictionary) -> void:
	pass


func tick(_delta: float) -> void:
	pass


# ── 共用小工具 ──

func definition(kind: String) -> Dictionary:
	return model.definition(kind)


func role_of(kind: String) -> String:
	return str(definition(kind).get("role", ""))


func cells_with_role(role: String) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for cell: Vector3i in model.cells:
		var item: Dictionary = model.cells[cell]
		if role_of(str(item["kind"])) == role:
			result.append(cell)
	return result


func cells_with_kind(kind: String) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for cell: Vector3i in model.cells:
		if str(model.cells[cell]["kind"]) == kind:
			result.append(cell)
	return result


func is_solid(cell: Vector3i) -> bool:
	return model.has_cell(cell)


func surface_cells() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for cell: Vector3i in model.cells:
		if not model.has_cell(cell + Vector3i.UP):
			result.append(cell)
	return result


func _set_natural(cell: Vector3i, kind: String, rotation: int = 0) -> void:
	if model.cells.has(cell):
		return
	model._set_raw(cell, {"kind": kind, "rot": rotation, "natural": true})
