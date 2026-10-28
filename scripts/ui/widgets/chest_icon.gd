class_name ChestIcon
extends Control
## Vector-drawn chest (body, lid, metal bands, lock) with an opening state.

var color := Color("#8a5a2b")
var lid_open := 0.0


static func make(col: Color, sz := 100) -> ChestIcon:
	var c := ChestIcon.new()
	c.color = col
	c.custom_minimum_size = Vector2(sz, sz)
	c.size = Vector2(sz, sz)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func open_lid() -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		lid_open = v
		queue_redraw(), 0.0, 1.0, 0.25)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var w := s * 0.86
	var x0 := (size.x - w) / 2
	var body_top := s * 0.45
	var dark := color.darkened(0.45)
	var band := Color("#c8b070") if color.v > 0.5 else Color("#a8adb4")
	# Body
	draw_rect(Rect2(x0, body_top, w, s * 0.45), color)
	draw_rect(Rect2(x0, body_top, w, s * 0.45), dark, false, 3.0)
	for bx in [0.12, 0.88]:
		draw_rect(Rect2(x0 + w * bx - s * 0.04, body_top, s * 0.08, s * 0.45), band)
	# Glow when open
	if lid_open > 0:
		var gc := color.lightened(0.6)
		gc.a = 0.6 * lid_open
		draw_rect(Rect2(x0 + 6, body_top - s * 0.05, w - 12, s * 0.08), gc)
	# Lid (rotates up)
	var lid_h := s * 0.25
	var lift := lid_open * s * 0.3
	var lid_rect := Rect2(x0, body_top - lid_h - lift, w, lid_h)
	draw_rect(lid_rect, color.lightened(0.1))
	draw_rect(lid_rect, dark, false, 3.0)
	for bx2 in [0.12, 0.88]:
		draw_rect(Rect2(x0 + w * bx2 - s * 0.04, lid_rect.position.y, s * 0.08, lid_h), band)
	# Lock
	if lid_open < 0.5:
		draw_rect(Rect2(size.x / 2 - s * 0.06, body_top - s * 0.04, s * 0.12, s * 0.14), Color("#ffd23f"))
		draw_circle(Vector2(size.x / 2, body_top + s * 0.04), s * 0.02, dark)
