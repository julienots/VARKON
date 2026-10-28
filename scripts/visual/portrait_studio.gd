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
	e.background_color = Color("#2a2018")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#a09080")
	e.ambient_light_energy = 0.7
	env.environment = e
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.3
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.8
	rim.light_color = Color("#9ab0ff")
	world.add_child(rim)
	var cam := Camera3D.new()
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


func _process_queue() -> void:
	_busy = true
	while not queue.is_empty():
		var id: String = queue.pop_front()
		if cache.has(id):
			continue
		for c in stage.get_children():
			c.free()
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
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := viewport.get_texture().get_image()
		if img:
			var tex := ImageTexture.create_from_image(img)
			cache[id] = tex
			portrait_ready.emit(id, tex)
	_busy = false
