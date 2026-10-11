class_name HarborFootprint
extends RefCounted

## M0 · 多格构件放置逻辑统一（core 项，四地点共用；任何地点不得单写一份放置逻辑）。
##
## 约定：格子坐标是整数网格，一个方块占据 [x, x+1] × [y, y+h] × [z, z+1]；
## 多格构件的 origin 是**最小角**，视觉中心在 origin + (w/2, 0, d/2)。
## 高度 height 与水平尺寸 size 都来自建材表，旋转只绕 Y 轴（4 向）。

static func size_of(definition: Dictionary) -> Vector3i:
	var height := int(definition.get("height", 1))
	var size_value: Variant = definition.get("size", null)
	if size_value is Array and (size_value as Array).size() == 3:
		var raw: Array = size_value
		return Vector3i(maxi(1, int(raw[0])), maxi(1, int(raw[1])), maxi(1, int(raw[2])))
	return Vector3i(1, height, 1)


static func rotated_size(size_value: Vector3i, rotation: int) -> Vector3i:
	if posmod(rotation, 2) == 1:
		return Vector3i(size_value.z, size_value.y, size_value.x)
	return size_value


static func cells_for(origin: Vector3i, definition: Dictionary, rotation: int = 0) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var size_value := rotated_size(size_of(definition), rotation)
	for dx in range(size_value.x):
		for dy in range(size_value.y):
			for dz in range(size_value.z):
				cells.append(origin + Vector3i(dx, dy, dz))
	return cells


static func top_cells(origin: Vector3i, definition: Dictionary, rotation: int = 0) -> Array[Vector3i]:
	## 构件最上层的格子——给「叠放」与「接触面」判定用。
	var cells: Array[Vector3i] = []
	var size_value := rotated_size(size_of(definition), rotation)
	for dx in range(size_value.x):
		for dz in range(size_value.z):
			cells.append(origin + Vector3i(dx, size_value.y - 1, dz))
	return cells


static func bottom_cells(origin: Vector3i, definition: Dictionary, rotation: int = 0) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var size_value := rotated_size(size_of(definition), rotation)
	for dx in range(size_value.x):
		for dz in range(size_value.z):
			cells.append(origin + Vector3i(dx, 0, dz))
	return cells


static func center_offset(definition: Dictionary, rotation: int = 0) -> Vector3:
	var size_value := rotated_size(size_of(definition), rotation)
	return Vector3(float(size_value.x) * 0.5, 0.0, float(size_value.z) * 0.5)


static func collision_shape(definition: Dictionary, rotation: int = 0) -> BoxShape3D:
	var size_value := rotated_size(size_of(definition), rotation)
	var shape := BoxShape3D.new()
	shape.size = Vector3(float(size_value.x) * 0.94, float(size_value.y), float(size_value.z) * 0.94)
	return shape
