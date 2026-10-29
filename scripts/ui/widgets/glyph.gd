class_name Glyph
extends Control
## Vector icons drawn in code (no emoji/font dependency).

const KINDS := ["bell", "gear", "back", "pause", "smile", "star", "star_empty", "lock", "check", "swords", "flag", "plus", "close", "chest", "info", "bag", "cart", "cards", "castle", "crown"]

var kind := "star"
var color := Color.WHITE


static func make(k: String, sz := 24, col := Color.WHITE) -> Glyph:
	var g := Glyph.new()
	g.kind = k
	g.color = col
	g.custom_minimum_size = Vector2(sz, sz)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2
	var r := s * 0.42
	var w := maxf(2.0, s * 0.09)
	match kind:
		"bell":
			var pts := PackedVector2Array([c + Vector2(-r * 0.75, r * 0.45), c + Vector2(-r * 0.6, -r * 0.2), c + Vector2(-r * 0.35, -r * 0.65), c + Vector2(0, -r * 0.8),
				c + Vector2(r * 0.35, -r * 0.65), c + Vector2(r * 0.6, -r * 0.2), c + Vector2(r * 0.75, r * 0.45)])
			draw_colored_polygon(pts, color)
			draw_circle(c + Vector2(0, r * 0.7), r * 0.18, color)
		"gear":
			for i in 8:
				var a := i * TAU / 8
				draw_line(c, c + Vector2(cos(a), sin(a)) * r, color, w * 1.8)
			draw_circle(c, r * 0.7, color)
			draw_circle(c, r * 0.3, Color(0.13, 0.1, 0.07))
		"back":
			draw_line(c + Vector2(r, 0), c - Vector2(r * 0.8, 0), color, w)
			draw_line(c - Vector2(r * 0.85, 0), c + Vector2(-r * 0.2, -r * 0.65), color, w)
			draw_line(c - Vector2(r * 0.85, 0), c + Vector2(-r * 0.2, r * 0.65), color, w)
		"pause":
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.7), Vector2(r * 0.4, r * 1.4)), color)
			draw_rect(Rect2(c + Vector2(r * 0.2, -r * 0.7), Vector2(r * 0.4, r * 1.4)), color)
		"smile":
			draw_arc(c, r, 0, TAU, 24, color, w, true)
			draw_circle(c + Vector2(-r * 0.35, -r * 0.25), r * 0.12, color)
			draw_circle(c + Vector2(r * 0.35, -r * 0.25), r * 0.12, color)
			draw_arc(c + Vector2(0, r * 0.05), r * 0.5, 0.3, PI - 0.3, 12, color, w, true)
		"star", "star_empty":
			var pts2 := PackedVector2Array()
			for i in 10:
				var a2 := -PI / 2 + i * PI / 5
				pts2.append(c + Vector2(cos(a2), sin(a2)) * (r if i % 2 == 0 else r * 0.45))
			if kind == "star":
				draw_colored_polygon(pts2, color)
			else:
				pts2.append(pts2[0])
				draw_polyline(pts2, color, w * 0.7, true)
		"lock":
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.1), Vector2(r * 1.4, r * 1.0)), color)
			draw_arc(c + Vector2(0, -r * 0.1), r * 0.45, PI, TAU, 12, color, w, true)
		"check":
			draw_line(c + Vector2(-r * 0.7, 0), c + Vector2(-r * 0.15, r * 0.55), color, w * 1.3)
			draw_line(c + Vector2(-r * 0.15, r * 0.55), c + Vector2(r * 0.75, -r * 0.6), color, w * 1.3)
		"swords":
			draw_line(c + Vector2(-r, -r), c + Vector2(r, r), color, w)
			draw_line(c + Vector2(r, -r), c + Vector2(-r, r), color, w)
			draw_line(c + Vector2(-r * 0.6, r * 0.2), c + Vector2(-r * 0.2, r * 0.6), color, w)
			draw_line(c + Vector2(r * 0.6, r * 0.2), c + Vector2(r * 0.2, r * 0.6), color, w)
		"flag":
			draw_line(c + Vector2(-r * 0.6, r), c + Vector2(-r * 0.6, -r), color, w)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r), c + Vector2(r * 0.8, -r * 0.55), c + Vector2(-r * 0.6, -r * 0.1)]), color)
		"plus":
			draw_line(c - Vector2(r, 0), c + Vector2(r, 0), color, w)
			draw_line(c - Vector2(0, r), c + Vector2(0, r), color, w)
		"close":
			draw_line(c - Vector2(r, r) * 0.7, c + Vector2(r, r) * 0.7, color, w)
			draw_line(c + Vector2(r, -r) * 0.7, c + Vector2(-r, r) * 0.7, color, w)
		"chest":
			draw_rect(Rect2(c + Vector2(-r, -r * 0.2), Vector2(r * 2, r * 1.1)), color)
			draw_rect(Rect2(c + Vector2(-r, -r * 0.75), Vector2(r * 2, r * 0.5)), color.darkened(0.3))
			draw_rect(Rect2(c + Vector2(-r * 0.15, -r * 0.35), Vector2(r * 0.3, r * 0.4)), Color("#ffd23f"))
		"bag":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.3), c + Vector2(r * 0.8, -r * 0.3), c + Vector2(r * 0.95, r * 0.9), c + Vector2(-r * 0.95, r * 0.9)]), color)
			draw_arc(c + Vector2(0, -r * 0.35), r * 0.42, PI, TAU, 12, color, w, true)
			draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.05), Vector2(r, r * 0.12)), color.darkened(0.35))
		"cart":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.85, -r * 0.45), c + Vector2(r * 0.95, -r * 0.45), c + Vector2(r * 0.6, r * 0.35), c + Vector2(-r * 0.55, r * 0.35)]), color)
			draw_line(c + Vector2(-r * 1.0, -r * 0.8), c + Vector2(-r * 0.75, -r * 0.45), color, w)
			draw_circle(c + Vector2(-r * 0.4, r * 0.72), r * 0.2, color)
			draw_circle(c + Vector2(r * 0.45, r * 0.72), r * 0.2, color)
		"cards":
			draw_set_transform(c, -0.25, Vector2.ONE)
			draw_rect(Rect2(Vector2(-r * 0.75, -r * 0.85), Vector2(r * 1.1, r * 1.5)), color.darkened(0.3))
			draw_set_transform(c, 0.15, Vector2.ONE)
			draw_rect(Rect2(Vector2(-r * 0.4, -r * 0.8), Vector2(r * 1.1, r * 1.5)), color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"castle":
			draw_rect(Rect2(c + Vector2(-r * 0.9, -r * 0.2), Vector2(r * 1.8, r * 1.1)), color)
			for i in 3:
				draw_rect(Rect2(c + Vector2(-r * 0.9 + i * r * 0.7, -r * 0.55), Vector2(r * 0.4, r * 0.4)), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.25, r * 0.9), c + Vector2(-r * 0.25, r * 0.35), c + Vector2(0, r * 0.15), c + Vector2(r * 0.25, r * 0.35), c + Vector2(r * 0.25, r * 0.9)]), color.darkened(0.45))
		"crown":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.95, r * 0.6), c + Vector2(-r * 0.95, -r * 0.5), c + Vector2(-r * 0.45, r * 0.05), c + Vector2(0, -r * 0.75),
				c + Vector2(r * 0.45, r * 0.05), c + Vector2(r * 0.95, -r * 0.5), c + Vector2(r * 0.95, r * 0.6)]), color)
			draw_rect(Rect2(c + Vector2(-r * 0.95, r * 0.62), Vector2(r * 1.9, r * 0.25)), color.darkened(0.2))
		"info":
			draw_arc(c, r, 0, TAU, 24, color, w, true)
			draw_line(c + Vector2(0, -r * 0.05), c + Vector2(0, r * 0.55), color, w)
			draw_circle(c + Vector2(0, -r * 0.45), w * 0.7, color)
