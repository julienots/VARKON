class_name CardView
extends Control
## Card widget: rarity frame, family band, 3D-rendered portrait, cost gem, name and level.

signal tapped(card_id: String)

var card_id := ""
var level := 1
var locked := false
var selected := false
var dim := false
var show_progress := false
var _tex: TextureRect
var _sel: Panel


static func make(cid: String, sz := Vector2(132, 176), lvl := 1, is_locked := false) -> CardView:
	var c := CardView.new()
	c.card_id = cid
	c.level = lvl
	c.locked = is_locked
	c.custom_minimum_size = sz
	return c


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var d: Dictionary = DB.unit_def(card_id)
	var rc := DB.rarity_color(str(d.get("rarity", "common")))
	var fc := DB.family_color(str(d.get("family", "")))
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UI.tile(rc, 0))
	add_child(frame)
	_tex = TextureRect.new()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_tex.anchor_right = 1
	_tex.anchor_bottom = 1
	_tex.offset_left = 6
	_tex.offset_top = 6
	_tex.offset_right = -6
	_tex.offset_bottom = -36
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex)
	var tex: Texture2D = Router.portraits.get_portrait(card_id) if Router.portraits else null
	if tex:
		_tex.texture = tex
	elif Router.portraits:
		Router.portraits.portrait_ready.connect(_on_portrait)
	# Family band + name
	var band := Panel.new()
	band.anchor_top = 1
	band.anchor_right = 1
	band.anchor_bottom = 1
	band.offset_top = -38
	band.offset_left = 3
	band.offset_right = -3
	band.offset_bottom = -3
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_theme_stylebox_override("panel", UI.candy(fc.darkened(0.1), true, true, 0))
	add_child(band)
	var nm := UI.label(DB.txt(d), 13 if size.x < 120 else 15, Color.WHITE, "bold")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.set_anchors_preset(Control.PRESET_FULL_RECT)
	nm.clip_text = true
	nm.add_theme_color_override("font_outline_color", Color.BLACK)
	nm.add_theme_constant_override("outline_size", 4)
	band.add_child(nm)
	# Cost gem
	var gem := Panel.new()
	gem.position = Vector2(-4, -4)
	gem.size = Vector2(34, 34)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gsb := UI.box(Color("#d23ad8"), UI.OUTLINE, 17, 3, 0)
	gsb.border_width_top = 2
	gsb.shadow_color = Color(0, 0, 0, 0.35)
	gsb.shadow_size = 3
	gem.add_theme_stylebox_override("panel", gsb)
	add_child(gem)
	var cl := UI.label(str(int(d.get("cost", 0))), 20, Color.WHITE, "display")
	cl.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cl.add_theme_color_override("font_outline_color", Color.BLACK)
	cl.add_theme_constant_override("outline_size", 4)
	gem.add_child(cl)
	if level > 0 and not locked:
		var lv := UI.label(tr("LBL_LEVEL_SHORT") % level, 14, Color.WHITE, "bold")
		lv.position = Vector2(size.x - 44 if size.x > 0 else custom_minimum_size.x - 44, 6)
		lv.add_theme_color_override("font_outline_color", Color.BLACK)
		lv.add_theme_constant_override("outline_size", 4)
		add_child(lv)
	_sel = Panel.new()
	_sel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sel.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.08), Color.WHITE, 14, 5, 0))
	_sel.visible = selected
	add_child(_sel)
	_refresh()


func _on_portrait(id: String, tex: Texture2D) -> void:
	if id == card_id and is_instance_valid(_tex):
		_tex.texture = tex


func set_selected(v: bool) -> void:
	selected = v
	if _sel:
		_sel.visible = v


func set_dim(v: bool) -> void:
	dim = v
	_refresh()


func _refresh() -> void:
	modulate = Color(0.45, 0.48, 0.58) if locked else (Color(0.62, 0.64, 0.72) if dim else Color.WHITE)


var _press_pos := Vector2(-999, -999)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_press_pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		# Ignore releases that end a scroll gesture
		if Rect2(Vector2.ZERO, size).has_point(event.position) and event.position.distance_to(_press_pos) < 14.0:
			Audio.play_sfx("ui_click")
			tapped.emit(card_id)
