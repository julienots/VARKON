extends Control
## Main menu: living 3D fortress scene with the player's King Gobelin, top bar, compact side
## shortcuts (chests, missions, pass, events, inventory), one big play button and a tab bar.

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
	# Side shortcuts: one compact coloured tile each (achievements live in the Missions tabs)
	var side := UI.vbox(10)
	side.position = Vector2(14, 96)
	add_child(side)
	for e in [["chests", "MENU_CHESTS", "chest", Color("#f0a51f")], ["missions", "MENU_MISSIONS", "check", Color("#3fbf2f")],
			["pass", "MENU_PASS", "star", Color("#8a55f0")], ["events", "MENU_EVENTS", "flag", Color("#f06a2a")], ["inventory", "MENU_INVENTORY", "bag", Color("#3d8ef0")]]:
		var target: String = e[0]
		var b := _tile(tr(e[1]), e[2], e[3], func() -> void:
			_king_react()
			Router.goto(target), Vector2(96, 92))
		side.add_child(b)
		side_buttons[target] = b
	_refresh_badges()
	# One big play button: next campaign mission
	var mid: String = Game.campaign.current_mission()
	var mm: Dictionary = DB.missions[mid]
	var play := UI.vbox(4)
	play.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	play.offset_left = -190
	play.offset_right = 190
	play.offset_top = -214
	play.offset_bottom = -112
	play.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var ml := UI.label(str(mm.name), 18, Color.WHITE, "bold")
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.add_theme_constant_override("outline_size", 6)
	play.add_child(ml)
	var start := func() -> void:
		if not Game.collection.deck_complete():
			Router.error("ERR_DECK_INCOMPLETE")
			return
		Router.start_battle(Game.campaign.mission_config(mid))
	var pb := UI.button(tr("BTN_FIGHT"), start, "big", 380, 76)
	pb.add_theme_font_size_override("font_size", int(34 * UI.ts()))
	play.add_child(pb)
	add_child(play)
	# Bottom navigation bar: five tabs, Combat raised in the middle
	var bar := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.08, 0.1, 0.23, 0.88)
	bsb.corner_radius_top_left = 22
	bsb.corner_radius_top_right = 22
	bsb.border_width_top = 3
	bsb.border_color = Color("#3a5aa8")
	bsb.content_margin_left = 10
	bsb.content_margin_right = 10
	bsb.content_margin_top = 6
	bsb.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", bsb)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -96
	bar.offset_left = 0
	bar.offset_right = 0
	add_child(bar)
	var nav := UI.hbox(8)
	bar.add_child(nav)
	for e2 in [["shop", "MENU_SHOP", "cart", Color("#e83a8a")], ["collection", "MENU_COLLECTION", "cards", Color("#3d8ef0")], ["combat", "MENU_COMBAT", "swords", Color("#ff9f1a")],
			["king", "MENU_KING", "crown", Color("#f0c020")], ["base", "MENU_BASE", "castle", Color("#3fbf2f")]]:
		var scr: String = e2[0]
		var nb := _tile(tr(e2[1]), e2[2], e2[3], func() -> void:
			_king_react()
			Router.goto(scr), Vector2(0, 84), scr != "combat")
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(nb)
	if SaveSys.last_load_source == "backup" and not Game.flag("backup_notice"):
		Game.set_flag("backup_notice")
		EventBus.notify(tr("TOAST_BACKUP_RESTORED"), "error")
	EventBus.missions_changed.connect(_refresh_badges)
	EventBus.pass_changed.connect(_refresh_badges)
	EventBus.inventory_changed.connect(_refresh_badges)


## Icon-over-label tile. `flat` tiles show only a coloured icon (used in the nav bar).
func _tile(text: String, glyph: String, col: Color, cb: Callable, sz: Vector2, flat := false) -> Button:
	var b := UI.button("", cb, "secondary", int(sz.x), int(sz.y))
	if flat:
		var empty := StyleBoxFlat.new()
		empty.bg_color = Color(1, 1, 1, 0.0)
		empty.set_corner_radius_all(16)
		var hov := empty.duplicate()
		hov.bg_color = Color(1, 1, 1, 0.08)
		b.add_theme_stylebox_override("normal", empty)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", hov)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	else:
		b.add_theme_stylebox_override("normal", UI.candy(col, false, true, 0))
		b.add_theme_stylebox_override("hover", UI.candy(col.lightened(0.1), false, true, 0))
		b.add_theme_stylebox_override("pressed", UI.candy(col, true, true, 0))
	var v := UI.vbox(2)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Glyph.make(glyph, 40 if not flat else 38, col if flat else Color.WHITE)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := UI.label(text, 15, Color.WHITE, "display")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 5)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.add_child(v)
	return b


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
	BuildingKit.environment(w, 1.0)
	BuildingKit.ground(w, Vector2(140, 140), Vector3.ZERO, Color("#4a5a2a"))
	BuildingKit.scenery(w, Vector3(0, 0, -6), 30.0)
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
	MeshKit.part(w, "cyl", [1.6, 0.14, 1.7], MeshKit.mat(Color("#857f73"), 0, 1.0), Vector3(0, 0.07, 0.4), Vector3.ZERO, Vector3.ONE, true)
	# Worn dirt path from the courtyard to the fortress gate
	MeshKit.part(w, "box", [2.2, 0.03, 5.0], MeshKit.mat(Color("#a8835a"), 0, 1.0), Vector3(0.6, 0.01, -2.4), Vector3(0, -6, 0))
	for x in [-1.8, 1.8]:
		BuildingKit.torch(w, Vector3(x, 0, -0.6))
	for k in 14:
		BuildingKit.tree(w, Vector3(randf_range(-16, 16), 0, randf_range(-18, -10)), randf_range(1.1, 1.8))
	for k in 4:
		BuildingKit.tree(w, Vector3([-9.5, -8.0, 9.0, 10.5][k], 0, randf_range(-3, 1)), randf_range(1.3, 1.7))
	for k in 6:
		BuildingKit.rock(w, Vector3(randf_range(-10, 10), 0, randf_range(2, 6)), randf_range(0.4, 0.9))
		BuildingKit.bush(w, Vector3(randf_range(3.5, 9) * (1 if k % 2 == 0 else -1), 0, randf_range(-1, 3)), randf_range(0.7, 1.1))
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
