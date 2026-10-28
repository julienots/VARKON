class_name Equipment
extends RefCounted
## Procedural meshes for weapons, armour pieces, accessories, mutations and auras.
## Each piece is attached to a GoblinRig socket so it follows the animations.


static func _metal_or(col: Color, metal: float, emit: Color) -> StandardMaterial3D:
	return MeshKit.mat(col, metal, 0.35 if metal > 0.5 else 0.8, emit, 1.8)


static func weapon(hand: Node3D, mesh_id: String, col: Color, metal: float, emit: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon"
	root.rotation_degrees = Vector3(70, 0, 0)
	hand.add_child(root)
	var m := _metal_or(col, metal, emit)
	var wood := MeshKit.mat(Color("#5a3a20"), 0, 0.9)
	var steel := MeshKit.mat(Color("#a8adb4"), 0.9, 0.3, emit if emit.a > 0 else Color(0, 0, 0, 0), 1.2)
	match mesh_id:
		"sword", "sword_big":
			var big := 1.5 if mesh_id == "sword_big" else 1.0
			MeshKit.part(root, "cyl", [0.02, 0.14], wood, Vector3(0, 0, 0))
			MeshKit.part(root, "box", [0.16 * big, 0.03, 0.04], m, Vector3(0, 0.08, 0))
			MeshKit.part(root, "box", [0.06 * big, 0.5 * big, 0.015], m if metal > 0.5 else steel, Vector3(0, 0.08 + 0.25 * big, 0))
			MeshKit.part(root, "prism", [0.06 * big, 0.08, 0.015], m if metal > 0.5 else steel, Vector3(0, 0.12 + 0.5 * big, 0))
		"axe", "axe_big", "dual_axe":
			var big2 := 1.4 if mesh_id == "axe_big" else 1.0
			MeshKit.part(root, "cyl", [0.02, 0.55 * big2], wood, Vector3(0, 0.2 * big2, 0))
			MeshKit.part(root, "box", [0.2 * big2, 0.16 * big2, 0.025], m, Vector3(0.09 * big2, 0.42 * big2, 0))
			MeshKit.part(root, "cyl", [0.08 * big2, 0.025, 0.08 * big2], m, Vector3(0.19 * big2, 0.42 * big2, 0), Vector3(90, 0, 0))
		"hammer", "hammer_big", "club", "bone_club":
			var big3 := 1.5 if mesh_id == "hammer_big" else 1.0
			var head_mat := m
			if mesh_id == "bone_club":
				head_mat = MeshKit.mat(Color("#e8dcc0"))
			MeshKit.part(root, "cyl", [0.022, 0.5 * big3], wood, Vector3(0, 0.2 * big3, 0))
			if mesh_id in ["club", "bone_club"]:
				MeshKit.part(root, "cyl", [0.07, 0.25, 0.04], head_mat, Vector3(0, 0.5, 0))
				for k in 3:
					MeshKit.part(root, "cone", [0.015, 0.06], steel, Vector3(0.06, 0.45 + k * 0.06, 0), Vector3(0, 0, -90))
			else:
				MeshKit.part(root, "box", [0.24 * big3, 0.13 * big3, 0.13 * big3], head_mat, Vector3(0, 0.45 * big3, 0))
		"dagger", "dual_dagger":
			MeshKit.part(root, "cyl", [0.018, 0.09], wood)
			MeshKit.part(root, "box", [0.04, 0.22, 0.012], m if metal > 0.4 else steel, Vector3(0, 0.15, 0))
		"spear", "halberd":
			MeshKit.part(root, "cyl", [0.018, 0.9], wood, Vector3(0, 0.3, 0))
			MeshKit.part(root, "cone", [0.04, 0.16], m if metal > 0.4 else steel, Vector3(0, 0.83, 0))
			if mesh_id == "halberd":
				MeshKit.part(root, "box", [0.16, 0.12, 0.02], steel, Vector3(0.07, 0.68, 0))
		"scythe":
			MeshKit.part(root, "cyl", [0.02, 0.9], wood, Vector3(0, 0.3, 0))
			MeshKit.part(root, "box", [0.42, 0.05, 0.02], m, Vector3(0.2, 0.74, 0), Vector3(0, 0, -12))
		"staff":
			MeshKit.part(root, "cyl", [0.022, 0.9], wood, Vector3(0, 0.3, 0))
			var orb_col := emit if emit.a > 0 else col.lightened(0.3)
			MeshKit.part(root, "sphere", [0.07], MeshKit.mat(orb_col, 0, 0.2, orb_col, 2.5), Vector3(0, 0.8, 0))
		"orb":
			var oc := emit if emit.a > 0 else col
			MeshKit.part(root, "sphere", [0.08], MeshKit.mat(oc, 0, 0.2, oc, 2.5), Vector3(0, 0.12, 0))
		"hourglass":
			MeshKit.part(root, "cone", [0.06, 0.1], MeshKit.mat(Color("#d9b44a"), 0.8), Vector3(0, 0.08, 0), Vector3(180, 0, 0))
			MeshKit.part(root, "cone", [0.06, 0.1], MeshKit.mat(Color("#4aa3ff"), 0, 0.2, Color("#4aa3ff"), 1.5), Vector3(0, 0.18, 0))
		"flask":
			MeshKit.part(root, "sphere", [0.06], MeshKit.mat(Color("#7bdc3a"), 0, 0.1, Color("#7bdc3a"), 1.3), Vector3(0, 0.07, 0))
			MeshKit.part(root, "cyl", [0.02, 0.06], MeshKit.mat(Color("#c0c0c0")), Vector3(0, 0.15, 0))
		"bomb":
			MeshKit.part(root, "sphere", [0.08], MeshKit.mat(Color("#222222"), 0.3, 0.5), Vector3(0, 0.08, 0))
			MeshKit.part(root, "cyl", [0.008, 0.06], MeshKit.mat(Color("#ff8a2b"), 0, 0.5, Color("#ff8a2b"), 3.0), Vector3(0, 0.18, 0))
		"crossbow", "sling":
			MeshKit.part(root, "box", [0.04, 0.32, 0.04], wood, Vector3(0, 0.12, 0))
			MeshKit.part(root, "box", [0.36, 0.03, 0.03], m if mesh_id == "crossbow" else wood, Vector3(0, 0.22, 0))
		"blaster":
			MeshKit.part(root, "cyl", [0.05, 0.36], m, Vector3(0, 0.16, 0))
			MeshKit.part(root, "torus", [0.04, 0.065], steel, Vector3(0, 0.3, 0))
			if emit.a > 0:
				MeshKit.part(root, "sphere", [0.035], MeshKit.mat(emit, 0, 0.2, emit, 3.0), Vector3(0, 0.35, 0))
		"wrench":
			MeshKit.part(root, "box", [0.04, 0.32, 0.02], steel, Vector3(0, 0.14, 0))
			MeshKit.part(root, "torus", [0.03, 0.06], steel, Vector3(0, 0.32, 0), Vector3(90, 0, 0))
		"saw":
			MeshKit.part(root, "cyl", [0.02, 0.2], wood, Vector3(0, 0.05, 0))
			MeshKit.part(root, "cyl", [0.16, 0.015], steel, Vector3(0, 0.28, 0), Vector3(0, 0, 90))
		"piston", "mech_jaw":
			MeshKit.part(root, "cyl", [0.07, 0.3], m, Vector3(0, 0.12, 0))
			MeshKit.part(root, "box", [0.18, 0.12, 0.18], m, Vector3(0, 0.32, 0))
			if mesh_id == "mech_jaw":
				MeshKit.part(root, "box", [0.18, 0.04, 0.16], steel, Vector3(0, 0.42, 0.02), Vector3(-25, 0, 0))
			if emit.a > 0:
				MeshKit.part(root, "sphere", [0.03], MeshKit.mat(emit, 0, 0.2, emit, 3.0), Vector3(0.09, 0.32, 0.09))
		"claws":
			for k in 3:
				MeshKit.part(root, "cone", [0.015, 0.16], m if metal > 0.3 else steel, Vector3(-0.04 + k * 0.04, 0.1, 0.02))
		"horn":
			MeshKit.part(root, "cone", [0.06, 0.28], MeshKit.mat(Color("#e8dcc0")), Vector3(0, 0.1, 0), Vector3(180, 0, 20))
		"banner":
			MeshKit.part(root, "cyl", [0.015, 1.1], wood, Vector3(0, 0.4, 0))
			MeshKit.part(root, "box", [0.3, 0.4, 0.01], MeshKit.mat(col, 0, 0.9), Vector3(0.16, 0.75, 0))
		"drum":
			MeshKit.part(root, "cyl", [0.012, 0.3], wood, Vector3(0, 0.12, 0))
			MeshKit.part(root, "sphere", [0.025], MeshKit.mat(Color("#e8dcc0")), Vector3(0, 0.27, 0))
		"torch":
			MeshKit.part(root, "cyl", [0.02, 0.35], wood, Vector3(0, 0.12, 0))
			MeshKit.part(root, "cone", [0.05, 0.14], MeshKit.mat(Color("#ff8a2b"), 0, 0.3, Color("#ff6a1f"), 3.0), Vector3(0, 0.36, 0))
		"tentacle":
			for k in 3:
				MeshKit.part(root, "capsule", [0.03 - k * 0.006, 0.18], MeshKit.mat(Color("#5a1e5e")), Vector3(0, 0.08 + k * 0.13, k * 0.03), Vector3(k * 15, 0, 0))
		"catapult":
			MeshKit.part(root, "box", [0.04, 0.3, 0.04], wood, Vector3(0, 0.12, 0))
		"shield", "shield_round", "shield_square", "shield_tower":
			root.rotation_degrees = Vector3(0, 0, 0)
			var dims: Array = {"shield_square": [0.34, 0.34, 0.04], "shield_tower": [0.34, 0.55, 0.05]}.get(mesh_id, [])
			if dims.is_empty():
				MeshKit.part(root, "cyl", [0.2, 0.04], m, Vector3(-0.04, 0, 0.08), Vector3(90, 0, 90))
				MeshKit.part(root, "sphere", [0.05], MeshKit.mat(Color("#c0c0c0"), 0.9), Vector3(-0.07, 0, 0.08))
			else:
				MeshKit.part(root, "box", dims, m, Vector3(-0.05, 0, 0.08), Vector3(0, 90, 0))
		"none", "horns", "":
			pass
		_:
			MeshKit.part(root, "box", [0.05, 0.4, 0.02], m, Vector3(0, 0.2, 0))
	if emit.a > 0 and Settings.particle_amount(10) > 0:
		var p := CPUParticles3D.new()
		p.amount = Settings.particle_amount(10)
		p.lifetime = 0.8
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.12
		p.position = Vector3(0, 0.35, 0)
		p.gravity = Vector3(0, 0.6, 0)
		p.scale_amount_min = 0.02
		p.scale_amount_max = 0.04
		p.mesh = MeshKit.mesh("sphere", 0.5)
		p.material_override = MeshKit.unshaded(emit, 0.8)
		root.add_child(p)
	return root


static func slot_item(rig: GoblinRig, slot: String, mesh_id: String, col: Color, metal: float, emit: Color) -> void:
	var m := _metal_or(col, metal, emit)
	var h := rig.head
	var to := rig.torso
	match slot:
		"head":
			match mesh_id:
				"cap":
					MeshKit.part(h, "hemi", [0.215], m, Vector3(0, 0.22, -0.01), Vector3.ZERO, Vector3(1, 0.9, 1))
				"helm", "helm_gear", "helm_horned":
					MeshKit.part(h, "hemi", [0.23], m, Vector3(0, 0.2, -0.01), Vector3.ZERO, Vector3(1, 1.05, 1.05), true)
					MeshKit.part(h, "box", [0.04, 0.12, 0.05], m, Vector3(0, 0.2, 0.22))
					if mesh_id == "helm_gear":
						MeshKit.part(h, "torus", [0.05, 0.08], MeshKit.mat(Color("#8d8f94"), 1.0), Vector3(0.2, 0.3, 0), Vector3(0, 0, 90))
						MeshKit.part(h, "box", [0.24, 0.05, 0.04], MeshKit.mat(emit if emit.a > 0 else Color.ORANGE, 0, 0.2, emit, 2.0), Vector3(0, 0.21, 0.2))
					if mesh_id == "helm_horned":
						for sx in [-1, 1]:
							MeshKit.part(h, "cone", [0.05, 0.3], MeshKit.mat(Color("#e8dcc0")), Vector3(0.2 * sx, 0.42, 0), Vector3(0, 0, -35 * sx))
				"crown", "crown_big", "crown_spiky":
					var big := 1.3 if mesh_id == "crown_big" else 1.0
					MeshKit.part(h, "cyl", [0.15 * big, 0.08, 0.15 * big], m, Vector3(0, 0.36, 0))
					for k in 6:
						var a := k * TAU / 6
						MeshKit.part(h, "cone", [0.03, 0.1 * big if mesh_id != "crown_spiky" else 0.16], m, Vector3(cos(a) * 0.13 * big, 0.44, sin(a) * 0.13 * big))
					if emit.a > 0:
						MeshKit.part(h, "sphere", [0.03], MeshKit.mat(emit, 0, 0.2, emit, 3.0), Vector3(0, 0.38, 0.15 * big))
				"mask":
					MeshKit.part(h, "box", [0.3, 0.22, 0.05], m, Vector3(0, 0.2, 0.2), Vector3(-5, 0, 0))
					for sx in [-1, 1]:
						MeshKit.part(h, "box", [0.07, 0.03, 0.02], MeshKit.mat(Color.BLACK, 0, 1, emit, 2.0), Vector3(0.07 * sx, 0.22, 0.23))
				"horns_ram":
					for sx in [-1, 1]:
						MeshKit.part(h, "torus", [0.06, 0.11], m, Vector3(0.19 * sx, 0.3, -0.02), Vector3(0, 90, 0))
		"eyes":
			match mesh_id:
				"monocle":
					MeshKit.part(h, "torus", [0.035, 0.05], m, Vector3(0.078, 0.2, 0.21), Vector3(90, 0, 0))
				"goggles":
					for sx in [-1, 1]:
						MeshKit.part(h, "cyl", [0.055, 0.05], MeshKit.mat(col, 0.3, 0.2, emit, 1.5), Vector3(0.078 * sx, 0.2, 0.2), Vector3(90, 0, 0))
					MeshKit.part(h, "box", [0.4, 0.03, 0.03], MeshKit.mat(Color("#3a2a1a")), Vector3(0, 0.2, 0.1))
				"eye_glow":
					for em in rig.eye_mats:
						em.emission_enabled = true
						em.emission = emit if emit.a > 0 else col
						em.emission_energy_multiplier = 3.0
		"torso":
			match mesh_id:
				"tunic":
					MeshKit.part(to, "cyl", [0.215, 0.3, 0.25], m, Vector3(0, 0.12, 0))
				"vest":
					MeshKit.part(to, "cyl", [0.22, 0.42, 0.23], m, Vector3(0, 0.2, 0))
					MeshKit.part(to, "cyl", [0.235, 0.05], MeshKit.mat(Color("#3a2a1a")), Vector3(0, 0.03, 0))
				"plate", "plate_royal":
					MeshKit.part(to, "cyl", [0.235, 0.46, 0.24], m, Vector3(0, 0.21, 0), Vector3.ZERO, Vector3(1, 1, 0.9), true)
					MeshKit.part(to, "box", [0.2, 0.18, 0.06], m, Vector3(0, 0.3, 0.19))
					if mesh_id == "plate_royal":
						MeshKit.part(to, "sphere", [0.05], MeshKit.mat(emit if emit.a > 0 else Color("#c9472b"), 0.5, 0.2, emit, 2.0), Vector3(0, 0.32, 0.23))
				"carapace":
					MeshKit.part(to, "sphere", [0.26], m, Vector3(0, 0.26, -0.03), Vector3.ZERO, Vector3(1, 1.1, 0.9), true)
					for k in 3:
						MeshKit.part(to, "box", [0.3, 0.03, 0.05], MeshKit.mat(col.lightened(0.2), 0, 0.4, emit, 1.0), Vector3(0, 0.12 + k * 0.1, 0.2))
				"mech_frame":
					MeshKit.part(to, "box", [0.42, 0.42, 0.34], m, Vector3(0, 0.22, 0), Vector3.ZERO, Vector3.ONE, true)
					MeshKit.part(to, "cyl", [0.06, 0.1], MeshKit.mat(emit if emit.a > 0 else Color.ORANGE, 0, 0.2, emit, 2.5), Vector3(0, 0.3, 0.17), Vector3(90, 0, 0))
				"robe":
					MeshKit.part(to, "cyl", [0.2, 0.62, 0.32], m, Vector3(0, 0.04, 0))
					MeshKit.part(to, "box", [0.04, 0.5, 0.02], MeshKit.mat(Color("#ffd23f"), 0.8, 0.3, emit, 1.5), Vector3(0, 0.1, 0.25))
		"shoulders":
			for sx in [-1, 1]:
				match mesh_id:
					"pads", "pads_big":
						var big := 1.35 if mesh_id == "pads_big" else 1.0
						MeshKit.part(to, "hemi", [0.11 * big], m, Vector3(0.27 * sx, 0.47, 0), Vector3(0, 0, -25 * sx), Vector3(1, 0.8, 1))
					"pads_spiked":
						MeshKit.part(to, "hemi", [0.11], m, Vector3(0.27 * sx, 0.47, 0), Vector3(0, 0, -25 * sx))
						for k in 3:
							MeshKit.part(to, "cone", [0.02, 0.1], MeshKit.mat(Color("#c0c0c0"), 0.9), Vector3(0.29 * sx, 0.55, -0.05 + k * 0.05), Vector3(0, 0, -20 * sx))
					"skulls":
						MeshKit.part(to, "sphere", [0.08], MeshKit.mat(Color("#e8dcc0")), Vector3(0.27 * sx, 0.52, 0))
						MeshKit.part(to, "box", [0.03, 0.02, 0.02], MeshKit.mat(Color.BLACK), Vector3(0.27 * sx, 0.53, 0.07))
		"hands":
			for hd in [rig.hand_l, rig.hand_r]:
				match mesh_id:
					"wraps":
						MeshKit.part(hd, "cyl", [0.075, 0.08], m, Vector3(0, 0.05, 0))
					"gauntlet", "gauntlet_big":
						var b := 1.4 if mesh_id == "gauntlet_big" else 1.0
						MeshKit.part(hd, "box", [0.15 * b, 0.16 * b, 0.15 * b], m, Vector3(0, 0.02, 0))
						if emit.a > 0:
							MeshKit.part(hd, "sphere", [0.025], MeshKit.mat(emit, 0, 0.2, emit, 3.0), Vector3(0, 0.03, 0.08 * b))
					"rings":
						MeshKit.part(hd, "torus", [0.06, 0.075], m, Vector3(0, -0.02, 0), Vector3(90, 0, 0))
		"legs":
			for lg in [rig.leg_l, rig.leg_r]:
				match mesh_id:
					"trousers":
						MeshKit.part(lg, "capsule", [0.08, 0.3], m, Vector3(0, -0.13, 0))
					"greaves":
						MeshKit.part(lg, "cyl", [0.085, 0.2, 0.075], m, Vector3(0, -0.22, 0.01))
		"feet":
			for lg in [rig.leg_l, rig.leg_r]:
				match mesh_id:
					"boots", "boots_big":
						var bb := 1.25 if mesh_id == "boots_big" else 1.0
						MeshKit.part(lg, "box", [0.16 * bb, 0.12 * bb, 0.24 * bb], m, Vector3(0, -0.33, 0.04))
					"hooves":
						MeshKit.part(lg, "cyl", [0.06, 0.12, 0.09], m, Vector3(0, -0.34, 0))
		"back":
			var bk := rig.back
			match mesh_id:
				"sack":
					MeshKit.part(bk, "sphere", [0.17], m, Vector3(0, -0.05, -0.08))
				"quiver":
					MeshKit.part(bk, "cyl", [0.06, 0.4], m, Vector3(0.08, 0.05, -0.05), Vector3(0, 0, 25))
					for k in 3:
						MeshKit.part(bk, "cone", [0.02, 0.08], MeshKit.mat(Color("#c9472b")), Vector3(0.14 + k * 0.02, 0.27, -0.05), Vector3(0, 0, 25))
				"engine", "jetpack":
					MeshKit.part(bk, "box", [0.3, 0.32, 0.16], m, Vector3(0, 0, -0.08), Vector3.ZERO, Vector3.ONE, true)
					for sx in [-1, 1]:
						MeshKit.part(bk, "cyl", [0.05, 0.2], m, Vector3(0.1 * sx, -0.16, -0.12))
						MeshKit.part(bk, "cone", [0.04, 0.12], MeshKit.mat(emit if emit.a > 0 else Color.ORANGE, 0, 0.2, emit if emit.a > 0 else Color.ORANGE, 3.0), Vector3(0.1 * sx, -0.3, -0.12), Vector3(180, 0, 0))
				"wings":
					for sx in [-1, 1]:
						var w := MeshKit.pivot(bk, Vector3(0.1 * sx, 0.05, -0.05), "WingK%d" % (sx + 1))
						MeshKit.part(w, "prism", [0.6, 0.35, 0.02], m, Vector3(0.3 * sx, 0.1, 0), Vector3(0, 0, -20 * sx))
						rig.wings.append(w)
				"tentacles":
					for k in 4:
						var a := -0.6 + k * 0.4
						MeshKit.part(bk, "capsule", [0.035, 0.45], m, Vector3(sin(a) * 0.2, 0.15, -0.15), Vector3(-40, 0, rad_to_deg(a)))
				"banner":
					MeshKit.part(bk, "cyl", [0.015, 0.9], MeshKit.mat(Color("#5a3a20")), Vector3(0, 0.3, -0.05))
					MeshKit.part(bk, "box", [0.3, 0.36, 0.01], m, Vector3(0.16, 0.55, -0.05))
		"belt":
			MeshKit.part(to, "cyl", [0.23, 0.06], MeshKit.mat(Color("#3a2a1a")), Vector3(0, 0.02, 0))
			match mesh_id:
				"belt_flasks":
					for k in 3:
						MeshKit.part(to, "sphere", [0.035], MeshKit.mat(Color("#7bdc3a"), 0, 0.1, Color("#7bdc3a"), 1.2), Vector3(-0.12 + k * 0.12, 0.0, 0.2))
				"totem":
					MeshKit.part(to, "box", [0.08, 0.14, 0.05], m, Vector3(0.15, -0.03, 0.17))
				"belt_tools":
					MeshKit.part(to, "box", [0.04, 0.16, 0.02], MeshKit.mat(Color("#a8adb4"), 0.9), Vector3(0.17, -0.05, 0.15))
				_:
					MeshKit.part(to, "box", [0.07, 0.06, 0.03], MeshKit.mat(Color("#c0a060"), 0.9), Vector3(0, 0.02, 0.22))
		"special":
			var orbit := MeshKit.pivot(to, Vector3(0.38, 0.65, 0))
			MeshKit.part(orbit, "sphere" if mesh_id == "relic_core" else "box", [0.06, 0.09, 0.06], MeshKit.mat(col, 0.3, 0.2, emit if emit.a > 0 else col, 2.5))


static func accessory(rig: GoblinRig, a: String, fam: Color) -> void:
	var h := rig.head
	var to := rig.torso
	var gold := MeshKit.mat(Color("#e0b84a"), 1.0, 0.3)
	var fam_m := MeshKit.mat(fam, 0, 0.8)
	match a:
		"flame_hair":
			for k in 3:
				MeshKit.part(h, "cone", [0.07 - k * 0.015, 0.22 + k * 0.05], MeshKit.mat(Color("#ff8a2b"), 0, 0.3, Color("#ff5a1f"), 2.5), Vector3((k - 1) * 0.06, 0.4, -0.03), Vector3(-15, 0, (k - 1) * -15))
		"skull_mask":
			MeshKit.part(h, "sphere", [0.15], MeshKit.mat(Color("#efe6d0")), Vector3(0, 0.2, 0.12), Vector3.ZERO, Vector3(1, 1, 0.6))
		"backpack":
			MeshKit.part(rig.back, "box", [0.28, 0.3, 0.16], MeshKit.mat(Color("#6b4a2b")), Vector3(0, -0.02, -0.08))
		"glow":
			var ring := MeshKit.part(rig, "torus", [0.42, 0.5], MeshKit.unshaded(fam, 0.55), Vector3(0, 0.03, 0))
			ring.scale = Vector3(1, 0.3, 1)
		"ice_spikes":
			for k in 4:
				MeshKit.part(to, "cone", [0.04, 0.2], MeshKit.mat(Color("#bfe8ff"), 0.2, 0.1, Color("#7fd8ff"), 0.8), Vector3(-0.15 + k * 0.1, 0.5, -0.12), Vector3(-30, 0, (k - 1.5) * 15))
		"ice_crown":
			for k in 5:
				var ang := k * TAU / 5
				MeshKit.part(h, "cone", [0.025, 0.14], MeshKit.mat(Color("#bfe8ff"), 0.2, 0.1, Color("#7fd8ff"), 1.0), Vector3(cos(ang) * 0.12, 0.42, sin(ang) * 0.12))
		"mushroom":
			MeshKit.part(h, "hemi", [0.18], MeshKit.mat(Color("#c9472b")), Vector3(0, 0.33, 0), Vector3.ZERO, Vector3(1.2, 0.6, 1.2))
			for k in 3:
				MeshKit.part(h, "sphere", [0.025], MeshKit.mat(Color.WHITE), Vector3(-0.08 + k * 0.08, 0.39, 0.06))
		"mushroom_big":
			for k in 2:
				MeshKit.part(rig.back, "cyl", [0.03, 0.2], MeshKit.mat(Color("#e8dcc0")), Vector3(-0.08 + k * 0.16, 0.08, -0.06))
				MeshKit.part(rig.back, "hemi", [0.14], MeshKit.mat(Color("#7bdc3a"), 0, 0.6, Color("#5a9a2a"), 0.6), Vector3(-0.08 + k * 0.16, 0.18, -0.06))
		"mask_gas":
			MeshKit.part(h, "cyl", [0.06, 0.12, 0.08], MeshKit.mat(Color("#555555"), 0.6), Vector3(0, 0.08, 0.22), Vector3(90, 0, 0))
		"goggles":
			for sx in [-1, 1]:
				MeshKit.part(h, "cyl", [0.05, 0.05], MeshKit.mat(Color("#b07a3a"), 0.8, 0.3, Color("#ffb347"), 0.6), Vector3(0.078 * sx, 0.24, 0.19), Vector3(90, 0, 0))
		"metal_plates":
			MeshKit.part(to, "box", [0.36, 0.22, 0.08], MeshKit.mat(Color("#7b7f86"), 0.9, 0.35), Vector3(0, 0.32, 0.17))
			for sx in [-1, 1]:
				MeshKit.part(to, "hemi", [0.11], MeshKit.mat(Color("#7b7f86"), 0.9, 0.35), Vector3(0.27 * sx, 0.47, 0), Vector3(0, 0, -25 * sx))
		"chimney":
			MeshKit.part(rig.back, "cyl", [0.06, 0.4], MeshKit.mat(Color("#4a4a4a"), 0.8), Vector3(0.1, 0.15, -0.08))
			MeshKit.part(rig.back, "sphere", [0.05], MeshKit.mat(Color("#ff8a2b"), 0, 0.2, Color("#ff6a1f"), 2.5), Vector3(0.1, 0.36, -0.08))
		"hood", "hood_red":
			var hc := MeshKit.mat(Color("#7a1a14") if a == "hood_red" else fam.darkened(0.55), 0, 0.95)
			MeshKit.part(h, "cone", [0.25, 0.45], hc, Vector3(0, 0.3, -0.04), Vector3(-12, 0, 0))
		"fur":
			for sx in [-1, 1]:
				MeshKit.part(to, "sphere", [0.12], MeshKit.mat(Color("#7a5a3a"), 0, 1.0), Vector3(0.24 * sx, 0.48, -0.02), Vector3.ZERO, Vector3(1, 0.7, 1))
		"horns_big":
			for sx in [-1, 1]:
				MeshKit.part(h, "cone", [0.05, 0.3], MeshKit.mat(Color("#d8c8a8")), Vector3(0.14 * sx, 0.42, 0), Vector3(-20, 0, -35 * sx))
		"runes":
			for k in 3:
				var ang2 := k * TAU / 3
				MeshKit.part(to, "box", [0.06, 0.06, 0.01], MeshKit.mat(Color("#58a6ff"), 0, 0.2, Color("#58a6ff"), 2.5), Vector3(cos(ang2) * 0.45, 0.5 + k * 0.05, sin(ang2) * 0.45))
		"blindfold":
			MeshKit.part(h, "cyl", [0.215, 0.06], fam_m, Vector3(0, 0.21, 0))
		"helm_royal":
			MeshKit.part(h, "hemi", [0.225], gold, Vector3(0, 0.2, -0.01), Vector3.ZERO, Vector3(1, 1, 1), true)
			MeshKit.part(h, "box", [0.03, 0.12, 0.25], MeshKit.mat(Color("#c9472b")), Vector3(0, 0.36, -0.02))
		"cape":
			MeshKit.part(to, "box", [0.42, 0.62, 0.02], MeshKit.mat(fam.darkened(0.2), 0, 0.9), Vector3(0, 0.08, -0.2), Vector3(12, 0, 0))
		"crown_small":
			MeshKit.part(h, "cyl", [0.12, 0.06], gold, Vector3(0, 0.37, 0))
			for k in 5:
				var ang3 := k * TAU / 5
				MeshKit.part(h, "cone", [0.025, 0.08], gold, Vector3(cos(ang3) * 0.1, 0.44, sin(ang3) * 0.1))
		"tentacles":
			for k in 3:
				MeshKit.part(rig.back, "capsule", [0.035, 0.42], MeshKit.mat(Color("#5a1e5e")), Vector3(-0.12 + k * 0.12, 0.1, -0.12), Vector3(-45, 0, (k - 1) * 30))
		"big_jaw":
			MeshKit.part(h, "box", [0.36, 0.14, 0.24], rig.skin_mat, Vector3(0, 0.02, 0.15), Vector3(15, 0, 0), Vector3.ONE, true)
			for k in 5:
				MeshKit.part(h, "cone", [0.025, 0.08], MeshKit.mat(Color("#f4ecd0")), Vector3(-0.12 + k * 0.06, 0.1, 0.27))
		"spikes":
			for k in 5:
				MeshKit.part(to, "cone", [0.04, 0.18], MeshKit.mat(Color("#d8c8a8")), Vector3(0, 0.15 + k * 0.08, -0.2), Vector3(-60, 0, 0))
		"boils":
			for k in 5:
				MeshKit.part(to, "sphere", [0.035], MeshKit.mat(Color("#b04fb9"), 0, 0.4, Color("#d03fd9"), 0.5), Vector3(sin(k * 1.7) * 0.18, 0.15 + k * 0.07, cos(k * 1.7) * 0.15))
		"wings":
			for sx in [-1, 1]:
				var w := MeshKit.pivot(rig.back, Vector3(0.08 * sx, 0.05, -0.05), "WingA%d" % (sx + 1))
				MeshKit.part(w, "prism", [0.55, 0.32, 0.02], MeshKit.mat(Color("#6b4a3a"), 0, 0.9), Vector3(0.28 * sx, 0.08, 0), Vector3(0, 0, -20 * sx))
				rig.wings.append(w)
		"feathers":
			for k in 3:
				MeshKit.part(h, "cone", [0.025, 0.22], MeshKit.mat([Color("#c9472b"), Color("#ffd23f"), Color("#3d8bff")][k]), Vector3(-0.06 + k * 0.06, 0.4, -0.12), Vector3(-35, 0, (k - 1) * 20))
		"helmet_work":
			MeshKit.part(h, "hemi", [0.22], MeshKit.mat(Color("#e0b030"), 0.2, 0.5), Vector3(0, 0.22, 0))
		"bandana":
			MeshKit.part(h, "cyl", [0.215, 0.07], MeshKit.mat(Color("#c9472b")), Vector3(0, 0.28, -0.01))
		"barrel":
			MeshKit.part(rig.back, "cyl", [0.13, 0.28], MeshKit.mat(Color("#6b4a2b")), Vector3(0, 0, -0.08))
			MeshKit.part(rig.back, "cyl", [0.01, 0.1], MeshKit.mat(Color("#ff8a2b"), 0, 0.3, Color("#ff6a1f"), 3.0), Vector3(0, 0.18, -0.08))
		"sack":
			MeshKit.part(rig.back, "sphere", [0.15], MeshKit.mat(Color("#8a6a40")), Vector3(0.06, -0.08, -0.06))
		"scars":
			MeshKit.part(h, "box", [0.012, 0.12, 0.01], MeshKit.mat(Color("#3a2a20")), Vector3(0.1, 0.16, 0.18), Vector3(0, 30, 25))
		"wolf_mount":
			var wolf := MeshKit.pivot(rig, Vector3(0, 0, 0))
			var fur := MeshKit.mat(Color("#4a3e34"), 0, 0.95)
			MeshKit.part(wolf, "capsule", [0.22, 0.9], fur, Vector3(0, 0.45, 0), Vector3(90, 0, 0), Vector3.ONE, true)
			MeshKit.part(wolf, "sphere", [0.16], fur, Vector3(0, 0.6, 0.5))
			MeshKit.part(wolf, "cone", [0.08, 0.2], fur, Vector3(0, 0.56, 0.68), Vector3(90, 0, 0))
			for p in [Vector3(-0.12, 0.2, 0.3), Vector3(0.12, 0.2, 0.3), Vector3(-0.12, 0.2, -0.3), Vector3(0.12, 0.2, -0.3)]:
				MeshKit.part(wolf, "capsule", [0.05, 0.42], fur, p)
			rig.body.position.y = 0.35
			rig.body.scale *= 0.85


static func mutation(rig: GoblinRig, v: String) -> void:
	match v:
		"scales":
			for k in 6:
				MeshKit.part(rig.torso, "box", [0.08, 0.05, 0.02], MeshKit.mat(Color("#3a6a4a"), 0.3, 0.3), Vector3(-0.1 + (k % 3) * 0.1, 0.3 + (k / 3) * 0.08, 0.19), Vector3(-10, 0, 45))
		"spines":
			accessory(rig, "spikes", Color.WHITE)
		"veins":
			for k in 4:
				MeshKit.part(rig.torso, "box", [0.012, 0.25, 0.01], MeshKit.mat(Color("#ff3030"), 0, 0.3, Color("#ff3030"), 2.0), Vector3(-0.12 + k * 0.08, 0.25, 0.195), Vector3(0, 0, (k - 1.5) * 12))
		"ancestral_glow":
			aura(rig, Color("#3ff0e0"))
		"big_arms", "glow_eyes", "big_tusks":
			pass  # handled while building the body/head


static func aura(rig: GoblinRig, col: Color) -> Node3D:
	var root := MeshKit.pivot(rig, Vector3.ZERO, "Aura")
	var ring := MeshKit.part(root, "torus", [0.5, 0.58], MeshKit.unshaded(col, 0.6 * Settings.flash_scale()), Vector3(0, 0.04, 0))
	ring.scale = Vector3(1, 0.25, 1)
	var n := Settings.particle_amount(24)
	if n > 0:
		var p := CPUParticles3D.new()
		p.amount = n
		p.lifetime = 1.4
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = 0.5
		p.emission_ring_inner_radius = 0.3
		p.emission_ring_height = 0.05
		p.gravity = Vector3(0, 0.9, 0)
		p.scale_amount_min = 0.03
		p.scale_amount_max = 0.06
		p.mesh = MeshKit.mesh("sphere", 0.5)
		p.material_override = MeshKit.unshaded(col, 0.85)
		root.add_child(p)
	return root
