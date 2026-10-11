extends SceneTree

## 最小复现：对话框按钮的 pressed 信号（bind 的具名方法）在无头环境是否触发。
var fired: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene._close_modal()
	scene._show_menu()
	await process_frame
	await physics_frame
	print("diag dialog actions:", scene._dialog_actions.size())
	# 直接调用（绕过点击）
	scene._run_dialog_option(1)
	await process_frame
	print("diag direct call -> sunset_panel created: ", scene.sunset_panel != null)
	# 再模拟真实点击路径：鼠标事件注入按钮
	scene.sunset_panel = null
	scene._show_menu()
	await process_frame
	await physics_frame
	var button: BaseButton = null
	for child in scene.hud.find_children("*", "BaseButton", true, false):
		if child is BaseButton and str(child.text).contains("调黄昏"):
			button = child
	print("diag found button: ", button != null, " disabled=", button != null and button.disabled)
	if button != null:
		button.pressed.emit()
		await process_frame
		await physics_frame
		print("diag emit -> sunset_panel created: ", scene.sunset_panel != null)
		print("diag sliders registered: ", scene.sunset_sliders.keys())
	quit(0)
