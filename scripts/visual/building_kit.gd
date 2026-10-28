class_name BuildingKit
extends RefCounted
## Procedural fortress buildings whose silhouette evolves with level, plus battle structures
## and environment props (ground, rocks, trees, torches).

const STONE := Color("#6d655c")
const STONE_DARK := Color("#4a443e")
const WOOD := Color("#5a3a20")
const ROOF := Color("#7a2a1c")


static func building(id: String, level: int, size: Vector2i, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = id
	var w := float(size.x)
	var d := float(size.y)
	var lv := maxi(level, 0)
	var stone := MeshKit.mat(STONE, 0, 0.9)
	var stone_d := MeshKit.mat(STONE_DARK, 0, 0.95)
	var wood := MeshKit.mat(WOOD, 0, 0.9)
	var accent := MeshKit.mat(color, 0.2, 0.6)
	var gold := MeshKit.mat(Color("#e0b84a"), 1.0, 0.3)
	var tier := 1 + lv / 3
	# Foundation
	MeshKit.part(root, "box", [w * 0.92, 0.12, d * 0.92], stone_d, Vector3(0, 0.06, 0))
	match id:
		"fortress":
			var hgt := 1.4 + lv * 0.18
			MeshKit.part(root, "box", [w * 0.62, hgt, d * 0.62], stone, Vector3(0, hgt / 2 + 0.1, 0), Vector3.ZERO, Vector3.ONE, true)
			for cx in [-1, 1]:
				for cz in [-1, 1]:
					var th := hgt + 0.5 + tier * 0.2
					MeshKit.part(root, "cyl", [0.38, th], stone, Vector3(cx * w * 0.36, th / 2 + 0.1, cz * d * 0.36), Vector3.ZERO, Vector3.ONE, true)
					MeshKit.part(root, "cone", [0.48, 0.7], MeshKit.mat(ROOF if lv < 8 else Color("#c9a030"), 0.3 if lv >= 8 else 0.0, 0.6), Vector3(cx * w * 0.36, th + 0.45, cz * d * 0.36))
			MeshKit.part(root, "box", [w * 0.42, 0.6 + tier * 0.3, d * 0.42], stone_d, Vector3(0, hgt + 0.4 + tier * 0.15, 0), Vector3.ZERO, Vector3.ONE, true)
			MeshKit.part(root, "cone", [w * 0.34, 1.0 + tier * 0.3], MeshKit.mat(ROOF), Vector3(0, hgt + 1.2 + tier * 0.45, 0), Vector3(0, 45, 0))
			MeshKit.part(root, "box", [0.6, 0.9, 0.08], wood, Vector3(0, 0.55, d * 0.31))
			_banner(root, Vector3(0, hgt + 2.0 + tier * 0.5, 0), color)
			if lv >= 5:
				MeshKit.part(root, "sphere", [0.18], MeshKit.mat(Color("#ffd23f"), 0.5, 0.2, Color("#ffd23f"), 2.0), Vector3(0, hgt + 1.9 + tier * 0.6, 0))
		"barracks":
			MeshKit.part(root, "box", [w * 0.8, 0.9 + tier * 0.15, d * 0.7], wood, Vector3(0, 0.55, 0), Vector3.ZERO, Vector3.ONE, true)
			MeshKit.part(root, "prism", [w * 0.86, 0.7, d * 0.76], MeshKit.mat(ROOF), Vector3(0, 1.35 + tier * 0.15, 0))
			for k in mini(lv, 4):
				MeshKit.part(root, "cyl", [0.03, 0.8], wood, Vector3(-w * 0.35 + k * 0.3, 0.5, d * 0.45))
				MeshKit.part(root, "cone", [0.05, 0.15], MeshKit.mat(Color("#a8adb4"), 0.9), Vector3(-w * 0.35 + k * 0.3, 0.95, d * 0.45))
			_banner(root, Vector3(w * 0.3, 2.0, 0), color)
		"treasury":
			MeshKit.part(root, "box", [w * 0.7, 0.8, d * 0.7], stone, Vector3(0, 0.5, 0), Vector3.ZERO, Vector3.ONE, true)
			MeshKit.part(root, "hemi", [w * 0.38], gold, Vector3(0, 0.9, 0))
			for k in mini(lv, 6):
				MeshKit.part(root, "cyl", [0.12, 0.06], gold, Vector3(-0.5 + (k % 3) * 0.5, 0.15 + (k / 3) * 0.07, d * 0.4))
		"gold_mine":
			MeshKit.part(root, "sphere", [w * 0.42], MeshKit.mat(Color("#5a4a3a"), 0, 1), Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1, 0.6, 1), true)
			MeshKit.part(root, "box", [0.5, 0.55, 0.1], wood, Vector3(0, 0.35, d * 0.38))
			MeshKit.part(root, "box", [0.42, 0.45, 0.1], MeshKit.mat(Color("#0a0806")), Vector3(0, 0.32, d * 0.4))
			MeshKit.part(root, "box", [0.35, 0.18, 0.25], wood, Vector3(w * 0.3, 0.2, d * 0.2))
			MeshKit.part(root, "sphere", [0.12], gold, Vector3(w * 0.3, 0.33, d * 0.2))
		"crystal_works":
			MeshKit.part(root, "cyl", [w * 0.35, 0.5, w * 0.4], stone, Vector3(0, 0.35, 0), Vector3.ZERO, Vector3.ONE, true)
			for k in 2 + mini(lv, 4):
				var a := k * TAU / (2 + mini(lv, 4))
				MeshKit.part(root, "prism", [0.25, 0.7 + (k % 2) * 0.3, 0.25], MeshKit.mat(Color("#58a6ff"), 0.2, 0.1, Color("#58a6ff"), 1.4), Vector3(cos(a) * 0.35, 0.95, sin(a) * 0.35))
		"workshop":
			MeshKit.part(root, "box", [w * 0.8, 0.9, d * 0.7], wood, Vector3(0, 0.55, 0), Vector3.ZERO, Vector3.ONE, true)
			MeshKit.part(root, "prism", [w * 0.86, 0.5, d * 0.76], MeshKit.mat(Color("#5a5a5a"), 0.6, 0.5), Vector3(0, 1.25, 0))
			MeshKit.part(root, "cyl", [0.14, 1.0 + tier * 0.3], MeshKit.mat(Color("#4a4a4a"), 0.8), Vector3(w * 0.28, 1.4, -d * 0.15))
			MeshKit.part(root, "torus", [0.18, 0.3], MeshKit.mat(Color("#8d8f94"), 1.0, 0.3), Vector3(-w * 0.2, 0.9, d * 0.37), Vector3(90, 0, 0))
		"card_hall":
			MeshKit.part(root, "box", [w * 0.75, 1.1 + tier * 0.2, d * 0.75], stone, Vector3(0, 0.65, 0), Vector3.ZERO, Vector3.ONE, true)
			for cx in [-1, 1]:
				MeshKit.part(root, "cyl", [0.12, 1.4], MeshKit.mat(Color("#d8d0c0")), Vector3(cx * w * 0.3, 0.75, d * 0.42))
			MeshKit.part(root, "prism", [w * 0.82, 0.6, d * 0.82], accent, Vector3(0, 1.5 + tier * 0.2, 0))
			MeshKit.part(root, "box", [0.5, 0.7, 0.04], MeshKit.mat(Color("#a35bff"), 0, 0.3, Color("#a35bff"), 1.2), Vector3(0, 0.9, d * 0.39))
		"laboratory":
			if lv <= 0:
				# Abandoned, partially collapsed laboratory with a sealed door and dead machines.
				MeshKit.part(root, "box", [w * 0.7, 0.9, 0.25], stone_d, Vector3(0, 0.5, -d * 0.3))
				MeshKit.part(root, "box", [0.25, 0.6, d * 0.5], stone_d, Vector3(-w * 0.32, 0.35, 0), Vector3(0, 0, 8))
				MeshKit.part(root, "box", [0.8, 0.3, 0.6], stone_d, Vector3(w * 0.15, 0.2, d * 0.15), Vector3(10, 30, 15))
				MeshKit.part(root, "box", [0.5, 0.25, 0.4], stone_d, Vector3(-w * 0.1, 0.18, d * 0.3), Vector3(-15, 60, 5))
				MeshKit.part(root, "box", [0.6, 0.8, 0.08], MeshKit.mat(Color("#3a3a3a"), 0.8, 0.6), Vector3(0, 0.5, -d * 0.16))
				MeshKit.part(root, "box", [0.7, 0.08, 0.1], MeshKit.mat(Color("#7a1a14")), Vector3(0, 0.6, -d * 0.11), Vector3(0, 0, 25))
				MeshKit.part(root, "box", [0.7, 0.08, 0.1], MeshKit.mat(Color("#7a1a14")), Vector3(0, 0.6, -d * 0.11), Vector3(0, 0, -25))
				MeshKit.part(root, "cyl", [0.2, 0.7], MeshKit.mat(Color("#3a3a3a"), 0.7, 0.7), Vector3(w * 0.3, 0.4, -d * 0.15))
			else:
				MeshKit.part(root, "box", [w * 0.75, 1.2, d * 0.75], MeshKit.mat(Color("#3a4a44")), Vector3(0, 0.7, 0), Vector3.ZERO, Vector3.ONE, true)
				MeshKit.part(root, "hemi", [w * 0.35], MeshKit.mat(Color("#7fffbf"), 0.3, 0.1, Color("#3ff0a0"), 0.8 + lv * 0.2, 0.75), Vector3(0, 1.3, 0))
				for k in mini(lv + 1, 5):
					MeshKit.part(root, "cyl", [0.08, 0.5], MeshKit.mat(Color("#d03fd9"), 0, 0.1, Color("#d03fd9"), 1.5, 0.8), Vector3(-w * 0.3 + k * 0.3, 0.35, d * 0.42))
				MeshKit.part(root, "cyl", [0.06, 1.2], MeshKit.mat(Color("#8d8f94"), 1.0), Vector3(w * 0.3, 1.6, -d * 0.2))
				MeshKit.part(root, "sphere", [0.12], MeshKit.mat(Color("#58a6ff"), 0, 0.1, Color("#58a6ff"), 3.0), Vector3(w * 0.3, 2.25, -d * 0.2))
		"royal_forge":
			MeshKit.part(root, "box", [w * 0.8, 0.8, d * 0.7], stone, Vector3(0, 0.5, 0), Vector3.ZERO, Vector3.ONE, true)
			MeshKit.part(root, "cyl", [0.25, 1.4 + tier * 0.2, 0.35], stone_d, Vector3(w * 0.25, 1.0, 0))
			MeshKit.part(root, "box", [0.6, 0.35, 0.05], MeshKit.mat(Color("#ff6a1f"), 0, 0.3, Color("#ff5a1f"), 2.5), Vector3(-w * 0.1, 0.4, d * 0.36))
			MeshKit.part(root, "box", [0.4, 0.2, 0.25], MeshKit.mat(Color("#3a3a3a"), 0.9, 0.4), Vector3(-w * 0.25, 0.95, d * 0.1))
		"watchtower":
			var th2 := 1.6 + lv * 0.15
			MeshKit.part(root, "cyl", [0.32, th2, 0.4], stone, Vector3(0, th2 / 2, 0), Vector3.ZERO, Vector3.ONE, true)
			MeshKit.part(root, "cyl", [0.44, 0.25], stone_d, Vector3(0, th2 + 0.1, 0))
			MeshKit.part(root, "cone", [0.5, 0.6], MeshKit.mat(ROOF), Vector3(0, th2 + 0.5, 0))
			if lv >= 4:
				MeshKit.part(root, "box", [0.5, 0.06, 0.06], MeshKit.mat(Color("#a8adb4"), 0.9), Vector3(0.3, th2 + 0.15, 0))
		"wall":
			MeshKit.part(root, "box", [w * 0.95, 0.7 + lv * 0.05, d * 0.5], stone, Vector3(0, 0.4, 0), Vector3.ZERO, Vector3.ONE, true)
			for k in 2:
				MeshKit.part(root, "box", [0.25, 0.2, d * 0.5], stone, Vector3(-0.25 + k * 0.5, 0.85 + lv * 0.05, 0))
		"trap":
			MeshKit.part(root, "cyl", [0.35, 0.05], wood, Vector3(0, 0.05, 0))
			for k in 5:
				MeshKit.part(root, "cone", [0.04, 0.2 + lv * 0.02], MeshKit.mat(Color("#a8adb4"), 0.9), Vector3(cos(k * 1.25) * 0.2, 0.15, sin(k * 1.25) * 0.2))
		"raid_portal":
			for cx in [-1, 1]:
				MeshKit.part(root, "box", [0.3, 1.8, 0.3], stone_d, Vector3(cx * w * 0.3, 0.9, 0), Vector3.ZERO, Vector3.ONE, true)
			MeshKit.part(root, "box", [w * 0.8, 0.3, 0.35], stone_d, Vector3(0, 1.9, 0))
			MeshKit.part(root, "box", [w * 0.5, 1.6, 0.04], MeshKit.mat(Color("#8a3aff"), 0, 0.1, Color("#a35bff"), 1.5 + lv * 0.3, 0.8), Vector3(0, 0.9, 0))
		"trophy_hall":
			MeshKit.part(root, "box", [w * 0.8, 1.2, d * 0.75], MeshKit.mat(Color("#e8dcc0")), Vector3(0, 0.7, 0), Vector3.ZERO, Vector3.ONE, true)
			MeshKit.part(root, "prism", [w * 0.86, 0.6, d * 0.8], gold, Vector3(0, 1.6, 0))
			for k in mini(lv + 1, 4):
				MeshKit.part(root, "cyl", [0.1, 0.3, 0.14], gold, Vector3(-w * 0.3 + k * 0.4, 0.3, d * 0.42))
		"mutant_pen":
			for k in 8:
				var a2 := k * TAU / 8
				MeshKit.part(root, "cyl", [0.05, 0.8], wood, Vector3(cos(a2) * w * 0.4, 0.45, sin(a2) * d * 0.4))
			MeshKit.part(root, "torus", [w * 0.38, w * 0.42], wood, Vector3(0, 0.75, 0))
			MeshKit.part(root, "sphere", [0.35], MeshKit.mat(Color("#7a3a7a"), 0, 0.6, Color("#d03fd9"), 0.4), Vector3(0, 0.4, 0), Vector3.ZERO, Vector3(1, 0.8, 1.2))
			MeshKit.part(root, "sphere", [0.18], MeshKit.mat(Color("#7a3a7a")), Vector3(0, 0.7, 0.3))
		"research_hall":
			MeshKit.part(root, "box", [w * 0.8, 1.0, d * 0.7], MeshKit.mat(Color("#3a4a6a")), Vector3(0, 0.6, 0), Vector3.ZERO, Vector3.ONE, true)
			MeshKit.part(root, "cyl", [0.3, 0.8], MeshKit.mat(Color("#8d8f94"), 0.9), Vector3(w * 0.2, 1.4, 0))
			MeshKit.part(root, "cyl", [0.06, 0.9], MeshKit.mat(Color("#8d8f94"), 0.9), Vector3(w * 0.2, 2.1, 0), Vector3(0, 0, 35))
			MeshKit.part(root, "sphere", [0.1], MeshKit.mat(Color("#4aa3ff"), 0, 0.1, Color("#4aa3ff"), 2.0), Vector3(-w * 0.25, 1.2, d * 0.3))
		_:
			MeshKit.part(root, "box", [w * 0.7, 1.0, d * 0.7], accent, Vector3(0, 0.6, 0))
	# Level plate / ornaments for high levels
	if lv >= 7 and id != "wall" and id != "trap":
		MeshKit.part(root, "box", [w * 0.94, 0.05, d * 0.94], gold, Vector3(0, 0.13, 0))
	return root


static func _banner(root: Node3D, pos: Vector3, color: Color) -> void:
	MeshKit.part(root, "cyl", [0.025, 0.9], MeshKit.mat(WOOD), pos)
	MeshKit.part(root, "box", [0.45, 0.3, 0.02], MeshKit.mat(color, 0, 0.9), pos + Vector3(0.24, 0.28, 0))


# ------------------------------------------------------------------ battle structures
static func throne(team_color: Color) -> Node3D:
	var root := Node3D.new()
	var stone := MeshKit.mat(STONE, 0, 0.9)
	MeshKit.part(root, "cyl", [1.4, 0.4, 1.6], MeshKit.mat(STONE_DARK), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3.ONE, true)
	MeshKit.part(root, "box", [1.8, 1.6, 1.8], stone, Vector3(0, 1.1, 0), Vector3(0, 45, 0), Vector3.ONE, true)
	for k in 4:
		var a := k * TAU / 4 + PI / 4
		MeshKit.part(root, "cyl", [0.32, 2.6], stone, Vector3(cos(a) * 1.15, 1.3, sin(a) * 1.15), Vector3.ZERO, Vector3.ONE, true)
		MeshKit.part(root, "cone", [0.42, 0.7], MeshKit.mat(team_color.darkened(0.3)), Vector3(cos(a) * 1.15, 2.95, sin(a) * 1.15))
	MeshKit.part(root, "box", [0.9, 1.2, 0.2], MeshKit.mat(Color("#e0b84a"), 1.0, 0.3), Vector3(0, 2.3, 0))
	MeshKit.part(root, "cone", [0.6, 1.2], MeshKit.mat(team_color), Vector3(0, 2.6, 0), Vector3(0, 45, 0))
	_banner(root, Vector3(0, 3.2, 0), team_color)
	return root


static func tower(team_color: Color) -> Node3D:
	var root := Node3D.new()
	var stone := MeshKit.mat(STONE, 0, 0.9)
	MeshKit.part(root, "cyl", [0.7, 2.4, 0.9], stone, Vector3(0, 1.2, 0), Vector3.ZERO, Vector3.ONE, true)
	MeshKit.part(root, "cyl", [0.95, 0.35], MeshKit.mat(STONE_DARK), Vector3(0, 2.5, 0))
	for k in 6:
		var a := k * TAU / 6
		MeshKit.part(root, "box", [0.25, 0.3, 0.25], stone, Vector3(cos(a) * 0.82, 2.8, sin(a) * 0.82))
	MeshKit.part(root, "cone", [0.6, 0.9], MeshKit.mat(team_color.darkened(0.2)), Vector3(0, 3.3, 0))
	return root


static func wall_segment() -> Node3D:
	var root := Node3D.new()
	var stone := MeshKit.mat(STONE, 0, 0.9)
	MeshKit.part(root, "box", [0.9, 1.0, 1.1], stone, Vector3(0, 0.5, 0), Vector3.ZERO, Vector3.ONE, true)
	MeshKit.part(root, "box", [0.3, 0.25, 1.1], stone, Vector3(0, 1.1, 0))
	return root


static func turret() -> Node3D:
	var root := Node3D.new()
	var metal := MeshKit.mat(Color("#8d8f94"), 0.9, 0.35)
	MeshKit.part(root, "cyl", [0.3, 0.4, 0.4], MeshKit.mat(WOOD), Vector3(0, 0.2, 0))
	MeshKit.part(root, "box", [0.4, 0.3, 0.4], metal, Vector3(0, 0.55, 0))
	MeshKit.part(root, "cyl", [0.06, 0.5], metal, Vector3(0, 0.6, 0.3), Vector3(90, 0, 0))
	return root


static func dummy() -> Node3D:
	var root := Node3D.new()
	var straw := MeshKit.mat(Color("#c8a860"), 0, 1)
	MeshKit.part(root, "cyl", [0.05, 1.6], MeshKit.mat(WOOD), Vector3(0, 0.8, 0))
	MeshKit.part(root, "capsule", [0.3, 0.9], straw, Vector3(0, 1.0, 0), Vector3.ZERO, Vector3.ONE, true)
	MeshKit.part(root, "sphere", [0.22], straw, Vector3(0, 1.65, 0))
	MeshKit.part(root, "box", [1.0, 0.1, 0.1], MeshKit.mat(WOOD), Vector3(0, 1.25, 0))
	return root


# ------------------------------------------------------------------ environment
static func environment(world: Node3D, bright := 1.0, warm := true) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#1a1410")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#8a7a6a") if warm else Color("#7a8aa0")
	e.ambient_light_energy = 0.42 * bright
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = Settings.effective_quality() >= 1
	e.fog_light_color = Color("#3a2e24")
	e.fog_density = 0.008
	e.glow_enabled = Settings.effective_quality() >= 2
	e.glow_intensity = 0.6 * Settings.flash_scale()
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("#ffe2b8") if warm else Color("#e0ecff")
	sun.light_energy = 1.05 * bright
	sun.shadow_enabled = Settings.shadows_enabled()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 140, 0)
	fill.light_color = Color("#6a7aa0")
	fill.light_energy = 0.35 * bright
	world.add_child(fill)


static func ground(world: Node3D, size: Vector2, center: Vector3, col := Color("#4a5a2a")) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	m.albedo_texture = _ground_texture(col)
	m.uv1_scale = Vector3(size.x / 4.0, size.y / 4.0, 1)
	mi.material_override = m
	mi.position = center
	world.add_child(mi)
	return mi


static var _ground_tex := {}


static func _ground_texture(col: Color) -> Texture2D:
	var key := col.to_html()
	if _ground_tex.has(key):
		return _ground_tex[key]
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.05
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var n2 := noise.get_noise_2d(x * 4.0, y * 4.0) * 0.5 + 0.5
			var c := Color.WHITE.lerp(Color(0.72, 0.68, 0.6), n * 0.6 + n2 * 0.25)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_ground_tex[key] = tex
	return tex


static func rock(parent: Node3D, pos: Vector3, s: float) -> void:
	MeshKit.part(parent, "sphere", [0.5 * s], MeshKit.mat(Color("#5a544c"), 0, 0.95), pos + Vector3(0, 0.15 * s, 0), Vector3(randf() * 30, randf() * 360, 0), Vector3(1.2, 0.7, 1.0), true)


static func tree(parent: Node3D, pos: Vector3, s: float, dead := false) -> void:
	MeshKit.part(parent, "cyl", [0.08 * s, 1.2 * s, 0.14 * s], MeshKit.mat(Color("#3a2a1a")), pos + Vector3(0, 0.6 * s, 0), Vector3.ZERO, Vector3.ONE, true)
	if dead:
		for k in 3:
			MeshKit.part(parent, "cyl", [0.03 * s, 0.6 * s], MeshKit.mat(Color("#3a2a1a")), pos + Vector3(0, (0.8 + k * 0.2) * s, 0), Vector3(0, k * 120, 50))
	else:
		MeshKit.part(parent, "cone", [0.6 * s, 1.4 * s], MeshKit.mat(Color("#2f4a24"), 0, 0.9), pos + Vector3(0, 1.5 * s, 0), Vector3.ZERO, Vector3.ONE, true)
		MeshKit.part(parent, "cone", [0.45 * s, 1.0 * s], MeshKit.mat(Color("#3a5a2a"), 0, 0.9), pos + Vector3(0, 2.1 * s, 0))


static func torch(parent: Node3D, pos: Vector3) -> void:
	MeshKit.part(parent, "cyl", [0.05, 1.2], MeshKit.mat(Color("#3a2a1a")), pos + Vector3(0, 0.6, 0))
	MeshKit.part(parent, "cone", [0.1, 0.25], MeshKit.mat(Color("#ff8a2b"), 0, 0.3, Color("#ff6a1f"), 3.0), pos + Vector3(0, 1.3, 0))
	if Settings.effective_quality() >= 2:
		var l := OmniLight3D.new()
		l.light_color = Color("#ff9a4a")
		l.light_energy = 1.2
		l.omni_range = 4.0
		l.position = pos + Vector3(0, 1.5, 0)
		parent.add_child(l)
