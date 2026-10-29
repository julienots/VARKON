extends Control
## Card collection, card details/upgrades, deck building and synergies.

var tab := "cards"
var body: VBoxContainer
var filter_family := ""
var filter_rarity := ""
var filter_owned := false
var deck_pick := ""   # card selected in the deck to swap out


func setup(p: Dictionary) -> void:
	tab = str(p.get("tab", "cards"))
	UIScreen.background(self, Color("#3a63d6"))
	var root := UIScreen.frame(self, tr("MENU_COLLECTION"), null, true, ["gold", "fragments"])
	var tabs_holder := UI.hbox()
	root.add_child(tabs_holder)
	set_meta("tabs", tabs_holder)
	body = UI.vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	EventBus.collection_changed.connect(_refresh)
	_refresh()


func _set_tab(t: String) -> void:
	tab = t
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var th: HBoxContainer = get_meta("tabs")
	UIScreen.clear(th)
	UIScreen.tabs(th, ["cards", "deck", "synergies"], tab, _set_tab).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIScreen.clear(body)
	match tab:
		"cards": _cards()
		"deck": _deck()
		"synergies": _synergies()


# ------------------------------------------------------------------ cards
func _cards() -> void:
	var filters := UI.hbox(8)
	var fam := OptionButton.new()
	fam.add_item(tr("FILTER_ALL_FAMILIES"))
	fam.set_item_metadata(0, "")
	var fams := DB.families.keys()
	for i in fams.size():
		fam.add_item(DB.family_name(fams[i]))
		fam.set_item_metadata(i + 1, fams[i])
		if fams[i] == filter_family:
			fam.select(i + 1)
	fam.item_selected.connect(func(i: int) -> void:
		filter_family = str(fam.get_item_metadata(i))
		_refresh())
	fam.custom_minimum_size = Vector2(220, 48)
	filters.add_child(fam)
	var rar := OptionButton.new()
	rar.add_item(tr("FILTER_ALL_RARITIES"))
	rar.set_item_metadata(0, "")
	for i in DB.RARITY_ORDER.size():
		rar.add_item(DB.rarity_name(DB.RARITY_ORDER[i]))
		rar.set_item_metadata(i + 1, DB.RARITY_ORDER[i])
		if DB.RARITY_ORDER[i] == filter_rarity:
			rar.select(i + 1)
	rar.item_selected.connect(func(i: int) -> void:
		filter_rarity = str(rar.get_item_metadata(i))
		_refresh())
	rar.custom_minimum_size = Vector2(200, 48)
	filters.add_child(rar)
	var own := CheckButton.new()
	own.text = tr("FILTER_OWNED")
	own.button_pressed = filter_owned
	own.toggled.connect(func(v: bool) -> void:
		filter_owned = v
		_refresh())
	filters.add_child(own)
	filters.add_child(UI.spacer())
	filters.add_child(UI.label(tr("LBL_COLLECTION_COUNT") % [Game.state.cards.size(), DB.cards.size()], 18, UI.GOLD, "bold"))
	body.add_child(filters)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var list: Array = DB.card_list.duplicate()
	list.sort_custom(func(a, b):
		var oa := Game.collection.owns(a.id)
		var ob := Game.collection.owns(b.id)
		if oa != ob:
			return oa
		if a.family != b.family:
			return a.family < b.family
		return int(a.cost) < int(b.cost))
	for c in list:
		if filter_family != "" and c.family != filter_family:
			continue
		if filter_rarity != "" and c.rarity != filter_rarity:
			continue
		var owned := Game.collection.owns(c.id)
		if filter_owned and not owned:
			continue
		var holder := UI.vbox(2)
		var cv := CardView.make(c.id, Vector2(132, 176), Game.collection.level_of(c.id) if owned else 0, not owned)
		cv.tapped.connect(_card_detail)
		holder.add_child(cv)
		if owned:
			var cost: Dictionary = Game.collection.upgrade_cost(c.id)
			if not cost.is_empty():
				var pb := UI.progress(mini(Game.collection.copies_of(c.id), int(cost.copies)), maxi(1, int(cost.copies)), UI.GREEN if Game.collection.can_upgrade(c.id).ok else Color("#58a6ff"), 10)
				holder.add_child(pb)
			if c.id in Game.state.deck:
				var dl := UI.label(tr("LBL_IN_DECK"), 13, UI.GOLD, "bold")
				dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				holder.add_child(dl)
		grid.add_child(holder)
	body.add_child(UI.scroll(grid))


func _card_detail(cid: String) -> void:
	var d: Dictionary = DB.cards[cid]
	var st: Dictionary = d.stats
	var owned := Game.collection.owns(cid)
	var lvl := Game.collection.level_of(cid)
	var cur := Game.collection.stats_at(cid, lvl)
	var p := UI.panel_box()
	p.custom_minimum_size = Vector2(900, 0)
	var h := UI.hbox(20)
	p.add_child(h)
	var left := UI.vbox(8)
	left.add_child(CardView.make(cid, Vector2(220, 292), lvl if owned else 0, not owned))
	h.add_child(left)
	var v := UI.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.title(DB.txt(d), 30))
	var tags := UI.hbox(8)
	tags.add_child(UI.rarity_badge(d.rarity))
	tags.add_child(UI.label(DB.family_name(d.family), 17, DB.family_color(d.family), "bold"))
	tags.add_child(UI.label(tr("ROLE_" + str(d.role).to_upper()), 17, UI.TEXT_DIM))
	v.add_child(tags)
	v.add_child(UI.para(DB.txt(d, "desc"), 18, UI.TEXT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	var next_lvl := mini(lvl + 1, int(DB.cards_json.upgrade.max_level))
	var nxt := Game.collection.stats_at(cid, next_lvl)
	var show_next := owned and next_lvl > lvl
	grid.add_child(UIScreen.stat_row(tr("STAT_HP"), str(cur.hp) + (" » %d" % nxt.hp if show_next else "")))
	grid.add_child(UIScreen.stat_row(tr("STAT_DMG"), str(cur.dmg) + (" » %d" % nxt.dmg if show_next else "")))
	grid.add_child(UIScreen.stat_row(tr("STAT_HIT_SPEED"), "%.2fs" % float(st.hit)))
	grid.add_child(UIScreen.stat_row(tr("STAT_DPS"), "%d" % int(float(cur.dmg) / float(st.hit))))
	grid.add_child(UIScreen.stat_row(tr("STAT_RANGE"), tr("RANGE_MELEE") if float(st.range) < 1.5 else "%.1f" % float(st.range)))
	grid.add_child(UIScreen.stat_row(tr("STAT_SPEED"), "%.1f" % float(st.speed)))
	grid.add_child(UIScreen.stat_row(tr("STAT_COUNT"), "x%d" % int(st.count)))
	grid.add_child(UIScreen.stat_row(tr("STAT_TARGETS"), tr("TARGETS_STRUCTURES") if st.targets == "structures" else (tr("TARGETS_AIR_GROUND") if st.air else tr("TARGETS_GROUND"))))
	if st.flying:
		grid.add_child(UIScreen.stat_row(tr("STAT_MOVEMENT"), tr("LBL_FLYING")))
	v.add_child(grid)
	var syn: Dictionary = DB.synergies.get(d.family, {})
	if not syn.is_empty():
		v.add_child(UI.para(tr("LBL_SYNERGY") + " — " + DB.txt(syn) + " : " + DB.txt(syn, "desc"), 15, Color("#9ad7ff")))
	if owned:
		var cost: Dictionary = Game.collection.upgrade_cost(cid)
		if cost.is_empty():
			v.add_child(UI.label(tr("LBL_MAX_LEVEL"), 18, UI.GOLD, "bold"))
		else:
			v.add_child(UI.label(tr("LBL_COPIES") % [Game.collection.copies_of(cid), int(cost.copies)], 17))
			var up_cost := {"gold": int(cost.gold)}
			if int(cost.fragments) > 0:
				up_cost["fragments"] = int(cost.fragments)
				v.add_child(UI.para(tr("LBL_FRAGMENTS_REPLACE") % [int(cost.missing), int(cost.fragments)], 15, Color("#e0a0ff")))
			var row := UI.hbox(12)
			row.add_child(UI.cost_row(up_cost))
			var chk: Dictionary = Game.collection.can_upgrade(cid)
			var ub := UI.button(tr("BTN_UPGRADE"), func() -> void:
				Router.confirm_spend(tr("CONFIRM_UPGRADE_CARD") % DB.txt(d), up_cost, func() -> void:
					if Game.collection.upgrade(cid):
						Audio.play_sfx("upgrade")
						EventBus.notify(tr("TOAST_CARD_UPGRADED") % [DB.txt(d), Game.collection.level_of(cid)], "success")
						_card_detail(cid)
					else:
						Router.error(Game.collection.can_upgrade(cid).reason)), "primary", 200)
			ub.disabled = not chk.ok
			row.add_child(ub)
			if not chk.ok:
				row.add_child(UI.label(tr(chk.reason), 15, Color("#ff8a70")))
			v.add_child(row)
		var in_deck: bool = cid in Game.state.deck
		var db := UI.button(tr("BTN_REMOVE_DECK") if in_deck else tr("BTN_ADD_DECK"), func() -> void:
			var err: String = Game.collection.toggle_in_deck(cid)
			if err != "":
				if err == "ERR_DECK_FULL":
					Router.close_popup()
					deck_pick = ""
					tab = "deck"
					set_meta("swap_in", cid)
					_refresh()
					EventBus.notify(tr("TOAST_PICK_SWAP") % DB.txt(d), "info")
				else:
					Router.error(err)
			else:
				_card_detail(cid), "secondary", 220)
		v.add_child(db)
	else:
		v.add_child(UI.label(tr("LBL_NOT_OWNED"), 18, Color("#ff8a70"), "bold"))
		v.add_child(UI.para(tr("LBL_OBTAIN_CARD") % int(d.unlock_level), 16))
	v.add_child(UI.button(tr("BTN_CLOSE"), Router.close_popup, "secondary", 160))
	Router.popup(p)


# ------------------------------------------------------------------ deck
func _deck() -> void:
	var swap_in: String = str(get_meta("swap_in", ""))
	var info := UI.hbox(16)
	info.add_child(UI.label(tr("LBL_DECK_SIZE") % [Game.state.deck.size(), int(DB.battle_cfg().deck_size)], 20, UI.GOLD, "bold"))
	info.add_child(UI.label(tr("LBL_AVG_COST") % Game.collection.average_cost(Game.state.deck), 18, Color("#e0a0ff"), "bold"))
	if swap_in != "":
		info.add_child(UI.label(tr("LBL_SWAP_HINT") % DB.any_name(swap_in), 17, Color("#7bdc3a"), "bold"))
	body.add_child(info)
	var deck_row := UI.hbox(10)
	for cid in Game.state.deck:
		var cv := CardView.make(cid, Vector2(126, 168), Game.collection.level_of(cid))
		cv.set_selected(cid == deck_pick)
		cv.tapped.connect(func(id: String) -> void:
			if swap_in != "":
				Game.collection.swap_in_deck(id, swap_in)
				set_meta("swap_in", "")
				_refresh()
			else:
				deck_pick = "" if deck_pick == id else id
				_refresh())
		deck_row.add_child(cv)
	for i in int(DB.battle_cfg().deck_size) - Game.state.deck.size():
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(126, 168)
		empty.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.3), UI.BORDER, 10, 2, 0))
		deck_row.add_child(empty)
	body.add_child(deck_row)
	var syns := Collection.active_synergies(Game.state.deck)
	var sl := UI.hbox(10)
	sl.add_child(UI.label(tr("LBL_ACTIVE_SYNERGIES"), 17, Color.WHITE, "bold"))
	if syns.is_empty():
		sl.add_child(UI.label(tr("LBL_NONE"), 17, UI.TEXT_DIM))
	for s in syns:
		sl.add_child(UI.label(DB.txt(s), 17, DB.family_color(s.family), "bold"))
	body.add_child(sl)
	body.add_child(UI.label(tr("LBL_DECK_PICK_HINT") if deck_pick != "" else tr("LBL_DECK_TAP_HINT"), 16, UI.TEXT_DIM))
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var owned: Array = Game.state.cards.keys()
	owned.sort_custom(func(a, b): return int(DB.cards[a].cost) < int(DB.cards[b].cost) or (int(DB.cards[a].cost) == int(DB.cards[b].cost) and a < b))
	for cid in owned:
		if cid in Game.state.deck:
			continue
		var cv2 := CardView.make(cid, Vector2(112, 150), Game.collection.level_of(cid))
		cv2.tapped.connect(func(id: String) -> void:
			if deck_pick != "":
				Game.collection.swap_in_deck(deck_pick, id)
				deck_pick = ""
			else:
				var err := Game.collection.toggle_in_deck(id)
				if err == "ERR_DECK_FULL":
					Router.error("ERR_DECK_PICK_FIRST")
			_refresh())
		grid.add_child(cv2)
	body.add_child(UI.scroll(grid))


func _synergies() -> void:
	var list := UI.vbox(8)
	var counts := Collection.family_counts(Game.state.deck)
	for fam in DB.synergies.keys():
		var s: Dictionary = DB.synergies[fam]
		var active := int(counts.get(fam, 0)) >= int(s.need)
		var row := UI.panel_box(Color("#2a4482"), DB.family_color(fam) if active else UI.BORDER)
		var h := UI.hbox(12)
		var fl := UI.label(DB.family_name(fam), 19, DB.family_color(fam), "bold")
		fl.custom_minimum_size.x = 150
		h.add_child(fl)
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(DB.txt(s), 18, Color.WHITE, "bold"))
		v.add_child(UI.para(DB.txt(s, "desc"), 15))
		h.add_child(v)
		h.add_child(UI.label("%d / %d" % [int(counts.get(fam, 0)), int(s.need)], 20, UI.GREEN if active else UI.TEXT_DIM, "display"))
		row.add_child(h)
		list.add_child(row)
	body.add_child(UI.para(tr("DESC_SYNERGIES"), 16))
	body.add_child(UI.scroll(list))
