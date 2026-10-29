class_name PortraitStudio
extends Node
## Renders card illustrations from the 3D goblin models into cached textures (one offscreen
## SubViewport, processed as a queue so the UI never stalls).

signal portrait_ready(id: String, tex: Texture2D)

const SIZE := 192

var viewport: SubViewport
var stage: Node3D
var cache := {}
var queue: Array = []
var _busy := false
var env_res: Environment
var cam: Camera3D


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = false
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#5a9ae0")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#b4c6e0")
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 1.6
	env_res = e
	env.environment = e
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.15
	key.light_color = Color("#ffe8c8")
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.8
	rim.light_color = Color("#9ab0ff")
	world.add_child(rim)
	cam = Camera3D.new()
	cam.fov = 30
	cam.position = Vector3(0, 1.05, 2.8)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.74, 0))
	stage = Node3D.new()
	world.add_child(stage)


func get_portrait(id: String) -> Texture2D:
	if cache.has(id):
		return cache[id]
	if DisplayServer.get_name() == "headless":
		return null
	if not id in queue:
		queue.append(id)
	if not _busy:
		_process_queue()
	return null


func _stage_unit(id: String) -> void:
	viewport.transparent_bg = false
	env_res.background_mode = Environment.BG_COLOR
	# Bright family-coloured backdrop (cards read at a glance)
	var fam := str(DB.unit_def(id).get("family", ""))
	env_res.background_color = DB.family_color(fam).lerp(Color("#6a9ad0"), 0.4)
	cam.position = Vector3(0, 1.05, 2.8)
	cam.look_at(Vector3(0, 0.74, 0))
	var rig := GoblinRig.new()
	var p := GoblinRig.card_params(id) if DB.unit_def(id).size() > 0 else {}
	p["detail"] = 2
	p["scale"] = 1.0
	stage.add_child(rig)
	rig.build(p)
	rig.rotation_degrees = Vector3(0, 25, 0)
	rig.set_process(false)
	var bd: Dictionary = DB.unit_def(id)
	var sc := float(bd.get("look", {}).get("scale", 1.0))
	if "wolf_mount" in bd.get("look", {}).get("acc", []):
		sc *= 1.3
	rig.scale = Vector3.ONE / maxf(0.8, sc * 0.85)


## Items: weapons/shields alone and large; other pieces worn by a goblin mannequin.
func _stage_item(id: String) -> void:
	viewport.transparent_bg = true
	env_res.background_mode = Environment.BG_CLEAR_COLOR
	var d: Dictionary = DB.items[id]
	var v: Dictionary = d.visual
	var col := Color(v.get("color", "#888888"))
	var emit := Color(v.emit) if v.has("emit") else Color(0, 0, 0, 0)
	if d.slot in ["right_arm", "left_arm"]:
		var holder := Node3D.new()
		stage.add_child(holder)
		var w := Equipment.weapon(holder, str(v.get("mesh", "")), col, float(v.get("metal", 0)), emit)
		w.rotation_degrees = Vector3(0, 0, -35) if not str(v.get("mesh", "")).begins_with("shield") else Vector3(0, -70, 0)
		BuildingKit.outline(holder, 0.05)
		var aabb := _aabb(holder)
		var c := aabb.get_center()
		var ext := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		holder.scale = Vector3.ONE * (1.3 / maxf(0.2, ext))
		holder.position = -c * holder.scale.x + Vector3(0, 0.74, 0)
	else:
		var rig := GoblinRig.new()
		stage.add_child(rig)
		var vis := {d.slot: v.duplicate()}
		rig.build({"is_king": true, "visuals": vis, "appearance": {}, "detail": 2})
		rig.set_process(false)
		rig.rotation_degrees = Vector3(0, 25, 0)
		var focus_y: float = {"head": 1.1, "eyes": 1.1, "shoulders": 0.9, "torso": 0.75, "belt": 0.55, "legs": 0.35, "feet": 0.2, "back": 0.8, "hands": 0.5, "aura": 0.5, "special": 0.95}.get(str(d.slot), 0.7)
		rig.position = Vector3(0, 0.74 - focus_y * 1.5, 0)
		rig.scale = Vector3.ONE * 1.5
		if d.slot == "back":
			rig.rotation_degrees = Vector3(0, 160, 0)
	cam.position = Vector3(0, 1.0, 2.8)
	cam.look_at(Vector3(0, 0.74, 0))


func _aabb(n: Node3D) -> AABB:
	var first := true
	var box := AABB()
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var t := n.global_transform.affine_inverse() * mi.global_transform if n.is_inside_tree() else mi.transform
		var b: AABB = t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _process_queue() -> void:
	_busy = true
	while not queue.is_empty():
		var id: String = queue.pop_front()
		if cache.has(id):
			continue
		for c in stage.get_children():
			c.free()
		if DB.items.has(id):
			_stage_item(id)
		else:
			_stage_unit(id)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := viewport.get_texture().get_image()
		if img:
			var tex := ImageTexture.create_from_image(img)
			cache[id] = tex
			portrait_ready.emit(id, tex)
	_busy = false
