extends Control

var model: HarborWorldModel
var focus_position := Vector3.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(158, 124)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	if model == null:
		return
	var scale_value := 2.15
	var center := size * 0.5
	var tops: Dictionary = {}
	for cell: Vector3i in model.cells:
		var key := Vector2i(cell.x, cell.z)
		if not tops.has(key) or cell.y > tops[key].y:
			tops[key] = cell
	for cell: Vector3i in tops.values():
		var item: Dictionary = model.cells[cell]
		var point := center + Vector2(cell.x, cell.z) * scale_value
		var color := Color("87a78c") if item.get("natural", false) else Color("bd7e64")
		draw_rect(Rect2(point,Vector2.ONE*scale_value),color)
	var p := center + Vector2(focus_position.x, focus_position.z) * scale_value
	draw_arc(p, 7, 0, TAU, 28, Color("faffed"), 1.5, true)
	draw_circle(p, 2.0, Color("355c56"))
	draw_line(Vector2(size.x-12,20), Vector2(size.x-12,8), Color("6b8b82"),1.0)
	draw_line(Vector2(size.x-12,8),Vector2(size.x-15,12),Color("6b8b82"),1.0)

func _background() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("d0e1d7")
	box.set_corner_radius_all(10)
	return box
