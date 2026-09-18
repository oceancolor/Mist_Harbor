extends Node3D

const Model = preload("res://scripts/world_model.gd")
const World = preload("res://scripts/build_world.gd")
const Icon = preload("res://scripts/catalog_icon.gd")
const MapView = preload("res://scripts/minimap.gd")
const INK := Color("2d514b")
const MUTED := Color("789087")
const PAPER := Color("f7f8ed")
const ACCENT := Color("497c6b")

var model: HarborWorldModel
var world: HarborBuildWorld
var camera := Camera3D.new()
var selected: String = "cottage"
var category: String = "建筑"
var piece_rotation: int = 0
var demolishing: bool = false
var focus := Vector3(0, 1, 1)
var target_focus := Vector3(0, 1, 1)
var yaw: float = 0.72
var target_yaw: float = 0.72
var pitch: float = 0.72
var target_pitch: float = 0.72
var zoom: float = 32.0
var target_zoom: float = 32.0
var orbiting: bool = false
var panning: bool = false
var pick_result: Dictionary = {}
var hud := Control.new()
var topbar: PanelContainer
var objective_panel: PanelContainer
var map_panel: PanelContainer
var dock: PanelContainer
var help_strip: Label
var toast_label: Label
var footer_label: Label
var status_label: Label
var item_hint: Label
var count_label: Label
var selected_label: Label
var dock_items: HBoxContainer
var category_buttons: Dictionary = {}
var item_buttons: Dictionary = {}
var item_shots: Dictionary = {}
var thumbs: ModelThumbnails
var action_buttons: Dictionary = {}
var mission_labels: Array[Label] = []
var mission_bars: Array[ProgressBar] = []
var objectives: Array = []
var minimap: Control
var modal: ColorRect
var sound := AudioStreamPlayer.new()
var sound_enabled: bool = true
var toast_time: float = 0.0
var qa_time: float = 0.0
var qa_enabled: bool = false
var import_callback: Variant
var dialog: FileDialog
var last_painted := Vector3i(999,999,999)
var painting: bool = false
var paint_elapsed: float = 0.0
var paint_screen := Vector2.ZERO

func _ready() -> void:
	model = Model.new()
	model.reset()
	model.migrate_legacy_save()
	if FileAccess.file_exists(Model.slot_path(model.current_slot)):
		model.load_local()
	thumbs = ModelThumbnails.new()
	add_child(thumbs)
	thumbs.thumbnail_ready.connect(_on_thumbnail_ready)
	world = World.new()
	add_child(world)
	world.setup(model)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 300.0
	add_child(camera)
	camera.current = true
	_update_camera(1.0)
	add_child(sound)
	sound.volume_db = -20.0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/objectives.json"))
	objectives = data.get("objectives", []) if data is Dictionary else []
	_build_ui()
	thumbs.request(model.palette.keys())
	model.changed.connect(_refresh_ui)
	_refresh_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_setup_browser()
	_toast("欢迎来到雾港。选一块建材，把你的想法放在岛上。", 6.0)

func _process(delta: float) -> void:
	_update_camera(delta)
	paint_elapsed += delta
	if painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		painting = false
	if modal == null and not orbiting and not panning:
		pick_result = world.pick(camera, get_viewport().get_mouse_position())
		var hovered := get_viewport().gui_get_hovered_control()
		if not pick_result.is_empty() and hovered == null:
			var cell: Vector3i = pick_result["cell"] if demolishing else pick_result["place"]
			var existing: Dictionary = model.get_cell(cell)
			var valid := model.has_cell(cell) if demolishing else model.can_place(cell, selected)
			var ghost_type := str(existing.get("kind", "stone")) if demolishing else selected
			world.show_ghost(ghost_type, cell, piece_rotation, valid, demolishing)
			status_label.text = ("拆除" if demolishing else "建造") + " · " + str(cell.x) + ", " + str(cell.y) + ", " + str(cell.z) + ("  可操作" if valid else "  需要空位或支撑")
			if painting and paint_elapsed > 0.17 and cell != last_painted and get_viewport().get_mouse_position().distance_to(paint_screen) > 8.0:
				_act_on_world(false)
		else:
			world.ghost.visible = false
	else:
		world.ghost.visible = false
	toast_time = maxf(0.0, toast_time - delta)
	toast_label.visible = toast_time > 0.0 and modal == null
	if qa_enabled:
		qa_time += delta
		if qa_time > 0.25:
			qa_time = 0.0
			JavaScriptBridge.get_interface("window").harborState = JSON.stringify(qa_snapshot())

func _update_camera(delta: float) -> void:
	if modal == null and is_inside_tree():
		var direction := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			if not Input.is_physical_key_pressed(KEY_CTRL): direction.y += 1
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var forward := Vector3(sin(yaw), 0, cos(yaw))
		target_focus += (right * direction.x + forward * direction.y) * delta * target_zoom * 0.33
		if Input.is_physical_key_pressed(KEY_Q): target_yaw += delta * 0.9
		if Input.is_physical_key_pressed(KEY_E): target_yaw -= delta * 0.9
	target_focus.x = clampf(target_focus.x, -23, 23)
	target_focus.z = clampf(target_focus.z, -23, 23)
	var weight := minf(1.0, delta * 12.0)
	focus = focus.lerp(target_focus, weight)
	yaw = lerpf(yaw, target_yaw, weight)
	pitch = lerpf(pitch, target_pitch, weight)
	zoom = lerpf(zoom, target_zoom, weight)
	camera.size = zoom
	camera.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 48.0
	camera.look_at(focus, Vector3.UP)
	if minimap != null and minimap.focus_position.distance_squared_to(focus) > 0.02:
		minimap.focus_position = focus
		minimap.queue_redraw()

func _input(event: InputEvent) -> void:
	# 鼠标在面板上松开时也必须释放拖拽状态。
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT: orbiting = false
		if event.button_index == MOUSE_BUTTON_MIDDLE: panning = false
		if event.button_index == MOUSE_BUTTON_LEFT: painting = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if modal != null:
			_close_modal()
		elif not hud.visible:
			hud.visible = true
		else:
			demolishing = false
			_refresh_ui()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if modal != null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = event.pressed
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clampf(target_zoom - 1.6, 10.0, 48.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clampf(target_zoom + 1.6, 10.0, 48.0)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			painting = true
			last_painted = Vector3i(999,999,999)
			_act_on_world(true)
	elif event is InputEventMouseMotion:
		if orbiting:
			target_yaw -= event.relative.x * 0.006
			target_pitch = clampf(target_pitch + event.relative.y * 0.004, 0.38, 1.25)
		if panning:
			var right := Vector3(cos(yaw), 0, -sin(yaw))
			var forward := Vector3(sin(yaw), 0, cos(yaw))
			target_focus -= (right * event.relative.x + forward * event.relative.y) * target_zoom * 0.0015
	elif event is InputEventScreenDrag:
		if event.index == 1:
			target_yaw -= event.relative.x * 0.006
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_Z:
			_redo() if event.shift_pressed else _undo()
		elif event.ctrl_pressed and event.keycode == KEY_Y: _redo()
		elif event.ctrl_pressed and event.keycode == KEY_S: _save()
		elif event.keycode == KEY_B: _toggle_demolition()
		elif event.keycode == KEY_R: _rotate_piece()
		elif event.keycode == KEY_N: _toggle_night()
		elif event.keycode == KEY_F: _center_camera()
		elif event.keycode == KEY_H: _show_help()
		elif event.keycode == KEY_P: hud.visible = not hud.visible
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var items := _category_items()
			var index: int = event.keycode - KEY_1
			if index < items.size(): _select_item(str(items[index]["id"]))

func _act_on_world(notify_invalid: bool) -> void:
	pick_result = world.pick(camera, get_viewport().get_mouse_position())
	if pick_result.is_empty(): return
	var cell: Vector3i = pick_result["cell"] if demolishing else pick_result["place"]
	var success := model.erase(cell) if demolishing else model.place(cell, selected, piece_rotation)
	if success:
		last_painted = cell
		paint_screen = get_viewport().get_mouse_position()
		paint_elapsed = 0.0
		_click_sound(310.0 if demolishing else 520.0 + float(posmod(cell.x + cell.y, 5)) * 50.0)
	elif notify_invalid:
		_toast("这里暂时不能建造：换一个空格，或从水面搭起地基。", 2.8)

func _style(color: Color = PAPER, border: Color = Color(0.42,0.56,0.48,0.15), radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _panel(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style())
	parent.add_child(panel)
	return panel

func _vbox(parent: Node, separation: int = 8) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box

func _hbox(parent: Node, separation: int = 8) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box

func _label(parent: Node, text_value: String, font_size: int = 14, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, title: String, action: Callable, key: String = "") -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(0, 35)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(Color("edf1e6"), Color("d5e0d3"), 9))
	button.add_theme_stylebox_override("hover", _style(Color("dbe8d9"), Color("93b8a0"), 9))
	button.add_theme_stylebox_override("pressed", _style(ACCENT, ACCENT, 9))
	button.add_theme_stylebox_override("focus", _style(Color(0,0,0,0), Color("77a98b"), 9))
	button.pressed.connect(action)
	parent.add_child(button)
	if not key.is_empty(): action_buttons[key] = button
	return button

func _spacer(parent: Node) -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)
	return spacer

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_theme := Theme.new()
	if ResourceLoader.exists("res://assets/fonts/harbor-sc.ttf"):
		ui_theme.default_font = load("res://assets/fonts/harbor-sc.ttf")
	ui_theme.default_font_size = 14
	hud.theme = ui_theme
	topbar = _panel(hud)
	var header := _hbox(topbar, 12)
	var logo := TextureRect.new()
	logo.texture = preload("res://assets/icon.svg")
	logo.custom_minimum_size = Vector2(39,39)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(logo)
	var brand := _vbox(header, 0)
	_label(brand, "MIST HARBOR", 18)
	_label(brand, "雾港造物记  /  给灵感一座岛", 11, MUTED)
	_spacer(header)
	_label(header, "创造模式 · 无限建材", 12, MUTED)
	_button(header, "日景  N", _toggle_night, "night")
	_button(header, "保存作品", _save, "save")
	_button(header, "作品管理", _show_menu, "menu")
	_button(header, "?", _show_help, "help")
	objective_panel = _panel(hud)
	var lesson := _vbox(objective_panel, 8)
	_label(lesson, "YOUR LITTLE ARCHIPELAGO", 10, MUTED)
	_label(lesson, "让灵感，\n长成一座岛。", 25)
	_label(lesson, "慢慢建造，不必急着完成。", 12, MUTED)
	var line := HSeparator.new()
	lesson.add_child(line)
	_label(lesson, "岛屿小挑战", 14)
	for goal: Dictionary in objectives:
		var row := _label(lesson, str(goal["title"]), 12, INK)
		mission_labels.append(row)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(180, 4)
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var track := _style(Color("e4e9dc"), Color(0,0,0,0), 2)
		var fill := _style(Color("78a68c"), Color(0,0,0,0), 2)
		for style in [track, fill]:
			style.content_margin_left = 0
			style.content_margin_right = 0
			style.content_margin_top = 0
			style.content_margin_bottom = 0
		bar.add_theme_stylebox_override("background", track)
		bar.add_theme_stylebox_override("fill", fill)
		lesson.add_child(bar)
		mission_bars.append(bar)
	_label(lesson, "仅统计亲手新建的部分 · 可自由游玩", 10, MUTED)
	map_panel = _panel(hud)
	var map_box := _vbox(map_panel, 8)
	var map_title := _hbox(map_box)
	_label(map_title, "海岛测绘图", 12)
	_spacer(map_title)
	_label(map_title, "N ↑", 11, MUTED)
	minimap = MapView.new()
	minimap.model = model
	map_box.add_child(minimap)
	count_label = _label(map_box, "", 12)
	_button(map_box, "回到岛屿  F", _center_camera, "center")
	_button(map_box, "拍照模式  P", func() -> void: hud.visible = false, "photo")
	dock = _panel(hud)
	var dock_box := _vbox(dock, 8)
	var selector := _hbox(dock_box, 6)
	for name_value in ["地形", "建筑", "自然"]:
		var tab := _button(selector, name_value, func() -> void: _set_category(name_value), "category-"+name_value)
		tab.toggle_mode = true
		category_buttons[name_value] = tab
	_spacer(selector)
	_button(selector, "旋转 R", _rotate_piece, "rotate")
	_button(selector, "拆除 B", _toggle_demolition, "demolish").toggle_mode = true
	_button(selector, "撤销", _undo, "undo")
	_button(selector, "重做", _redo, "redo")
	dock_items = _hbox(dock_box, 6)
	selected_label = _label(dock_box, "", 11, MUTED)
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_palette()
	status_label = _label(hud, "选中一块建材，在海岛上开始建造。", 12)
	help_strip = _label(hud, "左键 拼搭   /   右键拖动 环绕   /   WASD 平移   /   滚轮 缩放", 12, Color("335f59"))
	help_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label = _label(hud, "GODOT + BLENDER  /  原创建造样板", 10, Color("476e64"))
	toast_label = _label(hud, "", 14)
	toast_label.add_theme_stylebox_override("normal", _style(Color("edf6e4"), Color("b7cdb4"), 12))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _category_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for item: Dictionary in model.palette.values():
		if item["category"] == category:
			items.append(item)
	return items

func _build_palette() -> void:
	for child in dock_items.get_children():
		dock_items.remove_child(child)
		child.queue_free()
	item_buttons.clear()
	item_shots.clear()
	var entries := _category_items()
	for i in range(entries.size()):
		var entry := entries[i]
		var kind := str(entry["id"])
		var button := _button(dock_items, "", func() -> void: _select_item(kind))
		button.custom_minimum_size = Vector2(77, 77)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.tooltip_text = str(entry["tip"]) + "  [" + str(i + 1) + "]"
		var vbox := _vbox(button, 0)
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.offset_left = 4
		vbox.offset_right = -4
		vbox.offset_top = 4
		var icon_holder := Control.new()
		icon_holder.custom_minimum_size = Vector2(48, 39)
		icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon_holder)
		var icon := Icon.new()
		icon.kind = kind
		icon.color = Color(str(entry["color"]))
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_holder.add_child(icon)
		var shot := TextureRect.new()
		shot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shot.visible = false
		icon_holder.add_child(shot)
		item_shots[kind] = [icon, shot]
		if thumbs.has(kind): _apply_thumbnail(kind)
		var label := _label(vbox, str(entry["name"]), 11)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", INK)
		var number := _label(button, str(i + 1), 9, MUTED)
		number.position = Vector2(7, 3)
		item_buttons[kind] = button
	_refresh_ui()

func _apply_thumbnail(kind: String) -> void:
	if not item_shots.has(kind):
		return
	var pair: Array = item_shots[kind]
	var texture := thumbs.texture_for(kind)
	if texture == null:
		return
	var shot := pair[1] as TextureRect
	shot.texture = texture
	shot.visible = true
	(pair[0] as Control).visible = false

func _on_thumbnail_ready(kind: String) -> void:
	_apply_thumbnail(kind)

func _refresh_ui() -> void:
	if count_label == null:
		return
	var counts := model.player_counts()
	count_label.text = "已新建 %d 件  ·  SEED %d" % [model.placed_count(), model.world_seed]
	for i in range(objectives.size()):
		var goal: Dictionary = objectives[i]
		var key := str(goal["kind"])
		var amount := int(counts.get(key, 0))
		if key == "garden": amount = mini(3, int(counts.get("tree",0))) + mini(3, int(counts.get("flower",0)))
		if key == "journal": amount = mini(1, int(model.stats.get("saved",0))) + mini(1, int(model.stats.get("undone",0)))
		var target := int(goal["target"])
		mission_labels[i].text = ("完成  " if amount >= target else "%02d  " % [i + 1]) + str(goal["title"]) + "  %d/%d" % [mini(amount, target), target]
		mission_bars[i].value = float(amount) / target * 100.0
	for name_value in category_buttons:
		category_buttons[name_value].button_pressed = name_value == category
	for kind in item_buttons:
		item_buttons[kind].button_pressed = kind == selected and not demolishing
	if action_buttons.has("demolish"):
		action_buttons["demolish"].button_pressed = demolishing
		action_buttons["undo"].disabled = model.undo_stack.is_empty()
		action_buttons["redo"].disabled = model.redo_stack.is_empty()
		action_buttons["save"].text = "保存作品 *" if model.dirty else "保存作品"
		action_buttons["night"].text = "夜景  N" if world.night else "日景  N"
	if selected_label != null:
		selected_label.text = "拆除模式 · 点击或拖动移除格子，撤销可以恢复" if demolishing else str(model.definition(selected)["tip"]) + "  朝向 %d°" % [piece_rotation * 90]
	if minimap != null: minimap.queue_redraw()

func _layout() -> void:
	var size_value := get_viewport().get_visible_rect().size
	var compact := size_value.x < 1000.0
	topbar.position = Vector2(20, 18)
	topbar.size = Vector2(size_value.x - 40, 62)
	objective_panel.position = Vector2(20, 99)
	objective_panel.size.x = 246
	objective_panel.visible = size_value.x >= 1120 and size_value.y >= 650
	map_panel.position = Vector2(size_value.x - 208, 99)
	map_panel.size = Vector2(188, 240)
	map_panel.visible = not compact and size_value.y >= 600
	var width := minf(648, size_value.x - 32)
	dock.position = Vector2((size_value.x - width) * 0.5, size_value.y - 199)
	dock.size = Vector2(width, 157)
	help_strip.position = Vector2(20, size_value.y - 30)
	help_strip.size.x = size_value.x - 40
	status_label.position = Vector2((size_value.x - width) * 0.5, size_value.y - 226)
	status_label.size.x = width
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.position = Vector2(22, size_value.y - 51)
	footer_label.visible = size_value.x > 1160
	toast_label.position = Vector2((size_value.x - minf(620,size_value.x-40)) * 0.5, 96)
	toast_label.size = Vector2(minf(620,size_value.x-40), 40)

func _set_category(value: String) -> void:
	category = value
	var items := _category_items()
	selected = str(items[0]["id"])
	demolishing = false
	_build_palette()

func _select_item(kind: String) -> void:
	selected = kind
	demolishing = false
	_refresh_ui()

func _rotate_piece() -> void:
	piece_rotation = (piece_rotation + 1) % 4
	_refresh_ui()
	_toast("建材朝向：%d°" % [piece_rotation * 90], 1.5)

func _toggle_demolition() -> void:
	demolishing = not demolishing
	_refresh_ui()
	_toast("拆除模式：可以挖取地形或移除建筑；按 B 返回建造。" if demolishing else "已返回建造模式。")

func _undo() -> void:
	if model.undo(): _toast("已撤销上一次建造。", 1.8)

func _redo() -> void:
	if model.redo(): _toast("已重做。", 1.5)

func _toggle_night() -> void:
	world.set_night(not world.night)
	_refresh_ui()
	_toast("夜色降临，看看灯塔与路灯。" if world.night else "晨光回到海湾。", 2.0)

func _center_camera() -> void:
	target_focus = Vector3(0,1,1)
	target_yaw = 0.72
	target_pitch = 0.72
	target_zoom = 32.0

func _save() -> void:
	if model.save_local():
		_toast("作品已保存到存档槽 %d。跨设备请在作品管理中导出 JSON。" % [model.current_slot], 4.5)
	else:
		_toast(model.last_error, 5.0)
	_refresh_ui()

func _toast(message: String, seconds: float = 3.5) -> void:
	if toast_label == null: return
	toast_label.text = message
	toast_time = seconds

func _show_help() -> void:
	_show_dialog("给灵感一座岛", "这是一座没有资源限制、没有战斗的自由建造海湾。\n\n左键点击 / 拖动：放置建材    B：拆除或挖取地形\n右键拖动：环绕视角    中键拖动 / WASD：平移\n滚轮：缩放    Q / E：转动视角    F：回到岛屿\nR：旋转下一件建材    1—9：切换当前分类的建材\nCtrl+Z / Ctrl+Y：撤销 / 重做    Ctrl+S：保存\nN：切换昼夜    P：隐藏界面拍照    Esc：返回\n\n水面可以直接搭地基，空中格子须与既有建材相接。\n高模型占用多格，不能重叠。Ctrl+Z 最多回溯 160 次操作。\n移动设备建议横屏：点按建造，双指拖动旋转，使用界面按钮。\n\n学习任务是自练提示，不是自动教师评分。更多教材见工程 docs/learning-guide.md。", [{"text":"开始创造", "action":func() -> void: pass}])

func _show_menu() -> void:
	_show_dialog("作品管理", "存档仅保存在当前浏览器或设备。清理浏览器数据可能丢失作品，\n建议定期导出 JSON。导入时会校验版本、坐标、重叠与体积。\n\n加载或开始新岛会替换当前场景；请先保存或导出。\n样板预置建筑不计入小挑战，只有亲手新增的建材才计数。", [
		{"text":"保存当前作品", "action":_save},
		{"text":"存档槽…", "action":_show_slots},
		{"text":"导出 JSON", "action":_export_world},
		{"text":"导入 JSON", "action":_import_world},
		{"text":"空白群岛", "action":func() -> void: _confirm_reset(false)},
		{"text":"恢复灵感海湾", "action":func() -> void: _confirm_reset(true)},
		{"text":"音效：" + ("开" if sound_enabled else "关"), "action":func() -> void: sound_enabled = not sound_enabled}
	])

func _show_dialog(title: String, text_value: String, options: Array) -> void:
	_close_modal()
	painting = false
	orbiting = false
	panning = false
	modal = ColorRect.new()
	modal.color = Color(0.09,0.2,0.22,0.48)
	hud.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := _panel(center)
	panel.custom_minimum_size = Vector2(610, 0)
	var content := _vbox(panel, 15)
	_label(content, title, 24)
	var body := _label(content, text_value, 13, INK)
	body.custom_minimum_size.x = 560
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	content.add_child(actions)
	for option: Dictionary in options:
		var fn: Callable = option["action"]
		_button(actions, str(option["text"]), func() -> void:
			_close_modal()
			fn.call())
	_button(actions, "返回岛屿", _close_modal)

func _close_modal() -> void:
	if modal != null:
		modal.get_parent().remove_child(modal)
		modal.queue_free()
		modal = null

func _confirm_reset(with_village: bool) -> void:
	_show_dialog("开始新的岛屿？", "当前未保存的更改将被替换。已有本地存档不会被自动覆盖。", [{"text":"确认开始", "action":func() -> void:
		model.reset(240910, with_village)
		_center_camera()
		_toast("新的岛屿已经准备好。")
	}])

func _show_slots() -> void:
	var options: Array = []
	for index in range(1, Model.SLOT_COUNT + 1):
		options.append_array(_slot_options(index))
	_show_dialog("存档槽", "每个槽是一份独立作品，共 %d 个。切换或读取会替换当前场景，请先保存。\n导出 JSON 仍然是跨设备搬运作品的唯一方式。" % [Model.SLOT_COUNT], options)

func _slot_options(index: int) -> Array:
	var info := model.slot_info(index)
	var summary := "空槽" if not bool(info["exists"]) else "%d 件 · SEED %d · %s" % [int(info["cells"]), int(info["seed"]), str(info["saved_at"])]
	var mark := "（当前）" if index == model.current_slot else ""
	return [
		{"text": "槽 %d%s：%s" % [index, mark, summary], "action": func() -> void: _slot_save(index)},
		{"text": "读取槽 %d" % [index], "action": func() -> void: _slot_load(index)},
		{"text": "清空槽 %d" % [index], "action": func() -> void: _slot_clear(index)},
	]

func _slot_save(index: int) -> void:
	if model.save_slot(index):
		_toast("已保存到存档槽 %d。" % [index])
	else:
		_toast(model.last_error, 5.0)
	_refresh_ui()

func _slot_load(index: int) -> void:
	_show_dialog("读取存档槽 %d？" % [index], "当前未保存的更改将被替换。", [{"text":"确认读取", "action":func() -> void:
		if model.load_slot(index): _toast("已切换到存档槽 %d。" % [index])
		else: _toast(model.last_error, 5.0)
	}])

func _slot_clear(index: int) -> void:
	_show_dialog("清空存档槽 %d？" % [index], "该槽的作品会被删除，且无法恢复。", [{"text":"确认清空", "action":func() -> void:
		if model.delete_slot(index):
			_toast("存档槽 %d 已清空。" % [index])
			_show_slots()
		else:
			_toast(model.last_error, 5.0)
	}])

func _confirm_load() -> void:
	_show_dialog("读取本地存档？", "当前未保存的更改将被替换。", [{"text":"确认读取", "action":func() -> void:
		if model.load_local(): _toast("已恢复你的岛屿。")
		else: _toast(model.last_error)
	}])

func _export_world() -> void:
	var text_value := JSON.stringify(model.to_document(), "\t")
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text_value.to_utf8_buffer(), "mist-harbor-world.json", "application/json")
		_toast("已下载作品 JSON，妥善保存它。")
	else:
		var file := FileAccess.open("user://mist-harbor-export.json", FileAccess.WRITE)
		if file != null:
			file.store_string(text_value)
			file.close()
			_show_dialog("已导出", ProjectSettings.globalize_path("user://mist-harbor-export.json"), [])

func _setup_browser() -> void:
	if not OS.has_feature("web"): return
	qa_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa')"))
	import_callback = JavaScriptBridge.create_callback(_import_callback)
	JavaScriptBridge.get_interface("window").mistHarborImport = import_callback
	JavaScriptBridge.eval("document.addEventListener('contextmenu', function(e){e.preventDefault();}); document.addEventListener('keydown', function(e){if(e.ctrlKey && ['s','z','y'].includes(e.key.toLowerCase())) e.preventDefault();});")

func _import_world() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){const i=document.createElement('input');i.type='file';i.accept='.json,application/json';i.onchange=async function(){const f=i.files[0];if(!f)return;if(f.size>4000000){window.mistHarborImport('');return;}window.mistHarborImport(await f.text());};i.click();})();")
	else:
		dialog = FileDialog.new()
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dialog.filters = PackedStringArray(["*.json ; 雾港作品"])
		dialog.file_selected.connect(func(path: String) -> void:
			_accept_import(FileAccess.get_file_as_string(path))
			dialog.queue_free())
		hud.add_child(dialog)
		dialog.popup_centered(Vector2i(650,430))

func _import_callback(arguments: Array) -> void:
	if arguments.size() == 1:
		_accept_import(str(arguments[0]))

func _accept_import(text_value: String) -> void:
	_show_dialog("导入作品？", "导入将替换当前未保存场景。请确认已保存当前作品。", [{"text":"确认导入", "action":func() -> void:
		if model.import_json(text_value): _toast("作品导入成功；别忘记保存。")
		else: _toast(model.last_error, 5.0)
	}])

func _click_sound(frequency: float) -> void:
	if not sound_enabled or DisplayServer.get_name() == "headless": return
	var data := PackedByteArray()
	var samples: int = 1764
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / 22050.0
		var envelope := pow(1.0 - float(i) / samples, 2.0)
		data.encode_s16(i * 2, int(sin(t * TAU * frequency) * envelope * 6500))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	sound.stream = stream
	sound.play()

func qa_snapshot() -> Dictionary:
	var controls: Dictionary = {}
	for key in action_buttons:
		var button: Control = action_buttons[key]
		var rect := button.get_global_rect()
		controls[key] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	for key in item_buttons:
		var rect: Rect2 = item_buttons[key].get_global_rect()
		controls["item-" + key] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	return {"selected":selected,"category":category,"rotation":piece_rotation,"demolish":demolishing,"night":world.night,"placed":model.placed_count(),"counts":model.player_counts(),"cells":model.cells.size(),"undo":model.undo_stack.size(),"redo":model.redo_stack.size(),"dirty":model.dirty,"stats":model.stats,"faces":world.visible_faces,"assets":world.scenes.keys(),"modal":modal!=null,"buttons":controls,"viewport":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y],"pick":str(pick_result),"camera":[target_yaw,target_pitch,target_zoom],"revision":model.revision}
