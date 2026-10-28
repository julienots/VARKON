extends Control
## Daily / weekly missions and permanent achievements.

var tab := "daily"
var body: VBoxContainer


func setup(p: Dictionary) -> void:
	tab = str(p.get("tab", "daily"))
	Game.missions.refresh_rotations()
	UIScreen.background(self)
	var root := UIScreen.frame(self, tr("MENU_MISSIONS"))
	var th := UI.hbox()
	root.add_child(th)
	set_meta("tabs", th)
	body = UI.vbox(8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	EventBus.missions_changed.connect(_refresh)
	_refresh()


func _set_tab(t: String) -> void:
	tab = t
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var th: HBoxContainer = get_meta("tabs")
	UIScreen.clear(th)
	UIScreen.tabs(th, ["daily", "weekly", "achievements"], tab, _set_tab).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIScreen.clear(body)
	var list := UI.vbox(8)
	if tab == "achievements":
		var done := 0
		for a in DB.missions_json.achievements:
			if Game.missions.achievement_claimed(a.id):
				done += 1
		body.add_child(UI.label(tr("LBL_ACH_PROGRESS") % [done, DB.missions_json.achievements.size()], 18, UI.GOLD, "bold"))
		for a in DB.missions_json.achievements:
			var aid: String = a.id
			list.add_child(_row(DB.txt(a), Game.missions.achievement_progress(a), int(a.target), a.reward, Game.missions.achievement_claimed(aid),
				func() -> void: UI.show_rewards(Game.missions.claim_achievement(aid))))
	else:
		var reset := tr("LBL_RESET_IN") % UI.time_fmt(_reset_seconds())
		body.add_child(UI.label(reset, 15, UI.TEXT_DIM))
		for e in Game.state.missions.get(tab, []):
			var d: Dictionary = Game.missions.def_of(tab, e.id)
			var mid: String = e.id
			var k: String = tab
			var rw: Dictionary = d.reward.duplicate()
			rw["pass_xp"] = int(DB.season.xp_sources.get(tab + "_mission", 0))
			list.add_child(_row(DB.txt(d), int(e.progress), int(d.target), rw, bool(e.claimed),
				func() -> void: UI.show_rewards(Game.missions.claim(k, mid))))
	body.add_child(UI.scroll(list))


func _reset_seconds() -> float:
	var t := Time.get_time_dict_from_system()
	var to_midnight := 86400.0 - (int(t.hour) * 3600 + int(t.minute) * 60 + int(t.second))
	if tab == "daily":
		return to_midnight
	var wd := int(Time.get_date_dict_from_system().weekday)  # 0 = Sunday
	var days_to_monday := (8 - wd) % 7
	if days_to_monday == 0:
		days_to_monday = 7
	return to_midnight + (days_to_monday - 1) * 86400.0


func _row(title: String, progress: int, target: int, reward: Dictionary, claimed: bool, on_claim: Callable) -> Control:
	var p := UI.panel_box(Color("#221a13"), UI.GREEN if (progress >= target and not claimed) else UI.BORDER)
	var h := UI.hbox(12)
	p.add_child(h)
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(title, 18, Color.WHITE, "bold"))
	var pr := UI.hbox(8)
	var pb := UI.progress(progress, target, UI.GREEN if progress >= target else Color("#58a6ff"), 12)
	pb.custom_minimum_size.x = 300
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(pb)
	pr.add_child(UI.label("%d / %d" % [progress, target], 15, UI.TEXT_DIM))
	v.add_child(pr)
	h.add_child(v)
	var parts: Array = []
	for k in reward.keys():
		if DB.resources.has(k):
			parts.append("%d %s" % [int(reward[k]), DB.resource_name(k)])
		elif k == "pass_xp":
			if int(reward[k]) > 0:
				parts.append("%d XP Pass" % int(reward[k]))
		else:
			parts.append(DB.any_name(str(reward[k])))
	var rl := UI.label(", ".join(parts), 15, UI.GOLD)
	rl.custom_minimum_size.x = 260
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(rl)
	if claimed:
		h.add_child(UI.label(tr("LBL_CLAIMED"), 16, UI.GREEN, "bold"))
	else:
		var b := UI.button(tr("BTN_CLAIM"), on_claim, "green", 140, 46)
		b.disabled = progress < target
		h.add_child(b)
	return p
