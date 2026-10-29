class_name BattleView
extends Node3D
## Renders a BattleSim in 2.5D (perspective 3D camera over the battlefield) and turns
## simulation events into animations, projectiles, damage numbers and effects.

const TEAM_COLORS := [Color("#2f8cff"), Color("#ff4a3a")]
const VIS := 1.7   # visual scale of characters on the battlefield (gameplay radii are unchanged)

var sim: BattleSim
var camera: Camera3D
var nodes := {}          # id -> Node3D
var bars := {}           # id -> {root, fill}
var status_fx := {}      # id -> Node3D ring
var shield_fx := {}
var accum := 0.0
var shake := 0.0
var cam_base := Vector3.ZERO
var zone_highlight: MeshInstance3D
var ghost: MeshInstance3D
var range_ring: MeshInstance3D
var speed := 1.0
var protos := {}         # card id -> merged prototype rig (cloned for each spawn)


func setup(s: BattleSim) -> void:
	sim = s
	BuildingKit.environment(self, 1.0, true)
	var gcol := Color("#4f9a2e")
	match sim.mode:
		"boss": gcol = Color("#9a7a48")
		"raid": gcol = Color("#6f9a32")
		"defense", "survival": gcol = Color("#478f34")
	BuildingKit.ground(self, Vector2(90, 70), Vector3(BattleSim.L / 2, -0.01, BattleSim.W / 2), gcol.darkened(0.08))
	BuildingKit.scenery(self, Vector3(BattleSim.L / 2, 0, BattleSim.W / 2), 32.0)
	# Battlefield: painted lawn with soft mowing stripes
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = BuildingKit.field_texture(gcol)
	fm.uv1_scale = Vector3(BattleSim.L / 8.0, BattleSim.W / 8.0, 1)
	fm.roughness = 1.0
	fm.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	MeshKit.part(self, "box", [BattleSim.L, 0.06, BattleSim.W], fm, Vector3(BattleSim.L / 2, 0.0, BattleSim.W / 2))
	# Worn dirt paths toward the towers
	for lane in [4.0, BattleSim.W - 4.0]:
		MeshKit.part(self, "box", [BattleSim.L - 8.0, 0.065, 1.2], MeshKit.mat(Color("#a8835a"), 0, 1.0), Vector3(BattleSim.L / 2, 0.0, lane))
		MeshKit.part(self, "box", [BattleSim.L - 7.6, 0.062, 1.6], MeshKit.mat(Color("#8a8a4a"), 0, 1.0), Vector3(BattleSim.L / 2, 0.0, lane))
	MeshKit.part(self, "box", [0.1, 0.08, BattleSim.W], MeshKit.unshaded(Color(1, 1, 1), 0.3), Vector3(BattleSim.MID, 0.05, BattleSim.W / 2))
	# Field border: low stone kerb
	var kerb := MeshKit.mat(BuildingKit.STONE, 0, 1.0)
	for z in [-0.15, BattleSim.W + 0.15]:
		MeshKit.part(self, "box", [BattleSim.L + 0.6, 0.26, 0.3], kerb, Vector3(BattleSim.L / 2, 0.13, z), Vector3.ZERO, Vector3.ONE, true)
	for x in [-0.15, BattleSim.L + 0.15]:
		MeshKit.part(self, "box", [0.3, 0.26, BattleSim.W + 0.6], kerb, Vector3(x, 0.13, BattleSim.W / 2), Vector3.ZERO, Vector3.ONE, true)
	for z in [-0.4, BattleSim.W + 0.4]:
		for k in 16:
			BuildingKit.rock(self, Vector3(k * 2.1 + randf(), 0, z + randf_range(-0.3, 0.3)), randf_range(0.6, 1.2))
	for k in 12:
		BuildingKit.tree(self, Vector3(randf_range(-6, BattleSim.L + 6), 0, randf_range(-10, -2.5)), randf_range(1.0, 1.6), sim.mode == "boss")
		BuildingKit.tree(self, Vector3(randf_range(-6, BattleSim.L + 6), 0, randf_range(BattleSim.W + 3, BattleSim.W + 8)), randf_range(0.9, 1.4), sim.mode == "boss")
	for k in 8:
		BuildingKit.bush(self, Vector3(randf_range(-4, BattleSim.L + 4), 0, randf_range(-2.4, -1.2)), randf_range(0.8, 1.2))
	for x in [-1.5, BattleSim.L + 1.5]:
		for z in [3.0, BattleSim.W - 3.0]:
			BuildingKit.torch(self, Vector3(x, 0, z))
	# Deploy-zone highlight (shown while dragging a card)
	zone_highlight = MeshKit.part(self, "box", [1, 0.02, 1], MeshKit.unshaded(Color("#3d8bff"), 0.16), Vector3.ZERO)
	zone_highlight.visible = false
	ghost = MeshKit.part(self, "disc", [0.6], MeshKit.unshaded(Color("#ffffff"), 0.45), Vector3.ZERO)
	ghost.visible = false
	range_ring = MeshKit.part(self, "torus", [0.95, 1.0], MeshKit.unshaded(Color("#ffffff"), 0.4), Vector3.ZERO)
	range_ring.visible = false
	camera = Camera3D.new()
	camera.fov = 42
	cam_base = Vector3(BattleSim.L / 2, 21.5, BattleSim.W + 12.5)
	camera.position = cam_base
	add_child(camera)
	camera.look_at(Vector3(BattleSim.L / 2, 0, BattleSim.W / 2 + 0.6))
	camera.current = true
	for e in sim.ents:
		_create(e)


func to3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


## Screen position -> battlefield coordinates (intersection with the ground plane).
func screen_to_field(sp: Vector2) -> Variant:
	var from := camera.project_ray_origin(sp)
	var dir := camera.project_ray_normal(sp)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t < 0:
		return null
	var hit := from + dir * t
	return Vector2(hit.x, hit.z)


func show_deploy(team: int, p: Variant, radius := 0.6, rng := 0.0, valid := true) -> void:
	var z: Rect2 = sim.deploy_zone(team)
	zone_highlight.visible = p != null
	zone_highlight.scale = Vector3(z.size.x, 1, z.size.y)
	zone_highlight.position = Vector3(z.get_center().x, 0.06, z.get_center().y)
	ghost.visible = p != null
	range_ring.visible = p != null and rng > 1.5 and Settings.get_v("range_indicators")
	if p != null:
		ghost.position = to3(p, 0.08)
		ghost.scale = Vector3.ONE * radius / 0.6
		ghost.material_override = MeshKit.unshaded(Color("#7bdc3a") if valid else Color("#e0503a"), 0.5)
		range_ring.position = to3(p, 0.08)
		range_ring.scale = Vector3(rng, 0.3, rng)


# ------------------------------------------------------------------ entity visuals
func _create(e: BattleEnt) -> void:
	if nodes.has(e.id):
		return
	var n: Node3D
	var tc: Color = TEAM_COLORS[e.team]
	match e.kind:
		"structure":
			n = BuildingKit.throne(tc) if e.sub == "throne" else BuildingKit.tower(tc)
		"wall":
			n = BuildingKit.wall_segment()
		"turret":
			n = BuildingKit.turret()
		"dummy":
			n = BuildingKit.dummy()
		"trap", "rune":
			n = Node3D.new()
			var col := Color("#c0a080") if e.kind == "trap" else Color("#58a6ff")
			var visible_to_player := e.team == 0
			var disc := MeshKit.part(n, "disc", [e.radius], MeshKit.unshaded(col, 0.35 if visible_to_player else 0.0), Vector3(0, 0.05, 0))
			disc.name = "Disc"
			if e.kind == "trap":
				for k in 4:
					MeshKit.part(n, "cone", [0.04, 0.18], MeshKit.mat(Color("#a8adb4"), 0.9), Vector3(cos(k * 1.57) * 0.2, 0.09, sin(k * 1.57) * 0.2)).visible = visible_to_player
		"rift":
			n = Node3D.new()
			MeshKit.part(n, "torus", [e.radius * 0.7, e.radius], MeshKit.unshaded(Color("#8a5cff"), 0.8), Vector3(0, 0.1, 0))
			var exit_n := MeshKit.part(n, "torus", [e.radius * 0.5, e.radius * 0.8], MeshKit.unshaded(Color("#b28cff"), 0.6), Vector3.ZERO)
			exit_n.top_level = true
			exit_n.global_position = to3(e.data.exit, 0.1)
		"hero":
			var h: Dictionary = sim.sides[e.team].hero
			n = GoblinRig.new().build({"is_king": true, "appearance": h.appearance, "visuals": h.visuals, "scale": 1.25 * VIS, "color": tc.to_html()})
			_add_team_ring(n, tc, 0.6)
			_entry_effect(e, str(h.get("cosmetic_sel", {}).get("entry", "")))
		"boss":
			var bd: Dictionary = DB.bosses[e.def_id]
			var p := {"look": bd.look, "color": bd.look.color, "skin": Color(bd.look.color).lightened(0.15).to_html(), "scale": float(bd.look.scale) * 1.3, "glow_eyes": true}
			n = GoblinRig.new().build(p)
			_add_team_ring(n, tc, e.radius)
		"decoy":
			n = _unit_rig(e.def_id)
			for c in n.get_children():
				if c is Node3D:
					c.visible = true
			n.set_meta("decoy", true)
			_add_team_ring(n, Color("#b28cff"), e.radius)
		_:
			n = _unit_rig(e.def_id)
			_add_team_ring(n, tc, e.radius / VIS * 1.2)
			if e.flying:
				n.position.y = 1.4
	n.position = to3(e.pos, n.position.y)
	if e.team == 1 and n is GoblinRig:
		n.rotation.y = -PI / 2
	elif n is GoblinRig:
		n.rotation.y = PI / 2
	add_child(n)
	nodes[e.id] = n
	if e.kind in ["unit", "hero", "structure", "boss", "turret", "wall", "decoy", "dummy"]:
		_create_bar(e)
	if e.kind in ["unit", "hero", "boss"] and e.deploy_t > 0.3 and not Settings.get_v("limit_animations"):
		_puff(e.pos, TEAM_COLORS[e.team], 10)
		n.scale = Vector3.ONE * 0.01
		var target_scale := (n as GoblinRig).base_scale if n is GoblinRig else 1.0
		n.create_tween().tween_property(n, "scale", Vector3.ONE * target_scale, 0.35).set_trans(Tween.TRANS_BACK)


## Cosmetic entry effect of the King (owned "entry" cosmetic selected in the King screen).
func _entry_effect(e: BattleEnt, entry_id: String) -> void:
	if entry_id == "" or not DB.cosmetics.has(entry_id):
		return
	match str(DB.cosmetics[entry_id].anim):
		"smoke":
			_puff(e.pos, Color("#5a5a5a"), 30)
			_puff(e.pos, Color("#2a2a2a"), 20)
		"lightning":
			var bolt := MeshKit.part(self, "cyl", [0.12, 14.0], MeshKit.mat(Color("#bfe8ff"), 0, 0.2, Color("#9ad7ff"), 4.0 * Settings.flash_scale()), Vector3(e.pos.x, 7.0, e.pos.y))
			var tw := bolt.create_tween()
			tw.tween_property(bolt, "scale", Vector3(0.1, 1, 0.1), 0.35)
			tw.tween_callback(bolt.queue_free)
			_ring(e.pos, 2.2, Color("#9ad7ff"), 0.6, true)
			Audio.play_sfx("zap")
			shake = maxf(shake, 0.4)


func _unit_rig(cid: String) -> GoblinRig:
	if not protos.has(cid):
		var proto := GoblinRig.new().build(_unit_params(cid))
		proto.merge_static()
		protos[cid] = proto
	return (protos[cid] as GoblinRig).clone()


func _exit_tree() -> void:
	for p in protos.values():
		p.free()
	protos.clear()


func _unit_params(cid: String) -> Dictionary:
	var p := GoblinRig.card_params(cid)
	p.scale = float(p.scale) * VIS
	p.detail = mini(Settings.effective_quality(), 1)  # skip tiny facial details on the battlefield
	return p


func _add_team_ring(n: Node3D, col: Color, r: float) -> void:
	var ring := MeshKit.part(n, "torus", [r * 0.85, r], MeshKit.unshaded(col, 0.7), Vector3(0, 0.03, 0))
	ring.scale = Vector3(1, 0.2, 1)
	ring.top_level = false
	ring.set_meta("team_ring", true)


func _create_bar(e: BattleEnt) -> void:
	var root := Node3D.new()
	var w := 1.6 if e.kind in ["structure", "boss"] else (1.1 if e.kind == "hero" else 0.8)
	if e.kind == "boss":
		w = 3.0
	var h := 0.14 if e.kind in ["structure", "boss", "hero"] else 0.1
	var bg := MeshKit.part(root, "quad", [w + 0.06, h + 0.06], MeshKit.unshaded(Color(0, 0, 0), 0.75))
	var fill := MeshKit.part(root, "quad", [w, h], MeshKit.unshaded(TEAM_COLORS[e.team].lightened(0.15)), Vector3(0, 0, 0.01))
	var shield_q := MeshKit.part(root, "quad", [w, h * 0.45], MeshKit.unshaded(Color("#e8f4ff")), Vector3(0, h * 0.75, 0.02))
	shield_q.visible = false
	for q in [bg, fill, shield_q]:
		(q.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		(q.material_override as StandardMaterial3D).no_depth_test = true
		q.sorting_offset = 10
	add_child(root)
	var y := {"structure": 3.9 if e.sub == "throne" else 3.9, "wall": 1.6, "turret": 1.2, "boss": 5.5, "hero": 2.2, "dummy": 2.1}.get(e.kind, 1.5)
	if e.kind == "unit":
		y = 1.3 * float(GoblinRig.card_params(e.def_id).scale) * VIS + (1.4 if e.flying else 0.0)
	if e.kind == "hero":
		y = 1.4 * 1.25 * VIS
	if e.kind == "boss":
		y = 1.6 * float(DB.bosses[e.def_id].look.scale) * 1.3
	bars[e.id] = {"root": root, "fill": fill, "w": w, "y": y, "shield": shield_q, "always": e.kind in ["structure", "hero", "boss"]}


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	if sim == null:
		return
	if not sim.paused and not sim.finished:
		accum += delta * speed
		var steps := 0
		while accum >= BattleSim.DT and steps < 6:
			sim.step()
			accum -= BattleSim.DT
			steps += 1
			_consume(sim.pop_events())
	elif sim.finished:
		_consume(sim.pop_events())
	var alpha := clampf(accum / BattleSim.DT, 0.0, 1.0)
	for e in sim.ents:
		var n: Node3D = nodes.get(e.id)
		if n == null:
			_create(e)
			n = nodes.get(e.id)
			if n == null:
				continue
		var p := e.prev_pos.lerp(e.pos, alpha)
		var y := n.position.y
		n.position = Vector3(p.x, y, p.y)
		if n is GoblinRig:
			var rig := n as GoblinRig
			var mv := e.pos.distance_to(e.prev_pos) > 0.001
			rig.set_moving(mv, e.speed)
			var dir := e.facing
			if e.target and e.target.alive:
				dir = (e.target.pos - e.pos).normalized()
			rig.face(Vector3(dir.x, 0, dir.y))
			# Stealth: semi-transparent for the owner, invisible for the opponent
			var hidden := e.stealth_t > 0 and e.team == 1 and not sim.is_visible_to(e, 0)
			rig.visible = not hidden
			if e.kind == "hero" and e.has_status("fury") != rig.fury:
				rig.set_fury(e.has_status("fury"))
		_update_bar(e, p)
		_update_status_fx(e, n)
	# camera shake
	if shake > 0:
		shake = maxf(0.0, shake - delta * 2.5)
		var s := shake * Settings.shake_scale()
		camera.position = cam_base + Vector3(randf_range(-s, s), randf_range(-s, s), 0) * 0.35
	else:
		camera.position = cam_base


func _update_bar(e: BattleEnt, p: Vector2) -> void:
	var b: Dictionary = bars.get(e.id, {})
	if b.is_empty():
		return
	var root: Node3D = b.root
	var show: bool = b.always or e.hp < e.max_hp or e.shield > 0
	if e.stealth_t > 0 and e.team == 1 and not sim.is_visible_to(e, 0):
		show = false
	root.visible = show
	if not show:
		return
	root.position = Vector3(p.x, float(b.y), p.y)
	var f := clampf(e.hp_frac(), 0.0, 1.0)
	var fill: MeshInstance3D = b.fill
	fill.scale = Vector3(maxf(0.001, f), 1, 1)
	fill.position.x = -float(b.w) * (1.0 - f) / 2.0
	var sq: MeshInstance3D = b.shield
	sq.visible = e.shield > 0
	if e.shield > 0:
		var sf := clampf(e.shield / e.max_hp, 0.0, 1.0)
		sq.scale = Vector3(maxf(0.001, sf), 1, 1)
		sq.position.x = -float(b.w) * (1.0 - sf) / 2.0


func _update_status_fx(e: BattleEnt, n: Node3D) -> void:
	var key := ""
	for s in ["stun", "root", "burn", "poison", "slow", "timewarp", "buff_dmg", "buff_as", "exhausted"]:
		if e.has_status(s):
			key = s
			break
	var cur: Node3D = status_fx.get(e.id)
	if key == "":
		if cur:
			cur.queue_free()
			status_fx.erase(e.id)
		return
	if cur and cur.get_meta("k") == key:
		cur.rotation.y += 0.05
		return
	if cur:
		cur.queue_free()
	var col: Color = {"stun": Color("#ffd23f"), "root": Color("#8a5c2a"), "burn": Color("#ff6a1f"), "poison": Color("#7bdc3a"), "slow": Color("#7fd8ff"),
		"timewarp": Color("#4aa3ff"), "buff_dmg": Color("#ff3030"), "buff_as": Color("#ffb020"), "exhausted": Color("#ffffff")}[key]
	var fx := Node3D.new()
	fx.set_meta("k", key)
	var ring := MeshKit.part(fx, "torus", [e.radius * 0.9 + 0.05, e.radius * 0.9 + 0.15], MeshKit.unshaded(col, 0.75), Vector3(0, 0.08, 0))
	ring.scale = Vector3(1, 0.3, 1)
	if key in ["stun", "exhausted"]:
		for k in 3:
			MeshKit.part(fx, "sphere", [0.06], MeshKit.unshaded(col), Vector3(cos(k * 2.1) * 0.3, 1.6 if e.kind != "boss" else 4.0, sin(k * 2.1) * 0.3))
	n.add_child(fx)
	status_fx[e.id] = fx


# ------------------------------------------------------------------ events
func _consume(evs: Array) -> void:
	for ev in evs:
		match str(ev.t):
			"spawn":
				var e: BattleEnt = sim.by_id.get(int(ev.id))
				if e:
					_create(e)
			"die":
				_on_die(int(ev.id))
			"attack":
				var a: Node3D = nodes.get(int(ev.id))
				var tgt: Node3D = nodes.get(int(ev.target))
				if a is GoblinRig:
					(a as GoblinRig).play("attack_ranged" if ev.proj else "attack", 0.35)
				if ev.proj and a and tgt:
					_projectile(a, tgt, float(ev.travel), int(ev.id), ev.get("axe", false))
				elif not ev.proj and randf() < 0.35:
					Audio.play_sfx("swing", randf_range(0.9, 1.15), -6)
			"hit":
				_on_hit(int(ev.id), float(ev.amount), str(ev.kind))
			"heal":
				_number(int(ev.id), "+%d" % int(ev.amount), Color("#7bdc3a"))
			"splash":
				_ring(ev.pos, float(ev.radius), DB.family_color(str(ev.family)), 0.3)
			"zone":
				_ring(ev.pos, float(ev.radius), Color(ev.color), 0.6)
				Audio.play_sfx("ice" if str(ev.color) in ["#7fd8ff", "#bfe8ff"] else ("poison" if str(ev.color).begins_with("#7b") or str(ev.color).begins_with("#9b") else "magic"), 1.0, -8)
			"explosion":
				_ring(ev.pos, float(ev.radius), Color(ev.color), 0.45, true)
				_puff(ev.pos, Color(ev.color), 14)
				Audio.play_sfx("explosion", randf_range(0.9, 1.1), -4)
				shake = maxf(shake, 0.4)
			"telegraph":
				_telegraph(ev)
				Audio.play_sfx("telegraph", 1.0, -6)
			"cast":
				var cn: Node3D = nodes.get(int(ev.id))
				if cn is GoblinRig:
					(cn as GoblinRig).play("cast", 0.6)
				var e2: BattleEnt = sim.by_id.get(int(ev.id))
				if e2:
					var col := {"tyrant_strike": Color("#ffd23f"), "iron_skin": Color("#c0c8d0"), "royal_roar": Color("#ff6a3a"), "mutant_fury": Color("#d03fd9"),
						"overcharge": Color("#ffb347"), "raider_call": Color("#c9472b"), "axe_throw": Color("#ffffff")}.get(str(ev.ability), Color.WHITE)
					_ring(e2.pos, 2.6 if ev.ability != "axe_throw" else 0.8, col, 0.5, true)
				Audio.play_sfx("king_roar" if str(ev.ability) in ["royal_roar", "mutant_fury"] else "magic", 1.0 if int(ev.team) == 0 else 0.8)
				if int(ev.team) == 0:
					Settings.vibrate(30)
			"teleport":
				_puff(ev.from, Color("#8a5cff"), 10)
				_puff(ev.to, Color("#8a5cff"), 10)
				Audio.play_sfx("zap", 1.3, -6)
			"structure_destroyed":
				var sn: Node3D = nodes.get(int(ev.id))
				if sn:
					_puff(Vector2(sn.position.x, sn.position.z), Color("#8a7a6a"), 30)
				shake = 1.0
				Audio.play_sfx("tower_destroyed")
				Settings.vibrate(120)
			"deploy":
				Audio.play_sfx("deploy", randf_range(0.95, 1.1), -3)
			"armor_broken":
				_number(int(ev.id), tr("FX_ARMOR_BROKEN"), Color("#ffd23f"), 1.6)
				Audio.play_sfx("hit_heavy")
				shake = 0.8
			"exhausted":
				_number(int(ev.id), tr("FX_EXHAUSTED"), Color("#ffffff"), 1.3)
			"phase":
				var pe: BattleEnt = sim.by_id.get(int(ev.id))
				if pe and pe.kind == "boss":
					_ring(pe.pos, 4.0, Color("#ff3030"), 0.8, true)
					shake = 0.8
					Audio.play_sfx("king_roar", 0.6)
			"summon":
				var se: BattleEnt = sim.by_id.get(int(ev.id))
				if se:
					_puff(se.pos, Color("#c9472b"), 8)
			"stealth":
				var st: Node3D = nodes.get(int(ev.id))
				if st:
					_puff(Vector2(st.position.x, st.position.z), Color("#2a1a3a"), 6)
			"text":
				_number_at(ev.pos, str(ev.text), Color("#ffd23f"))
			"wave":
				Audio.play_sfx("telegraph", 0.8)
			"hero_respawn":
				Audio.play_sfx("king_roar", 1.0, -4)


func _on_die(id: int) -> void:
	var n: Node3D = nodes.get(id)
	nodes.erase(id)
	if bars.has(id):
		bars[id].root.queue_free()
		bars.erase(id)
	if status_fx.has(id):
		status_fx.erase(id)
	if n == null:
		return
	if n is GoblinRig:
		(n as GoblinRig).play("die", 0.6)
		Audio.play_sfx("goblin_hurt", randf_range(0.8, 1.3), -6)
		var tw := n.create_tween()
		tw.tween_interval(0.8)
		tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.35)
		tw.tween_callback(n.queue_free)
	else:
		var tw2 := n.create_tween()
		tw2.tween_property(n, "position:y", -2.5, 0.8).set_ease(Tween.EASE_IN)
		tw2.tween_callback(n.queue_free)


func _on_hit(id: int, amount: float, kind: String) -> void:
	var n: Node3D = nodes.get(id)
	if n == null:
		return
	if n is GoblinRig and kind != "dot" and randf() < 0.5:
		(n as GoblinRig).play("hit", 0.18)
	if kind != "dot" and randf() < 0.4:
		Audio.play_sfx("hit", randf_range(0.85, 1.2), -8)
	if amount >= 1.0 and Settings.get_v("damage_numbers") and (kind != "dot" or randf() < 0.1):
		var col := Color("#ffffff") if kind == "attack" else (Color("#ffb347") if kind == "ability" else (Color("#c0c0c0") if kind == "armor" else Color("#ffdd88")))
		_number(id, str(int(amount)), col)


func _number(id: int, text: String, col: Color, size := 1.0) -> void:
	var n: Node3D = nodes.get(id)
	if n == null:
		return
	_number_at(Vector2(n.position.x, n.position.z), text, col, size, n.position.y + float(bars.get(id, {}).get("y", 1.6)))


func _number_at(p: Vector2, text: String, col: Color, size := 1.0, y := 2.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font = UI.font("display")
	l.font_size = int(54 * size)
	l.pixel_size = 0.01
	l.modulate = col
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.position = Vector3(p.x + randf_range(-0.2, 0.2), y, p.y)
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", y + 1.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _projectile(a: Node3D, tgt: Node3D, travel: float, src_id: int, axe := false) -> void:
	var e: BattleEnt = sim.by_id.get(src_id)
	var col := Color("#ffe0a0")
	if e:
		col = DB.family_color(e.family) if e.family != "" else Color("#ffe0a0")
		if e.kind == "structure":
			col = Color("#d0c0a0")
	var p := MeshKit.part(self, "sphere" if not axe else "box", [0.11, 0.3, 0.05] if not axe else [0.3, 0.3, 0.05], MeshKit.mat(col, 0, 0.3, col, 2.0))
	var from := a.position + Vector3(0, 1.0, 0)
	if e and e.kind == "structure":
		from = a.position + Vector3(0, 3.2, 0)
	p.position = from
	var to := tgt.position + Vector3(0, 0.8, 0)
	var arc := 0.6 + from.distance_to(to) * 0.08
	var fly := func(k: float) -> void:
		if not is_instance_valid(tgt):
			return
		var tt := tgt.position + Vector3(0, 0.8, 0)
		p.position = from.lerp(tt, k) + Vector3(0, sin(k * PI) * arc, 0)
		if axe:
			p.rotation.z = k * 20.0
	var tw := p.create_tween()
	tw.tween_method(fly, 0.0, 1.0, maxf(0.05, travel / speed))
	tw.tween_callback(p.queue_free)


func _ring(pos: Vector2, r: float, col: Color, dur: float, fill := false) -> void:
	var a := 0.55 * Settings.flash_scale() + 0.15
	var m := MeshKit.part(self, "disc" if fill else "torus", [r] if fill else [r * 0.8, r], MeshKit.unshaded(col, a).duplicate(), Vector3(pos.x, 0.1, pos.y))
	if not fill:
		m.scale = Vector3(0.3, 0.2, 0.3)
	else:
		m.scale = Vector3(0.3, 1, 0.3)
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(1, 0.2 if not fill else 1.0, 1), dur * 0.6)
	tw.tween_property(m.material_override, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(m.queue_free)


func _telegraph(ev: Dictionary) -> void:
	var delay := float(ev.delay)
	var col := Color("#ff2020")
	var root := Node3D.new()
	add_child(root)
	if str(ev.shape) == "line":
		var from: Vector2 = ev.from
		var to: Vector2 = ev.to
		var mid := (from + to) / 2.0
		var length := from.distance_to(to)
		root.position = Vector3(mid.x, 0.09, mid.y)
		root.rotation.y = -atan2(to.y - from.y, to.x - from.x)
		MeshKit.part(root, "box", [length, 0.02, float(ev.width)], MeshKit.unshaded(col, 0.3))
		var fillb := MeshKit.part(root, "box", [length, 0.03, float(ev.width)], MeshKit.unshaded(col, 0.5).duplicate())
		fillb.scale = Vector3(0.01, 1, 1)
		fillb.create_tween().tween_property(fillb, "scale:x", 1.0, delay)
	else:
		var p: Vector2 = ev.pos
		root.position = Vector3(p.x, 0.09, p.y)
		var r := float(ev.radius)
		MeshKit.part(root, "torus", [r * 0.93, r], MeshKit.unshaded(col, 0.9))
		var fill := MeshKit.part(root, "disc", [r], MeshKit.unshaded(col, 0.35).duplicate())
		fill.scale = Vector3(0.05, 1, 0.05)
		fill.create_tween().tween_property(fill, "scale", Vector3.ONE, delay)
	var tw := root.create_tween()
	tw.tween_interval(delay + 0.05)
	tw.tween_callback(root.queue_free)


func _puff(p: Vector2, col: Color, n: int) -> void:
	var amount := Settings.particle_amount(n)
	if amount <= 0:
		return
	var ps := CPUParticles3D.new()
	ps.amount = amount
	ps.one_shot = true
	ps.explosiveness = 0.9
	ps.lifetime = 0.7
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ps.emission_sphere_radius = 0.4
	ps.direction = Vector3.UP
	ps.spread = 70
	ps.initial_velocity_min = 1.5
	ps.initial_velocity_max = 3.5
	ps.gravity = Vector3(0, -4, 0)
	ps.scale_amount_min = 0.08
	ps.scale_amount_max = 0.16
	ps.mesh = MeshKit.mesh("sphere", 0.5)
	ps.material_override = MeshKit.unshaded(col, 0.85)
	ps.position = Vector3(p.x, 0.5, p.y)
	add_child(ps)
	ps.emitting = true
	get_tree().create_timer(1.2).timeout.connect(ps.queue_free)
