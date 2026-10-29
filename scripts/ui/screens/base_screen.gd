extends Control
## "Ma base": isometric 3D fortress. Tap a building to inspect/upgrade/collect, move it on the
## grid (invalid footprints refused), build new ones, unlock zones and repair the laboratory.

const CELL := 1.0

var world: Node3D
var cam: Camera3D
var cam_target := Vector3(13, 0, 13)
var zoom := 17.0
var bnodes := {}            # uid -> Node3D
var timer_labels := {}      # uid -> Label3D
var selected_uid := ""
var panel: PanelContainer
var panel_body: VBoxContainer
var mode := ""              # "", "move", "build"
var place_id := ""
var place_pos := Vector2i(12, 12)
var place_rot := 0
var ghost: Node3D
var ghost_mat_ok: StandardMaterial3D
var ghost_mat_bad: StandardMaterial3D
var place_bar: HBoxContainer
var touches := {}
var pinch_d := 0.0
var tick := 0.0


func setup(_p: Dictionary) -> void:
	Audio.play_music("music_menu")
	Audio.play_ambience("ambience_fortress")
	Game.base.process_timers()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := UI.hbox(10)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 8
	top.add_child(UI.icon_button("back", Router.back, 56, tr("BTN_BACK")))
	var t := UI.title(tr("MENU_BASE"), 30)
	top.add_child(t)
	top.add_child(UI.label(tr("LBL_FORTRESS_LEVEL") % Game.base.building_level("fortress"), 18, UI.GOLD, "bold"))
	var tb := TopBar.make(true, ["gold", "crystals", "components", "mutant_essence"])
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tb)
	add_child(top)
	var tools := UI.vbox(8)
	tools.position = Vector2(14, 90)
	tools.add_child(UI.button(tr("BTN_BUILD"), _open_build_menu, "primary", 200, 52))
	tools.add_child(UI.button(tr("BTN_ZONES"), _open_zones, "secondary", 200, 52))
	tools.add_child(UI.button(tr("BTN_COLLECT_ALL"), _collect_all, "secondary", 200, 52))
	tools.add_child(UI.button(tr("MENU_LAB"), func() -> void: Router.goto("lab"), "secondary", 200, 52))
	var zr := UI.hbox(8)
	zr.add_child(UI.button("+", func() -> void: _zoom(-3.0), "secondary", 96, 48))
	zr.add_child(UI.button("-", func() -> void: _zoom(3.0), "secondary", 96, 48))
	tools.add_child(zr)
	tools.add_child(UI.label(tr("LBL_BUILDERS") % [Game.base.active_builders(), BaseSystem.MAX_BUILDERS], 16, UI.TEXT_DIM))
	set_meta("builders_label", tools.get_child(tools.get_child_count() - 1))
	add_child(tools)
	panel = UI.panel_box(Color("#23396f", 0.94))
	panel.anchor_left = 1
	panel.anchor_right = 1
	panel.anchor_top = 0
	panel.anchor_bottom = 1
	panel.offset_left = -400
	panel.offset_right = -12
	panel.offset_top = 90
	panel.offset_bottom = -12
	panel_body = UI.vbox(8)
	panel.add_child(UI.scroll(panel_body))
	panel.visible = false
	add_child(panel)
	place_bar = UI.hbox(10)
	place_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	place_bar.offset_left = -330
	place_bar.offset_right = 330
	place_bar.offset_top = -80
	place_bar.offset_bottom = -14
	place_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	place_bar.add_child(UI.button(tr("BTN_CANCEL"), _cancel_place, "secondary", 160))
	place_bar.add_child(UI.button(tr("BTN_ROTATE"), _rotate_place, "secondary", 160))
	place_bar.add_child(UI.button(tr("BTN_CONFIRM"), _confirm_place, "primary", 180))
	place_bar.visible = false
	add_child(place_bar)
	var hint := UI.label(tr("HINT_BASE"), 15, Color(1, 1, 1, 0.7))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_top = -34
	hint.offset_left = 16
	add_child(hint)
	EventBus.base_changed.connect(_rebuild_buildings)


func build_world() -> Node3D:
	world = Node3D.new()
	BuildingKit.environment(world, 1.0)
	var g: Dictionary = DB.buildings_json.grid
	var gw := int(g.width)
	var gh := int(g.height)
	BuildingKit.ground(world, Vector2(gw + 40, gh + 40), Vector3(gw / 2.0, -0.02, gh / 2.0), Color("#3f4a26"))
	for k in 30:
		var a := randf() * TAU
		var r := randf_range(gw * 0.75, gw * 1.1)
		BuildingKit.tree(world, Vector3(gw / 2.0 + cos(a) * r, 0, gh / 2.0 + sin(a) * r), randf_range(1.0, 1.8))
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(cam)
	_update_cam()
	cam.current = true
	ghost_mat_ok = MeshKit.unshaded(Color("#7bdc3a"), 0.45)
	ghost_mat_bad = MeshKit.unshaded(Color("#e0503a"), 0.45)
	_build_zones()
	_rebuild_buildings()
	return world


func _update_cam() -> void:
	cam.size = zoom
	var pos := cam_target + Vector3(18, 22, 18)
	cam.transform = Transform3D(Basis.looking_at(cam_target - pos), pos)


func _zoom(d: float) -> void:
	zoom = clampf(zoom + d, 10.0, 34.0)
	_update_cam()


func _build_zones() -> void:
	var root := Node3D.new()
	root.name = "Zones"
	world.add_child(root)
	for z in DB.buildings_json.zones:
		var r: Array = z.rect
		var unlocked := Game.base.zone_unlocked(z.id)
		var center := Vector3(float(r[0]) + float(r[2]) / 2.0, 0.0, float(r[1]) + float(r[3]) / 2.0)
		var col := Color("#5a5040") if unlocked else Color("#151210")
		MeshKit.part(root, "box", [float(r[2]) - 0.05, 0.05, float(r[3]) - 0.05], MeshKit.mat(col, 0, 1.0), center)
		if unlocked:
			for x in int(r[2]) + 1:
				MeshKit.part(root, "box", [0.03, 0.06, float(r[3])], MeshKit.unshaded(Color(1, 1, 1), 0.08), Vector3(float(r[0]) + x, 0.03, center.z))
			for y in int(r[3]) + 1:
				MeshKit.part(root, "box", [float(r[2]), 0.06, 0.03], MeshKit.unshaded(Color(1, 1, 1), 0.08), Vector3(center.x, 0.03, float(r[1]) + y))
		else:
			var l := Label3D.new()
			l.text = DB.txt(z) + "\n" + tr("LBL_LOCKED")
			l.font = UI.font("title")
			l.font_size = 64
			l.pixel_size = 0.012
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.modulate = Color(1, 0.85, 0.5, 0.8)
			l.outline_size = 12
			l.position = center + Vector3(0, 0.8, 0)
			root.add_child(l)
		set_meta("zones_root", root)


func _rebuild_zones() -> void:
	var z: Node = get_meta("zones_root", null)
	if z:
		z.queue_free()
	_build_zones()


func _rebuild_buildings() -> void:
	if world == null:
		return
	for uid in bnodes.keys():
		bnodes[uid].queue_free()
	bnodes.clear()
	timer_labels.clear()
	for bd in Game.base.b().buildings:
		_make_building(bd)
	if selected_uid != "":
		_show_panel(selected_uid)
	var bl: Label = get_meta("builders_label", null)
	if bl:
		bl.text = tr("LBL_BUILDERS") % [Game.base.active_builders(), BaseSystem.MAX_BUILDERS]


func _make_building(bd: Dictionary) -> void:
	var sz: Vector2i = Game.base.size_of(bd)
	var d: Dictionary = DB.buildings[bd.id]
	var n := BuildingKit.building(bd.id, int(bd.level), sz, Color(d.get("color", "#c9472b")))
	n.position = Vector3(float(bd.x) + sz.x / 2.0, 0.03, float(bd.y) + sz.y / 2.0)
	if sz != Vector2i(int(d.size[0]), int(d.size[1])):
		pass
	world.add_child(n)
	bnodes[bd.uid] = n
	if bd.uid == selected_uid:
		var ring := MeshKit.part(n, "box", [sz.x + 0.2, 0.05, sz.y + 0.2], MeshKit.unshaded(UI.GOLD, 0.35), Vector3(0, 0.02, 0))
		ring.name = "Sel"
	if float(bd.upgrade_end) > 0:
		for cx in [-1, 1]:
			for cz in [-1, 1]:
				MeshKit.part(n, "cyl", [0.04, 2.0], MeshKit.mat(Color("#8a6a40")), Vector3(cx * sz.x * 0.45, 1.0, cz * sz.y * 0.45))
		var l := Label3D.new()
		l.font = UI.font("display")
		l.font_size = 48
		l.pixel_size = 0.012
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.outline_size = 10
		l.position = Vector3(0, 3.2, 0)
		n.add_child(l)
		timer_labels[bd.uid] = l
	var prod: Dictionary = Game.base.production_of(bd)
	if not prod.is_empty() and Game.base.pending(bd) > 0:
		var icon := MeshKit.part(n, "sphere", [0.22], MeshKit.mat(DB.resource_color(str(prod.resource)), 0.6, 0.3, DB.resource_color(str(prod.resource)), 1.2), Vector3(0, 2.6, 0))
		icon.name = "Ready"


func _process(delta: float) -> void:
	tick -= delta
	if tick <= 0:
		tick = 0.5
		var done: Array = Game.base.process_timers()
		if not done.is_empty():
			Audio.play_sfx("upgrade")
			for bd in done:
				EventBus.notify(tr("TOAST_BUILDING_DONE") % [DB.txt(DB.buildings[bd.id]), int(bd.level)], "success")
		for uid in timer_labels.keys():
			var bd2: Dictionary = Game.base.get_building(uid)
			if not bd2.is_empty():
				timer_labels[uid].text = UI.time_fmt(Game.base.remaining(bd2))
		if selected_uid != "" and panel.visible and mode == "":
			var bd3: Dictionary = Game.base.get_building(selected_uid)
			if not bd3.is_empty() and float(bd3.upgrade_end) > 0:
				_show_panel(selected_uid)
	for n in bnodes.values():
		var r: Node3D = n.get_node_or_null("Ready")
		if r:
			r.position.y = 2.6 + sin(Time.get_ticks_msec() / 300.0) * 0.15


# ------------------------------------------------------------------ input
func _cell_at(sp: Vector2) -> Variant:
	var from := cam.project_ray_origin(sp)
	var dir := cam.project_ray_normal(sp)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	var hit := from + dir * t
	return Vector2i(int(floor(hit.x)), int(floor(hit.z)))


func _unhandled_input(event: InputEvent) -> void:
	if world == null or Router.popup_open:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		pinch_d = 0.0
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() == 2:
			var pts: Array = touches.values()
			var d: float = pts[0].distance_to(pts[1])
			if pinch_d > 0:
				zoom = clampf(zoom * pinch_d / maxf(1.0, d), 10.0, 34.0)
				_update_cam()
			pinch_d = d
	if event is InputEventMagnifyGesture:
		zoom = clampf(zoom / event.factor, 10.0, 34.0)
		_update_cam()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(-1.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(1.5)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and Router.drag_dist < 14 and touches.size() <= 1:
			_on_tap(event.position)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) and touches.size() <= 1:
		if mode != "":
			var c = _cell_at(event.position)
			if c != null:
				var sz := _place_size()
				place_pos = Vector2i(c.x - sz.x / 2, c.y - sz.y / 2)
				_update_ghost()
		else:
			# Pan the camera along the isometric axes
			var k := zoom / get_viewport_rect().size.y
			var right := Vector3(1, 0, -1).normalized()
			var fwd := Vector3(1, 0, 1).normalized()
			cam_target -= right * event.relative.x * k * 1.4 + fwd * event.relative.y * k * 1.9
			cam_target.x = clampf(cam_target.x, 0, 26)
			cam_target.z = clampf(cam_target.z, 0, 26)
			_update_cam()


func _on_tap(sp: Vector2) -> void:
	var c = _cell_at(sp)
	if c == null:
		return
	if mode != "":
		var sz := _place_size()
		place_pos = Vector2i(c.x - sz.x / 2, c.y - sz.y / 2)
		_update_ghost()
		return
	for bd in Game.base.b().buildings:
		var sz2: Vector2i = Game.base.size_of(bd)
		if Rect2i(int(bd.x), int(bd.y), sz2.x, sz2.y).has_point(c):
			selected_uid = bd.uid
			Audio.play_sfx("ui_open")
			_rebuild_buildings()
			_show_panel(bd.uid)
			return
	selected_uid = ""
	panel.visible = false
	_rebuild_buildings()


# ------------------------------------------------------------------ panel
func _show_panel(uid: String) -> void:
	var bd: Dictionary = Game.base.get_building(uid)
	if bd.is_empty():
		panel.visible = false
		return
	var d: Dictionary = DB.buildings[bd.id]
	panel.visible = true
	UIScreen.clear(panel_body)
	var hdr := UI.hbox()
	var t := UI.title(DB.txt(d), 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(t)
	hdr.add_child(UI.icon_button("close", func() -> void:
		selected_uid = ""
		panel.visible = false
		_rebuild_buildings(), 44))
	panel_body.add_child(hdr)
	if bd.id == "laboratory" and int(bd.level) == 0:
		_lab_ruin_panel()
		return
	panel_body.add_child(UI.label(tr("LBL_LEVEL") % int(bd.level) + " / %d" % int(d.max_level), 18, UI.GOLD, "bold"))
	panel_body.add_child(UI.para(DB.txt(d, "desc"), 16, UI.TEXT))
	var prod: Dictionary = Game.base.production_of(bd)
	if not prod.is_empty():
		panel_body.add_child(UIScreen.stat_row(tr("LBL_PRODUCTION"), "%.0f %s / h" % [Game.base.rate_per_hour(bd), DB.resource_name(str(prod.resource))]))
		panel_body.add_child(UIScreen.stat_row(tr("LBL_STORED"), "%d / %d" % [Game.base.pending(bd), Game.base.capacity(bd)]))
		var cb := UI.button(tr("BTN_COLLECT"), func() -> void:
			var n: int = Game.base.collect(uid)
			if n > 0:
				Audio.play_sfx("coin")
				EventBus.notify("+%d %s" % [n, DB.resource_name(str(prod.resource))], "success")
			_show_panel(uid), "green", 0, 48)
		cb.disabled = Game.base.pending(bd) <= 0
		panel_body.add_child(cb)
	if float(bd.upgrade_end) > 0:
		panel_body.add_child(UI.label(tr("LBL_UPGRADING") % UI.time_fmt(Game.base.remaining(bd)), 18, Color("#9ad7ff"), "bold"))
		var cost := Game.base.speedup_cost(bd)
		var sb := UI.button(tr("BTN_SPEEDUP") % cost, func() -> void:
			Router.confirm_spend(tr("CONFIRM_SPEEDUP"), {"crystals": cost}, func() -> void:
				var err: String = Game.base.speedup(uid)
				if err != "":
					Router.error(err)), "secondary", 0, 48)
		panel_body.add_child(sb)
	elif int(bd.level) < int(d.max_level):
		var ucost: Dictionary = Game.base.upgrade_cost(bd)
		panel_body.add_child(UI.label(tr("LBL_NEXT_LEVEL") % (int(bd.level) + 1), 17, Color.WHITE, "bold"))
		panel_body.add_child(UI.cost_row(ucost))
		panel_body.add_child(UI.label(tr("LBL_DURATION") % UI.time_fmt(Game.base.upgrade_time(bd)), 15, UI.TEXT_DIM))
		var why: String = Game.base.can_upgrade(bd)
		var ub := UI.button(tr("BTN_UPGRADE"), func() -> void:
			Router.confirm_spend(tr("CONFIRM_UPGRADE_BUILDING") % DB.txt(d), ucost, func() -> void:
				var err: String = Game.base.start_upgrade(uid)
				if err != "":
					Router.error(err)
				else:
					Audio.play_sfx("build")), "primary", 0, 52)
		ub.disabled = why != ""
		panel_body.add_child(ub)
		if why != "":
			var wl := UI.para(tr(why) + (" (%d)" % (int(bd.level) * 2) if why == "ERR_PLAYER_LEVEL" else ""), 15, Color("#ff8a70"))
			panel_body.add_child(wl)
	else:
		panel_body.add_child(UI.label(tr("LBL_MAX_LEVEL"), 17, UI.GOLD, "bold"))
	panel_body.add_child(UI.button(tr("BTN_MOVE"), func() -> void: _start_move(uid), "secondary", 0, 48))
	if bd.id == "laboratory":
		panel_body.add_child(UI.button(tr("MENU_LAB"), func() -> void: Router.goto("lab"), "primary", 0, 48))
	if bd.id == "raid_portal":
		panel_body.add_child(UI.button(tr("TAB_RAID"), func() -> void: Router.goto("combat", {"tab": "raid"}), "primary", 0, 48))
	if bd.id == "card_hall":
		panel_body.add_child(UI.button(tr("MENU_COLLECTION"), func() -> void: Router.goto("collection"), "primary", 0, 48))
	if bd.id == "trophy_hall":
		panel_body.add_child(UI.button(tr("MENU_ACHIEVEMENTS"), func() -> void: Router.goto("missions", {"tab": "achievements"}), "primary", 0, 48))


func _lab_ruin_panel() -> void:
	panel_body.add_child(UI.para(tr("LAB_LOCKED_MSG"), 17, Color("#ff8a70")))
	for s in Game.lab.unlock_status():
		panel_body.add_child(UI.label(("» " if s.ok else "• ") + str(s.text), 17, UI.GREEN if s.ok else UI.TEXT_DIM, "bold"))
	var why: String = Game.lab.can_repair()
	if why != "ERR_ALREADY_DONE":
		panel_body.add_child(UI.label(tr("LBL_REPAIR_MISSION"), 17, Color.WHITE, "bold"))
		panel_body.add_child(UI.cost_row(DB.lab.repair_cost))
		var b := UI.button(tr("BTN_REPAIR"), func() -> void:
			Router.confirm_spend(tr("CONFIRM_REPAIR"), DB.lab.repair_cost, func() -> void:
				var err: String = Game.lab.repair()
				if err != "":
					Router.error(err)
				else:
					Audio.play_sfx("craft")
					EventBus.notify(tr("TOAST_LAB_UNLOCKED"), "level")), "primary", 0, 52)
		b.disabled = why != ""
		panel_body.add_child(b)
		if why == "ERR_CONDITIONS":
			panel_body.add_child(UI.para(tr("ERR_CONDITIONS"), 15, UI.TEXT_DIM))


# ------------------------------------------------------------------ placement
func _place_size() -> Vector2i:
	var s: Array = DB.buildings[place_id].size
	return Vector2i(int(s[1]), int(s[0])) if place_rot % 2 == 1 else Vector2i(int(s[0]), int(s[1]))


func _start_move(uid: String) -> void:
	var bd: Dictionary = Game.base.get_building(uid)
	mode = "move"
	place_id = bd.id
	place_pos = Vector2i(int(bd.x), int(bd.y))
	place_rot = int(bd.rot)
	panel.visible = false
	place_bar.visible = true
	_update_ghost()


func _start_build(id: String) -> void:
	Router.close_popup()
	mode = "build"
	place_id = id
	place_rot = 0
	var c := Vector2i(int(cam_target.x), int(cam_target.z))
	place_pos = c
	panel.visible = false
	place_bar.visible = true
	_update_ghost()


func _update_ghost() -> void:
	if ghost:
		ghost.queue_free()
	var sz := _place_size()
	var err: String = Game.base.check_placement(place_id, place_pos.x, place_pos.y, place_rot, selected_uid if mode == "move" else "")
	ghost = Node3D.new()
	MeshKit.part(ghost, "box", [sz.x, 0.15, sz.y], ghost_mat_ok if err == "" else ghost_mat_bad, Vector3(0, 0.08, 0))
	var preview := BuildingKit.building(place_id, 1, sz, Color(DB.buildings[place_id].get("color", "#c9472b")))
	ghost.add_child(preview)
	ghost.position = Vector3(place_pos.x + sz.x / 2.0, 0.05, place_pos.y + sz.y / 2.0)
	world.add_child(ghost)
	if mode == "move" and bnodes.has(selected_uid):
		bnodes[selected_uid].visible = false
	var cb: Button = place_bar.get_child(2)
	cb.disabled = err != ""
	cb.tooltip_text = tr(err) if err != "" else ""


func _rotate_place() -> void:
	place_rot = (place_rot + 1) % 2
	_update_ghost()


func _cancel_place() -> void:
	mode = ""
	if ghost:
		ghost.queue_free()
		ghost = null
	place_bar.visible = false
	_rebuild_buildings()


func _confirm_place() -> void:
	var err := ""
	if mode == "move":
		err = Game.base.move(selected_uid, place_pos.x, place_pos.y, place_rot)
	elif mode == "build":
		err = Game.base.build(place_id, place_pos.x, place_pos.y, place_rot)
	if err != "":
		Router.error(err)
		return
	Audio.play_sfx("build")
	_cancel_place()


func _open_build_menu() -> void:
	var p := UI.panel_box()
	p.custom_minimum_size = Vector2(820, 560)
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.title(tr("BTN_BUILD"), 28))
	var list := UI.vbox(6)
	for d in DB.buildings_json.buildings:
		if d.get("locked_ruin", false):
			continue
		var id: String = d.id
		var row := UI.panel_box(Color("#2a4482"))
		var h := UI.hbox(10)
		var vv := UI.vbox(2)
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vv.add_child(UI.label("%s  (%d / %d)" % [DB.txt(d), Game.base.buildings_of(id).size(), Game.base.max_count(id)], 18, Color.WHITE, "bold"))
		vv.add_child(UI.para(DB.txt(d, "desc"), 14))
		h.add_child(vv)
		h.add_child(UI.cost_row(Game.base.build_cost(id), 16))
		var why: String = Game.base.can_build(id)
		var b := UI.button(tr("BTN_PLACE"), _start_build.bind(id), "primary", 130, 46)
		b.disabled = why != ""
		h.add_child(b)
		if why != "":
			h.add_child(UI.label(tr(why), 13, Color("#ff8a70")))
		row.add_child(h)
		list.add_child(row)
	v.add_child(UI.scroll(list))
	v.add_child(UI.button(tr("BTN_CLOSE"), Router.close_popup, "secondary", 160))
	Router.popup(p)


func _open_zones() -> void:
	var p := UI.panel_box()
	p.custom_minimum_size = Vector2(760, 0)
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.title(tr("BTN_ZONES"), 28))
	for z in DB.buildings_json.zones:
		var zid: String = z.id
		var st: String = Game.base.zone_status(zid)
		var row := UI.hbox(10)
		var vv := UI.vbox(2)
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vv.add_child(UI.label(DB.txt(z), 18, UI.GREEN if st == "unlocked" else Color.WHITE, "bold"))
		vv.add_child(UI.para(DB.txt(z, "desc") + "  " + tr("LBL_REQ_FORTRESS") % int(z.req.get("fortress", 1)), 14))
		row.add_child(vv)
		if st == "unlocked":
			row.add_child(UI.label(tr("LBL_UNLOCKED"), 16, UI.GREEN, "bold"))
		else:
			row.add_child(UI.cost_row(z.cost, 16))
			var b := UI.button(tr("BTN_UNLOCK"), func() -> void:
				Router.confirm_spend(tr("CONFIRM_ZONE") % DB.txt(z), z.cost, func() -> void:
					var err: String = Game.base.unlock_zone(zid)
					if err != "":
						Router.error(err)
					else:
						Audio.play_sfx("upgrade")
						_rebuild_zones()
						Router.close_popup()), "primary", 130, 44)
			b.disabled = st != ""
			row.add_child(b)
		v.add_child(row)
	v.add_child(UI.button(tr("BTN_CLOSE"), Router.close_popup, "secondary", 160))
	Router.popup(p)


func _collect_all() -> void:
	var t: Dictionary = Game.base.collect_all()
	if t.is_empty():
		EventBus.notify(tr("TOAST_NOTHING_TO_COLLECT"), "info")
		return
	Audio.play_sfx("coin")
	var parts: Array = []
	for k in t.keys():
		parts.append("+%d %s" % [int(t[k]), DB.resource_name(k)])
	EventBus.notify(", ".join(parts), "success")
