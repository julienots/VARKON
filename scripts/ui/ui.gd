class_name UI
extends RefCounted
## UI factory: theme, typography, buttons, panels and shared widgets.

const BG := Color("#120e0b")
const PANEL := Color("#211912")
const PANEL_2 := Color("#2c2219")
const BORDER := Color("#7a5a32")
const GOLD := Color("#ffd23f")
const TEXT := Color("#f2e6d0")
const TEXT_DIM := Color("#b9a88c")
const RED := Color("#e0503a")
const GREEN := Color("#7bdc3a")

static var _theme: Theme
static var _fonts := {}


static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path: String = {"title": "res://assets/fonts/Cinzel.ttf", "display": "res://assets/fonts/LuckiestGuy-Regular.ttf"}.get(kind, "res://assets/fonts/Nunito.ttf")
	var f: Font = load(path)
	var weight: int = {"title": 700, "bold": 800, "body": 600}.get(kind, 0)
	if weight > 0:
		var fv := FontVariation.new()
		fv.base_font = f
		var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
		fv.variation_opentype = {wght: weight}
		f = fv
	_fonts[kind] = f
	return f


static func ts() -> float:
	return float(Settings.get_v("text_scale"))


static func bs() -> float:
	return float(Settings.get_v("button_scale"))


static func contrast() -> bool:
	return bool(Settings.get_v("high_contrast"))


static func box(bg: Color, border: Color = BORDER, radius := 12, bw := 2, margin := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.7
	sb.content_margin_bottom = margin * 0.7
	sb.anti_aliasing = true
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	rebuild_theme()
	return _theme


static func rebuild_theme() -> void:
	var t := theme() if _theme else Theme.new()
	_theme = t
	var text := Color.WHITE if contrast() else TEXT
	t.default_font = font("body")
	t.default_font_size = int(20 * ts())
	t.set_color("font_color", "Label", text)
	t.set_color("font_color", "Button", text)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.55, 0.5))
	t.set_stylebox("panel", "PanelContainer", box(PANEL if not contrast() else Color.BLACK, BORDER if not contrast() else Color.WHITE))
	t.set_stylebox("panel", "Panel", box(PANEL, BORDER))
	t.set_stylebox("normal", "Button", box(PANEL_2, BORDER, 10))
	t.set_stylebox("hover", "Button", box(PANEL_2.lightened(0.08), GOLD, 10))
	t.set_stylebox("pressed", "Button", box(PANEL_2.darkened(0.2), GOLD, 10))
	t.set_stylebox("disabled", "Button", box(PANEL_2.darkened(0.3), BORDER.darkened(0.4), 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var grabber := box(GOLD, GOLD.darkened(0.3), 10, 2, 8)
	t.set_icon("grabber", "HSlider", _circle_tex(26, GOLD))
	t.set_icon("grabber_highlight", "HSlider", _circle_tex(28, Color.WHITE))
	var slider_bg := box(PANEL_2.darkened(0.3), BORDER, 6, 1, 0)
	slider_bg.content_margin_top = 6
	slider_bg.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", box(GOLD.darkened(0.3), GOLD.darkened(0.3), 6, 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", grabber)
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.5), BORDER.darkened(0.3), 6, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(GOLD, GOLD, 6, 0, 0))
	t.set_color("font_color", "LineEdit", text)
	t.set_stylebox("normal", "LineEdit", box(Color(0, 0, 0, 0.4), BORDER, 8))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0.4), GOLD, 8))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	var sbv := StyleBoxFlat.new()
	sbv.bg_color = Color(1, 1, 1, 0.25)
	sbv.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", sbv)
	t.set_stylebox("grabber_highlight", "VScrollBar", sbv)
	t.set_stylebox("grabber_pressed", "VScrollBar", sbv)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	t.set_stylebox("grabber", "HScrollBar", sbv)
	t.set_stylebox("grabber_highlight", "HScrollBar", sbv)
	t.set_stylebox("grabber_pressed", "HScrollBar", sbv)
	t.set_stylebox("scroll", "HScrollBar", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckButton", text)
	t.set_color("font_color", "OptionButton", text)
	t.set_stylebox("normal", "OptionButton", box(PANEL_2, BORDER, 10))
	t.set_stylebox("hover", "OptionButton", box(PANEL_2.lightened(0.08), GOLD, 10))
	t.set_stylebox("pressed", "OptionButton", box(PANEL_2, GOLD, 10))
	t.set_stylebox("panel", "PopupMenu", box(PANEL, BORDER, 8))
	t.set_font_size("font_size", "PopupMenu", int(22 * ts()))
	t.set_color("font_color", "PopupMenu", text)


static func _circle_tex(sz: int, c: Color) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var r := sz / 2.0
	for y in sz:
		for x in sz:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ basic widgets
static func label(text: String, size := 20, color := Color(0, 0, 0, 0), kind := "body") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(size * ts()))
	if kind != "body":
		l.add_theme_font_override("font", font(kind))
	if color.a > 0:
		l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, size := 34) -> Label:
	var l := label(text, size, GOLD, "title")
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func para(text: String, size := 18, color := TEXT_DIM) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	return l


static func button(text: String, cb: Callable, style := "secondary", min_w := 0, h := 56) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, h * bs())
	b.add_theme_font_size_override("font_size", int(22 * ts()))
	b.add_theme_font_override("font", font("display") if style in ["primary", "danger", "big"] else font("bold"))
	var col: Color = {"primary": Color("#c98a1a"), "danger": Color("#a8331f"), "big": Color("#c98a1a"), "ghost": Color(0, 0, 0, 0.25), "green": Color("#3c7a24")}.get(style, PANEL_2)
	var brd: Color = {"primary": GOLD, "danger": Color("#ff8a70"), "big": GOLD, "green": GREEN}.get(style, BORDER)
	if style != "secondary":
		b.add_theme_stylebox_override("normal", box(col, brd, 12))
		b.add_theme_stylebox_override("hover", box(col.lightened(0.12), Color.WHITE, 12))
		b.add_theme_stylebox_override("pressed", box(col.darkened(0.2), Color.WHITE, 12))
		b.add_theme_stylebox_override("disabled", box(col.darkened(0.5), brd.darkened(0.5), 12))
	if style in ["primary", "danger", "big", "green"]:
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		b.add_theme_constant_override("outline_size", 5)
	b.mouse_filter = Control.MOUSE_FILTER_PASS  # lets ScrollContainers scroll by dragging over buttons
	var on_press := func() -> void:
		if Router.drag_dist > 18.0:
			return
		Audio.play_sfx("ui_click")
		cb.call()
	b.pressed.connect(on_press)
	return b


static func icon_button(icon: String, cb: Callable, size := 56, tooltip := "", badge := "") -> Button:
	## `icon` is a Glyph kind (see Glyph.KINDS) or short text.
	var is_glyph := icon in Glyph.KINDS
	var b := button("" if is_glyph else icon, cb, "secondary", int(size * bs()), size)
	b.tooltip_text = tooltip
	b.add_theme_font_size_override("font_size", int(size * 0.45 * ts()))
	if is_glyph:
		var gl := Glyph.make(icon, int(size * 0.5), TEXT)
		gl.set_anchors_preset(Control.PRESET_CENTER)
		gl.offset_left = -size * 0.25 * bs()
		gl.offset_top = -size * 0.25 * bs()
		gl.offset_right = size * 0.25 * bs()
		gl.offset_bottom = size * 0.25 * bs()
		b.add_child(gl)
	if badge != "":
		b.add_child(make_badge(badge))
	return b


static func make_badge(text: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(RED, Color.WHITE, 12, 2, 4))
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.offset_left = -18
	p.offset_top = -8
	p.offset_right = 8
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, 14, Color.WHITE, "bold")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.name = "Badge"
	return p


static func panel_box(bg := PANEL, border := BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, 14, 2, 18))
	return p


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func margin(c: Control, l := 16, t := 12, r := 16, b := 12) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(c)
	return m


static func spacer(expand_h := true) -> Control:
	var c := Control.new()
	if expand_h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func scroll(content: Control, horizontal := false) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if horizontal:
		s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	else:
		s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


static func progress(value: float, max_v: float, color := GOLD, h := 14) -> ProgressBar:
	var p := ProgressBar.new()
	p.max_value = maxf(max_v, 0.001)
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(60, h)
	p.add_theme_stylebox_override("fill", box(color, color, 6, 0, 0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func res_icon(res_id: String, size := 26) -> Control:
	var i := ResIcon.new()
	i.res_id = res_id
	i.custom_minimum_size = Vector2(size, size)
	return i


static func amount(res_id: String, value: int, size := 20, color := Color(0, 0, 0, 0)) -> HBoxContainer:
	var h := hbox(4)
	h.add_child(res_icon(res_id, int(size * 1.25)))
	var l := label(fmt(value), size, color, "bold")
	h.add_child(l)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func cost_row(cost: Dictionary, size := 20) -> HBoxContainer:
	var h := hbox(12)
	for k in cost.keys():
		var have: int = Game.res(k) if DB.resources.has(k) else Game.inventory.material_count(k)
		var ok := have >= int(cost[k])
		if DB.resources.has(k):
			h.add_child(amount(k, int(cost[k]), size, TEXT if ok else RED))
		else:
			h.add_child(label("%s x%d" % [DB.any_name(k), int(cost[k])], size, TEXT if ok else RED, "bold"))
	return h


static func fmt(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 10000:
		return "%.1fk" % (n / 1000.0)
	return str(n)


static func time_fmt(seconds: float) -> String:
	var s := int(ceil(seconds))
	if s >= 86400:
		return "%dj %dh" % [s / 86400, (s % 86400) / 3600]
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%dm %02ds" % [s / 60, s % 60]
	return "%ds" % s


static func rarity_badge(r: String, size := 15) -> PanelContainer:
	var p := PanelContainer.new()
	var c := DB.rarity_color(r)
	p.add_theme_stylebox_override("panel", box(c.darkened(0.55), c, 8, 2, 6))
	var l := label(DB.rarity_name(r).to_upper(), size, c.lightened(0.3), "bold")
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Header bar with back button and title, used by sub-screens.
static func header(title_text: String, extra: Control = null) -> HBoxContainer:
	var h := hbox(14)
	h.add_child(icon_button("back", Router.back, 56, TranslationServer.translate("BTN_BACK")))
	var t := title(title_text, 30)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if extra:
		h.add_child(extra)
	return h


static func reward_text(entry: Dictionary) -> String:
	match str(entry.type):
		"resource":
			return "+%s %s" % [fmt(int(entry.amount)), DB.resource_name(entry.id)]
		"xp":
			return "+%d XP" % int(entry.amount)
		"pass_xp":
			return "+%d XP Pass" % int(entry.amount)
		"chest":
			return DB.any_name(entry.id)
		"card", "card_new":
			return ("%s x%d" % [DB.any_name(entry.id), int(entry.amount)]) + ("  — " + TranslationServer.translate("LBL_NEW") if entry.type == "card_new" else "")
		"item", "material", "cosmetic":
			return DB.any_name(entry.id)
	return str(entry)


static func reward_rarity(entry: Dictionary) -> String:
	var id: String = str(entry.get("id", ""))
	for table in [DB.cards, DB.items, DB.cosmetics, DB.materials, DB.chests]:
		if table.has(id):
			return str(table[id].get("rarity", "common"))
	return "common"


## Shows a popup listing granted rewards (chest openings, claims...).
static func show_rewards(entries: Array, heading := "") -> void:
	if entries.is_empty():
		return
	var p := panel_box()
	p.custom_minimum_size = Vector2(620, 0)
	var v := vbox(10)
	p.add_child(v)
	var t := title(heading if heading != "" else TranslationServer.translate("LBL_REWARDS"), 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var best := 0
	var i := 0
	for e in entries:
		var r := reward_rarity(e)
		best = maxi(best, DB.rarity_rank(r))
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", box(DB.rarity_color(r).darkened(0.7), DB.rarity_color(r), 10, 2, 8))
		cell.custom_minimum_size = Vector2(190, 64)
		var cv := vbox(2)
		var name_l := label(reward_text(e), 17, TEXT, "bold")
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(name_l)
		if e.type in ["card", "card_new", "item", "material", "cosmetic", "chest"]:
			var rl := label(DB.rarity_name(r), 14, DB.rarity_color(r))
			rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(rl)
		cell.add_child(cv)
		grid.add_child(cell)
		if not Settings.get_v("limit_animations"):
			cell.modulate.a = 0.0
			cell.create_tween().tween_property(cell, "modulate:a", 1.0, 0.25).set_delay(0.06 * i)
		i += 1
	var sc := scroll(grid)
	sc.custom_minimum_size = Vector2(600, mini(420, 80 * int(ceil(entries.size() / 3.0)) + 10))
	v.add_child(sc)
	var ok := button(TranslationServer.translate("BTN_OK"), Router.close_popup, "primary", 200)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ok)
	Router.popup(p)
	Audio.play_sfx("chest_rare" if best >= 3 else "coin")
