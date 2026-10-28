extends Control
## Battle screen: owns the BattleSim, the 3D BattleView and the touch HUD.

var cfg: Dictionary
var sim: BattleSim
var view: BattleView
var hand_box: HBoxContainer
var hand_cards: Array = []
var next_card: CardView
var energy_bar: ProgressBar
var energy_label: Label
var energy_segments: HBoxContainer
var timer_label: Label
var score_label: Label
var wave_label: Label
var boss_bar: ProgressBar
var boss_label: Label
var ability_btns := {}
var hero_bar: ProgressBar
var hero_label: Label
var tip_panel: PanelContainer
var sound_label: Label
var selected := -1
var dragging := false
var drag_start := Vector2.ZERO
var drag_ghost: Control
var end_handled := false
var hand_signature := ""


func setup(_params: Dictionary) -> void:
	cfg = Game.pending_battle
	if cfg.is_empty():
		# Direct launch (QA: --screen=battle [--param=mission:c1m8] [--param=autoplay:1])
		var mid: String = str(_params.get("mission", Game.campaign.current_mission()))
		cfg = Game.campaign.mission_config(mid)
		cfg["battle_id"] = "dev_%d" % int(Game.now())
		if _params.has("autoplay"):
			cfg["autoplay"] = true
	sim = BattleSim.new(cfg)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hud()
	Audio.play_music("music_boss" if sim.mode == "boss" else "music_battle")
	Audio.play_ambience("")
	EventBus.sound_played.connect(_on_sound)


func build_world() -> Node3D:
	view = BattleView.new()
	return view


func on_world_ready(_w: Node3D) -> void:
	view.setup(sim)


func on_back() -> bool:
	_pause()
	return true


# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	var bsc := UI.bs()
	# Top bar
	var top := UI.hbox(16)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 10
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var title_p := UI.panel_box(Color(0, 0, 0, 0.55))
	var tv := UI.vbox(0)
	tv.add_child(UI.label(str(cfg.get("title", tr("MODE_" + sim.mode.to_upper()))), 18, UI.GOLD, "title"))
	tv.add_child(UI.label(tr("MODE_" + sim.mode.to_upper()), 14, UI.TEXT_DIM))
	title_p.add_child(tv)
	top.add_child(title_p)
	top.add_child(UI.spacer())
	var tp := UI.panel_box(Color(0, 0, 0, 0.6))
	var th := UI.hbox(18)
	score_label = UI.label("", 24, Color.WHITE, "display")
	th.add_child(score_label)
	timer_label = UI.label("3:00", 30, Color.WHITE, "display")
	th.add_child(timer_label)
	wave_label = UI.label("", 20, UI.GOLD, "bold")
	th.add_child(wave_label)
	tp.add_child(th)
	top.add_child(tp)
	top.add_child(UI.spacer())
	var pause_btn := UI.icon_button("pause", _pause, 56, tr("BTN_PAUSE"))
	top.add_child(pause_btn)
	# Boss bar
	if sim.boss:
		var bb := UI.vbox(2)
		bb.set_anchors_preset(Control.PRESET_CENTER_TOP)
		bb.offset_top = 82
		bb.offset_left = -300
		bb.offset_right = 300
		bb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boss_label = UI.label(sim.boss.name, 20, Color("#ff8a70"), "title")
		boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bb.add_child(boss_label)
		boss_bar = UI.progress(sim.boss.hp, sim.boss.max_hp, Color("#e0503a"), 18)
		bb.add_child(boss_bar)
		add_child(bb)
	# Bottom-left: hand + energy
	var bottom := UI.vbox(6)
	bottom.anchor_top = 1
	bottom.anchor_bottom = 1
	bottom.offset_left = 14
	bottom.offset_top = -(190 * bsc)
	bottom.offset_bottom = -10
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	var hand_row := UI.hbox(8)
	hand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_box = UI.hbox(8)
	hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_row.add_child(hand_box)
	var nv := UI.vbox(2)
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nv.add_child(UI.label(tr("LBL_NEXT"), 14, UI.TEXT_DIM))
	var next_holder := Control.new()
	next_holder.custom_minimum_size = Vector2(66, 88) * bsc
	next_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nv.add_child(next_holder)
	nv.set_meta("holder", next_holder)
	hand_row.add_child(nv)
	bottom.add_child(hand_row)
	var erow := UI.hbox(8)
	erow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gem := Panel.new()
	gem.custom_minimum_size = Vector2(40, 40)
	gem.add_theme_stylebox_override("panel", UI.box(Color("#7a1aa8"), Color("#e0a0ff"), 20, 2, 0))
	energy_label = UI.label("5", 22, Color.WHITE, "display")
	energy_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem.add_child(energy_label)
	erow.add_child(gem)
	energy_bar = UI.progress(5, sim.energy_max, Color("#c05aff"), 22)
	energy_bar.custom_minimum_size = Vector2(4 * 112 * bsc - 40, 22)
	erow.add_child(energy_bar)
	bottom.add_child(erow)
	hand_row.set_meta("next_holder", next_holder)
	set_meta("next_holder", next_holder)
	_rebuild_hand()
	# Bottom-right: King abilities
	if sim.heroes[0] != null or (cfg.player.get("hero") != null):
		var ab := UI.vbox(6)
		ab.anchor_left = 1
		ab.anchor_right = 1
		ab.anchor_top = 1
		ab.anchor_bottom = 1
		ab.offset_left = -(400 * bsc)
		ab.offset_right = -14
		ab.offset_top = -(170 * bsc)
		ab.offset_bottom = -12
		ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ab)
		var hb := UI.hbox(6)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hero_label = UI.label(tr("LBL_KING"), 16, Color.WHITE, "bold")
		hb.add_child(hero_label)
		hero_bar = UI.progress(1, 1, Color("#3d8bff"), 14)
		hero_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(hero_bar)
		ab.add_child(hb)
		var row := UI.hbox(8)
		row.alignment = BoxContainer.ALIGNMENT_END
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var emote_btn := UI.icon_button("smile", _emote_menu, 64, tr("BTN_EMOTE"))
		row.add_child(emote_btn)
		for slot in ["active", "defensive", "ultimate"]:
			var aid: String = sim.hero_ability_id(0, slot)
			if aid == "":
				continue
			var b := UI.button(DB.txt(DB.abilities[aid]), _cast.bind(slot), "primary" if slot == "ultimate" else "secondary", int(92 * bsc), int(96 * bsc))
			b.clip_text = true
			b.add_theme_font_size_override("font_size", int(14 * UI.ts()))
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.tooltip_text = DB.txt(DB.abilities[aid], "desc")
			var cd := UI.label("", 22, Color.WHITE, "display")
			cd.set_anchors_preset(Control.PRESET_FULL_RECT)
			cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cd.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			cd.add_theme_color_override("font_outline_color", Color.BLACK)
			cd.add_theme_constant_override("outline_size", 5)
			b.add_child(cd)
			row.add_child(b)
			ability_btns[slot] = {"btn": b, "cd": cd}
		ab.add_child(row)
		if Settings.get_v("hud_left_handed"):
			ab.anchor_left = 0
			ab.anchor_right = 0
			ab.offset_left = 14
			ab.offset_right = 400 * bsc
			bottom.anchor_left = 1
			bottom.anchor_right = 1
			bottom.offset_left = -(4 * 112 * bsc + 100)
	# Tip
	var tip: String = str(cfg.get("tip", ""))
	if tip != "":
		tip_panel = UI.panel_box(Color(0, 0, 0, 0.75), UI.GOLD)
		tip_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
		tip_panel.offset_top = 130
		tip_panel.offset_left = -330
		tip_panel.offset_right = 330
		var tl := UI.para(tip, 19, Color.WHITE)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip_panel.add_child(tl)
		tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tip_panel)
		var tw := tip_panel.create_tween()
		tw.tween_interval(7.0)
		tw.tween_property(tip_panel, "modulate:a", 0.0, 0.6)
	if not str(cfg.get("modifiers", {}).get("text", "")).is_empty():
		var mt := UI.label(str(cfg.modifiers.text), 16, UI.GOLD, "bold")
		mt.position = Vector2(16, 84)
		add_child(mt)
	sound_label = UI.label("", 16, Color("#ffd23f"), "bold")
	sound_label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	sound_label.offset_left = -230
	sound_label.offset_top = -60
	add_child(sound_label)


func _rebuild_hand() -> void:
	var sig := ",".join(sim.hands[0]) + "|" + sim.next_card(0)
	if sig == hand_signature:
		return
	hand_signature = sig
	for c in hand_box.get_children():
		c.queue_free()
	hand_cards.clear()
	var bsc := UI.bs()
	for i in sim.hands[0].size():
		var cid: String = sim.hands[0][i]
		var cv := CardView.make(cid, Vector2(104, 138) * bsc, Game.collection.level_of(cid))
		cv.gui_input.connect(_on_card_input.bind(i))
		hand_box.add_child(cv)
		hand_cards.append(cv)
		cv.set_selected(i == selected)
	var holder: Control = get_meta("next_holder")
	for c in holder.get_children():
		c.queue_free()
	var nc := sim.next_card(0)
	if nc != "":
		var n := CardView.make(nc, Vector2(66, 88) * bsc, 0)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(n)


func _process(_delta: float) -> void:
	if sim == null:
		return
	_rebuild_hand()
	var e: float = sim.energy[0]
	energy_bar.value = e
	energy_label.text = str(int(floor(e)))
	for i in hand_cards.size():
		var cid: String = sim.hands[0][i] if i < sim.hands[0].size() else ""
		if cid != "":
			hand_cards[i].set_dim(e < float(DB.cards[cid].cost))
	var tl := sim.time_left()
	timer_label.text = "%d:%02d" % [int(tl) / 60, int(tl) % 60]
	if sim.mode in ["duel", "challenge"] and tl <= 60.0:
		timer_label.add_theme_color_override("font_color", Color("#ff8a70"))
		wave_label.text = tr("LBL_DOUBLE_RAGE")
	match sim.mode:
		"defense", "survival":
			wave_label.text = tr("LBL_WAVE") % [sim.wave_index, sim.waves.size()] if not sim.endless else tr("LBL_WAVE_ENDLESS") % sim.wave_index
			score_label.text = ""
		"boss":
			score_label.text = ""
		_:
			score_label.text = "%d - %d" % [sim.structures_lost[1], sim.structures_lost[0]]
	if boss_bar and sim.boss:
		boss_bar.value = sim.boss.hp
		var layer := float(sim.boss.data.get("armor_layer", 0))
		boss_label.text = sim.boss.name + ("  [%s %d]" % [tr("LBL_ARMOR"), int(layer)] if layer > 0 else "") + "  — %s %d" % [tr("LBL_PHASE"), int(sim.boss.data.phase) + 1]
	_update_abilities()
	if sim.finished and not end_handled:
		end_handled = true
		_on_end()


func _update_abilities() -> void:
	var h: BattleEnt = sim.heroes[0]
	if hero_bar:
		if h and h.alive:
			hero_bar.max_value = h.max_hp
			hero_bar.value = h.hp
			hero_label.text = tr("LBL_KING")
		else:
			hero_bar.value = 0
			hero_label.text = tr("LBL_KING_RESPAWN") % int(ceil(sim.hero_respawn_t[0]))
	for slot in ability_btns.keys():
		var b: Button = ability_btns[slot].btn
		var cd: Label = ability_btns[slot].cd
		var why := sim.hero_can_cast(0, slot)
		b.disabled = why != ""
		if slot == "ultimate":
			cd.text = "%d%%" % int(sim.hero_charge[0]) if why != "" else "!"
		else:
			var rem := float(sim.hero_cd[0].get(slot, 0.0))
			cd.text = str(int(ceil(rem))) if rem > 0 else ""


# ------------------------------------------------------------------ input
func _on_card_input(event: InputEvent, index: int) -> void:
	if sim.finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			selected = index
			dragging = false
			drag_start = event.global_position
			for i in hand_cards.size():
				hand_cards[i].set_selected(i == selected)
		else:
			if dragging:
				_try_deploy(event.global_position)
				_end_drag()
	elif event is InputEventMouseMotion and selected == index and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if not dragging and event.global_position.distance_to(drag_start) > 18:
			dragging = true
			_begin_drag(index)
		if dragging:
			_update_drag(event.global_position)


func _begin_drag(index: int) -> void:
	var cid: String = sim.hands[0][index]
	drag_ghost = CardView.make(cid, Vector2(70, 92), 0)
	drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_ghost.modulate.a = 0.85
	add_child(drag_ghost)


func _update_drag(gp: Vector2) -> void:
	if drag_ghost:
		drag_ghost.position = gp - Vector2(35, 120)
	_preview_at(gp)


func _preview_at(gp: Vector2) -> void:
	if selected < 0 or selected >= sim.hands[0].size():
		view.show_deploy(0, null)
		return
	var p = view.screen_to_field(gp)
	var cid: String = sim.hands[0][selected]
	var d: Dictionary = DB.cards[cid]
	if p == null:
		view.show_deploy(0, null)
		return
	var ok := sim.can_play(0, selected, p) == ""
	view.show_deploy(0, p, float(d.stats.radius) * (1.6 if int(d.stats.count) > 1 else 1.0), float(d.stats.range), ok)


func _end_drag() -> void:
	dragging = false
	if drag_ghost:
		drag_ghost.queue_free()
		drag_ghost = null
	view.show_deploy(0, null)


func _try_deploy(gp: Vector2) -> bool:
	if selected < 0:
		return false
	var p = view.screen_to_field(gp)
	if p == null:
		return false
	var why := sim.can_play(0, selected, p)
	if why != "":
		if why == "ERR_ENERGY":
			Router.toast(tr("ERR_ENERGY"), "error")
		elif why == "ERR_ZONE":
			Router.toast(tr("ERR_ZONE"), "error")
		return false
	sim.play_card(0, selected, p)
	Settings.vibrate(20)
	selected = -1
	hand_signature = ""
	return true


func _unhandled_input(event: InputEvent) -> void:
	if sim == null or sim.finished or sim.paused:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if Router.drag_dist > 24:
			return
		if selected >= 0:
			if _try_deploy(event.position):
				return
			selected = -1
			for c in hand_cards:
				c.set_selected(false)
			return
		var p = view.screen_to_field(event.position)
		if p != null and sim.heroes[0] and sim.heroes[0].alive:
			sim.hero_move(0, p)
			view._ring(p, 0.5, Color("#3d8bff"), 0.4)
	elif event is InputEventMouseMotion and selected >= 0 and not dragging:
		_preview_at(event.position)


func _cast(slot: String) -> void:
	if not sim.hero_cast(0, slot):
		var why := sim.hero_can_cast(0, slot)
		if why != "":
			Router.toast(tr(why), "error")


func _emote_menu() -> void:
	var sel: Dictionary = Game.state.king.cosmetic_sel
	var p := UI.panel_box()
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.title(tr("BTN_EMOTE"), 24))
	for key in ["emote_1", "emote_2"]:
		var eid := str(sel.get(key, ""))
		if eid == "" or not DB.cosmetics.has(eid):
			continue
		var play_it := func() -> void:
			Router.close_popup()
			var h: BattleEnt = sim.heroes[0]
			if h and view.nodes.has(h.id):
				(view.nodes[h.id] as GoblinRig).play(str(DB.cosmetics[eid].anim), 1.4)
				Audio.play_sfx("goblin_laugh" if DB.cosmetics[eid].anim == "laugh" else "goblin_grunt")
		v.add_child(UI.button(DB.txt(DB.cosmetics[eid]), play_it, "secondary", 260))
	Router.popup(p)


func _pause() -> void:
	if sim.finished:
		return
	var solo := true
	sim.paused = solo
	var p := UI.panel_box()
	p.custom_minimum_size = Vector2(440, 0)
	var v := UI.vbox(12)
	p.add_child(v)
	var t := UI.title(tr("LBL_PAUSE"), 32)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var resume := func() -> void:
		Router.close_popup()
		sim.paused = false
	v.add_child(UI.button(tr("BTN_RESUME"), resume, "primary"))
	var mus := HSlider.new()
	mus.min_value = 0
	mus.max_value = 1
	mus.step = 0.05
	mus.value = Settings.get_v("vol_music")
	mus.value_changed.connect(func(x: float) -> void: Settings.set_v("vol_music", x))
	v.add_child(UI.label(tr("SET_VOL_MUSIC"), 18))
	v.add_child(mus)
	var sfx := HSlider.new()
	sfx.min_value = 0
	sfx.max_value = 1
	sfx.step = 0.05
	sfx.value = Settings.get_v("vol_sfx")
	sfx.value_changed.connect(func(x: float) -> void: Settings.set_v("vol_sfx", x))
	v.add_child(UI.label(tr("SET_VOL_SFX"), 18))
	v.add_child(sfx)
	var forfeit := func() -> void:
		Router.close_popup()
		Router.confirm(tr("CONFIRM_FORFEIT"), func() -> void:
			sim.paused = false
			sim._finish("loss"))
		if Router.popup_open == null:
			return
		# Cancelling the confirmation resumes the battle
		Router.popup_open.tree_exited.connect(func() -> void: sim.paused = false)
	v.add_child(UI.button(tr("BTN_FORFEIT"), forfeit, "danger"))
	Router.popup(p, false)


func _on_sound(sfx_name: String) -> void:
	if not Settings.get_v("sound_indicators") or sound_label == null:
		return
	if sfx_name in ["explosion", "telegraph", "tower_destroyed", "king_roar", "hit_heavy"]:
		sound_label.text = "[ " + tr("SND_" + sfx_name.to_upper()) + " ]"
		sound_label.modulate.a = 1.0
		var tw := sound_label.create_tween()
		tw.tween_interval(1.0)
		tw.tween_property(sound_label, "modulate:a", 0.0, 0.5)


func _on_end() -> void:
	var res := sim.result()
	Audio.play_sfx("victory" if res.won else "defeat")
	var h: BattleEnt = sim.heroes[0]
	if h and h.alive and view.nodes.has(h.id):
		var sel: Dictionary = Game.state.king.cosmetic_sel
		var anim_id := str(sel.get("victory" if res.won else "defeat", ""))
		var anim := "victory" if res.won else "shrug"
		if DB.cosmetics.has(anim_id):
			anim = str(DB.cosmetics[anim_id].anim)
		(view.nodes[h.id] as GoblinRig).play(anim, 2.5)
	var banner := UI.title(tr("LBL_VICTORY") if res.won else (tr("LBL_DRAW") if res.draw else tr("LBL_DEFEAT")), 72)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.offset_left = -400
	banner.offset_right = 400
	banner.offset_top = -60
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_color", UI.GOLD if res.won else Color("#ff8a70"))
	add_child(banner)
	banner.scale = Vector2(0.5, 0.5)
	banner.pivot_offset = Vector2(400, 40)
	banner.create_tween().tween_property(banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	var report: Dictionary = Game.campaign.report(cfg, res)
	Game.last_battle_result = {"cfg": cfg, "result": res, "report": report}
	await get_tree().create_timer(2.6).timeout
	if is_inside_tree():
		Router.goto("results", {})
