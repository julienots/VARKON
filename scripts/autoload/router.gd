extends Node
## Screen navigation, popups and toasts.

const SCREENS := {
	"boot": "res://scripts/ui/screens/boot_screen.gd",
	"menu": "res://scripts/ui/screens/menu_screen.gd",
	"combat": "res://scripts/ui/screens/combat_screen.gd",
	"battle": "res://scripts/ui/screens/battle_screen.gd",
	"results": "res://scripts/ui/screens/results_screen.gd",
	"collection": "res://scripts/ui/screens/collection_screen.gd",
	"king": "res://scripts/ui/screens/king_screen.gd",
	"base": "res://scripts/ui/screens/base_screen.gd",
	"lab": "res://scripts/ui/screens/lab_screen.gd",
	"chests": "res://scripts/ui/screens/chests_screen.gd",
	"shop": "res://scripts/ui/screens/shop_screen.gd",
	"pass": "res://scripts/ui/screens/pass_screen.gd",
	"missions": "res://scripts/ui/screens/missions_screen.gd",
	"inventory": "res://scripts/ui/screens/inventory_screen.gd",
	"settings": "res://scripts/ui/screens/settings_screen.gd",
	"legal": "res://scripts/ui/screens/legal_screen.gd",
	"events": "res://scripts/ui/screens/events_screen.gd",
}

var main: Node
var current: Control
var current_name := ""
var history: Array = []
var _toast_box: VBoxContainer
var popup_open: Control
var portraits: PortraitStudio
var drag_dist := 0.0
var _press_pos := Vector2.ZERO


func _input(event: InputEvent) -> void:
	# Tracks drag distance so taps that end a scroll gesture are ignored by buttons.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
			drag_dist = 0.0
		else:
			drag_dist = event.position.distance_to(_press_pos)


func attach(m: Node) -> void:
	main = m
	portraits = PortraitStudio.new()
	main.add_child(portraits)
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.position = Vector2(-260, 70)
	_toast_box.custom_minimum_size = Vector2(520, 0)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_theme_constant_override("separation", 6)
	main.overlay_root.add_child(_toast_box)
	if not EventBus.toast.is_connected(toast):
		EventBus.toast.connect(toast)


func goto(screen: String, params: Dictionary = {}, push_history := true) -> void:
	if not SCREENS.has(screen):
		push_error("Unknown screen " + screen)
		return
	close_popup()
	if current:
		if push_history and current_name != "" and not current_name in ["boot", "battle", "results"]:
			history.append({"name": current_name, "params": current.get_meta("params", {})})
		current.queue_free()
		current = null
	for c in main.world_root.get_children():
		c.queue_free()
	var script: Script = load(SCREENS[screen])
	var s: Control = script.new()
	s.set_meta("params", params)
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	current = s
	current_name = screen
	main.ui_root.add_child(s)
	if s.has_method("setup"):
		s.setup(params)
	if s.has_method("build_world"):
		var w = s.build_world()
		if w:
			main.world_root.add_child(w)
			if s.has_method("on_world_ready"):
				s.on_world_ready(w)


func back() -> void:
	if popup_open:
		close_popup()
		return
	if current and current.has_method("on_back") and current.on_back():
		return
	if history.is_empty():
		if current_name == "menu":
			# Android back button on the main menu: ask before leaving the game.
			confirm(tr("CONFIRM_QUIT"), func() -> void:
				Game.save_now()
				get_tree().quit(), tr("BTN_QUIT"), true)
		elif current_name != "boot":
			goto("menu", {}, false)
		return
	var h: Dictionary = history.pop_back()
	goto(h.name, h.params, false)


func home() -> void:
	history.clear()
	goto("menu", {}, false)


# ------------------------------------------------------------------ popups
func popup(content: Control, dismissable := true) -> Control:
	close_popup()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if dismissable:
		var on_dim := func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				close_popup()
		dim.gui_input.connect(on_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	center.add_child(content)
	main.overlay_root.add_child(dim)
	main.overlay_root.move_child(dim, 0)
	popup_open = dim
	content.scale = Vector2(0.9, 0.9)
	content.pivot_offset = content.get_combined_minimum_size() / 2
	if not Settings.get_v("limit_animations"):
		content.create_tween().tween_property(content, "scale", Vector2.ONE, 0.12)
	else:
		content.scale = Vector2.ONE
	return dim


func close_popup() -> void:
	if popup_open and is_instance_valid(popup_open):
		popup_open.queue_free()
	popup_open = null


func confirm(text: String, on_yes: Callable, yes_label := "", danger := false) -> void:
	# Destructive actions always ask; other important actions follow the player's setting.
	if not danger and not Settings.get_v("confirm_important"):
		on_yes.call()
		return
	var p := UI.panel_box()
	var v := UI.vbox(14)
	p.add_child(v)
	p.custom_minimum_size = Vector2(520, 0)
	var l := UI.label(text, 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var h := UI.hbox(16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(UI.button(tr("BTN_CANCEL"), close_popup, "secondary"))
	var yes := func() -> void:
		close_popup()
		on_yes.call()
	h.add_child(UI.button(yes_label if yes_label != "" else tr("BTN_CONFIRM"), yes, "danger" if danger else "primary"))
	v.add_child(h)
	popup(p)


## Asks for confirmation of a spend when the setting is on; otherwise runs directly.
func confirm_spend(text: String, cost: Dictionary, on_yes: Callable) -> void:
	if not Settings.get_v("confirm_spend") or cost.is_empty():
		on_yes.call()
		return
	var total := 0
	for k in cost.keys():
		total += int(cost[k])
	if total <= 0:
		on_yes.call()
		return
	var p := UI.panel_box()
	var v := UI.vbox(14)
	p.add_child(v)
	p.custom_minimum_size = Vector2(520, 0)
	var l := UI.label(text, 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var cr := UI.cost_row(cost, 26)
	cr.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cr)
	var h := UI.hbox(16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(UI.button(tr("BTN_CANCEL"), close_popup, "secondary"))
	var yes := func() -> void:
		close_popup()
		on_yes.call()
	h.add_child(UI.button(tr("BTN_CONFIRM"), yes, "primary"))
	v.add_child(h)
	popup(p)


func toast(text: String, kind: String = "info") -> void:
	if _toast_box == null:
		return
	if kind in ["reward", "progress"] and not Settings.get_v("notif_progress"):
		return
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = {"error": Color("#5a1a14"), "success": Color("#1f4a22"), "level": Color("#5a4410")}.get(kind, Color("#2a211a"))
	sb.border_color = {"error": Color("#ff6a50"), "success": Color("#7bdc3a"), "level": Color("#ffd23f")}.get(kind, Color("#a07a3a"))
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.label(text, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	_toast_box.add_child(p)
	if kind == "error":
		Audio.play_sfx("ui_error")
	var tw := p.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	while _toast_box.get_child_count() > 4:
		_toast_box.get_child(0).free()


func error(key: String) -> void:
	toast(tr(key), "error")


## Starts a battle with a prepared config.
func start_battle(cfg: Dictionary) -> void:
	cfg["battle_id"] = "%d_%d" % [int(Game.now() * 1000), randi() % 1000000]
	Game.pending_battle = cfg
	goto("battle", {})
