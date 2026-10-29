extends Control
## Laboratory & workshops: crafting (forge / workshop / lab), mutation, experimentation,
## research, recycling and relics. Lab rooms stay sealed until the lab is unlocked.

var tab := "design"
var body: VBoxContainer
var tick := 0.0


func setup(p: Dictionary) -> void:
	tab = str(p.get("tab", "design"))
	Game.lab.process_timers()
	UIScreen.background(self, Color("#1f9a8a"))
	var root := UIScreen.frame(self, tr("MENU_LAB"), null, true, ["gold", "components", "mutant_essence", "ancestral"])
	var th := UI.hbox()
	root.add_child(th)
	set_meta("tabs", th)
	body = UI.vbox(8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	EventBus.lab_changed.connect(_refresh)
	EventBus.king_changed.connect(_refresh)
	_refresh()


func _set_tab(t: String) -> void:
	tab = t
	_refresh()


func _process(delta: float) -> void:
	tick -= delta
	if tick <= 0:
		tick = 1.0
		var got: Array = Game.lab.process_timers()
		for iid in got:
			Audio.play_sfx("craft")
			EventBus.notify(tr("TOAST_CRAFTED") % DB.any_name(iid), "success")
		var busy: bool = not Game.state.lab.craft_queue.is_empty() or not Game.state.lab.research_job.is_empty()
		if tab in ["design", "research"] and busy and is_inside_tree() and Router.popup_open == null:
			_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var th: HBoxContainer = get_meta("tabs")
	UIScreen.clear(th)
	UIScreen.tabs(th, ["design", "mutation", "experiment", "research", "recycle", "relics"], tab, _set_tab).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prev_scroll := 0
	for c in body.get_children():
		if c is ScrollContainer:
			prev_scroll = c.scroll_vertical
	UIScreen.clear(body)
	if prev_scroll > 0:
		_restore_scroll(prev_scroll)
	var room: String = {"design": "design", "mutation": "mutation", "experiment": "experiment", "research": "research", "recycle": "recycle", "relics": "relics"}[tab]
	if tab != "design" and not Game.lab.room_available(room):
		_locked(room)
		return
	match tab:
		"design": _design()
		"mutation": _mutation()
		"experiment": _experiment()
		"research": _research()
		"recycle": _recycle()
		"relics": _relics()


## Keeps the list position when the screen refreshes its timers.
func _restore_scroll(v: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for c in body.get_children():
		if c is ScrollContainer and not c.is_queued_for_deletion():
			c.scroll_vertical = v


func _locked(room: String) -> void:
	if not Game.lab.is_unlocked():
		body.add_child(UI.title(tr("LBL_LAB_SEALED"), 26))
		body.add_child(UI.para(tr("LAB_LOCKED_MSG"), 18, Color("#ff8a70")))
		for s in Game.lab.unlock_status():
			body.add_child(UI.label(("» " if s.ok else "• ") + str(s.text), 18, UI.GREEN if s.ok else UI.TEXT_DIM, "bold"))
		body.add_child(UI.button(tr("MENU_BASE"), func() -> void: Router.goto("base"), "secondary", 220))
	else:
		var need := 1
		for r in DB.lab.rooms:
			if r.id == room:
				need = int(r.lab_level)
		body.add_child(UI.para(tr("LOCK_ROOM") % need, 18, Color("#ff8a70")))


# ------------------------------------------------------------------ crafting
func _design() -> void:
	var q: Array = Game.state.lab.craft_queue
	body.add_child(UI.label(tr("LBL_QUEUE") % [q.size(), LabSystem.MAX_CRAFT_QUEUE], 18, UI.GOLD, "bold"))
	for j in q:
		var rc: Dictionary = DB.recipes[j.recipe]
		var row := UI.hbox(10)
		var rem := maxf(0.0, float(j.end) - Game.now())
		var l := UI.label("%s — %s" % [DB.any_name(rc.item), UI.time_fmt(rem) if rem > 0 else tr("LBL_DONE")], 17)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var jid: String = j.job
		var sc: int = Game.lab.speedup_cost(j)
		row.add_child(UI.button(tr("BTN_SPEEDUP") % sc, func() -> void:
			Router.confirm_spend(tr("CONFIRM_SPEEDUP"), {"crystals": sc}, func() -> void:
				var err: String = Game.lab.speedup_craft(jid)
				if err != "":
					Router.error(err)), "secondary", 170, 42))
		row.add_child(UI.button(tr("BTN_CANCEL"), func() -> void:
			Router.confirm(tr("CONFIRM_CANCEL_CRAFT"), func() -> void: Game.lab.cancel_craft(jid)), "danger", 130, 42))
		body.add_child(row)
	body.add_child(UI.para(tr("DESC_CRAFT_RULES"), 15))
	var list := UI.vbox(6)
	for rc in DB.lab.recipes:
		var it: Dictionary = DB.items[rc.item]
		var row2 := UI.panel_box(Color("#2a4482"), DB.rarity_color(it.rarity).darkened(0.3))
		var h := UI.hbox(10)
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(DB.txt(it), 18, DB.rarity_color(it.rarity), "bold"))
		v.add_child(UI.label("%s · %s · %s" % [tr("STATION_" + str(rc.station).to_upper()), DB.slot_name(it.slot), UI.time_fmt(Game.lab.craft_time(rc))], 14, UI.TEXT_DIM))
		var reqs: Array = []
		for k in rc.get("requires", {}).keys():
			reqs.append(("%s %d" % [DB.any_name(k), int(rc.requires[k])]) if k != "research" else DB.txt(DB.research[rc.requires[k]]))
		if not reqs.is_empty():
			v.add_child(UI.label(tr("LBL_REQUIRES") + " : " + ", ".join(reqs), 13, UI.TEXT_DIM))
		h.add_child(v)
		h.add_child(UI.cost_row(rc.cost, 15))
		var rid: String = rc.id
		var why: String = Game.lab.can_craft(rid)
		var b := UI.button(tr("BTN_CRAFT"), func() -> void:
			Router.confirm_spend(tr("CONFIRM_CRAFT") % DB.txt(it), rc.cost, func() -> void:
				var err: String = Game.lab.start_craft(rid)
				if err != "":
					Router.error(err)
				else:
					Audio.play_sfx("craft")), "primary", 140, 44)
		b.disabled = why != ""
		b.tooltip_text = tr(why) if why != "" else DB.txt(it, "desc")
		h.add_child(b)
		row2.add_child(h)
		list.add_child(row2)
	body.add_child(UI.scroll(list))


# ------------------------------------------------------------------ mutation
func _mutation() -> void:
	body.add_child(UI.para(tr("DESC_MUTATION_ROOM"), 16))
	body.add_child(UI.label(tr("LBL_MUTATION_SLOTS") % [Game.state.king.mutations_active.size(), Game.king.mutation_slots()], 18, UI.GOLD, "bold"))
	body.add_child(UI.label(tr("LBL_LARMES") % Game.inventory.material_count("mat_larme_ancestrale"), 16, Color("#ff3d6e")))
	var list := UI.vbox(6)
	for m in DB.king.mutations:
		var mid: String = m.id
		var owned: bool = mid in Game.state.king.mutations_owned
		var active: bool = mid in Game.state.king.mutations_active
		var h := UI.hbox(10)
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(DB.txt(m) + ("  [" + tr("LBL_ACTIVE") + "]" if active else ""), 18, Color("#d03fd9") if owned else Color.WHITE, "bold"))
		v.add_child(UI.para(DB.txt(m, "desc"), 14))
		h.add_child(v)
		if owned:
			h.add_child(UI.button(tr("BTN_DEACTIVATE") if active else tr("BTN_ACTIVATE"), func() -> void:
				var err: String = Game.king.toggle_mutation(mid)
				if err != "":
					Router.error(err), "secondary", 160, 44))
		else:
			h.add_child(UI.cost_row(m.cost, 15))
			h.add_child(UI.button(tr("BTN_UNLOCK"), func() -> void:
				Router.confirm_spend(tr("CONFIRM_MUTATION") % DB.txt(m), m.cost, func() -> void:
					var err: String = Game.king.unlock_mutation(mid)
					if err != "":
						Router.error(err)
					else:
						Audio.play_sfx("magic")), "primary", 140, 44))
		list.add_child(h)
	body.add_child(UI.scroll(list))


# ------------------------------------------------------------------ experiment
func _experiment() -> void:
	body.add_child(UI.para(tr("DESC_EXPERIMENT"), 17))
	var st: Dictionary = Game.king.current_stats()
	body.add_child(UI.label(tr("LBL_POWER") % int(st.power), 20, UI.GOLD, "display"))
	var h := UI.hbox(12)
	h.add_child(UI.button(tr("BTN_DUMMIES"), func() -> void:
		var cfg := Game.campaign.free_config("training", "normal")
		cfg.title = tr("TAB_EXPERIMENT")
		Router.start_battle(cfg), "primary", 260, 60))
	for d in ["easy", "normal", "expert"]:
		var diff: String = d
		h.add_child(UI.button(tr("BTN_VS_BOT") % tr("DIFF_" + d.to_upper()), func() -> void:
			var cfg2 := Game.campaign.free_config("duel", diff)
			cfg2.mode = "training"
			cfg2.training_bot = true
			cfg2.title = tr("TAB_EXPERIMENT")
			Router.start_battle(cfg2), "secondary", 220, 60))
	body.add_child(h)
	body.add_child(UI.button(tr("MENU_KING"), func() -> void: Router.goto("king", {"tab": "loadouts"}), "secondary", 240))


# ------------------------------------------------------------------ research
func _research() -> void:
	var job: Dictionary = Game.state.lab.research_job
	if not job.is_empty():
		body.add_child(UI.label(tr("LBL_RESEARCHING") % [DB.txt(DB.research[job.id]), UI.time_fmt(maxf(0.0, float(job.end) - Game.now()))], 18, Color("#9ad7ff"), "bold"))
	body.add_child(UI.para(tr("DESC_RESEARCH") % maxi(1, Game.base.building_level("research_hall")), 15))
	var list := UI.vbox(6)
	for r in DB.lab.research:
		var rid: String = r.id
		var lvl: int = Game.lab.research_level(rid)
		var h := UI.hbox(10)
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label("%s  (%d / %d)" % [DB.txt(r), lvl, int(r.max)], 18, Color.WHITE, "bold"))
		v.add_child(UI.para(DB.txt(r, "desc"), 14))
		h.add_child(v)
		if lvl < int(r.max):
			var cost: Dictionary = Game.lab.research_cost(rid)
			h.add_child(UI.cost_row(cost, 15))
			var why: String = Game.lab.can_research(rid)
			var b := UI.button(tr("BTN_RESEARCH"), func() -> void:
				Router.confirm_spend(tr("CONFIRM_RESEARCH") % DB.txt(r), cost, func() -> void:
					var err: String = Game.lab.start_research(rid)
					if err != "":
						Router.error(err)), "primary", 150, 44)
			b.disabled = why != ""
			b.tooltip_text = tr(why) if why != "" else ""
			h.add_child(b)
		else:
			h.add_child(UI.label(tr("LBL_MAX_LEVEL"), 16, UI.GOLD, "bold"))
		list.add_child(h)
	body.add_child(UI.scroll(list))


# ------------------------------------------------------------------ recycle
func _recycle() -> void:
	body.add_child(UI.para(tr("DESC_RECYCLE"), 16))
	var list := UI.vbox(6)
	var any := false
	for uid in Game.state.items.keys():
		if Game.king.is_equipped_anywhere(uid):
			continue
		any = true
		var d: Dictionary = Game.inventory.item_def(uid)
		var h := UI.hbox(10)
		var l := UI.label(DB.txt(d), 17, DB.rarity_color(d.rarity), "bold")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var val: Dictionary = Game.lab.recycle_value(uid)
		var parts: Array = []
		for k in val.keys():
			parts.append("+%d %s" % [int(val[k]), DB.resource_name(k)])
		h.add_child(UI.label(", ".join(parts), 15, UI.GREEN))
		var u: String = uid
		h.add_child(UI.button(tr("BTN_RECYCLE"), func() -> void:
			Router.confirm(tr("CONFIRM_RECYCLE") % DB.txt(d), func() -> void:
				var err: String = Game.lab.recycle(u)
				if err != "":
					Router.error(err)
				else:
					Audio.play_sfx("craft")
					_refresh(), "", true), "danger", 140, 42))
		list.add_child(h)
	if not any:
		body.add_child(UI.label(tr("LBL_NOTHING_TO_RECYCLE"), 17, UI.TEXT_DIM))
	body.add_child(UI.scroll(list))


# ------------------------------------------------------------------ relics
func _relics() -> void:
	body.add_child(UI.para(tr("DESC_RELICS"), 16))
	var list := UI.vbox(6)
	var any := false
	for uid in Game.state.items.keys():
		if not Game.lab.is_relic(uid):
			continue
		any = true
		var d: Dictionary = Game.inventory.item_def(uid)
		var lvl: int = Game.lab.relic_level(uid)
		var h := UI.hbox(10)
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label("%s  —  %s" % [DB.txt(d), tr("LBL_RELIC_LEVEL") % lvl], 17, DB.rarity_color(d.rarity), "bold"))
		v.add_child(UI.para(DB.txt(d, "desc"), 14))
		h.add_child(v)
		if lvl < int(DB.lab.relic_upgrade.max_level):
			var cost: Dictionary = Game.lab.relic_upgrade_cost(uid)
			h.add_child(UI.cost_row(cost, 15))
			var u: String = uid
			h.add_child(UI.button(tr("BTN_UPGRADE"), func() -> void:
				Router.confirm_spend(tr("CONFIRM_RELIC") % DB.txt(d), cost, func() -> void:
					var err: String = Game.lab.upgrade_relic(u)
					if err != "":
						Router.error(err)
					else:
						Audio.play_sfx("upgrade")), "primary", 140, 44))
		else:
			h.add_child(UI.label(tr("LBL_MAX_LEVEL"), 16, UI.GOLD, "bold"))
		list.add_child(h)
	if not any:
		body.add_child(UI.label(tr("LBL_NO_RELICS"), 17, UI.TEXT_DIM))
	body.add_child(UI.scroll(list))
