extends Node
## Root node: hosts the 3D world layer, the screen UI layer and the overlay layer.

var world_root: Node3D
var ui_layer: CanvasLayer
var ui_root: Control
var overlay_layer: CanvasLayer
var overlay_root: Control


func _ready() -> void:
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 1
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UI.theme()
	ui_layer.add_child(ui_root)
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 10
	add_child(overlay_layer)
	overlay_root = Control.new()
	overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.theme = UI.theme()
	overlay_layer.add_child(overlay_root)
	Router.attach(self)
	var start := "boot"
	var params := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			start = a.substr(9)
		elif a.begins_with("--param="):
			var kv := a.substr(8).split(":")
			params[kv[0]] = kv[1]
		elif a.begins_with("--screenshot="):
			_schedule_screenshot(a.substr(13))
	Router.goto(start, params)


## Dev/QA helper: --screenshot=path.png[@seconds] saves the screen and quits.
func _schedule_screenshot(arg: String) -> void:
	var parts := arg.split("@")
	var delay := float(parts[1]) if parts.size() > 1 else 3.0
	await get_tree().create_timer(delay).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(parts[0])
	print("screenshot saved: ", parts[0])
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Router.back()
