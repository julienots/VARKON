extends Control
## Launch sequence: SuperEssence Studio logo -> VARKON logo -> King in his fortress while
## data loads (real, measured steps) -> main menu. Skippable after the first launch.

var stage := 0
var can_skip := false
var black: ColorRect
var logo_se: TextureRect
var logo_vk: TextureRect
var sweep: ColorRect
var progress: ProgressBar
var status: Label
var tip: Label
var world: Node3D
var king: GoblinRig
var _skipping := false

const TIPS := ["TIP_1", "TIP_2", "TIP_3", "TIP_4", "TIP_5", "TIP_6"]


func setup(_p: Dictionary) -> void:
	can_skip = Game.flag("intro_seen")
	black = ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	logo_se = _logo("res://assets/branding/superessence_logo.png", Vector2(760, 112))
	logo_vk = _logo("res://assets/branding/varkon_logo.png", Vector2(460, 460))
	var sp := CPUParticles2D.new()
	sp.amount = 60 if Settings.particle_amount(60) > 0 else 1
	sp.lifetime = 2.2
	sp.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sp.emission_rect_extents = Vector2(380, 60)
	sp.gravity = Vector2(0, -25)
	sp.initial_velocity_min = 5
	sp.initial_velocity_max = 30
	sp.scale_amount_min = 1.5
	sp.scale_amount_max = 3.5
	sp.color = Color("#ffd23f")
	sp.set_anchors_preset(Control.PRESET_CENTER)
	sp.position = get_viewport_rect().size / 2
	sp.emitting = false
	add_child(sp)
	set_meta("sparks", sp)
	sweep = ColorRect.new()
	sweep.color = Color(1, 1, 0.85, 0.0)
	sweep.size = Vector2(70, 160)
	sweep.rotation = 0.25
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sweep)
	var bottom := UI.vbox(6)
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left = -360
	bottom.offset_right = 360
	bottom.offset_top = -130
	bottom.offset_bottom = -30
	progress = UI.progress(0, 100, UI.GOLD, 16)
	status = UI.label("", 16, UI.TEXT_DIM)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip = UI.para("", 18, UI.TEXT)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(tip)
	bottom.add_child(progress)
	bottom.add_child(status)
	bottom.modulate.a = 0.0
	add_child(bottom)
	set_meta("bottom", bottom)
	if can_skip:
		var sk := UI.label(tr("LBL_TAP_TO_SKIP"), 16, Color(1, 1, 1, 0.5))
		sk.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		sk.offset_left = -220
		sk.offset_top = -40
		add_child(sk)
	Audio.play_music("music_menu", 2.5)
	_run()


func _logo(path: String, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.offset_left = -sz.x / 2
	t.offset_right = sz.x / 2
	t.offset_top = -sz.y / 2
	t.offset_bottom = sz.y / 2
	t.pivot_offset = sz / 2
	t.modulate.a = 0.0
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


func _wait(sec: float) -> void:
	if _skipping:
		return
	await get_tree().create_timer(sec).timeout


func _run() -> void:
	await _wait(0.5)
	# 1. SuperEssence Studio
	if not _skipping:
		var sp: CPUParticles2D = get_meta("sparks")
		sp.position = get_viewport_rect().size / 2
		sp.emitting = Settings.particle_amount(60) > 0
		logo_se.scale = Vector2(0.94, 0.94)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(logo_se, "modulate:a", 1.0, 0.9)
		tw.tween_property(logo_se, "scale", Vector2.ONE, 2.2)
		await _wait(0.9)
		if not _skipping and not Settings.get_v("reduce_flashes"):
			var c := get_viewport_rect().size / 2
			sweep.position = Vector2(c.x - 420, c.y - 80)
			sweep.color.a = 0.0
			var tw2 := create_tween()
			tw2.tween_property(sweep, "color:a", 0.35, 0.15)
			tw2.parallel().tween_property(sweep, "position:x", c.x + 380, 0.9)
			tw2.tween_property(sweep, "color:a", 0.0, 0.15)
			Audio.play_sfx("magic", 1.2, -6)
		await _wait(1.4)
		create_tween().tween_property(logo_se, "modulate:a", 0.0, 0.5)
		sp.emitting = false
		await _wait(0.6)
	# 2. VARKON
	if not _skipping:
		logo_vk.scale = Vector2(1.25, 1.25)
		var tw3 := create_tween().set_parallel(true)
		tw3.tween_property(logo_vk, "modulate:a", 1.0, 0.8)
		tw3.tween_property(logo_vk, "scale", Vector2.ONE, 1.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		Audio.play_sfx("king_roar", 0.9, -4)
		await _wait(1.9)
	# 3. King in the fortress + real loading
	_build_scene()
	var tw4 := create_tween().set_parallel(true)
	tw4.tween_property(logo_vk, "modulate:a", 0.0, 0.6)
	tw4.tween_property(logo_vk, "scale", Vector2(0.6, 0.6), 0.6)
	tw4.tween_property(black, "color:a", 0.0, 0.8)
	var bottom: Control = get_meta("bottom")
	tw4.tween_property(bottom, "modulate:a", 1.0, 0.5)
	await _load_steps()
	Game.set_flag("intro_seen")
	Game.save_now()
	Router.goto("menu", {}, false)


func _build_scene() -> void:
	world = Node3D.new()
	Router.main.world_root.add_child(world)
	BuildingKit.environment(world, 0.9)
	BuildingKit.ground(world, Vector2(40, 40), Vector3.ZERO, Color("#4a5a2a"))
	var fort := BuildingKit.building("fortress", Game.base.building_level("fortress"), Vector2i(4, 4), Color("#c9472b"))
	fort.position = Vector3(0, 0, -4)
	world.add_child(fort)
	BuildingKit.torch(world, Vector3(-2, 0, 0))
	BuildingKit.torch(world, Vector3(2, 0, 0))
	king = GoblinRig.new().build(Game.campaign.player_hero().merged({"is_king": true, "scale": 1.6}))
	king.position = Vector3(0, 0, 0.5)
	world.add_child(king)
	king.play("roar", 1.5)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.8, 5.2)
	world.add_child(cam)
	cam.look_at(Vector3(0, 1.2, 0))
	cam.current = true
	cam.create_tween().tween_property(cam, "position", Vector3(0.6, 1.6, 4.4), 4.0)


func _step_data() -> bool:
	return DB.load_errors.is_empty()


func _step_save() -> bool:
	return not Game.state.is_empty()


func _step_timers() -> bool:
	Game.base.process_timers()
	Game.lab.process_timers()
	Game.missions.refresh_rotations()
	return true


func _step_audio() -> bool:
	for s in ["ui_click", "hit", "deploy", "explosion"]:
		Audio._stream(s)
	return true


func _step_card(cid: String) -> bool:
	Router.portraits.get_portrait(cid)
	return true


func _load_steps() -> void:
	var steps: Array = [["LOAD_DATA", _step_data], ["LOAD_SAVE", _step_save], ["LOAD_TIMERS", _step_timers], ["LOAD_AUDIO", _step_audio]]
	for cid in Game.state.deck:
		steps.append(["LOAD_CARDS", _step_card.bind(cid)])
	var n := steps.size()
	for i in n:
		tip.text = tr(TIPS[(i / 3) % TIPS.size()])
		status.text = tr(steps[i][0])
		var ok = steps[i][1].call()
		if not ok:
			status.text = tr("LOAD_ERROR")
			push_error("Load step failed: " + steps[i][0])
		progress.value = (i + 1) * 100.0 / n
		await get_tree().process_frame
		if not _skipping:
			await get_tree().create_timer(0.18).timeout
	# Let the portrait queue finish (bounded wait)
	var waited := 0.0
	while Router.portraits.queue.size() > 0 and waited < 3.0 and not _skipping:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if not _skipping:
		await get_tree().create_timer(0.5).timeout


func _gui_input(event: InputEvent) -> void:
	if can_skip and event is InputEventMouseButton and event.pressed:
		_skipping = true
