class_name TopBar
extends PanelContainer
## Profile + currencies + notifications + settings. Values always come from Game.state.

var name_l: Label
var lvl_l: Label
var xp_bar: ProgressBar
var res_labels := {}
var bell: Button
var compact := false
var shown: Array = []


static func make(is_compact := false, resources: Array = []) -> TopBar:
	var t := TopBar.new()
	t.compact = is_compact
	t.shown = resources
	return t


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.05, 0.04, 0.82), UI.BORDER, 12, 2, 10))
	var h := UI.hbox(14)
	add_child(h)
	if not compact:
		var av := Panel.new()
		av.custom_minimum_size = Vector2(54, 54)
		av.add_theme_stylebox_override("panel", UI.box(Color("#3a5a2a"), UI.GOLD, 27, 3, 0))
		var al := UI.label(str(Game.state.profile.name).substr(0, 1).to_upper(), 28, Color.WHITE, "display")
		al.set_anchors_preset(Control.PRESET_FULL_RECT)
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		al.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		av.add_child(al)
		h.add_child(av)
		var pv := UI.vbox(2)
		name_l = UI.label("", 20, Color.WHITE, "bold")
		pv.add_child(name_l)
		var lh := UI.hbox(6)
		lvl_l = UI.label("", 15, UI.GOLD, "bold")
		lh.add_child(lvl_l)
		xp_bar = UI.progress(0, 1, Color("#58a6ff"), 10)
		xp_bar.custom_minimum_size = Vector2(120, 10)
		xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lh.add_child(xp_bar)
		pv.add_child(lh)
		h.add_child(pv)
	h.add_child(UI.spacer())
	var list: Array = shown if not shown.is_empty() else (["gold", "crystals", "war_tokens"] if not compact else ["gold", "crystals"])
	for r in list:
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.45), UI.BORDER.darkened(0.3), 16, 1, 8))
		var row := UI.hbox(6)
		row.add_child(UI.res_icon(r, 26))
		var l := UI.label("", 19, Color.WHITE, "bold")
		l.custom_minimum_size.x = 58
		row.add_child(l)
		box.add_child(row)
		box.tooltip_text = DB.resource_name(r)
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(box)
		res_labels[r] = l
	if not compact:
		bell = UI.icon_button("bell", _show_notifications, 52, tr("LBL_NOTIFICATIONS"))
		h.add_child(bell)
		h.add_child(UI.icon_button("gear", func() -> void: Router.goto("settings"), 52, tr("MENU_SETTINGS")))
	EventBus.resources_changed.connect(refresh)
	EventBus.profile_changed.connect(refresh)
	EventBus.missions_changed.connect(refresh)
	EventBus.pass_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	if name_l:
		name_l.text = str(Game.state.profile.name)
		lvl_l.text = tr("LBL_LEVEL") % Game.level()
		xp_bar.max_value = maxf(1, Game.xp_for_next() - Game.xp_for_current())
		xp_bar.value = int(Game.state.profile.xp) - Game.xp_for_current()
	for r in res_labels.keys():
		res_labels[r].text = UI.fmt(Game.res(r))
	if bell:
		var n := notifications().size()
		var old := bell.get_node_or_null("Badge")
		if old:
			old.free()
		if n > 0:
			bell.add_child(UI.make_badge(str(n)))


static func notifications() -> Array:
	var out: Array = []
	if Settings.get_v("notif_rewards"):
		var m: int = Game.missions.claimable_count()
		if m > 0:
			out.append({"text": TranslationServer.translate("NOTIF_MISSIONS") % m, "screen": "missions"})
		var pc: int = Game.season.claimable_count()
		if pc > 0:
			out.append({"text": TranslationServer.translate("NOTIF_PASS") % pc, "screen": "pass"})
		var ch: int = Game.chests.total_count()
		if ch > 0:
			out.append({"text": TranslationServer.translate("NOTIF_CHESTS") % ch, "screen": "chests"})
		if Game.shop.free_daily_available():
			out.append({"text": TranslationServer.translate("NOTIF_FREE_DAILY"), "screen": "shop"})
	if Settings.get_v("notif_progress"):
		for j in Game.state.lab.craft_queue:
			if Game.now() >= float(j.end):
				out.append({"text": TranslationServer.translate("NOTIF_CRAFT_DONE"), "screen": "lab"})
				break
		var ready := 0
		for bd in Game.base.b().buildings:
			if Game.base.production_of(bd).size() > 0 and Game.base.pending(bd) >= maxi(1, Game.base.capacity(bd) / 2):
				ready += 1
		if ready > 0:
			out.append({"text": TranslationServer.translate("NOTIF_PRODUCTION") % ready, "screen": "base"})
	if Settings.get_v("notif_events"):
		var ev: Dictionary = Game.campaign.current_event()
		if not ev.is_empty() and not Game.campaign.event_completed_this_week(ev.id):
			out.append({"text": TranslationServer.translate("NOTIF_EVENT") % DB.txt(ev), "screen": "events"})
	return out


func _show_notifications() -> void:
	var p := UI.panel_box()
	p.custom_minimum_size = Vector2(560, 0)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.title(tr("LBL_NOTIFICATIONS"), 28))
	var list := notifications()
	if list.is_empty():
		v.add_child(UI.para(tr("NOTIF_NONE"), 18))
	for n in list:
		var row := UI.hbox(10)
		var l := UI.label(n.text, 18)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		var go := func() -> void:
			Router.close_popup()
			Router.goto(n.screen)
		row.add_child(UI.button(tr("BTN_GO"), go, "primary", 110, 48))
		v.add_child(row)
	Router.popup(p)
