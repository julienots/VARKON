extends Control
## Battle results: outcome, stars, statistics and rewards actually granted.


func setup(_p: Dictionary) -> void:
	var data: Dictionary = Game.last_battle_result
	var res: Dictionary = data.get("result", {})
	var cfg: Dictionary = data.get("cfg", {})
	var report: Dictionary = data.get("report", {})
	Audio.play_music("music_menu")
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.035, 0.03, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := UI.vbox(14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_right = -60
	root.offset_top = 30
	root.offset_bottom = -24
	add_child(root)
	var won: bool = res.get("won", false)
	var t := UI.title(tr("LBL_VICTORY") if won else (tr("LBL_DRAW") if res.get("draw", false) else tr("LBL_DEFEAT")), 56)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", UI.GOLD if won else Color("#ff8a70"))
	root.add_child(t)
	var sub := UI.label(str(cfg.get("title", "")), 22, UI.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)
	if cfg.get("mode", "") != "training":
		var stars := UI.hbox(12)
		stars.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in 3:
			var gl := Glyph.make("star" if i < int(report.get("stars", 0)) else "star_empty", 54, UI.GOLD if i < int(report.get("stars", 0)) else UI.TEXT_DIM)
			stars.add_child(gl)
			if i < int(report.get("stars", 0)) and not Settings.get_v("limit_animations"):
				gl.scale = Vector2(0.1, 0.1)
				gl.pivot_offset = Vector2(27, 27)
				gl.create_tween().tween_property(gl, "scale", Vector2.ONE, 0.3).set_delay(0.25 * i).set_trans(Tween.TRANS_BACK)
		root.add_child(stars)
	var cols := UI.hbox(24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var sp := UI.panel_box()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sv := UI.vbox(8)
	sp.add_child(sv)
	sv.add_child(UI.title(tr("LBL_STATS"), 24))
	var rows := [["STAT_TIME", "%d:%02d" % [int(res.get("time", 0)) / 60, int(res.get("time", 0)) % 60]],
		["STAT_UNITS", str(res.get("units_deployed", 0))], ["STAT_ABILITIES", str(res.get("abilities_used", 0))],
		["STAT_DAMAGE", UI.fmt(int(res.get("damage_dealt", 0)))], ["STAT_DESTROYED", str(res.get("structures_destroyed", 0))],
		["STAT_LOST", str(res.get("structures_lost", 0))]]
	if cfg.get("mode", "") in ["defense", "survival"]:
		rows.append(["STAT_WAVES", str(res.get("waves_cleared", 0))])
	for r in rows:
		var h := UI.hbox()
		var l := UI.label(tr(r[0]), 19, UI.TEXT_DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(UI.label(r[1], 19, Color.WHITE, "bold"))
		sv.add_child(h)
	cols.add_child(sp)
	var rp := UI.panel_box()
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rv := UI.vbox(8)
	rp.add_child(rv)
	rv.add_child(UI.title(tr("LBL_REWARDS"), 24))
	var entries: Array = report.get("entries", [])
	if entries.is_empty():
		rv.add_child(UI.para(tr("LBL_NO_REWARDS") if cfg.get("mode", "") != "training" else tr("LBL_TRAINING_NO_REWARDS"), 18))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	for e in entries:
		var r2 := UI.reward_rarity(e)
		grid.add_child(UI.label(UI.reward_text(e), 18, DB.rarity_color(r2) if e.type in ["card", "card_new", "item", "chest", "material", "cosmetic"] else Color.WHITE, "bold"))
	rv.add_child(UI.scroll(grid))
	cols.add_child(rp)
	var btns := UI.hbox(16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_child(UI.button(tr("BTN_MENU"), Router.home, "secondary", 220))
	var mid: String = str(cfg.get("mission_id", ""))
	var retry := func() -> void:
		var c2: Dictionary
		if mid != "":
			c2 = Game.campaign.mission_config(mid)
		else:
			c2 = cfg.duplicate(true)
			c2.player = Game.campaign.player_side(cfg.get("modifiers", {}))
			c2.erase("battle_id")
		Router.start_battle(c2)
	btns.add_child(UI.button(tr("BTN_RETRY"), retry, "secondary", 220))
	if mid != "" and won:
		var idx := DB.mission_list.find(DB.missions[mid])
		if idx + 1 < DB.mission_list.size():
			var nxt: String = DB.mission_list[idx + 1].id
			btns.add_child(UI.button(tr("BTN_NEXT_MISSION"), func() -> void: Router.start_battle(Game.campaign.mission_config(nxt)), "primary", 260))
	btns.add_child(UI.button(tr("MENU_COMBAT"), func() -> void: Router.goto("combat"), "secondary", 200))
	root.add_child(btns)
