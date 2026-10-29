class_name GoblinRig
extends Node3D
## Procedural goblin character (units, the King Gobelin, bosses) with a code-driven rig:
## idle / walk / attack / hit / cast / death / victory and emotes. Equipment meshes are
## attached to sockets (head, eyes, torso, shoulders, hands, back, belt, legs, feet).

const SKIN_DEFAULT := Color("#7ea83e")

var params := {}
var body: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var back: Node3D
var weapon: Node3D
var wings: Array = []
var aura: Node3D
var eye_mats: Array = []
var skin_mat: StandardMaterial3D

var moving := false
var move_speed := 1.0
var anim := ""
var anim_t := 0.0
var anim_len := 0.0
var t := 0.0
var dead := false
var base_scale := 1.0
var detail := 2           # 0 low, 1 medium, 2 high
var idle_variant := 0
var fury := false


# ------------------------------------------------------------------ build
func build(p: Dictionary) -> GoblinRig:
	params = p
	detail = int(p.get("detail", Settings.effective_quality()))
	base_scale = float(p.get("scale", 1.0))
	idle_variant = randi() % 3
	t = randf() * 10.0
	var look: Dictionary = p.get("look", {})
	var acc: Array = look.get("acc", [])
	if "wolf_body" in acc:
		_build_wolf(p)
		scale = Vector3.ONE * base_scale
		return self
	if "bird_body" in acc:
		_build_bird(p)
		scale = Vector3.ONE * base_scale
		return self
	var app: Dictionary = p.get("appearance", {})
	var opts: Dictionary = DB.king.get("appearance", {})
	var skin := Color(p.get("skin", SKIN_DEFAULT))
	if app.has("skin"):
		skin = Color(opts.skin[int(app.skin)])
	# Painted olive tones: tame the saturation so goblins read as earthy, not neon.
	skin = Color.from_hsv(skin.h, skin.s * 0.82, skin.v * 0.84)
	var fam_col := Color(p.get("color", "#8a6a40"))
	var bulk: float = float(opts.bulk[int(app.bulk)]) if app.has("bulk") else float(p.get("bulk", 1.0))
	var height_m: float = float(opts.height[int(app.height)]) if app.has("height") else 1.0
	var muscle := 1.0 + 0.15 * int(app.get("muscle", 1))
	var mut: Array = app.get("mutation_visuals", [])
	if "big_arms" in mut:
		muscle *= 1.3
	skin_mat = MeshKit.mat(skin, 0.0, 0.7)
	var cloth := MeshKit.mat(fam_col, 0.0, 0.8)
	var dark := MeshKit.mat(fam_col.darkened(0.55).lerp(Color("#5a3a24"), 0.5), 0.0, 0.85)

	body = MeshKit.pivot(self, Vector3.ZERO, "Body")
	body.scale = Vector3(bulk, height_m, bulk)
	# Legs
	leg_l = MeshKit.pivot(body, Vector3(-0.11, 0.38, 0), "LegL")
	leg_r = MeshKit.pivot(body, Vector3(0.11, 0.38, 0), "LegR")
	for lg in [leg_l, leg_r]:
		MeshKit.part(lg, "capsule", [0.085, 0.34], dark, Vector3(0, -0.16, 0))
		MeshKit.part(lg, "sphere", [0.1], MeshKit.mat(Color("#7a4a2a")), Vector3(0, -0.34, 0.05), Vector3.ZERO, Vector3(0.95, 0.6, 1.35))
	# Torso
	torso = MeshKit.pivot(body, Vector3(0, 0.38, 0), "Torso")
	MeshKit.part(torso, "capsule", [0.2, 0.52], skin_mat, Vector3(0, 0.24, 0), Vector3.ZERO, Vector3(1, 1, 0.85), true)
	MeshKit.part(torso, "sphere", [0.19], skin_mat, Vector3(0, 0.15, 0.06), Vector3.ZERO, Vector3(1, 0.9, 0.9))
	# Default clothing (tunic + belt) for units; the King gets his torso item instead.
	if not p.get("is_king", false):
		MeshKit.part(torso, "cyl", [0.215, 0.26, 0.24], cloth, Vector3(0, 0.12, 0))
		MeshKit.part(torso, "cyl", [0.228, 0.06], MeshKit.mat(Color("#6b3f1f")), Vector3(0, 0.02, 0))
		MeshKit.part(torso, "box", [0.07, 0.06, 0.03], MeshKit.mat(Color("#ffd23f"), 0.8), Vector3(0, 0.02, 0.23))
	back = MeshKit.pivot(torso, Vector3(0, 0.3, -0.17), "Back")
	# Arms
	arm_l = MeshKit.pivot(torso, Vector3(-0.25, 0.43, 0), "ArmL")
	arm_r = MeshKit.pivot(torso, Vector3(0.25, 0.43, 0), "ArmR")
	for ar in [arm_l, arm_r]:
		MeshKit.part(ar, "sphere", [0.08 * muscle], skin_mat)
		MeshKit.part(ar, "capsule", [0.058 * muscle, 0.36], skin_mat, Vector3(0, -0.16, 0))
		var hand := MeshKit.pivot(ar, Vector3(0, -0.34, 0.02), "HandL" if ar == arm_l else "HandR")
		MeshKit.part(hand, "sphere", [0.085 * muscle], skin_mat)
		if ar == arm_l:
			hand_l = hand
		else:
			hand_r = hand
	arm_l.rotation_degrees = Vector3(0, 0, -12)
	arm_r.rotation_degrees = Vector3(0, 0, 12)
	# Head
	head = MeshKit.pivot(torso, Vector3(0, 0.54, 0.02), "Head")
	head.scale = Vector3.ONE * 1.22  # big expressive cartoon head
	_build_head(head, app, skin, fam_col, p)
	# Equipment / accessories
	if p.get("is_king", false):
		_apply_equipment(p.get("visuals", {}))
	else:
		var w := str(look.get("weapon", "none"))
		weapon = Equipment.weapon(hand_r, w, fam_col, 0.6 if w in ["sword", "axe", "hammer_big", "saw", "piston", "halberd", "axe_big", "dual_axe", "spear", "scythe"] else 0.0, Color(0, 0, 0, 0))
		if w == "shield":
			Equipment.weapon(hand_l, "shield_round", fam_col, 0.5, Color(0, 0, 0, 0))
			weapon = Equipment.weapon(hand_r, "sword", Color("#9aa0a8"), 0.8, Color(0, 0, 0, 0))
		if w in ["dual_dagger", "dual_axe", "claws"]:
			Equipment.weapon(hand_l, w.replace("dual_", ""), fam_col, 0.6, Color(0, 0, 0, 0))
		for a in acc:
			Equipment.accessory(self, a, fam_col)
	for mv in mut:
		Equipment.mutation(self, str(mv))
	apply_outlines()
	scale = Vector3.ONE * base_scale
	return self


## Cartoon contour on every part big enough to read (skips pupils, teeth, tiny details).
func apply_outlines() -> void:
	if not MeshKit.outlines_enabled() or params.get("no_outline", false):
		return
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.has_meta("team_ring"):
			continue
		var sz := mi.mesh.get_aabb().size * mi.scale
		if maxf(sz.x, maxf(sz.y, sz.z)) < 0.07:
			continue
		mi.material_override = MeshKit.outlined(mi.material_override)


func _build_head(h: Node3D, app: Dictionary, skin: Color, fam_col: Color, p: Dictionary) -> void:
	var opts: Dictionary = DB.king.get("appearance", {})
	var face := int(app.get("face_shape", p.get("face", 0)))
	var head_scale: Vector3 = [Vector3(1, 0.95, 1), Vector3(0.9, 1.0, 1.0), Vector3(0.88, 1.12, 0.95), Vector3(1.05, 0.92, 1.0)][face % 4]
	MeshKit.part(h, "sphere", [0.21], skin_mat, Vector3(0, 0.17, 0), Vector3.ZERO, head_scale, true)
	# Brow ridge gives the goblin a mean look
	var expr := int(app.get("expression", 2 if p.get("angry", true) else 0))
	var brow_rot: float = [0.0, 8.0, 18.0, -6.0][expr % 4]
	var brow_mat := MeshKit.mat(skin.darkened(0.55), 0.0, 0.85)
	MeshKit.part(h, "box", [0.11, 0.035, 0.05], brow_mat, Vector3(-0.08, 0.27, 0.17), Vector3(0, 0, -brow_rot))
	MeshKit.part(h, "box", [0.11, 0.035, 0.05], brow_mat, Vector3(0.08, 0.27, 0.17), Vector3(0, 0, brow_rot))
	# Eyes
	var eye_col := Color(opts.eye_color[int(app.eye_color)]) if app.has("eye_color") else Color(p.get("eye_color", "#ffd23f"))
	var eye_shape := int(app.get("eyes", 0))
	var eye_scale: Vector3 = [Vector3.ONE, Vector3(1.1, 0.55, 1), Vector3(1.3, 1.3, 1.1), Vector3(1, 1, 1)][eye_shape % 4]
	var glow: bool = "glow_eyes" in app.get("mutation_visuals", []) or p.get("glow_eyes", false)
	var em := MeshKit.mat(eye_col, 0.0, 0.3, eye_col if glow else Color(0, 0, 0, 0), 2.5)
	if p.get("is_king", false):
		em = em.duplicate()  # the King's eyes can be changed by equipment without touching shared materials
	eye_mats.append(em)
	for sx in [-1, 1]:
		# Big cartoon eyes: white, coloured iris, black pupil and a highlight
		MeshKit.part(h, "sphere", [0.062], MeshKit.mat(Color("#ffffff"), 0, 0.3), Vector3(0.08 * sx, 0.2, 0.15), Vector3.ZERO, eye_scale)
		var pupil_scale := Vector3(0.45, 1.0, 1.0) if eye_shape == 3 else Vector3.ONE
		MeshKit.part(h, "sphere", [0.036], em, Vector3(0.082 * sx, 0.2, 0.193), Vector3.ZERO, pupil_scale * Vector3(1, 1, 0.6))
		MeshKit.part(h, "sphere", [0.019], MeshKit.mat(Color("#101018"), 0, 0.2), Vector3(0.083 * sx, 0.2, 0.213), Vector3.ZERO, pupil_scale * Vector3(1, 1, 0.5))
		MeshKit.part(h, "sphere", [0.009], MeshKit.unshaded(Color.WHITE), Vector3(0.09 * sx, 0.212, 0.222))
	# Ears
	var ears := int(app.get("ears", p.get("ears", 0)))
	var ear_len: float = [0.3, 0.26, 0.42, 0.22, 0.3][ears % 5]
	var ear_rot: Vector3 = [Vector3(0, 0, 78), Vector3(0, 0, 125), Vector3(0, 0, 82), Vector3(0, 0, 70), Vector3(25, 0, 60)][ears % 5]
	for sx in [-1, 1]:
		var ear := MeshKit.part(h, "cone", [0.07, ear_len], skin_mat, Vector3(0.2 * sx, 0.2, -0.02), Vector3(ear_rot.x, 0, -ear_rot.z * sx), Vector3(1, 1, 0.45))
		ear.position += Vector3(ear_len * 0.4 * sx, 0, 0)
		if ears == 4:
			MeshKit.part(h, "cone", [0.05, ear_len * 0.7], skin_mat, Vector3(0.28 * sx, 0.3, -0.04), Vector3(0, 0, -40 * sx), Vector3(1, 1, 0.4))
	# Nose
	var nose := int(app.get("nose", 0))
	match nose % 4:
		0: MeshKit.part(h, "cone", [0.045, 0.16], skin_mat, Vector3(0, 0.13, 0.24), Vector3(110, 0, 0))
		1: MeshKit.part(h, "sphere", [0.05], skin_mat, Vector3(0, 0.13, 0.21), Vector3.ZERO, Vector3(1.4, 0.7, 0.8))
		2: MeshKit.part(h, "cone", [0.04, 0.24], skin_mat, Vector3(0, 0.15, 0.28), Vector3(95, 0, 0))
		3: MeshKit.part(h, "sphere", [0.07], skin_mat, Vector3(0, 0.12, 0.22))
	# Jaw / mouth
	var jaw := int(app.get("jaw", 1))
	var jaw_w: float = [0.16, 0.24, 0.2, 0.3][jaw % 4]
	var jaw_z: float = [0.14, 0.13, 0.19, 0.15][jaw % 4]
	MeshKit.part(h, "box", [jaw_w, 0.07, 0.14], skin_mat, Vector3(0, 0.04, jaw_z), Vector3(10, 0, 0))
	var mouth_open := 0.03 if expr == 3 else 0.015
	MeshKit.part(h, "box", [jaw_w * 0.8, mouth_open, 0.02], MeshKit.mat(Color("#2a0a08")), Vector3(0, 0.075, jaw_z + 0.065))
	if detail > 0:
		var teeth := int(app.get("teeth", 0))
		var tooth_mat := MeshKit.mat(Color("#ffd23f") if teeth == 3 else Color("#f4ecd0"), 0.9 if teeth == 3 else 0.0, 0.4)
		var n := 4 if teeth != 2 else 2
		for i in n:
			var tx := (i - (n - 1) / 2.0) * jaw_w * 0.2
			if teeth == 1:
				MeshKit.part(h, "cone", [0.012, 0.035], tooth_mat, Vector3(tx, 0.06, jaw_z + 0.07), Vector3(180, 0, 0))
			else:
				MeshKit.part(h, "box", [0.022, 0.025, 0.01], tooth_mat, Vector3(tx, 0.065, jaw_z + 0.072))
	var tusks := int(app.get("tusks", p.get("tusks", 1)))
	if "big_tusks" in app.get("mutation_visuals", []):
		tusks = 2
	if tusks > 0:
		var tl: float = [0.0, 0.07, 0.13, 0.11][tusks % 4]
		for sx in [-1, 1]:
			MeshKit.part(h, "cone", [0.025, tl], MeshKit.mat(Color("#f0e6c8"), 0, 0.5), Vector3(jaw_w * 0.42 * sx, 0.1 + tl * 0.3, jaw_z + 0.05), Vector3(-15 if tusks != 3 else -40, 0, 15 * sx))
	# Scars and war paint
	var scars := int(app.get("scars", 0))
	if scars > 0 and detail > 0:
		var sm := MeshKit.mat(skin.darkened(0.45), 0, 0.9)
		if scars in [1, 3, 4]:
			MeshKit.part(h, "box", [0.012, 0.11, 0.01], sm, Vector3(0.12, 0.13, 0.17), Vector3(0, 30, 25))
		if scars in [2, 3, 4]:
			MeshKit.part(h, "box", [0.012, 0.14, 0.01], sm, Vector3(-0.075, 0.2, 0.2), Vector3(0, 0, -20))
		if scars == 4:
			MeshKit.part(h, "box", [0.1, 0.012, 0.01], sm, Vector3(0, 0.3, 0.16), Vector3(-30, 0, 0))
	var paint := int(app.get("paint", 0))
	if paint > 0 and detail > 0:
		var pc := Color(opts.paint_color[int(app.get("paint_color", 0))]) if opts.has("paint_color") else Color.RED
		var pm := MeshKit.mat(pc, 0, 0.7)
		match paint:
			1:
				for sx in [-1, 1]:
					for k in 2:
						MeshKit.part(h, "box", [0.07, 0.014, 0.012], pm, Vector3(0.1 * sx, 0.12 + k * 0.035, 0.18), Vector3(0, 25 * sx, 0))
			2:
				MeshKit.part(h, "box", [0.18, 0.08, 0.012], MeshKit.mat(Color("#f0f0f0")), Vector3(0, 0.24, 0.19), Vector3(-20, 0, 0))
			3:
				MeshKit.part(h, "box", [0.02, 0.12, 0.012], pm, Vector3(0.07, 0.18, 0.2), Vector3(0, 0, 25))
				MeshKit.part(h, "box", [0.02, 0.1, 0.012], pm, Vector3(0.1, 0.11, 0.19), Vector3(0, 0, -25))
			4:
				for k in 5:
					MeshKit.part(h, "sphere", [0.012], pm, Vector3(-0.1 + k * 0.05, 0.31, 0.15))
			5, 6, 7:
				# Mille Visages: glowing ritual patterns
				var mc: Color = [Color("#d03fd9"), Color("#3ff0e0"), Color("#ffd23f")][paint - 5]
				var gm := MeshKit.mat(mc, 0, 0.3, mc, 2.0)
				MeshKit.part(h, "box", [0.24, 0.02, 0.012], gm, Vector3(0, 0.27, 0.19), Vector3(-15, 0, 0))
				for sx in [-1, 1]:
					MeshKit.part(h, "box", [0.015, 0.14, 0.012], gm, Vector3(0.075 * sx, 0.15, 0.2), Vector3(0, 0, 10 * sx))
					if paint >= 6:
						MeshKit.part(h, "sphere", [0.02], gm, Vector3(0.14 * sx, 0.22, 0.15))
				if paint == 7:
					MeshKit.part(h, "prism", [0.06, 0.06, 0.012], gm, Vector3(0, 0.33, 0.17), Vector3(-20, 0, 0))
	# Horns / crest / hair
	var horns := int(app.get("horns", 0))
	var horn_mat := MeshKit.mat(Color("#d8c8a8"), 0, 0.6)
	match horns:
		1:
			for sx in [-1, 1]:
				MeshKit.part(h, "cone", [0.035, 0.1], horn_mat, Vector3(0.09 * sx, 0.36, 0.02), Vector3(0, 0, -20 * sx))
		2:
			for sx in [-1, 1]:
				MeshKit.part(h, "torus", [0.05, 0.085], horn_mat, Vector3(0.17 * sx, 0.28, -0.02), Vector3(0, 90, 0), Vector3(1, 1, 1.2))
		3:
			for sx in [-1, 1]:
				MeshKit.part(h, "cone", [0.045, 0.28], MeshKit.mat(Color("#2a1a1a"), 0.2, 0.4), Vector3(0.11 * sx, 0.45, -0.02), Vector3(-10, 0, -15 * sx))
	var hair_col := Color(opts.hair_color[int(app.get("hair_color", 0))]) if opts.has("hair_color") else Color("#1a1410")
	var hair_mat := MeshKit.mat(hair_col, 0, 0.95)
	var crest := int(app.get("crest", 0))
	match crest:
		1:
			for k in 5:
				MeshKit.part(h, "box", [0.035, 0.1, 0.06], hair_mat, Vector3(0, 0.38 - abs(k - 2) * 0.02, 0.1 - k * 0.06))
		2:
			for k in 4:
				MeshKit.part(h, "cone", [0.03, 0.12], horn_mat, Vector3(0, 0.38, 0.08 - k * 0.07), Vector3(-20, 0, 0))
		3:
			for k in 3:
				MeshKit.part(h, "cone", [0.03, 0.2], MeshKit.mat(Color("#c9472b")), Vector3(-0.04 + k * 0.04, 0.42, -0.08), Vector3(-30, 0, (k - 1) * 15))
	var hair := int(app.get("hair", 0))
	match hair:
		1:
			for k in 3:
				MeshKit.part(h, "capsule", [0.015, 0.14], hair_mat, Vector3(-0.05 + k * 0.05, 0.36, 0.02), Vector3(0, 0, (k - 1) * 25))
		2:
			MeshKit.part(h, "capsule", [0.035, 0.32], hair_mat, Vector3(0, 0.12, -0.24), Vector3(25, 0, 0))
		3:
			MeshKit.part(h, "sphere", [0.2], hair_mat, Vector3(0, 0.24, -0.08), Vector3.ZERO, Vector3(1.15, 0.9, 1.0))


func _apply_equipment(vis: Dictionary) -> void:
	for slot in vis.keys():
		var v: Dictionary = vis[slot]
		var col := Color(v.get("color", "#888888"))
		var metal := float(v.get("metal", 0.0))
		var emit := Color(v.emit) if v.has("emit") else Color(0, 0, 0, 0)
		var m: String = str(v.get("mesh", ""))
		match slot:
			"right_arm":
				weapon = Equipment.weapon(hand_r, m, col, metal, emit)
				if m in ["dual_dagger", "claws"]:
					Equipment.weapon(hand_l, m.replace("dual_", ""), col, metal, emit)
			"left_arm":
				Equipment.weapon(hand_l, m, col, metal, emit)
			"aura":
				aura = Equipment.aura(self, col)
			_:
				Equipment.slot_item(self, slot, m, col, metal, emit)
	# Without torso item, show a simple loincloth
	if not vis.has("torso"):
		MeshKit.part(torso, "cyl", [0.215, 0.12, 0.23], MeshKit.mat(Color("#5a4630")), Vector3(0, 0.04, 0))


func _build_wolf(p: Dictionary) -> void:
	var fur := MeshKit.mat(Color("#5a4a3a"), 0, 0.95)
	body = MeshKit.pivot(self, Vector3.ZERO, "Body")
	torso = MeshKit.pivot(body, Vector3(0, 0.45, 0), "Torso")
	MeshKit.part(torso, "capsule", [0.18, 0.75], fur, Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, true)
	head = MeshKit.pivot(torso, Vector3(0, 0.12, 0.42), "Head")
	MeshKit.part(head, "sphere", [0.15], fur)
	MeshKit.part(head, "cone", [0.08, 0.2], fur, Vector3(0, -0.03, 0.15), Vector3(90, 0, 0))
	for sx in [-1, 1]:
		MeshKit.part(head, "cone", [0.05, 0.12], fur, Vector3(0.08 * sx, 0.14, -0.02))
		MeshKit.part(head, "sphere", [0.025], MeshKit.mat(Color("#ffd23f"), 0, 0.3, Color("#ffd23f"), 1.5), Vector3(0.06 * sx, 0.04, 0.12))
	leg_l = MeshKit.pivot(torso, Vector3(-0.1, -0.05, 0.25), "LegL")
	leg_r = MeshKit.pivot(torso, Vector3(0.1, -0.05, -0.25), "LegR")
	arm_l = MeshKit.pivot(torso, Vector3(0.1, -0.05, 0.25), "ArmL")
	arm_r = MeshKit.pivot(torso, Vector3(-0.1, -0.05, -0.25), "ArmR")
	for lg in [leg_l, leg_r, arm_l, arm_r]:
		MeshKit.part(lg, "capsule", [0.05, 0.38], fur, Vector3(0, -0.2, 0))
	back = MeshKit.pivot(torso, Vector3(0, 0.15, -0.2), "Back")


func _build_bird(p: Dictionary) -> void:
	var fe := MeshKit.mat(Color("#8a6a4a"), 0, 0.9)
	body = MeshKit.pivot(self, Vector3.ZERO, "Body")
	torso = MeshKit.pivot(body, Vector3(0, 0.3, 0), "Torso")
	MeshKit.part(torso, "sphere", [0.16], fe, Vector3.ZERO, Vector3.ZERO, Vector3(0.9, 0.9, 1.4))
	head = MeshKit.pivot(torso, Vector3(0, 0.08, 0.2), "Head")
	MeshKit.part(head, "sphere", [0.09], MeshKit.mat(Color("#f0e6d0")))
	MeshKit.part(head, "cone", [0.03, 0.08], MeshKit.mat(Color("#ffb020")), Vector3(0, -0.01, 0.1), Vector3(90, 0, 0))
	for sx in [-1, 1]:
		var w := MeshKit.pivot(torso, Vector3(0.12 * sx, 0.04, 0), "Wing%d" % (sx + 1))
		MeshKit.part(w, "box", [0.45, 0.02, 0.2], fe, Vector3(0.22 * sx, 0, 0))
		wings.append(w)
	back = torso


# ------------------------------------------------------------------ animation API
func set_moving(m: bool, spd := 1.0) -> void:
	moving = m
	move_speed = spd


func play(a: String, length := 0.4) -> void:
	if dead and a != "die":
		return
	if Settings.get_v("limit_animations") and a in ["victory", "laugh", "spin_weapon"]:
		length *= 0.5
	anim = a
	anim_t = 0.0
	anim_len = length
	if a == "die":
		dead = true


func face(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 0.35)


func set_fury(on: bool) -> void:
	fury = on
	var s := base_scale * (1.3 if on else 1.0)
	create_tween().tween_property(self, "scale", Vector3.ONE * s, 0.3)


func _process(delta: float) -> void:
	t += delta
	if body == null:
		return
	var walk := 0.0
	if moving and not dead:
		walk = sin(t * 9.0 * clampf(move_speed, 0.6, 2.0))
	# Base pose
	body.position.y = absf(walk) * 0.05 + sin(t * 2.2) * 0.008
	if leg_l:
		leg_l.rotation.x = walk * 0.6
		leg_r.rotation.x = -walk * 0.6
	if arm_l:
		arm_l.rotation.x = -walk * 0.5
		arm_r.rotation.x = walk * 0.4 - 0.15
		arm_l.rotation.z = deg_to_rad(-12)
		arm_r.rotation.z = deg_to_rad(12)
	if head:
		head.rotation = Vector3(sin(t * 1.3) * 0.04, sin(t * 0.7 + idle_variant) * 0.12 if not moving else 0.0, 0)
	if torso:
		torso.rotation = Vector3(0.12 if moving else 0.0, 0, 0)
	for w in wings:
		w.rotation.z = sin(t * 14.0) * 0.6 * (1 if w.position.x > 0 else -1)
	if aura:
		aura.rotation.y += delta * 1.5
	if anim == "":
		return
	anim_t += delta
	var k := clampf(anim_t / maxf(0.01, anim_len), 0.0, 1.0)
	match anim:
		"attack":
			# Wind-up then strike
			var swing := sin(k * PI)
			arm_r.rotation.x = -2.4 * swing + 0.6 * k
			torso.rotation.y = -0.4 * swing
		"attack_ranged":
			arm_r.rotation.x = -1.4 * sin(k * PI)
			arm_l.rotation.x = -1.2 * sin(k * PI)
		"cast":
			arm_l.rotation.x = -2.6 * sin(k * PI)
			arm_r.rotation.x = -2.6 * sin(k * PI)
			head.rotation.x = -0.3 * sin(k * PI)
		"hit":
			torso.rotation.x = -0.35 * sin(k * PI)
		"die":
			body.rotation.x = -k * 1.5
			body.position.y = -k * 0.3
			if k >= 1.0:
				return
		"victory", "jump":
			body.position.y = absf(sin(anim_t * 7.0)) * 0.35
			arm_l.rotation.z = -2.6
			arm_r.rotation.z = 2.6
		"laugh":
			torso.rotation.x = -0.15 + sin(anim_t * 22.0) * 0.08
			head.rotation.x = -0.35
			body.position.y = absf(sin(anim_t * 18.0)) * 0.04
		"smash":
			var up := k < 0.6
			arm_l.rotation.x = -2.8 if up else -0.4
			arm_r.rotation.x = -2.8 if up else -0.4
			body.position.y = 0.15 * sin(k / 0.6 * PI) if up else 0.0
		"cross_arms":
			arm_l.rotation = Vector3(-1.4, 0.9, -0.3)
			arm_r.rotation = Vector3(-1.4, -0.9, 0.3)
		"spin_weapon":
			arm_r.rotation.x = -1.6
			if weapon:
				weapon.rotation.y = anim_t * 14.0
		"roar":
			head.rotation.x = -0.5
			arm_l.rotation.z = -1.4
			arm_r.rotation.z = 1.4
			torso.rotation.x = -0.2
		"flex":
			arm_l.rotation = Vector3(0, 0, -2.0)
			arm_r.rotation = Vector3(0, 0, 2.0)
			body.scale = Vector3.ONE * (1.0 + 0.05 * sin(anim_t * 10.0))
		"taunt", "shrug":
			torso.rotation.x = 0.35 * sin(k * PI)
			arm_l.rotation.z = -1.2 * sin(k * PI)
			arm_r.rotation.z = 1.2 * sin(k * PI)
		"look":
			head.rotation.y = sin(k * TAU) * 0.8
		"throne":
			body.position.y = -0.12
			leg_l.rotation.x = -1.4
			leg_r.rotation.x = -1.4
			arm_l.rotation.z = -0.6
			arm_r.rotation.z = 0.6
	if anim_t >= anim_len and not anim in ["die"]:
		anim = ""
		if weapon:
			weapon.rotation.y = 0
		body.scale = Vector3.ONE


# ------------------------------------------------------------------ batching / cloning
## Merges the static mesh parts of every pivot into one mesh per material (fewer nodes and
## draw calls). Pivots stay separate so the procedural animation still works.
func merge_static() -> void:
	_merge_node(self)


func _merge_node(n: Node) -> void:
	var groups := {}
	for c in n.get_children():
		if c is MeshInstance3D and c.mesh is PrimitiveMesh and not c.has_meta("team_ring"):
			var key: Material = c.material_override
			if not groups.has(key):
				groups[key] = []
			groups[key].append(c)
		elif c is Node3D:
			_merge_node(c)
	var total := 0
	for k in groups.keys():
		total += groups[k].size()
	if total < 2:
		return
	var am := ArrayMesh.new()
	var shadow := false
	for mat in groups.keys():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi in groups[mat]:
			st.append_from(mi.mesh, 0, mi.transform)
			shadow = shadow or mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, mat)
		for mi in groups[mat]:
			n.remove_child(mi)
			mi.free()
	var merged := MeshInstance3D.new()
	merged.name = "Merged"
	merged.mesh = am
	merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(merged)


## Fast copy of a built rig (meshes are shared). Used to spawn many identical units.
func clone() -> GoblinRig:
	var c: GoblinRig = duplicate()
	c.params = params
	c.base_scale = base_scale
	c.detail = detail
	c.idle_variant = randi() % 3
	c.t = randf() * 10.0
	c.rebind()
	return c


func rebind() -> void:
	body = find_child("Body", true, false)
	torso = find_child("Torso", true, false)
	head = find_child("Head", true, false)
	back = find_child("Back", true, false)
	leg_l = find_child("LegL", true, false)
	leg_r = find_child("LegR", true, false)
	arm_l = find_child("ArmL", true, false)
	arm_r = find_child("ArmR", true, false)
	hand_l = find_child("HandL", true, false)
	hand_r = find_child("HandR", true, false)
	weapon = find_child("Weapon", true, false)
	aura = find_child("Aura", true, false)
	wings = []
	for w in find_children("Wing*", "Node3D", true, false):
		wings.append(w)


static func card_params(cid: String) -> Dictionary:
	## Builds rig parameters for a card or token id.
	var d: Dictionary = DB.unit_def(cid)
	var look: Dictionary = d.get("look", {})
	var fam_col := DB.family_color(str(d.get("family", "")))
	var skin := Color("#7ea83e")
	match str(d.get("family", "")):
		"fire": skin = Color("#9aa83a")
		"ice": skin = Color("#6fb3a0")
		"toxic": skin = Color("#8cbf3a")
		"mech": skin = Color("#8aa04e")
		"shadow": skin = Color("#5f8a68")
		"mystic": skin = Color("#62a890")
		"mutant": skin = Color("#9a74b8")
		"royal": skin = Color("#7ea83e")
		"wild": skin = Color("#8aa23e")
		"air": skin = Color("#84b44c")
		"raider": skin = Color("#7aa23c")
		"support": skin = Color("#7cb060")
	var sc := float(look.get("scale", 1.0))
	var role := str(d.get("role", ""))
	var fam := str(d.get("family", ""))
	match role:
		"tank": sc *= 1.08
		"swarm": sc *= 0.85
	# Distinct silhouettes: proportions by role, facial features by card, hair/horns by family
	var h1 := absi(hash(cid))
	var h2 := absi(hash(cid + "#"))
	var height_i: int = {"assassin": 3, "caster": 4, "support": 2, "ranged": 2, "tank": 1, "swarm": 0, "siege": 1, "flyer": 1}.get(role, 2)
	var bulk_i: int = {"tank": 4, "siege": 3, "melee": 3, "assassin": 0, "caster": 1, "ranged": 1, "swarm": 1, "flyer": 1}.get(role, 2)
	var muscle_i: int = {"tank": 3, "melee": 2, "siege": 2, "assassin": 1}.get(role, 0)
	var app := {"face_shape": h1 % 4, "ears": h2 % 4, "nose": (h1 / 7) % 4, "jaw": 3 if role == "tank" else (h2 / 5) % 3,
		"teeth": (h1 / 11) % 3, "tusks": 2 if role in ["tank", "melee"] else (h2 / 3) % 2, "eyes": 3 if fam == "shadow" else (h1 / 13) % 3,
		"height": height_i, "bulk": bulk_i, "muscle": muscle_i, "expression": 2 if role in ["melee", "tank", "assassin"] else (h2 / 17) % 4,
		"horns": {"wild": 1 + h1 % 2, "mutant": 3, "royal": 0}.get(fam, 0), "crest": {"wild": 1, "raider": 1, "mech": 0, "fire": 2}.get(fam, 0) if h2 % 3 != 0 else 0,
		"hair": {"mystic": 2, "royal": 3, "ice": 1, "support": 1}.get(fam, 0), "hair_color": h1 % 5, "scars": (h2 / 7) % 5 if role in ["melee", "tank", "assassin"] else 0,
		"paint": (h1 / 19) % 5 if fam in ["wild", "raider", "fire"] else 0, "paint_color": h2 % 5}
	return {"look": look, "color": fam_col.to_html(), "skin": skin.to_html(), "scale": sc * 0.95, "appearance": app,
		"eye_color": ["#ffd23f", "#ff3030", "#7fd8ff", "#7bdc3a"][h2 % 4], "glow_eyes": "glow" in look.get("acc", []) or fam == "shadow"}
