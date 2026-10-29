class_name UIScreen
extends RefCounted
## Shared layout for 2D sub-screens: background + header (back button, title, extra) + body.


static var _pattern: Texture2D

## Bright gradient backdrop with a subtle diagonal pattern; `tint` gives each screen its colour.
static func background(owner: Control, tint := Color("#2b6fd0")) -> void:
	if tint.v < 0.35:
		tint = Color("#2b6fd0")  # legacy dark tints -> default blue
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, tint.lightened(0.28))
	grad.set_color(1, tint.darkened(0.35))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.25)
	gt.fill_to = Vector2(1.15, 1.2)
	gt.width = 256
	gt.height = 256
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(bg)
	if _pattern == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var stripe := ((x + y) % 32) < 12
				img.set_pixel(x, y, Color(1, 1, 1, 0.05 if stripe else 0.0))
		_pattern = ImageTexture.create_from_image(img)
	var pat := TextureRect.new()
	pat.texture = _pattern
	pat.stretch_mode = TextureRect.STRETCH_TILE
	pat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pat.set_anchors_preset(Control.PRESET_FULL_RECT)
	pat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(pat)


static func frame(owner: Control, title_text: String, extra: Control = null, compact_bar := true, resources: Array = []) -> VBoxContainer:
	var root := UI.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 10
	root.offset_bottom = -12
	owner.add_child(root)
	var head := UI.header(title_text, extra)
	if compact_bar:
		var tb := TopBar.make(true, resources)
		tb.size_flags_horizontal = Control.SIZE_SHRINK_END
		head.add_child(tb)
	root.add_child(head)
	return root


static func tabs(parent: Control, names: Array, current: String, cb: Callable) -> Container:
	## Wrapping tab row: never wider than the screen, whatever the language or text size.
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 6)
	for n in names:
		var key: String = n
		var b := UI.button(TranslationServer.translate("TAB_" + key.to_upper()), cb.bind(key), "primary" if key == current else "secondary", 0, 46)
		b.add_theme_font_size_override("font_size", int(18 * UI.ts()))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	parent.add_child(h)
	return h


static func clear(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()


static func stat_row(label_text: String, value: String, color := Color.WHITE) -> HBoxContainer:
	var h := UI.hbox()
	var l := UI.label(label_text, 17, UI.TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UI.label(value, 17, color, "bold"))
	return h
