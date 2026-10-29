class_name BuildingKit
extends RefCounted
## Procedural fortress buildings whose silhouette evolves with level, plus battle structures
## and environment props (ground, rocks, trees, torches).

const STONE := Color("#9a958a")
const STONE_DARK := Color("#726f66")
const WOOD := Color("#8f5a32")
const ROOF := Color("#c9432e")


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
	outline(root)
	return root


## Cartoon contour on the large pieces of a prop/building.
static func outline(root: Node3D, min_size := 0.25) -> void:
	if not MeshKit.outlines_enabled() or not root.has_meta("force_outline"):
		return
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.has_meta("team_ring"):
			continue
		var sz := mi.mesh.get_aabb().size * mi.scale
		if maxf(sz.x, maxf(sz.y, sz.z)) >= min_size:
			mi.material_override = MeshKit.outlined(mi.material_override, 0.025)


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
	outline(root)
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
	# Wooden bands, stone base and a team pennant: warmer, hand-built look
	var wood := MeshKit.mat(WOOD, 0, 1.0)
	MeshKit.part(root, "cyl", [0.76, 0.14, 0.8], wood, Vector3(0, 1.6, 0))
	MeshKit.part(root, "cyl", [0.98, 0.3, 1.05], MeshKit.mat(STONE_DARK, 0, 1.0), Vector3(0, 0.15, 0), Vector3.ZERO, Vector3.ONE, true)
	MeshKit.part(root, "box", [0.36, 0.6, 0.1], wood, Vector3(0, 0.45, 0.82))
	MeshKit.part(root, "cyl", [0.025, 0.8], wood, Vector3(0, 4.0, 0))
	MeshKit.part(root, "box", [0.4, 0.24, 0.02], MeshKit.mat(team_color, 0, 1.0), Vector3(0.21, 4.22, 0))
	outline(root)
	return root


static func wall_segment() -> Node3D:
	var root := Node3D.new()
	var stone := MeshKit.mat(STONE, 0, 0.9)
	MeshKit.part(root, "box", [0.9, 1.0, 1.1], stone, Vector3(0, 0.5, 0), Vector3.ZERO, Vector3.ONE, true)
	MeshKit.part(root, "box", [0.3, 0.25, 1.1], stone, Vector3(0, 1.1, 0))
	outline(root)
	return root


static func turret() -> Node3D:
	var root := Node3D.new()
	var metal := MeshKit.mat(Color("#8d8f94"), 0.9, 0.35)
	MeshKit.part(root, "cyl", [0.3, 0.4, 0.4], MeshKit.mat(WOOD), Vector3(0, 0.2, 0))
	MeshKit.part(root, "box", [0.4, 0.3, 0.4], metal, Vector3(0, 0.55, 0))
	MeshKit.part(root, "cyl", [0.06, 0.5], metal, Vector3(0, 0.6, 0.3), Vector3(90, 0, 0))
	outline(root)
	return root


static func dummy() -> Node3D:
	var root := Node3D.new()
	var straw := MeshKit.mat(Color("#c8a860"), 0, 1)
	MeshKit.part(root, "cyl", [0.05, 1.6], MeshKit.mat(WOOD), Vector3(0, 0.8, 0))
	MeshKit.part(root, "capsule", [0.3, 0.9], straw, Vector3(0, 1.0, 0), Vector3.ZERO, Vector3.ONE, true)
	MeshKit.part(root, "sphere", [0.22], straw, Vector3(0, 1.65, 0))
	MeshKit.part(root, "box", [1.0, 0.1, 0.1], MeshKit.mat(WOOD), Vector3(0, 1.25, 0))
	outline(root)
	return root


# ------------------------------------------------------------------ environment
static var _sky_shader: Shader


static func environment(world: Node3D, bright := 1.0, warm := true, haze := true) -> void:
	## Painted daylight: blue sky with soft clouds, warm low sun, hazy distance.
	var env := WorldEnvironment.new()
	var e := Environment.new()
	if _sky_shader == null:
		_sky_shader = load("res://shaders/painted_sky.gdshader")
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = _sky_shader
	sky_mat.set_shader_parameter("horizon", Color("#9cc4e8"))
	sky_mat.set_shader_parameter("zenith", Color("#2f63b8"))
	if not warm:
		sky_mat.set_shader_parameter("zenith", Color("#3a62a8"))
		sky_mat.set_shader_parameter("cloud_cover", 0.62)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#a9bedc")
	e.ambient_light_energy = 0.36 * bright
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.95
	e.tonemap_white = 1.6
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.22
	e.adjustment_contrast = 1.06
	# Aerial perspective: far scenery fades into a pale blue haze.
	e.fog_enabled = haze and Settings.effective_quality() >= 1
	e.fog_light_color = Color("#b9cfe6")
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_density = 1.0
	e.fog_depth_begin = 38.0
	e.fog_depth_end = 150.0
	e.fog_depth_curve = 1.4
	e.fog_sky_affect = 0.0
	e.glow_enabled = false
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color("#ffe6bf")
	sun.light_energy = 0.95 * bright
	sun.shadow_enabled = Settings.shadows_enabled()
	sun.shadow_opacity = 0.7
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 150, 0)
	fill.light_color = Color("#8fb4ff")
	fill.light_energy = 0.25 * bright
	world.add_child(fill)


## Rich painted grass / earth tone (deep, not neon).
static func vivid(col: Color) -> Color:
	return Color.from_hsv(col.h, clampf(col.s, 0.68, 0.8), clampf(col.v, 0.4, 0.46))


static func ground(world: Node3D, size: Vector2, center: Vector3, col := Color("#4a5a2a")) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	col = vivid(col)
	m.albedo_color = Color.WHITE
	m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.albedo_texture = _ground_texture(col)
	m.uv1_scale = Vector3(size.x / 12.0, size.y / 12.0, 1)
	mi.material_override = m
	mi.position = center
	world.add_child(mi)
	return mi


static var _ground_tex := {}


## Painterly grass: big soft patches of warm/cool greens with small brush flecks.
static func _ground_texture(col: Color) -> Texture2D:
	var key := col.to_html()
	if _ground_tex.has(key):
		return _ground_tex[key]
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.022
	noise.fractal_octaves = 3
	var fleck := FastNoiseLite.new()
	fleck.seed = 11
	fleck.frequency = 0.25
	var warm := Color.from_hsv(col.h - 0.05, col.s * 0.95, col.v * 1.15)
	var cool := Color.from_hsv(col.h + 0.04, col.s, col.v * 0.78)
	var sz := 192
	var img := Image.create(sz, sz, false, Image.FORMAT_RGB8)
	for y in sz:
		for x in sz:
			# Tileable sampling on a torus.
			var ax := x / float(sz) * TAU
			var ay := y / float(sz) * TAU
			var n := noise.get_noise_3d(cos(ax) * 30.0, sin(ax) * 30.0, cos(ay) * 30.0 + sin(ay) * 17.0) * 0.5 + 0.5
			var f := fleck.get_noise_2d(x, y)
			var c := cool.lerp(col, smoothstep(0.2, 0.5, n)).lerp(warm, smoothstep(0.55, 0.8, n))
			if f > 0.55:
				c = c.lightened(0.08)
			elif f < -0.6:
				c = c.darkened(0.08)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_ground_tex[key] = tex
	return tex


static var _field_tex := {}


## Battlefield lawn: the painted grass with soft mowing stripes (4 stripes per 8 m tile).
static func field_texture(col: Color) -> Texture2D:
	var key := col.to_html()
	if _field_tex.has(key):
		return _field_tex[key]
	var base: Image = (_ground_texture(vivid(col.lightened(0.06))) as ImageTexture).get_image()
	base.decompress()
	if base.has_mipmaps():
		base.clear_mipmaps()
	var sz := base.get_width()
	for y in sz:
		for x in sz:
			var stripe := int(x * 4 / sz) % 2 == 0
			var c := base.get_pixel(x, y)
			base.set_pixel(x, y, c.lightened(0.05) if stripe else c.darkened(0.04))
	base.generate_mipmaps()
	var tex := ImageTexture.create_from_image(base)
	_field_tex[key] = tex
	return tex


static func rock(parent: Node3D, pos: Vector3, s: float) -> void:
	var m := MeshKit.mat(Color("#9c968a").lerp(Color("#8a8f98"), randf()), 0, 0.95)
	MeshKit.part(parent, "rocky", [0.5 * s, float(randi() % 5)], m, pos + Vector3(0, 0.12 * s, 0), Vector3(0, randf() * 360, 0), Vector3(1.25, 0.75, 1.0), true)
	if randf() < 0.6:
		MeshKit.part(parent, "rocky", [0.25 * s, float(randi() % 5 + 5)], m, pos + Vector3(0.45 * s, 0.05 * s, 0.2 * s), Vector3(0, randf() * 360, 0), Vector3(1.1, 0.7, 1.0))


const LEAF_COLS := [Color("#2a6226"), Color("#346f28"), Color("#417a2b"), Color("#285a33")]


## Low-poly painted tree: chunky round canopy (oak) or stacked faceted pine.
static func tree(parent: Node3D, pos: Vector3, s: float, dead := false) -> void:
	var trunk := MeshKit.mat(Color("#6b4a2e"), 0, 0.95)
	if dead:
		MeshKit.part(parent, "cyl", [0.06 * s, 1.2 * s, 0.12 * s], trunk, pos + Vector3(0, 0.6 * s, 0), Vector3.ZERO, Vector3.ONE, true)
		for k in 3:
			MeshKit.part(parent, "cyl", [0.03 * s, 0.6 * s], MeshKit.mat(Color("#5e4630")), pos + Vector3(0, (0.8 + k * 0.2) * s, 0), Vector3(0, k * 120, 50))
		return
	var leaf: Color = LEAF_COLS[randi() % LEAF_COLS.size()]
	if randf() < 0.55:
		MeshKit.part(parent, "cyl", [0.09 * s, 1.3 * s, 0.16 * s], trunk, pos + Vector3(0, 0.65 * s, 0), Vector3(0, 0, randf_range(-6, 6)), Vector3.ONE, true)
		var blobs := [[Vector3(0, 1.75, 0), 0.85], [Vector3(0.5, 1.45, 0.2), 0.6], [Vector3(-0.45, 1.5, -0.15), 0.62], [Vector3(0.1, 2.25, -0.1), 0.55]]
		for i in blobs.size():
			var b: Array = blobs[i]
			var lc := leaf.lightened(0.06 * (i % 2)) if i < 3 else leaf.lightened(0.12)
			MeshKit.part(parent, "lowsphere", [b[1] * s, float(i)], MeshKit.mat(lc, 0, 1.0), pos + b[0] * s, Vector3(0, randf() * 360, 0), Vector3(1, 0.85, 1), true)
	else:
		MeshKit.part(parent, "cyl", [0.07 * s, 0.9 * s, 0.11 * s], trunk, pos + Vector3(0, 0.45 * s, 0), Vector3.ZERO, Vector3.ONE, true)
		var pine := leaf.darkened(0.1)
		MeshKit.part(parent, "lowcone", [0.75 * s, 1.3 * s, 1.0], MeshKit.mat(pine, 0, 1.0), pos + Vector3(0, 1.3 * s, 0), Vector3(0, randf() * 360, 0), Vector3.ONE, true)
		MeshKit.part(parent, "lowcone", [0.58 * s, 1.1 * s, 2.0], MeshKit.mat(pine.lightened(0.06), 0, 1.0), pos + Vector3(0, 1.9 * s, 0), Vector3(0, randf() * 360, 0))
		MeshKit.part(parent, "lowcone", [0.38 * s, 0.8 * s, 3.0], MeshKit.mat(pine.lightened(0.12), 0, 1.0), pos + Vector3(0, 2.45 * s, 0), Vector3(0, randf() * 360, 0))


static func bush(parent: Node3D, pos: Vector3, s: float) -> void:
	var c: Color = LEAF_COLS[randi() % LEAF_COLS.size()]
	for k in 3:
		MeshKit.part(parent, "lowsphere", [(0.35 - k * 0.06) * s, float(k + 4)], MeshKit.mat(c.lightened(k * 0.04), 0, 1.0),
			pos + Vector3((k - 1) * 0.3 * s, (0.2 - k * 0.03) * s, randf_range(-0.1, 0.1) * s), Vector3(0, randf() * 360, 0), Vector3(1, 0.8, 1), k == 0)


## Distant scenery ring: faceted blue-green hills/mountains, tree line and tufts of grass.
static func scenery(parent: Node3D, center: Vector3, radius: float, mountains := true) -> void:
	if mountains:
		for k in 14:
			var a := k / 14.0 * TAU + randf_range(-0.1, 0.1)
			var r := radius + randf_range(14, 26)
			var h := randf_range(9, 20)
			var col := Color("#5f7f8e").lerp(Color("#7a93a6"), randf())
			MeshKit.part(parent, "lowcone", [h * randf_range(0.8, 1.1), h, float(k)], MeshKit.mat(col, 0, 1.0),
				center + Vector3(cos(a) * r, h / 2.0 - 1.0, sin(a) * r), Vector3(0, randf() * 360, 0))
			if h > 15:
				MeshKit.part(parent, "lowcone", [h * 0.28, h * 0.27, float(k + 20)], MeshKit.mat(Color("#e8eef4"), 0, 1.0),
					center + Vector3(cos(a) * r, h - 1.0 - h * 0.13, sin(a) * r), Vector3(0, randf() * 360, 0))
		for k in 10:
			var a2 := k / 10.0 * TAU + randf_range(-0.2, 0.2)
			var r2 := radius + randf_range(5, 10)
			MeshKit.part(parent, "lowsphere", [randf_range(5, 8), float(k)], MeshKit.mat(Color("#4f7a3a").lerp(Color("#5d8a48"), randf()), 0, 1.0),
				center + Vector3(cos(a2) * r2, -2.5, sin(a2) * r2), Vector3(0, randf() * 360, 0), Vector3(1.6, 0.6, 1.2))
	grass_tufts(parent, center, radius, 220)


static var _tuft_mesh: Mesh


## Instanced grass tufts (one draw call) for a painted, lived-in ground.
static func grass_tufts(parent: Node3D, center: Vector3, radius: float, count: int, avoid := Rect2()) -> void:
	if Settings.effective_quality() < 1:
		return
	if _tuft_mesh == null:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.07
		cm.height = 0.32
		cm.radial_segments = 4
		cm.rings = 1
		_tuft_mesh = MeshKit.facet(cm)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _tuft_mesh
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var tries := 0
	while xf.size() < count * 3 and tries < count * 12:
		tries += 1
		var p := center + Vector3(randf_range(-radius, radius), 0, randf_range(-radius, radius))
		if avoid.size != Vector2.ZERO and avoid.has_point(Vector2(p.x, p.z)):
			continue
		var gc := Color("#3f7d2a").lerp(Color("#7aa83a"), randf())
		for b in 3:
			var t := Transform3D(Basis.from_euler(Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.35, 0.35))).scaled(Vector3.ONE * randf_range(0.7, 1.3)),
				p + Vector3(randf_range(-0.08, 0.08), 0.12, randf_range(-0.08, 0.08)))
			xf.append(t)
			cols.append(gc)
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.roughness = 1.0
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


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
