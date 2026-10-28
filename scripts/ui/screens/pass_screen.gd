extends Control
## Season pass: free and premium tracks, real tier progress and claim states.

var body: VBoxContainer


func setup(_p: Dictionary) -> void:
	Game.season.ensure_season()
	UIScreen.background(self, Color("#120f16"))
	var root := UIScreen.frame(self, tr("MENU_PASS"))
	body = UI.vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	EventBus.pass_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	UIScreen.clear(body)
	var cfg: Dictionary = DB.season
	var head := UI.hbox(16)
	var hv := UI.vbox(4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.title(DB.txt(cfg), 26))
	var active: bool = Game.season.is_active()
	hv.add_child(UI.label((tr("LBL_SEASON_LOCAL") % UI.time_fmt(Game.season.seconds_left())) if active else tr("LBL_SEASON_ENDED"), 15, UI.TEXT_DIM))
	var tier: int = Game.season.tier()
	var xp_in := Game.season.xp() - tier * int(cfg.xp_per_tier)
	hv.add_child(UI.label(tr("LBL_TIER") % [tier, cfg.tiers.size()], 18, UI.GOLD, "bold"))
	var pb := UI.progress(xp_in if tier < cfg.tiers.size() else 1, int(cfg.xp_per_tier) if tier < cfg.tiers.size() else 1, Color("#a35bff"), 14)
	pb.custom_minimum_size.x = 380
	hv.add_child(pb)
	hv.add_child(UI.label(tr("LBL_PASS_XP_SOURCES") % [int(cfg.xp_sources.battle_win), int(cfg.xp_sources.daily_mission), int(cfg.xp_sources.weekly_mission)], 14, UI.TEXT_DIM))
	head.add_child(hv)
	var prem: bool = Game.state.pass.premium
	if prem:
		head.add_child(UI.label(tr("LBL_PREMIUM_ACTIVE"), 20, UI.GOLD, "display"))
	else:
		var price: Dictionary = cfg.premium_price
		var bb := UI.button(tr("BTN_BUY_PREMIUM") % int(price.crystals), func() -> void:
			Router.confirm_spend(tr("CONFIRM_PREMIUM"), price, func() -> void:
				var err: String = Game.season.buy_premium()
				if err != "":
					Router.error(err)
				else:
					Audio.play_sfx("chest_rare")), "primary", 300, 56)
		bb.disabled = not active
		head.add_child(bb)
	var ca := UI.button(tr("BTN_CLAIM_ALL") + " (%d)" % Game.season.claimable_count(), func() -> void:
		UI.show_rewards(Game.season.claim_all())
		_refresh(), "green", 220, 56)
	ca.disabled = Game.season.claimable_count() == 0
	head.add_child(ca)
	body.add_child(head)
	body.add_child(UI.para(tr("DESC_PASS"), 14))
	# Tracks
	var row := UI.hbox(8)
	var labels := UI.vbox(8)
	labels.add_child(UI.label(" ", 16))
	var fl := UI.label(tr("TRACK_FREE"), 16, UI.GREEN, "bold")
	fl.custom_minimum_size = Vector2(110, 120)
	fl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	labels.add_child(fl)
	var pl := UI.label(tr("TRACK_PREMIUM"), 16, UI.GOLD, "bold")
	pl.custom_minimum_size = Vector2(110, 120)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	labels.add_child(pl)
	row.add_child(labels)
	var tiers := UI.hbox(8)
	for t in cfg.tiers:
		var col := UI.vbox(8)
		var tl := UI.label(str(int(t.tier)), 18, UI.GOLD if int(t.tier) <= tier else UI.TEXT_DIM, "display")
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(tl)
		col.add_child(_cell(int(t.tier), "free", t.free, tier))
		col.add_child(_cell(int(t.tier), "premium", t.premium, tier))
		tiers.add_child(col)
	var sc := UI.scroll(tiers, true)
	row.add_child(sc)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	# scroll to current tier
	await get_tree().process_frame
	if is_instance_valid(sc):
		sc.scroll_horizontal = maxi(0, (tier - 2) * 148)


func _reward_label(r: Dictionary) -> Array:
	## [text, rarity]
	for k in r.keys():
		var v = r[k]
		if DB.resources.has(k):
			return ["%d %s" % [int(v), DB.resource_name(k)], "common"]
		match k:
			"chest": return [DB.any_name(str(v)), DB.chests[str(v)].rarity]
			"item": return [DB.any_name(str(v)), DB.items[str(v)].rarity]
			"cosmetic": return [DB.any_name(str(v)), DB.cosmetics[str(v)].rarity]
	return ["?", "common"]


func _cell(t: int, track: String, reward: Dictionary, cur_tier: int) -> Control:
	var info := _reward_label(reward)
	var p := PanelContainer.new()
	var claimed: bool = Game.season.is_claimed(t, track)
	var can: String = Game.season.can_claim(t, track)
	var border := DB.rarity_color(info[1]) if can == "" else (UI.GREEN if claimed else UI.BORDER.darkened(0.3))
	p.add_theme_stylebox_override("panel", UI.box(Color("#221a13") if t <= cur_tier else Color("#151110"), border, 10, 2, 8))
	p.custom_minimum_size = Vector2(140, 120)
	var v := UI.vbox(4)
	p.add_child(v)
	var l := UI.label(str(info[0]), 14, DB.rarity_color(info[1]) if info[1] != "common" else Color.WHITE, "bold")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(l)
	if claimed:
		v.add_child(UI.label(tr("LBL_CLAIMED"), 13, UI.GREEN, "bold"))
	elif can == "":
		v.add_child(UI.button(tr("BTN_CLAIM"), func() -> void:
			UI.show_rewards(Game.season.claim(t, track))
			_refresh(), "green", 0, 36))
	elif can == "ERR_PREMIUM_REQUIRED":
		v.add_child(Glyph.make("lock", 18, UI.GOLD))
	else:
		v.add_child(UI.label(tr("LBL_TIER_SHORT") % t, 13, UI.TEXT_DIM))
	return p
