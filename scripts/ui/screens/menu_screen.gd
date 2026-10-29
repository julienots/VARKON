extends Control
## Main menu: living 3D fortress scene with the player's King Gobelin, top bar, side shortcuts
## (chests, missions, pass, events, achievements, inventory) and the five main entries.

var king: GoblinRig
var cam: Camera3D
var idle_t := 3.0
var orbit_t := 0.0
var side_buttons := {}


func setup(_p: Dictionary) -> void:
	Router.history.clear()
	Audio.play_music("music_menu")
	Audio.play_ambience("ambience_fortress")
	Game.base.process_timers()
	Game.lab.process_timers()
	Game.missions.refresh_rotations()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Top bar
	var top := TopBar.make()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 8
	add_child(top)
	# Side shortcuts
	var side := UI.vbox(10)
	side.position = Vector2(14, 96)
	add_child(side)
	for e in [["chests", "MENU_CHESTS", "chest"], ["missions", "MENU_MISSIONS", "check"], ["pass", "MENU_PASS", "star"],
			["events", "MENU_EVENTS", "flag"], ["achievements", "MENU_ACHIEVEMENTS", "star_empty"], ["inventory", "MENU_INVENTORY", "info"]]:
		var target: String = e[0]
		var go := func() -> void:
			_king_react()
			if target == "achievements":
				Router.goto("missions", {"tab": "achievements"})
			else:
				Router.goto(target)
		var b := UI.button(tr(e[1]), go, "secondary", 230, 54)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var scol: Color = {"chests": Color("#f0a51f"), "missions": Color("#3fbf2f"), "pass": Color("#8a55f0"), "events": Color("#f06a2a"),
			"achievements": Color("#1fb5b0"), "inventory": Color("#3d8ef0")}[target]
		b.add_theme_stylebox_override("normal", UI.candy(scol, false, true, 52))
		b.add_theme_stylebox_override("hover", UI.candy(scol.lightened(0.1), false, true, 52))
		b.add_theme_stylebox_override("pressed", UI.candy(scol, true, true, 52))
		var gl := Glyph.make(e[2], 26, Color.WHITE)
		gl.position = Vector2(14, 12)
		b.add_child(gl)
		side.add_child(b)
		side_buttons[target] = b
	_refresh_badges()
	# Campaign quick-play
	var mid: String = Game.campaign.current_mission()
	var mm: Dictionary = DB.missions[mid]
	var play := UI.panel_box(Color("#23396f"), UI.GOLD)
	play.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	play.offset_left = -420
	play.offset_top = -262
	play.offset_right = -14
	play.offset_bottom = -110
	play.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	play.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var pv := UI.vbox(6)
	pv.add_child(UI.label(tr("LBL_CAMPAIGN") + " — " + mid.to_upper(), 16, UI.TEXT_DIM, "bold"))
	var ml := UI.label(str(mm.name), 20, UI.GOLD, "title")
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.custom_minimum_size.x = 370
	pv.add_child(ml)
	var start := func() -> void:
		if not Game.collection.deck_complete():
			Router.error("ERR_DECK_INCOMPLETE")
			return
		Router.start_battle(Game.campaign.mission_config(mid))
	pv.add_child(UI.button(tr("BTN_FIGHT"), start, "big", 280, 60))
	play.add_child(pv)
	add_child(play)
	# Bottom navigation
	var nav := UI.hbox(10)
	nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nav.offset_left = 14
	nav.offset_right = -14
	nav.offset_top = -96
	nav.offset_bottom = -12
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(nav)
	for e2 in [["combat", "MENU_COMBAT"], ["collection", "MENU_COLLECTION"], ["base", "MENU_BASE"], ["king", "MENU_KING"], ["shop", "MENU_SHOP"]]:
		var scr: String = e2[0]
		var go2 := func() -> void:
			_king_react()
			Router.goto(scr)
		var nb := UI.button(tr(e2[1]), go2, "primary" if scr == "combat" else "secondary", 200, 76)
		nb.add_theme_font_size_override("font_size", int(22 * UI.ts()))
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(nb)
	if SaveSys.last_load_source == "backup" and not Game.flag("backup_notice"):
		Game.set_flag("backup_notice")
		EventBus.notify(tr("TOAST_BACKUP_RESTORED"), "error")
	EventBus.missions_changed.connect(_refresh_badges)
	EventBus.pass_changed.connect(_refresh_badges)
	EventBus.inventory_changed.connect(_refresh_badges)


func _refresh_badges() -> void:
	if not is_inside_tree():
		return
	var counts := {"chests": Game.chests.total_count(), "missions": Game.missions.claimable_count(), "pass": Game.season.claimable_count()}
	for k in counts.keys():
		var b: Button = side_buttons.get(k)
		if b == null:
			continue
		var old := b.get_node_or_null("Badge")
		if old:
			old.free()
		if int(counts[k]) > 0:
			b.add_child(UI.make_badge(str(counts[k])))


func build_world() -> Node3D:
	var w := Node3D.new()
	BuildingKit.environment(w, 0.95)
	BuildingKit.ground(w, Vector2(60, 60), Vector3.ZERO, Color("#4a5a2a"))
	var flvl: int = Game.base.building_level("fortress")
	var fort := BuildingKit.building("fortress", flvl, Vector2i(4, 4), Color("#c9472b"))
	fort.position = Vector3(1.2, 0, -5)
	w.add_child(fort)
	var others := [["barracks", Vector3(-5, 0, -4), Vector2i(3, 3)], ["royal_forge", Vector3(6.5, 0, -3), Vector2i(3, 2)], ["watchtower", Vector3(-3.5, 0, -1.5), Vector2i(1, 1)],
		["laboratory", Vector3(5.5, 0, -8), Vector2i(3, 3)], ["treasury", Vector3(-6, 0, -8), Vector2i(2, 2)]]
	for o in others:
		var b := BuildingKit.building(o[0], maxi(Game.base.building_level(o[0]), 1 if o[0] != "laboratory" else Game.base.building_level("laboratory")), o[2], Color("#c9472b"))
		b.position = o[1]
		w.add_child(b)
	# Courtyard platform
	MeshKit.part(w, "cyl", [1.6, 0.18, 1.7], MeshKit.mat(Color("#6d655c"), 0, 0.9), Vector3(0, 0.09, 0.4), Vector3.ZERO, Vector3.ONE, true)
	for x in [-1.8, 1.8]:
		BuildingKit.torch(w, Vector3(x, 0, -0.6))
	for k in 8:
		BuildingKit.tree(w, Vector3(randf_range(-14, 14), 0, randf_range(-16, -10)), randf_range(1.0, 1.6))
		BuildingKit.rock(w, Vector3(randf_range(-10, 10), 0, randf_range(2, 6)), randf_range(0.4, 0.9))
	king = GoblinRig.new().build(Game.campaign.player_hero().merged({"is_king": true, "scale": 1.5}))
	king.position = Vector3(0, 0.18, 0.4)
	w.add_child(king)
	cam = Camera3D.new()
	cam.fov = 40
	w.add_child(cam)
	_place_camera(0.0)
	cam.current = true
	return w


func _place_camera(a: float) -> void:
	if cam == null:
		return
	# The King stands slightly right of center so the left shortcuts never cover him.
	var target := Vector3(-1.4, 1.4, 0)
	var pos := Vector3(-1.4 + sin(a) * 0.8, 2.3, 6.4 + cos(a) * 0.2)
	cam.transform = Transform3D(Basis.looking_at(target - pos), pos)


func _process(delta: float) -> void:
	if king == null:
		return
	if not Settings.get_v("limit_animations"):
		orbit_t += delta * 0.12
		_place_camera(sin(orbit_t) * 0.5)
	idle_t -= delta
	if idle_t <= 0 and king.anim == "":
		idle_t = randf_range(4.0, 7.0)
		var choices := [["look", 2.0], ["spin_weapon", 1.4], ["smash", 1.0], ["laugh", 1.4], ["cross_arms", 2.5], ["flex", 1.6]]
		var c: Array = choices[randi() % choices.size()]
		king.play(c[0], c[1])
		if c[0] == "laugh":
			Audio.play_sfx("goblin_laugh", _voice_pitch(), -8)
		elif c[0] == "smash":
			Audio.play_sfx("hit_heavy", 0.8, -10)


func _voice_pitch() -> float:
	var v := int(Game.state.king.appearance.get("voice", 0))
	return [0.85, 0.95, 1.3, 1.0][v % 4]


func _king_react() -> void:
	if king:
		king.play("roar", 0.6)
		Audio.play_sfx("goblin_grunt", _voice_pitch(), -6)
