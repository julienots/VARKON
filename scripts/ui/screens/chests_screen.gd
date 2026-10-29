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
		var tcol := Color(ch.color).lerp(DB.rarity_color(ch.rarity), 0.35)
		p.add_theme_stylebox_override("panel", UI.tile(tcol if n > 0 else tcol.lerp(Color("#5a6a8a"), 0.55), 10))
		p.custom_minimum_size = Vector2(286, 236)
		var v := UI.vbox(4)
		p.add_child(v)
		var top := UI.hbox(4)
		top.add_child(UI.rarity_badge(ch.rarity, 12))
		top.add_child(UI.spacer())
		top.add_child(UI.icon_button("info", _odds.bind(cid), 40, tr("BTN_ODDS")))
		v.add_child(top)
		var icon := ChestIcon.make(Color(ch.color), 84)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
		var nl := UI.label(DB.txt(ch), 19, Color.WHITE, "display")
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.add_theme_constant_override("outline_size", 6)
		v.add_child(nl)
		var ob := UI.button(tr("BTN_OPEN") + ("  x%d" % n if n > 0 else ""), _open.bind(cid), "primary" if n > 0 else "grey", 220, 48)
		ob.disabled = n <= 0
		ob.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ob)
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
