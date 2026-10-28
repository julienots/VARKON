class_name KingPreview
extends SubViewportContainer
## Interactive 3D preview of the King Gobelin (drag to rotate). Can show a temporary
## equipment override so the player sees an item before equipping it.

var viewport: SubViewport
var stage: Node3D
var rig: GoblinRig
var yaw := 0.4
var dragging := false
var override_visuals := {}
var override_appearance := {}
var platform_color := Color("#3a5a4a")


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X if Settings.effective_quality() >= 1 else Viewport.MSAA_DISABLED
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#16110d")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#a09080")
	e.ambient_light_energy = 0.55
	e.glow_enabled = Settings.effective_quality() >= 2
	env.environment = e
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 25, 0)
	key.light_energy = 1.2
	key.shadow_enabled = Settings.shadows_enabled()
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 200, 0)
	rim.light_color = Color("#8aa0ff")
	rim.light_energy = 0.9
	world.add_child(rim)
	MeshKit.part(world, "cyl", [0.9, 0.12, 1.0], MeshKit.mat(Color("#4a443e"), 0, 0.9), Vector3(0, -0.06, 0), Vector3.ZERO, Vector3.ONE, true)
	MeshKit.part(world, "torus", [0.85, 0.95], MeshKit.unshaded(UI.GOLD, 0.5), Vector3(0, 0.01, 0)).scale = Vector3(1, 0.2, 1)
	var cam := Camera3D.new()
	cam.fov = 32
	cam.position = Vector3(0, 1.05, 3.6)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.75, 0))
	stage = Node3D.new()
	world.add_child(stage)
	rebuild()


func rebuild() -> void:
	if stage == null:
		return
	for c in stage.get_children():
		c.queue_free()
	var visuals: Dictionary = Game.king.equipped_visuals()
	for k in override_visuals.keys():
		if override_visuals[k] == null:
			visuals.erase(k)
		else:
			visuals[k] = override_visuals[k]
	var app: Dictionary = Game.king.appearance_with_mutations()
	app.merge(override_appearance, true)
	rig = GoblinRig.new().build({"is_king": true, "appearance": app, "visuals": visuals, "scale": 1.0, "detail": 2})
	rig.rotation.y = yaw
	stage.add_child(rig)


func play(anim: String, length := 1.5) -> void:
	if rig:
		rig.play(anim, length)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		yaw += event.relative.x * 0.012
		if rig:
			rig.rotation.y = yaw
