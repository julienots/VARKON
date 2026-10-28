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
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.metallic = metal
	m.roughness = rough if metal < 0.5 else minf(rough, 0.45)
	if metal > 0.5:
		m.metallic_specular = 0.8
	m.rim_enabled = true
	m.rim = 0.25
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
