class_name HarborExpansionRules
extends RefCounted

const DIRECTIONS: Array[Vector3i] = [
	Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP,
	Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD,
]
const DIRECTION_NAMES := ["east", "west", "up", "down", "south", "north"]

static func rotate_horizontal(direction: Vector3i, quarter_turns: int) -> Vector3i:
	var result := direction
	for _step in range(posmod(quarter_turns, 4)):
		result = Vector3i(-result.z, result.y, result.x)
	return result

static func opposite(direction: Vector3i) -> Vector3i:
	return -direction

static func connector_for(definition: Dictionary, direction: Vector3i, rotation: int = 0) -> String:
	var expansion: Dictionary = definition.get("expansion", {})
	if expansion.is_empty():
		return ""
	var local_direction := rotate_horizontal(direction, -rotation)
	var index := DIRECTIONS.find(local_direction)
	if index < 0:
		return ""
	var connectors: Dictionary = expansion.get("connectors", {})
	return str(connectors.get(DIRECTION_NAMES[index], ""))

static func connectors_match(a: String, b: String) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if a == "*" or b == "*":
		return true
	return a == b

static func can_connect(a_definition: Dictionary, a_rotation: int, direction: Vector3i,
		b_definition: Dictionary, b_rotation: int) -> bool:
	var a := connector_for(a_definition, direction, a_rotation)
	var b := connector_for(b_definition, opposite(direction), b_rotation)
	return connectors_match(a, b)

static func mask_for(model: RefCounted, cell: Vector3i) -> int:
	var item: Dictionary = model.get_cell(cell)
	if item.is_empty():
		return 0
	var origin: Vector3i = model.owner_at(cell)
	var definition: Dictionary = model.definition(str(item.get("kind", "")))
	var result := 0
	for index in range(DIRECTIONS.size()):
		var target: Vector3i = origin + DIRECTIONS[index]
		var neighbor: Dictionary = model.get_cell(target)
		if neighbor.is_empty():
			continue
		var neighbor_definition: Dictionary = model.definition(str(neighbor.get("kind", "")))
		if can_connect(definition, int(item.get("rot", 0)), DIRECTIONS[index],
				neighbor_definition, int(neighbor.get("rot", 0))):
			result |= 1 << index
	return result

static func variant_for_mask(mask: int) -> String:
	var horizontal := mask & 0b110011
	var vertical := mask & 0b001100
	var count := 0
	for bit in range(6):
		if mask & (1 << bit):
			count += 1
	if count == 0:
		return "single"
	if vertical != 0 and horizontal == 0:
		return "vertical"
	if count == 1:
		return "end"
	if count == 2:
		if horizontal in [0b000011, 0b110000] or vertical == 0b001100:
			return "straight"
		return "corner"
	if count == 3:
		return "tee"
	if count >= 4:
		return "cross"
	return "connected"

static func dirty_neighborhood(cell: Vector3i, height: int = 1) -> Array[Vector3i]:
	var result: Array[Vector3i] = [cell]
	for dy in range(height):
		var occupied := cell + Vector3i.UP * dy
		if occupied not in result:
			result.append(occupied)
		for direction in DIRECTIONS:
			var neighbor := occupied + direction
			if neighbor not in result:
				result.append(neighbor)
	return result
