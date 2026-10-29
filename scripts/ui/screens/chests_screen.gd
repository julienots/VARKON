extends Control
## Chests: owned counts, exact drop odds (computed from the real loot tables), opening animation.

var grid: GridContainer
var opening := false


func setup(_p: Dictionary) -> void:
	UIScreen.background(self, Color("#d9831f"))
	var root := UIScreen.frame(self, tr("MENU_CHESTS"))
	root.add_child(UI.para(tr("DESC_CHESTS"), 16))
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	root.add_child(UI.scroll(grid))
	_refresh()


func _refresh() -> void:
	UIScreen.clear(grid)
	for ch in DB.economy.chests:
		var cid: String = ch.id
		var n: int = Game.chests.count(cid)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.box(Color("#2a4482"), DB.rarity_color(ch.rarity), 14, 3 if n > 0 else 1, 12))
		p.custom_minimum_size = Vector2(280, 230)
		var v := UI.vbox(6)
		p.add_child(v)
		var icon := ChestIcon.make(Color(ch.color), 90)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
		var nl := UI.label(DB.txt(ch), 19, DB.rarity_color(ch.rarity), "title")
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
		var cl := UI.label(tr("LBL_OWNED") % n, 16, Color.WHITE if n > 0 else UI.TEXT_DIM, "bold")
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cl)
		var h := UI.hbox(8)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(UI.button(tr("BTN_ODDS"), _odds.bind(cid), "secondary", 110, 44))
		var ob := UI.button(tr("BTN_OPEN"), _open.bind(cid), "primary", 120, 44)
		ob.disabled = n <= 0
		h.add_child(ob)
		v.add_child(h)
		grid.add_child(p)


func _odds(cid: String) -> void:
	var ch: Dictionary = DB.chests[cid]
	var p := UI.panel_box()
	p.custom_minimum_size = Vector2(640, 0)
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.title(DB.txt(ch), 26))
	v.add_child(UI.para(DB.txt(ch, "desc"), 16, UI.TEXT))
	v.add_child(UIScreen.stat_row(DB.resource_name("gold"), "%d - %d" % [int(ch.gold[0]), int(ch.gold[1])]))
	for k in ch.get("resources", {}).keys():
		v.add_child(UIScreen.stat_row(DB.resource_name(k), "%d - %d" % [int(ch.resources[k][0]), int(ch.resources[k][1])]))
	for r in Game.chests.effective_odds(cid):
		if r.type in ["card", "item"]:
			v.add_child(UI.label(tr("ODDS_" + str(r.type).to_upper()) % int(r.count), 17, UI.GOLD, "bold"))
			var row := UI.hbox(14)
			for rar in DB.RARITY_ORDER:
				if r.odds.has(rar):
					row.add_child(UI.label("%s %.1f%%" % [DB.rarity_name(rar), float(r.odds[rar]) * 100.0], 15, DB.rarity_color(rar), "bold"))
			v.add_child(row)
		else:
			var what := DB.any_name(str(r.id))
			v.add_child(UIScreen.stat_row(what, "%.0f%%" % (float(r.chance) * 100.0)))
	v.add_child(UI.para(tr("ODDS_NOTE"), 14))
	v.add_child(UI.button(tr("BTN_CLOSE"), Router.close_popup, "secondary", 160))
	Router.popup(p)


func _open(cid: String) -> void:
	if opening or Game.chests.count(cid) <= 0:
		return
	opening = true
	var ch: Dictionary = DB.chests[cid]
	# Animation overlay
	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.8)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ov)
	var icon := ChestIcon.make(Color(ch.color), 220)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.position = get_viewport_rect().size / 2 - Vector2(110, 110)
	icon.pivot_offset = Vector2(110, 110)
	ov.add_child(icon)
	Audio.play_sfx("chest_open")
	var anim: bool = not Settings.get_v("limit_animations")
	if anim:
		var tw := create_tween()
		for i in 6:
			tw.tween_property(icon, "rotation", 0.08 * (1 if i % 2 == 0 else -1), 0.07)
		tw.tween_property(icon, "rotation", 0.0, 0.05)
		tw.tween_property(icon, "scale", Vector2(1.2, 1.2), 0.15)
		await tw.finished
	icon.open_lid()
	var sp := CPUParticles2D.new()
	sp.amount = maxi(1, Settings.particle_amount(80))
	sp.one_shot = true
	sp.explosiveness = 0.9
	sp.lifetime = 1.0
	sp.spread = 180
	sp.initial_velocity_min = 200
	sp.initial_velocity_max = 450
	sp.gravity = Vector2(0, 400)
	sp.scale_amount_min = 3
	sp.scale_amount_max = 7
	sp.color = DB.rarity_color(ch.rarity).lightened(0.3)
	sp.position = icon.position + Vector2(110, 90)
	ov.add_child(sp)
	sp.emitting = Settings.particle_amount(80) > 0
	var entries: Array = Game.chests.open(cid)
	if anim:
		await get_tree().create_timer(0.7).timeout
	ov.queue_free()
	opening = false
	_refresh()
	UI.show_rewards(entries, DB.txt(ch))
