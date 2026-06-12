extends Control
class_name NightTdCountdownRing

var ratio := 1.0


func set_ratio(value: float) -> void:
	ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var accent := Color("#6ed08b") if ratio > 0.17 else Color("#e87840")
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	draw_arc(c, r + 3.0, 0.0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.14), 5.0)
	draw_arc(c, r, 0.0, TAU, 48, Color("#1a2838", 0.85), 3.0)
	if ratio > 0.001:
		var start := -PI * 0.5
		var end := start + TAU * ratio
		draw_arc(c, r, start, end, 40, accent, 3.0)
	for i in range(12):
		var a := TAU * float(i) / 12.0
		var p0 := c + Vector2(cos(a), sin(a)) * (r - 4.0)
		var p1 := c + Vector2(cos(a), sin(a)) * (r + 2.0)
		draw_line(p0, p1, Color("#5ec8ff", 0.22), 1.0)
