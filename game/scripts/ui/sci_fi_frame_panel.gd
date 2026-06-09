class_name SciFiFramePanel
extends Control

@export var corner_cut: float = 20.0
@export var fill_color: Color = Color(0.035, 0.06, 0.095, 0.9)
@export var border_color: Color = Color("#2e4a62", 0.82)
@export var accent_color: Color = Color("#5ec8ff", 0.92)
@export var inner_glow: Color = Color("#6eb8ff", 0.06)


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var pts := _cut_rect_points()
	if pts.is_empty():
		return
	draw_colored_polygon(pts, fill_color)
	var inset := _cut_rect_points(3.0)
	if not inset.is_empty():
		draw_colored_polygon(inset, inner_glow)
	_draw_polyline(pts, border_color, 1.5)
	_draw_corner_ticks(pts)


func _cut_rect_points(pad: float = 0.0) -> PackedVector2Array:
	var w := size.x - pad * 2.0
	var h := size.y - pad * 2.0
	if w <= corner_cut * 2.0 or h <= corner_cut * 2.0:
		return PackedVector2Array()
	var ox := pad
	var oy := pad
	var c := corner_cut
	return PackedVector2Array([
		Vector2(ox + c, oy),
		Vector2(ox + w - c, oy),
		Vector2(ox + w, oy + c),
		Vector2(ox + w, oy + h - c),
		Vector2(ox + w - c, oy + h),
		Vector2(ox + c, oy + h),
		Vector2(ox, oy + h - c),
		Vector2(ox, oy + c),
	])


func _draw_polyline(pts: PackedVector2Array, color: Color, width: float) -> void:
	if pts.size() < 2:
		return
	for i in range(pts.size()):
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		draw_line(a, b, color, width)


func _draw_corner_ticks(pts: PackedVector2Array) -> void:
	if pts.size() < 8:
		return
	var tick := corner_cut * 0.42
	draw_line(pts[0] + Vector2(-tick, 0), pts[0], accent_color, 2.0)
	draw_line(pts[0] + Vector2(0, -tick), pts[0], accent_color, 2.0)
	draw_line(pts[2], pts[2] + Vector2(tick, 0), accent_color, 2.0)
	draw_line(pts[2], pts[2] + Vector2(0, -tick), accent_color, 2.0)
	draw_line(pts[4] + Vector2(tick, 0), pts[4], accent_color, 2.0)
	draw_line(pts[4] + Vector2(0, tick), pts[4], accent_color, 2.0)
	draw_line(pts[6], pts[6] + Vector2(-tick, 0), accent_color, 2.0)
	draw_line(pts[6], pts[6] + Vector2(0, tick), accent_color, 2.0)
