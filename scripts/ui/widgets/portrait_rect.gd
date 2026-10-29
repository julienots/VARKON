class_name PortraitRect
extends TextureRect
## Card or item picture rendered from the 3D models (filled in when the studio has rendered it).

var portrait_id := ""


static func make(id: String, size := 64) -> PortraitRect:
	var t := PortraitRect.new()
	t.portrait_id = id
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _ready() -> void:
	if Router.portraits == null:
		return
	var tex: Texture2D = Router.portraits.get_portrait(portrait_id)
	if tex:
		texture = tex
	else:
		Router.portraits.portrait_ready.connect(_on_ready)


func _on_ready(id: String, tex: Texture2D) -> void:
	if id == portrait_id:
		texture = tex
