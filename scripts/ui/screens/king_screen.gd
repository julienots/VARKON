extends Control
## King Gobelin: equipment (with live preview & comparison), appearance, abilities, mutations,
## loadouts, cosmetics and full statistics.

var tab := "equipment"
var preview: KingPreview
var panel_body: VBoxContainer
var power_label: Label
var slot_open := ""


func setup(p: Dictionary) -> void:
	tab = str(p.get("tab", "equipment"))
	UIScreen.background(self, Color("#2f6fd6"))
	var root := UIScreen.frame(self, tr("MENU_KING"), null, true, ["gold", "mutant_essence"])
	var body := UI.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var left := UI.vbox(8)
	left.custom_minimum_size.x = 420
	preview = KingPreview.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(420, 380)
	left.add_child(preview)
	power_label = UI.label("", 22, UI.GOLD, "display")
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(power_label)
	left.add_child(UI.label(tr("LBL_DRAG_ROTATE"), 14, UI.TEXT_DIM))
	body.add_child(left)
	var right := UI.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var th := UI.hbox()
	right.add_child(th)
	set_meta("tabs", th)
	var panel := UI.panel_box()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_body = UI.vbox(8)
	panel.add_child(panel_body)
	right.add_child(panel)
	body.add_child(right)
	EventBus.king_changed.connect(_on_king_changed)
	_refresh()


func _on_king_changed() -> void:
	if is_inside_tree():
		preview.override_visuals = {}
		preview.override_appearance = {}
		preview.rebuild()
		_refresh()


func _set_tab(t: String) -> void:
	tab = t
	slot_open = ""
	preview.override_visuals = {}
	preview.override_appearance = {}
	preview.rebuild()
	_refresh()


func _refresh() -> void:
	var th: HBoxContainer = get_meta("tabs")
	UIScreen.clear(th)
	UIScreen.tabs(th, ["equipment", "appearance", "abilities", "mutations", "loadouts", "cosmetics", "stats"], tab, _set_tab).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIScreen.clear(panel_body)
	var st: Dictionary = Game.king.current_stats()
	power_label.text = tr("LBL_POWER") % int(st.power)
	match tab:
		"equipment": _equipment()
		"appearance": _appearance()
		"abilities": _abilities()
		"mutations": _mutations()
		"loadouts": _loadouts()
		"cosmetics": _cosmetics()
		"stats": _stats()


# ------------------------------------------------------------------ equipment
func _equipment() -> void:
	var h := UI.hbox(12)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_body.add_child(h)
	var slots := UI.vbox(4)
	for s in DB.slots:
		var sid: String = s.id
		var unlocked: bool = Game.king.slot_unlocked(sid)
		var d: Dictionary = Game.king.equipped_def(sid)
		var row := UI.hbox(6)
		var txt := "%s : %s" % [DB.slot_name(sid), DB.txt(d) if not d.is_empty() else tr("LBL_EMPTY")]
		var b := UI.button(txt, func() -> void:
			slot_open = sid
			_refresh(), "secondary", 330, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_font_size_override("font_size", int(16 * UI.ts()))
		if not d.is_empty():
			b.add_theme_color_override("font_color", DB.rarity_color(d.rarity))
		if not unlocked:
			b.disabled = true
			b.text = "%s : %s" % [DB.slot_name(sid), Game.condition_text(s.unlock)]
		if sid == slot_open:
			b.add_theme_stylebox_override("normal", UI.box(UI.PANEL_2, UI.GOLD, 10))
		row.add_child(b)
		slots.add_child(row)
	h.add_child(UI.scroll(slots))
	slots.get_parent().custom_minimum_size.x = 345
	var detail := UI.vbox(8)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(detail)
	if slot_open == "":
		detail.add_child(UI.para(tr("HINT_PICK_SLOT"), 17))
		return
	detail.add_child(UI.title(DB.slot_name(slot_open), 22))
	var uids: Array = Game.inventory.items_for_slot(slot_open)
	if uids.is_empty():
		detail.add_child(UI.para(tr("LBL_NO_ITEM_SLOT"), 16))
	var list := UI.vbox(6)
	for uid in uids:
		var d2: Dictionary = Game.inventory.item_def(uid)
		var eq: bool = Game.king.equipped(slot_open) == uid
		var item_btn := UI.button(("» " if eq else "") + DB.txt(d2) + ("  (" + tr("LBL_COSMETIC") + ")" if d2.get("cosmetic", false) else ""), _show_item.bind(uid), "secondary", 0, 44)
		item_btn.add_theme_color_override("font_color", DB.rarity_color(d2.rarity))
		item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(item_btn)
	detail.add_child(UI.scroll(list))
	if Game.king.equipped(slot_open) != "":
		detail.add_child(UI.button(tr("BTN_UNEQUIP"), func() -> void: Game.king.unequip(slot_open), "secondary", 200, 44))


func _show_item(uid: String) -> void:
	var d: Dictionary = Game.inventory.item_def(uid)
	# Live preview on the model
	var v: Dictionary = d.visual.duplicate()
	preview.override_visuals = {d.slot: v}
	preview.rebuild()
	var p := UI.panel_box()
	p.custom_minimum_size = Vector2(620, 0)
	var box := UI.vbox(8)
	p.add_child(box)
	box.add_child(UI.title(DB.txt(d), 26))
	var tags := UI.hbox(8)
	tags.add_child(UI.rarity_badge(d.rarity))
	tags.add_child(UI.label(DB.slot_name(d.slot) + " · " + tr("CAT_" + str(d.category).to_upper()), 16, UI.TEXT_DIM))
	if d.get("cosmetic", false):
		tags.add_child(UI.label(tr("LBL_COSMETIC_ONLY"), 16, Color("#9ad7ff"), "bold"))
	box.add_child(tags)
	box.add_child(UI.para(DB.txt(d, "desc"), 17, UI.TEXT))
	box.add_child(UI.label(tr("LBL_ORIGIN") + " : " + ", ".join(d.sources.map(func(x): return tr("SRC_" + str(x).to_upper()))), 15, UI.TEXT_DIM))
	if Game.lab.relic_level(uid) > 0:
		box.add_child(UI.label(tr("LBL_RELIC_LEVEL") % Game.lab.relic_level(uid), 15, UI.GOLD))
	# Comparison
	var cur: Dictionary = Game.king.current_stats()
	var nw: Dictionary = Game.king.preview_with(uid)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	for k in [["hp", "STAT_HP", "%d"], ["dmg", "STAT_DMG", "%d"], ["armor", "STAT_ARMOR", "%.0f"], ["hit", "STAT_HIT_SPEED", "%.2fs"], ["range", "STAT_RANGE", "%.1f"], ["speed", "STAT_SPEED", "%.2f"], ["resist", "STAT_RESIST", "%.0f"], ["cdr_pct", "STAT_CDR", "%.0f%%"], ["ability_power_pct", "STAT_AP", "%.0f%%"]]:
		var a := float(cur[k[0]])
		var b := float(nw[k[0]])
		if absf(a - b) < 0.001 and a == 0.0:
			continue
		grid.add_child(UI.label(tr(k[1]), 16, UI.TEXT_DIM))
		grid.add_child(UI.label(k[2] % a, 16, Color.WHITE))
		grid.add_child(UI.label("»", 16, UI.TEXT_DIM))
		var better: bool = (b > a) if k[0] != "hit" else (b < a)
		var col := Color.WHITE if absf(a - b) < 0.001 else (UI.GREEN if better else UI.RED)
		grid.add_child(UI.label(k[2] % b, 16, col, "bold"))
	box.add_child(grid)
	for e in d.get("effects", []):
		box.add_child(UI.label("• " + tr("EFF_" + str(e.type).to_upper()), 15, Color("#e0a0ff")))
	var h := UI.hbox(12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(UI.button(tr("BTN_CLOSE"), func() -> void:
		Router.close_popup()
		preview.override_visuals = {}
		preview.rebuild(), "secondary", 160))
	var eqb := UI.button(tr("BTN_EQUIP"), func() -> void:
		var err: String = Game.king.equip(uid)
		Router.close_popup()
		if err != "":
			Router.error(err)
		else:
			Audio.play_sfx("upgrade")
			preview.play("flex", 1.2), "primary", 200)
	eqb.disabled = Game.king.equipped(d.slot) == uid
	h.add_child(eqb)
	box.add_child(h)
	Router.popup(p)


# ------------------------------------------------------------------ appearance
func _appearance() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 6)
	var app: Dictionary = Game.state.king.appearance
	for key in KingSystem.APPEARANCE_KEYS:
		var opts: Array = Game.king.appearance_options(key)
		var idx := int(app.get(key, 0))
		var row := UI.hbox(6)
		var l := UI.label(tr("APP_" + key.to_upper()), 16, UI.TEXT_DIM)
		l.custom_minimum_size.x = 130
		row.add_child(l)
		row.add_child(UI.button("<", _cycle.bind(key, -1), "secondary", 44, 40))
		var val := str(opts[idx]) if idx < opts.size() else "?"
		var vl: Control
		if val.begins_with("#"):
			var sw := ColorRect.new()
			sw.color = Color(val)
			sw.custom_minimum_size = Vector2(120, 30)
			vl = sw
		else:
			var lab := UI.label(val if not key in ["height", "bulk"] else "%d%%" % int(float(val) * 100), 16, Color.WHITE, "bold")
			lab.custom_minimum_size.x = 120
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vl = lab
		row.add_child(vl)
		row.add_child(UI.button(">", _cycle.bind(key, 1), "secondary", 44, 40))
		grid.add_child(row)
	panel_body.add_child(UI.scroll(grid))
	panel_body.add_child(UI.para(tr("HINT_APPEARANCE"), 15))


func _cycle(key: String, d: int) -> void:
	var opts := Game.king.appearance_options(key)
	var cur := int(Game.state.king.appearance.get(key, 0))
	var n := opts.size()
	for i in n:
		cur = (cur + d + n) % n
		var lock := Game.king.appearance_locked(key, cur)
		if lock == "":
			Game.king.set_appearance(key, cur)
			if key == "voice":
				Audio.play_sfx("goblin_grunt", [0.85, 0.95, 1.3, 1.0][cur % 4])
			return
		else:
			EventBus.notify(tr("LBL_LOCKED_OPTION") % [str(opts[cur]), lock], "info")


# ------------------------------------------------------------------ abilities
func _abilities() -> void:
	for slot in ["active", "defensive", "ultimate", "passive"]:
		panel_body.add_child(UI.label(tr("ABSLOT_" + slot.to_upper()), 19, UI.GOLD, "title"))
		var row := UI.hbox(8)
		for a in Game.king.abilities_for_slot(slot):
			var aid: String = a.id
			var why: String = Game.king.ability_available(aid)
			var cur: bool = Game.state.king.abilities.get(slot, "") == aid
			var b := UI.button(DB.txt(a), func() -> void:
				if Game.king.set_ability(slot, aid):
					Audio.play_sfx("ui_confirm"), "primary" if cur else "secondary", 220, 48)
			b.tooltip_text = DB.txt(a, "desc") + ("" if why == "" else "\n" + why)
			b.disabled = why != ""
			row.add_child(b)
		panel_body.add_child(row)
		var cur_id: String = Game.state.king.abilities.get(slot, "")
		if DB.abilities.has(cur_id):
			panel_body.add_child(UI.para(DB.txt(DB.abilities[cur_id], "desc"), 15))


# ------------------------------------------------------------------ mutations
func _mutations() -> void:
	if not Game.lab.is_unlocked():
		panel_body.add_child(UI.para(tr("LOCK_LAB"), 18, Color("#ff8a70")))
		for s in Game.lab.unlock_status():
			panel_body.add_child(UI.label(("» " if s.ok else "• ") + str(s.text), 17, UI.GREEN if s.ok else UI.TEXT_DIM))
		panel_body.add_child(UI.button(tr("MENU_BASE"), func() -> void: Router.goto("base"), "secondary", 220))
		return
	panel_body.add_child(UI.label(tr("LBL_MUTATION_SLOTS") % [Game.state.king.mutations_active.size(), Game.king.mutation_slots()], 18, UI.GOLD, "bold"))
	var list := UI.vbox(6)
	for m in DB.king.mutations:
		var mid: String = m.id
		var owned: bool = mid in Game.state.king.mutations_owned
		var active: bool = mid in Game.state.king.mutations_active
		var row := UI.panel_box(Color("#2a4482"), Color("#d03fd9") if active else UI.BORDER)
		var h := UI.hbox(10)
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(DB.txt(m), 18, Color.WHITE, "bold"))
		v.add_child(UI.para(DB.txt(m, "desc"), 15))
		h.add_child(v)
		if owned:
			h.add_child(UI.button(tr("BTN_DEACTIVATE") if active else tr("BTN_ACTIVATE"), func() -> void:
				var err: String = Game.king.toggle_mutation(mid)
				if err != "":
					Router.error(err), "secondary", 170, 44))
		else:
			h.add_child(UI.cost_row(m.cost, 16))
			h.add_child(UI.button(tr("BTN_UNLOCK"), func() -> void:
				Router.confirm_spend(tr("CONFIRM_MUTATION") % DB.txt(m), m.cost, func() -> void:
					var err: String = Game.king.unlock_mutation(mid)
					if err != "":
						Router.error(err)
					else:
						Audio.play_sfx("magic")
						EventBus.notify(tr("TOAST_MUTATION") % DB.txt(m), "success")), "primary", 150, 44))
		row.add_child(h)
		list.add_child(row)
	panel_body.add_child(UI.scroll(list))


# ------------------------------------------------------------------ loadouts
func _loadouts() -> void:
	panel_body.add_child(UI.para(tr("DESC_LOADOUTS") % Game.king.loadout_slots(), 16))
	var names := ["LO_OFFENSIVE", "LO_DEFENSIVE", "LO_FAST", "LO_MAGIC", "LO_CUSTOM"]
	for i in Game.king.loadout_slots():
		var idx := i
		var lo = Game.state.king.loadouts[i] if i < Game.state.king.loadouts.size() else null
		var row := UI.panel_box(Color("#2a4482"), UI.GOLD if int(Game.state.king.active_loadout) == i else UI.BORDER)
		var h := UI.hbox(10)
		var name_edit := LineEdit.new()
		name_edit.text = str(lo.name) if lo != null else tr(names[i % names.size()])
		name_edit.custom_minimum_size = Vector2(220, 44)
		name_edit.max_length = 24
		h.add_child(name_edit)
		h.add_child(UI.label(tr("LBL_SAVED") if lo != null else tr("LBL_EMPTY"), 15, UI.TEXT_DIM))
		h.add_child(UI.spacer())
		h.add_child(UI.button(tr("BTN_SAVE"), func() -> void:
			if Game.king.save_loadout(idx, name_edit.text.strip_edges().substr(0, 24)):
				EventBus.notify(tr("TOAST_LOADOUT_SAVED"), "success"), "secondary", 130, 44))
		var lb := UI.button(tr("BTN_LOAD"), func() -> void:
			var skipped: Array = Game.king.apply_loadout(idx)
			if not skipped.is_empty():
				EventBus.notify(tr("TOAST_LOADOUT_PARTIAL") % skipped.size(), "info"), "primary", 130, 44)
		lb.disabled = lo == null
		h.add_child(lb)
		var db := UI.button(tr("BTN_DELETE"), func() -> void: Game.king.delete_loadout(idx), "danger", 120, 44)
		db.disabled = lo == null
		h.add_child(db)
		row.add_child(h)
		panel_body.add_child(row)


# ------------------------------------------------------------------ cosmetics
func _cosmetics() -> void:
	var sel: Dictionary = Game.state.king.cosmetic_sel
	for key in [["emote_1", "emote"], ["emote_2", "emote"], ["victory", "victory"], ["entry", "entry"], ["defeat", "defeat"]]:
		panel_body.add_child(UI.label(tr("COS_" + str(key[0]).to_upper()), 17, UI.GOLD, "bold"))
		var row := UI.hbox(8)
		for cid in Game.state.cosmetics:
			var cd: Dictionary = DB.cosmetics.get(cid, {})
			if cd.is_empty() or cd.kind != key[1]:
				continue
			var k0: String = key[0]
			var cur: bool = str(sel.get(k0, "")) == cid
			var b := UI.button(DB.txt(cd), func() -> void:
				Game.state.king.cosmetic_sel[k0] = cid
				Game.mark_dirty()
				preview.play(str(cd.anim), 1.6)
				_refresh(), "primary" if cur else "secondary", 0, 44)
			b.add_theme_color_override("font_color", DB.rarity_color(cd.rarity))
			row.add_child(b)
		if row.get_child_count() == 0:
			row.add_child(UI.label(tr("LBL_NONE_OWNED"), 15, UI.TEXT_DIM))
		panel_body.add_child(row)
	panel_body.add_child(UI.para(tr("HINT_COSMETICS"), 15))


# ------------------------------------------------------------------ stats
func _stats() -> void:
	var st: Dictionary = Game.king.current_stats()
	var caps: Dictionary = DB.king.caps
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	var rows := [["STAT_HP", str(st.hp)], ["STAT_DMG", str(st.dmg)], ["STAT_ARMOR", "%.0f / %d" % [st.armor, int(caps.armor)]],
		["STAT_SPEED", "%.2f (+%.0f%%)" % [st.speed, st.speed_pct]], ["STAT_ATK_SPEED", "%.2f/s (+%.0f%%)" % [1.0 / st.hit, st.atk_speed_pct]],
		["STAT_RANGE", "%.1f" % st.range], ["STAT_ENERGY", "+%.1f" % st.energy], ["STAT_RESIST", "%.0f" % st.resist],
		["STAT_CDR", "%.0f%% / %d%%" % [st.cdr_pct, int(caps.cdr_pct)]], ["STAT_AP", "%.0f%%" % st.ability_power_pct],
		["STAT_WEAPON", tr("CAT_" + str(st.weapon).to_upper())], ["STAT_MECH", tr("LBL_YES") if st.mech_module else tr("LBL_NO")]]
	for r in rows:
		grid.add_child(UIScreen.stat_row(tr(r[0]), r[1]))
	panel_body.add_child(grid)
	if not st.effects.is_empty():
		panel_body.add_child(UI.label(tr("LBL_ACTIVE_EFFECTS"), 18, UI.GOLD, "bold"))
		for e in st.effects:
			panel_body.add_child(UI.label("• %s (%s)" % [tr("EFF_" + str(e.type).to_upper()), DB.any_name(str(e.get("source", "")))], 15, Color("#e0a0ff")))
	panel_body.add_child(UI.para(tr("HINT_CAPS"), 14))
