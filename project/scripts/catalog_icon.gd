extends Control

var kind: String = "stone"
var color := Color("b9bcad")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48, 39)

func _draw() -> void:
	var c := size * Vector2(0.5, 0.53)
	var s := minf(size.x / 52.0, size.y / 38.0)
	if kind in ["tree", "flower"]:
		draw_rect(Rect2(c + Vector2(-2,0)*s, Vector2(4,13)*s), Color("9c755b"))
		if kind == "tree":
			for i in range(3):
				var y := c.y + float(i * 6 - 13) * s
				draw_colored_polygon(PackedVector2Array([Vector2(c.x,y-9*s),Vector2(c.x-12*s,y+8*s),Vector2(c.x+12*s,y+8*s)]), color.darkened(float(i)*0.08))
		else:
			for p in [Vector2(-10,-3),Vector2(2,-9),Vector2(11,-1)]:
				draw_circle(c+p*s, 6*s, color)
				draw_circle(c+p*s, 2*s, Color("fff1c5"))
		return
	if kind in ["beacon", "lamp", "windmill"]:
		draw_rect(Rect2(c+Vector2(-5,-14)*s,Vector2(10,27)*s), Color("e6d9bc"))
		draw_rect(Rect2(c+Vector2(-6,-4)*s,Vector2(12,5)*s), color)
		draw_rect(Rect2(c+Vector2(-7,-15)*s,Vector2(14,7)*s), Color("eccc83"))
		draw_colored_polygon(PackedVector2Array([c+Vector2(-9,-16)*s,c+Vector2(0,-22)*s,c+Vector2(9,-16)*s]), color)
		if kind == "windmill":
			draw_line(c+Vector2(-13,-15)*s,c+Vector2(12,6)*s,Color("946e54"),4*s)
			draw_line(c+Vector2(12,-15)*s,c+Vector2(-13,6)*s,Color("946e54"),4*s)
		return
	var top := PackedVector2Array([c+Vector2(-18,-4)*s,c+Vector2(0,-13)*s,c+Vector2(18,-4)*s,c+Vector2(0,5)*s])
	var left := PackedVector2Array([c+Vector2(-18,-4)*s,c+Vector2(0,5)*s,c+Vector2(0,18)*s,c+Vector2(-18,9)*s])
	var right := PackedVector2Array([c+Vector2(18,-4)*s,c+Vector2(0,5)*s,c+Vector2(0,18)*s,c+Vector2(18,9)*s])
	draw_colored_polygon(left, color.darkened(0.08))
	draw_colored_polygon(right, color.darkened(0.24))
	draw_colored_polygon(top, color.lightened(0.14))
	if kind in ["cottage", "roof"]:
		draw_colored_polygon(PackedVector2Array([c+Vector2(-21,-4)*s,c+Vector2(-2,-23)*s,c+Vector2(21,-4)*s,c+Vector2(0,6)*s]),Color("cb8066"))
		draw_line(c+Vector2(-2,-23)*s,c+Vector2(0,6)*s,Color("d79573"),2*s)
		if kind == "cottage":
			draw_rect(Rect2(c+Vector2(-12,3)*s,Vector2(5,8)*s),Color("54746c"))
	if kind == "arch":
		draw_arc(c+Vector2(-8,10)*s,6*s,PI,TAU,16,Color("e9eedf"),5*s)
