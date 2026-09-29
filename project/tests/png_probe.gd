extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("need two png paths")
		quit(1)
		return
	var a := Image.load_from_file(args[0])
	var b := Image.load_from_file(args[1])
	if a == null or b == null:
		print("LOAD FAILED")
		quit(1)
		return
	var lum_a := 0.0
	var lum_b := 0.0
	var darker := 0
	var total := 0
	var w := mini(a.get_width(), b.get_width())
	var h := mini(a.get_height(), b.get_height())
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var la := (ca.r + ca.g + ca.b) / 3.0
			var lb := (cb.r + cb.g + cb.b) / 3.0
			lum_a += la
			lum_b += lb
			if lb < la - 0.06:
				darker += 1
			total += 1
	print("avg_lum_on=%.3f avg_lum_off=%.3f" % [lum_a / total, lum_b / total])
	print("pixels_darkened_by_shadow=%.2f%%" % [100.0 * darker / total])
	quit(0)
