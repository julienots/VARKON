extends Control
## Combat hub: campaign chapters, raids, defense, survival, challenges, training, bosses.

var content: VBoxContainer
var tab := "campaign"
var chapter := 1
var tab_buttons := {}

const TABS := ["campaign", "raid", "defense", "survival", "challenges", "training", "bosses", "online"]


func setup(p: Dictionary) -> void:
	tab = str(p.get("tab", "campaign"))
	chapter = int(DB.missions[Game.campaign.current_mission()].chapter)
	UIScreen.background(self, Color("#2f7ad6"))
	var root := UIScreen.frame(self, tr("MENU_COMBAT"), UI.button(tr("BTN_DECK"), func() -> void: Router.goto("collection", {"tab": "deck"}), "secondary", 160, 52))
	var body := UI.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var side := UI.vbox(6)
	side.custom_minimum_size.x = 210
	for t in TABS:
		var b := UI.button(tr("TAB_" + t.to_upper()), _select.bind(t), "secondary", 210, 50)
		side.add_child(b)
		tab_buttons[t] = b
	body.add_child(UI.scroll(side))
	side.get_parent().custom_minimum_size.x = 220
	side.get_parent().size_flags_horizontal = Control.SIZE_FILL
	var panel := UI.panel_box()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content = UI.vbox(12)
	panel.add_child(content)
	body.add_child(panel)
	_select(tab)


func _select(t: String) -> void:
	tab = t
	for k in tab_buttons.keys():
		var b: Button = tab_buttons[k]
		b.modulate = Color(1, 1, 1) if k == t else Color(0.75, 0.72, 0.68)
		b.add_theme_color_override("font_color", UI.GOLD if k == t else UI.TEXT)
	for c in content.get_children():
		c.queue_free()
	match t:
		"campaign": _campaign()
		"raid": _free_mode("raid")
		"defense": _free_mode("defense")
		"survival": _free_mode("survival")
		"challenges": _challenges()
		"training": _training()
		"bosses": _bosses()
		"online": _online()


func _start(cfg: Dictionary) -> void:
	if not Game.collection.deck_complete() and not cfg.get("modifiers", {}).get("no_cards", false):
		Router.error("ERR_DECK_INCOMPLETE")
		return
	Router.start_battle(cfg)


# ------------------------------------------------------------------ campaign
func _campaign() -> void:
	var chs := UI.hbox(8)
	for ch in DB.campaign_json.chapters:
		var cid := int(ch.id)
		var unlocked: bool = cid == 1 or Game.campaign.chapter_completed(cid - 1)
		var b := UI.button(tr("LBL_CHAPTER") % cid, func() -> void:
			chapter = cid
			_select("campaign"), "primary" if cid == chapter else "secondary", 0, 48)
		b.disabled = not unlocked
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chs.add_child(b)
	content.add_child(chs)
	var chd: Dictionary = DB.campaign_json.chapters[chapter - 1]
	content.add_child(UI.title(DB.txt(chd), 28))
	content.add_child(UI.para(DB.txt(chd, "desc"), 17))
	var stars_in := 0
	for m in DB.mission_list:
		if int(m.chapter) == chapter:
			stars_in += Game.campaign.stars(m.id)
	content.add_child(UI.label(tr("LBL_STARS_CHAPTER") % [stars_in, 24], 16, UI.GOLD, "bold"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for m in DB.mission_list:
		if int(m.chapter) != chapter:
			continue
		grid.add_child(_mission_tile(m))
	content.add_child(UI.scroll(grid))


func _mission_tile(m: Dictionary) -> Control:
	var avail: bool = Game.campaign.is_available(m.id)
	var st: int = Game.campaign.stars(m.id)
	var is_boss: bool = m.type == "boss"
	var p := PanelContainer.new()
	var border := UI.GOLD if is_boss else (UI.GREEN if st > 0 else UI.BORDER)
	p.add_theme_stylebox_override("panel", UI.box(Color("#2a4482") if avail else Color("#1f305e"), border, 12, 3 if is_boss else 2, 10))
	p.custom_minimum_size = Vector2(196, 128)
	var v := UI.vbox(4)
	p.add_child(v)
	var hdr := UI.hbox(6)
	hdr.add_child(UI.label(str(m.id).to_upper(), 15, UI.TEXT_DIM, "bold"))
	hdr.add_child(UI.spacer())
	hdr.add_child(UI.label(tr("MODE_" + str(m.type).to_upper()), 14, UI.GOLD if is_boss else Color("#9ad7ff"), "bold"))
	v.add_child(hdr)
	var nm := UI.label(str(m.name), 17, Color.WHITE if avail else UI.TEXT_DIM, "bold")
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var sr := UI.hbox(2)
	if avail:
		for i in 3:
			sr.add_child(Glyph.make("star" if i < st else "star_empty", 20, UI.GOLD if i < st else UI.TEXT_DIM))
		sr.add_child(UI.spacer())
		sr.add_child(UI.label(tr("DIFF_" + str(m.difficulty).to_upper()), 13, UI.TEXT_DIM))
	else:
		sr.add_child(Glyph.make("lock", 20, UI.TEXT_DIM))
	v.add_child(sr)
	if avail:
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.pressed.connect(func() -> void:
			if Router.drag_dist < 18:
				_mission_popup(m))
		p.add_child(btn)
	return p


func _mission_popup(m: Dictionary) -> void:
	Audio.play_sfx("ui_open")
	var p := UI.panel_box()
	p.custom_minimum_size = Vector2(760, 0)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.title("%s — %s" % [str(m.id).to_upper(), m.name], 28))
	v.add_child(UI.label("%s  ·  %s  ·  %s" % [tr("MODE_" + str(m.type).to_upper()), tr("DIFF_" + str(m.difficulty).to_upper()), tr("LBL_ENEMY_LEVEL") % int(m.enemy_level)], 18, UI.TEXT_DIM))
	if m.has("boss"):
		v.add_child(UI.para(DB.txt(DB.bosses[m.boss], "desc"), 17, Color("#ff8a70")))
	if m.has("modifiers"):
		v.add_child(UI.label(str(m.modifiers.get("text", "")), 17, UI.GOLD, "bold"))
	if str(m.get("tip", "")) != "":
		v.add_child(UI.para(str(m.tip), 16))
	v.add_child(UI.label(tr("LBL_ENEMY_DECK"), 17, Color.WHITE, "bold"))
	var deck := UI.hbox(6)
	for cid in m.enemy_deck:
		deck.add_child(CardView.make(cid, Vector2(80, 106), 0))
	v.add_child(deck)
	var rw := UI.hbox(14)
	rw.add_child(UI.label(tr("LBL_REWARDS") + ":", 17, Color.WHITE, "bold"))
	rw.add_child(UI.amount("gold", int(m.rewards.gold), 17))
	rw.add_child(UI.label("+%d XP" % int(m.rewards.xp), 17, Color("#58a6ff"), "bold"))
	if not Game.state.claims.has("first_clear_" + m.id):
		var fc: Array = []
		for k in m.first_clear.keys():
			fc.append(DB.any_name(str(m.first_clear[k])) if not DB.resources.has(k) else "%d %s" % [int(m.first_clear[k]), DB.resource_name(k)])
		rw.add_child(UI.label(tr("LBL_FIRST_CLEAR") + ": " + ", ".join(fc), 16, UI.GOLD))
	v.add_child(rw)
	var h := UI.hbox(14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(UI.button(tr("BTN_CANCEL"), Router.close_popup, "secondary", 180))
	h.add_child(UI.button(tr("BTN_FIGHT"), func() -> void:
		Router.close_popup()
		_start(Game.campaign.mission_config(m.id)), "big", 240))
	v.add_child(h)
	Router.popup(p)


# ------------------------------------------------------------------ free modes
func _free_mode(mode: String) -> void:
	content.add_child(UI.title(tr("MODE_" + mode.to_upper()), 28))
	content.add_child(UI.para(tr("DESC_MODE_" + mode.to_upper()), 18))
	if mode == "raid" and not Game.base.raids_unlocked():
		content.add_child(UI.label(tr("LOCK_RAID_PORTAL"), 19, Color("#ff8a70"), "bold"))
		content.add_child(UI.button(tr("MENU_BASE"), func() -> void: Router.goto("base"), "secondary", 240))
		return
	if mode == "defense":
		var b: Dictionary = Game.base.battle_bonuses()
		content.add_child(UI.label(tr("LBL_DEFENSES") % [int(b.wall_segments), int(b.traps), int(b.tower_pct)], 17, Color("#9ad7ff")))
	if mode == "survival":
		content.add_child(UI.label(tr("LBL_SURVIVAL_BEST") % int(Game.state.survival_best), 19, UI.GOLD, "bold"))
	var h := UI.hbox(14)
	for d in ["easy", "normal", "expert"]:
		var diff: String = d
		h.add_child(UI.button(tr("DIFF_" + d.to_upper()), func() -> void: _start(Game.campaign.free_config(mode, diff)), "primary" if d == "normal" else "secondary", 200, 64))
	content.add_child(h)
	content.add_child(UI.para(tr("NOTE_BOTS"), 15))


func _challenges() -> void:
	content.add_child(UI.title(tr("TAB_CHALLENGES"), 28))
	var ev: Dictionary = Game.campaign.current_event()
	if not ev.is_empty():
		var ep := UI.panel_box(Color("#2a4482"), UI.GOLD)
		var ev_v := UI.vbox(6)
		ev_v.add_child(UI.label(tr("LBL_WEEKLY_EVENT") + " : " + DB.txt(ev), 20, UI.GOLD, "title"))
		ev_v.add_child(UI.para(DB.txt(ev, "desc"), 16))
		ev_v.add_child(UI.button(tr("MENU_EVENTS"), func() -> void: Router.goto("events"), "primary", 220, 48))
		ep.add_child(ev_v)
		content.add_child(ep)
	var list := UI.vbox(8)
	var mods: Array = [
		{"only_families": ["raider", "wild"], "text": tr("CH_RAIDER_WILD")}, {"energy_rate": 2.0, "text": tr("CH_DOUBLE_RAGE")},
		{"no_hero": true, "text": tr("CH_NO_KING")}, {"max_cost": 4, "text": tr("CH_MAX_COST")}, {"enemy_double_hp": true, "text": tr("CH_FORTIFIED")},
	]
	for m in mods:
		var row := UI.hbox(10)
		var l := UI.label(str(m.text), 18)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var mm: Dictionary = m
		row.add_child(UI.button(tr("BTN_FIGHT"), func() -> void:
			var cfg := Game.campaign.free_config("duel", "normal")
			cfg.mode = "challenge"
			cfg.modifiers = mm
			cfg.title = str(mm.text)
			cfg.player = Game.campaign.player_side(mm)
			_start(cfg), "primary", 160, 48))
		list.add_child(row)
	content.add_child(UI.scroll(list))
	content.add_child(UI.para(tr("NOTE_CHALLENGE_REWARD"), 15))


func _training() -> void:
	content.add_child(UI.title(tr("TAB_TRAINING"), 28))
	content.add_child(UI.para(tr("DESC_MODE_TRAINING"), 18))
	var h := UI.hbox(12)
	h.add_child(UI.button(tr("BTN_DUMMIES"), func() -> void: Router.start_battle(Game.campaign.free_config("training", "normal")), "primary", 240, 60))
	content.add_child(h)
	var h2 := UI.hbox(12)
	for d in ["easy", "normal", "expert"]:
		var diff: String = d
		h2.add_child(UI.button(tr("BTN_VS_BOT") % tr("DIFF_" + d.to_upper()), func() -> void:
			var cfg := Game.campaign.free_config("duel", diff)
			cfg.mode = "training"
			cfg.training_bot = true
			_start(cfg), "secondary", 220, 56))
	content.add_child(h2)


func _bosses() -> void:
	content.add_child(UI.title(tr("TAB_BOSSES"), 28))
	var list := UI.vbox(8)
	for ch in DB.campaign_json.chapters:
		var bid: String = ch.boss
		var bd: Dictionary = DB.bosses[bid]
		var beaten: bool = Game.campaign.is_completed("c%dm8" % int(ch.id))
		var row := UI.panel_box(Color("#2a4482"), UI.GOLD if beaten else UI.BORDER)
		var rh := UI.hbox(10)
		var rv := UI.vbox(2)
		rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rv.add_child(UI.label(DB.txt(bd), 20, UI.GOLD if beaten else UI.TEXT_DIM, "title"))
		rv.add_child(UI.para(DB.txt(bd, "desc"), 15))
		rh.add_child(rv)
		if beaten:
			rh.add_child(UI.button(tr("BTN_FIGHT"), func() -> void:
				var cfg := Game.campaign.free_config("boss", "normal")
				cfg.boss = bid
				cfg.boss_level = maxi(1, Game.level())
				cfg.title = DB.txt(bd)
				_start(cfg), "primary", 150, 52))
		else:
			rh.add_child(UI.label(tr("LOCK_BOSS") % int(ch.id), 16, UI.TEXT_DIM))
		row.add_child(rh)
		list.add_child(row)
	content.add_child(UI.scroll(list))


func _online() -> void:
	content.add_child(UI.title(tr("TAB_ONLINE"), 28))
	content.add_child(UI.para(tr("DESC_ONLINE_UNAVAILABLE"), 18, Color("#ff8a70")))
