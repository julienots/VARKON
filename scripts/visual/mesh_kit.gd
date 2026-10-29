class_name MeshKit
extends RefCounted
## Shared primitive meshes and materials (cached so hundreds of parts reuse the same resources).

static var _meshes := {}
static var _mats := {}


static func mat(color: Color, metal := 0.0, rough := 0.75, emit := Color(0, 0, 0, 0), emit_energy := 1.6, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s|%.1f|%.2f" % [color.to_html(), metal, rough, emit.to_html() if emit.a > 0 else "-", emit_energy, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	# Hand-painted look: soft wrapped lambert, matte surfaces, gentle sky-tinted rim.
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.metallic = metal * 0.5
	m.roughness = clampf(rough, 0.6, 1.0) if metal < 0.5 else 0.4
	m.metallic_specular = 0.4 if metal > 0.5 else 0.2
	m.rim_enabled = true
	m.rim = 0.12
	m.rim_tint = 0.6
	if emit.a > 0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_energy
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


static var _outlined := {}
static var _outline_mats := {}


## Same material with a dark "inverted hull" outline pass (cartoon contour).
static func outlined(m: Material, width := 0.008) -> Material:
	if m == null or not m is StandardMaterial3D or (m as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return m
	if (m as StandardMaterial3D).next_pass != null:
		return m  # already outlined
	var key := [m, width]
	if _outlined.has(key):
		return _outlined[key]
	var om: StandardMaterial3D = _outline_mats.get(width)
	if om == null:
		om = StandardMaterial3D.new()
		om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		om.albedo_color = Color("#1c2414")
		om.cull_mode = BaseMaterial3D.CULL_FRONT
		om.grow = true
		om.grow_amount = width
		_outline_mats[width] = om
	var c: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
	c.next_pass = om
	_outlined[key] = c
	return c


static func outlines_enabled() -> bool:
	return Settings.effective_quality() >= 1


static func unshaded(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var key := "U%s%.2f" % [color.to_html(), alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


static func mesh(shape: String, a := 1.0, b := 1.0, c := 1.0) -> Mesh:
	var key := "%s|%.3f|%.3f|%.3f" % [shape, a, b, c]
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh
	match shape:
		"box":
			var bm := BoxMesh.new()
			bm.size = Vector3(a, b, c)
			m = bm
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = a
			sm.height = a * 2.0
			sm.radial_segments = 16
			sm.rings = 8
			m = sm
		"hemi":
			var hm := SphereMesh.new()
			hm.radius = a
			hm.height = a
			hm.is_hemisphere = true
			hm.radial_segments = 16
			hm.rings = 6
			m = hm
		"capsule":
			var cm := CapsuleMesh.new()
			cm.radius = a
			cm.height = maxf(b, a * 2.0 + 0.01)
			cm.radial_segments = 12
			cm.rings = 4
			m = cm
		"cyl":
			var cy := CylinderMesh.new()
			cy.top_radius = a
			cy.bottom_radius = c if c != 1.0 else a
			cy.height = b
			cy.radial_segments = 12
			cy.rings = 1
			m = cy
		"cone":
			var co := CylinderMesh.new()
			co.top_radius = 0.0
			co.bottom_radius = a
			co.height = b
			co.radial_segments = 10
			co.rings = 1
			m = co
		"torus":
			var tm := TorusMesh.new()
			tm.inner_radius = a
			tm.outer_radius = b
			tm.rings = 20
			tm.ring_segments = 8
			m = tm
		"prism":
			var pm := PrismMesh.new()
			pm.size = Vector3(a, b, c)
			m = pm
		"quad":
			var qm := QuadMesh.new()
			qm.size = Vector2(a, b)
			m = qm
		"lowsphere", "rocky":
			var ls := SphereMesh.new()
			ls.radius = a
			ls.height = a * 2.0
			ls.radial_segments = 7
			ls.rings = 4
			m = facet(ls, 0.18 * a if shape == "rocky" else 0.06 * a, int(b * 97.0))
		"lowcone":
			var lc := CylinderMesh.new()
			lc.top_radius = 0.0
			lc.bottom_radius = a
			lc.height = b
			lc.radial_segments = 7
			lc.rings = 2
			m = facet(lc, 0.05 * a, int(c * 31.0))
		"disc":
			var dm := CylinderMesh.new()
			dm.top_radius = a
			dm.bottom_radius = a
			dm.height = 0.02
			dm.radial_segments = 32
			dm.rings = 1
			m = dm
	_meshes[key] = m
	return m


## Low-poly faceted copy of a mesh: per-face normals plus optional vertex jitter
## (stylised painted-scenery look for foliage, rocks and mountains).
static func facet(src: Mesh, jitter := 0.0, seed_v := 0) -> ArrayMesh:
	var arr: Array = src.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + seed_v
	# Jitter shared positions consistently so faces stay closed.
	var moved := {}
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var count := idx.size() if idx.size() > 0 else verts.size()
	for t in range(0, count, 3):
		var tri: Array[Vector3] = []
		for k in 3:
			var v: Vector3 = verts[idx[t + k] if idx.size() > 0 else t + k]
			if jitter > 0.0:
				var key := Vector3i(roundi(v.x * 1000), roundi(v.y * 1000), roundi(v.z * 1000))
				if not moved.has(key):
					moved[key] = v + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.6), rng.randf_range(-1, 1)) * jitter
				v = moved[key]
			tri.append(v)
		var n := (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
		if n == Vector3.ZERO:
			continue
		if n.dot(tri[0] + tri[1] + tri[2]) < 0.0:  # convex source: normals point away from origin
			n = -n
		for k in 3:
			out_v.append(tri[k])
			out_n.append(n)
	var a2 := []
	a2.resize(Mesh.ARRAY_MAX)
	a2[Mesh.ARRAY_VERTEX] = out_v
	a2[Mesh.ARRAY_NORMAL] = out_n
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
	return am


static func part(parent: Node3D, shape: String, dims: Array, material: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE, shadow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(shape, dims[0] if dims.size() > 0 else 1.0, dims[1] if dims.size() > 1 else 1.0, dims[2] if dims.size() > 2 else 1.0)
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow and Settings.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func pivot(parent: Node3D, pos := Vector3.ZERO, pname := "") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	if pname != "":
		n.name = pname
	parent.add_child(n)
	return n
