class_name ResIcon
extends Control
## Vector-drawn resource icons (no external art needed, crisp at any scale).

var res_id := "gold"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := Vector2(size.x / 2, size.y / 2)
	var r := s * 0.45
	var col := DB.resource_color(res_id)
	var dark := col.darkened(0.45)
	match res_id:
		"gold":
			draw_circle(c, r, dark)
			draw_circle(c, r * 0.82, col)
			draw_circle(c - Vector2(r * 0.2, r * 0.2), r * 0.3, col.lightened(0.4))
			draw_string(UI.font("display"), c + Vector2(-r * 0.32, r * 0.42), "V", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 1.1), dark)
		"crystals":
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.8, -r * 0.2)])
			draw_colored_polygon(pts, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, -r * 0.05)]), col.lightened(0.45))
			draw_polyline(pts + PackedVector2Array([pts[0]]), dark, 2.0, true)
		"fragments":
			for i in 3:
				var o := Vector2(cos(i * 2.1) * r * 0.45, sin(i * 2.1) * r * 0.45)
				var p2 := PackedVector2Array([c + o + Vector2(0, -r * 0.5), c + o + Vector2(r * 0.35, 0), c + o + Vector2(0, r * 0.5), c + o + Vector2(-r * 0.35, 0)])
				draw_colored_polygon(p2, col if i != 1 else col.lightened(0.3))
		"components":
			draw_circle(c, r * 0.95, dark)
			for i in 8:
				var a := i * PI / 4
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.5, c + Vector2(cos(a), sin(a)) * r * 0.98, col, r * 0.3)
			draw_circle(c, r * 0.62, col)
			draw_circle(c, r * 0.25, dark)
		"mutant_essence":
			# Teardrop: lower half-circle plus an apex on top
			var pts2 := PackedVector2Array()
			var cc := c + Vector2(0, r * 0.25)
			for i in 13:
				var a2 := i / 12.0 * PI
				pts2.append(cc + Vector2(cos(a2), sin(a2)) * r * 0.65)
			pts2.append(c + Vector2(0, -r))
			draw_colored_polygon(pts2, col)
			draw_circle(cc + Vector2(-r * 0.2, -r * 0.05), r * 0.16, col.lightened(0.5))
		"war_tokens":
			var sh := PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.8), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)])
			draw_colored_polygon(sh, col)
			draw_polyline(sh + PackedVector2Array([sh[0]]), dark, 2.0, true)
			draw_line(c + Vector2(-r * 0.4, -r * 0.4), c + Vector2(r * 0.4, r * 0.3), Color.WHITE, 2.0)
			draw_line(c + Vector2(r * 0.4, -r * 0.4), c + Vector2(-r * 0.4, r * 0.3), Color.WHITE, 2.0)
		"ancestral":
			draw_circle(c, r, dark)
			draw_arc(c, r * 0.8, 0, TAU, 32, col, 2.0, true)
			var star := PackedVector2Array()
			for i in 10:
				var a3 := -PI / 2 + i * PI / 5
				var rr2 := r * (0.7 if i % 2 == 0 else 0.3)
				star.append(c + Vector2(cos(a3), sin(a3)) * rr2)
			draw_colored_polygon(star, col)
		_:
			draw_circle(c, r, col)
